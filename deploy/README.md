# Rapyd Sentinel — split architecture PoC

A proof-of-concept of Rapyd Sentinel's split architecture: two isolated VPCs,
one EKS cluster per VPC, private cross-VPC connectivity, and a proxy in the
public-facing cluster forwarding to an internal service in the private one.
Built with Terraform (via Terragrunt) and deployed through GitHub Actions.

## Layout

```
deploy/
  modules/            Terraform modules: vpc, eks, karpenter, vpc-peering
  terragrunt/          Terragrunt units wiring the modules together
    root.hcl            shared backend/provider config, account+region derived from path
    dev/us-east-1/
      network/
        vpcs/vpc-backend, vpcs/vpc-gateway
        peering/          VPC peering + cross-VPC security group rule
      platform/eks/
        eks-backend/cluster, eks-backend/karpenter
        eks-gateway/cluster, eks-gateway/karpenter
helm/
  hello-backend/      the backend's "Hello from backend" service
  gateway-proxy/       the gateway's nginx reverse proxy
scripts/
  setup-github-oidc.sh   one-time GitHub Actions OIDC bootstrap (not run by CI)
.github/workflows/terraform.yml   the whole CI/CD pipeline
```

## How to run it

Everything runs through the GitHub Actions pipeline; there is deliberately no
"run this locally" path for apply (see CI/CD section — this was a hard
requirement, not a default).

1. Set two repository variables: `AWS_TERRAFORM_ROLE_ARN` (an IAM role the
   GitHub OIDC provider can assume, with permission to create `eks-*` and
   `sentinel-*` prefixed roles plus the VPC/EKS/EC2 resources below) and
   confirm the OIDC identity provider trust is set up for
   `token.actions.githubusercontent.com` on that account.
2. Push to a branch and open a PR: the pipeline validates and runs
   `terragrunt run --all --non-interactive -- plan` (read-only, no
   credentials needed for a fork PR).
3. Merge to `main`: the pipeline applies the full Terraform stack in
   dependency order (VPCs → EKS clusters → Karpenter → peering), then
   installs both Helm charts and validates the proxy actually reaches the
   backend.

(Commands here are for Terragrunt 1.x. `run-all <cmd>` became
`run --all -- <cmd>`, and `render-json`/`hclfmt` became `render --format=json`
and `hcl fmt` respectively — Terragrunt 1.0 renamed most of its CLI surface;
see the CI/CD section for the full set this repo actually depends on,
verified against the real 1.1.6 binary, not assumed from release notes.)

To iterate locally without applying anything: `terragrunt plan` inside any
unit under `deploy/terragrunt/dev/us-east-1/`, or `terragrunt render --format=json`
to inspect what a unit resolves to. Both are safe, read-only(-ish, `plan` can
create the S3 state bucket on first use) operations used throughout this
repo's own development.

## Networking: how the two VPCs and clusters connect

- **`vpc-backend`** (`10.1.0.0/16`): two private subnets across two AZs, plus
  two small public subnets that exist *only* to give a NAT gateway
  somewhere to live — no workload ever runs there. Without them the
  backend's nodes would have zero internet egress at all (no path to pull
  images or reach the EKS API), since a NAT gateway isn't an EC2 instance
  and accepts no inbound traffic, this doesn't conflict with "no public
  EC2s."
- **`vpc-gateway`** (`10.0.0.0/16`): two public and two private subnets.
  Public subnets host the gateway's own NAT and the public NLB in front of
  the proxy; EKS nodes still only ever run in the private subnets.
- **VPC peering** (`deploy/modules/vpc-peering`): one
  `aws_vpc_peering_connection` (`auto_accept = true`, same account/region, so
  no separate accepter resource is needed), plus a route in every private
  route table on both sides pointing the other VPC's CIDR at the peering
  connection.
- **Cross-VPC security group rule**: an ingress rule on the backend node
  security group, allowing TCP on port 80 from `vpc-gateway`'s node security
  group specifically — not its whole CIDR, not the internet, and not even
  all of the backend VPC. AWS supports referencing a security group from a
  peer VPC directly for same-region peering, so the peering unit takes a
  dependency on both `eks-backend/cluster` and `eks-gateway/cluster` for
  their respective node security group IDs.

## How the proxy talks to the backend

1. The backend's Helm chart (`helm/hello-backend`) exposes its
   `hashicorp/http-echo` pod through a Kubernetes `Service` of
   `type: LoadBalancer` with the AWS **internal**-scheme annotations. A plain
   `ClusterIP` would only be reachable inside the backend cluster's own pod
   network; the internal NLB gets a real ENI with a private IP inside
   `vpc-backend`'s subnets, reachable from the peered `vpc-gateway` over the
   peering connection and the security group rule above.
2. The internal NLB's hostname is only known after that chart is installed,
   so the gateway chart (`helm/gateway-proxy`) takes it as a required
   Helm value (`backendHostname`, no usable default — the render fails
   loudly if it's missing) and templates it directly into nginx's
   `proxy_pass`. This is the "configure DNS resolution, not hardcoded IPs"
   requirement: nginx addresses the backend by its DNS name, resolved fresh
   via CoreDNS → the VPC resolver → AWS's own DNS for the NLB's hostname,
   never a literal IP written into config by hand.
3. CI passes the real hostname in with `--set backendHostname=...` after
   polling the backend Service's status for it (see CI section).
4. The gateway's own public NLB (`gateway-proxy` Service) is the only thing
   in the whole setup meant to be reachable from the internet.

**A real gotcha this design has to account for:** nginx resolves
`proxy_pass` hostnames once at startup and caches the result for the pod's
lifetime; it does not re-resolve on a TTL. That means a plain redeploy of
the backend (a new internal NLB, a new hostname) would leave already-running
gateway-proxy pods silently talking to the old, possibly-deleted backend
forever, since nothing would otherwise tell them to restart. The
`gateway-proxy` Deployment carries the standard Helm `checksum/config` pod
annotation, a hash of the rendered `configmap.yaml`, so a changed hostname
(which now lives directly in that file) forces a rollout.

**Related, unfixed, and worth knowing:** even within a single pod's
lifetime, if the backend's internal NLB's *same* hostname ever resolves to
a different underlying IP (AWS reserves the right to rotate these, which is
exactly why hardcoding an ELB's IP instead of its DNS name is normally the
thing to avoid), nginx still won't notice without a restart, since it
cached the resolved IP, not just the hostname. The standard fix is an
explicit `resolver` directive pointing at CoreDNS's ClusterIP plus a
variable-based `proxy_pass` (forcing per-request re-resolution instead of
resolve-once-at-startup), left out here because reliably discovering that
ClusterIP without hardcoding it adds real complexity for a lower-probability
issue than the redeploy case above.

## Security model / NetworkPolicy

Kubernetes `NetworkPolicy` was **not** implemented — it's explicitly called
out as optional in the assignment, and with the 3-day scope already covering
two VPCs, two clusters, peering, cross-VPC SGs, two Helm charts, and a
multi-stage CI/CD pipeline, it was cut deliberately rather than accidentally.
The next step there would be a default-deny `NetworkPolicy` in the `backend`
namespace, allowing ingress only from pods carrying a label the ingress path
actually needs (which, notably, none currently do — since traffic arrives via
an AWS NLB terminating on the node, not via another in-cluster pod, the
policy would need to allow the node's own IP range rather than a pod
selector, worth designing carefully rather than adding as an afterthought).

IAM roles follow the assignment's required prefixes: `eks-` for every EKS
cluster and node role (cluster role, node group role, Karpenter's controller
and node roles), enforced via `iam_role_name`/`iam_role_use_name_prefix` (or
exact names where a `name_prefix` would exceed IAM's 38-character limit —
see the comments in `deploy/modules/eks/main.tf` and
`deploy/modules/karpenter/main.tf`). No `sentinel-`-prefixed role currently
exists in this PoC: nothing here needs its own IAM role outside of EKS/node
provisioning (the apps use no AWS APIs), so the prefix is documented but
unused, not skipped.

## CI/CD pipeline

One workflow, one job, sequential steps (splitting into multiple jobs with
artifact-passed outputs would be the natural next step for a bigger
pipeline, see "What's next"):

1. **Lint/validate, no credentials needed**: `terraform fmt -check`,
   `terraform validate` per module,
   `terragrunt hcl fmt --check --working-dir deploy/terragrunt`, `helm lint`
   on both charts, and `helm template | kubeconform -strict` on both charts'
   rendered output.
   - `kubeval` is archived/unmaintained; `kubeconform` is its actively
     maintained successor with the same job (schema-validate against the
     Kubernetes OpenAPI spec, no live cluster needed), used in its place.
   - Terraform modules deliberately carry no `required_providers` of their
     own — Terragrunt generates one shared block into every unit at
     plan/apply time (`root.hcl`'s `generate "versions"`), and a module can
     only have one such block. Standalone `terraform validate` therefore
     needs that same block supplied temporarily; the workflow writes it as
     `ci_versions.tf` (not dot-prefixed — confirmed by testing that
     Terraform silently skips dotfiles when scanning for `*.tf`), validates,
     then deletes it, never committing it.
2. **OIDC auth**: `aws-actions/configure-aws-credentials` assumes
   `AWS_TERRAFORM_ROLE_ARN` via GitHub's OIDC provider — no long-lived AWS
   keys stored anywhere (the assignment's optional bonus).
3. **Plan (PRs) or apply (push to `main`)**:
   `terragrunt run --all --non-interactive -- plan|apply` from the account
   root (Terragrunt 1.x renamed `run-all <cmd>` to `run --all -- <cmd>`).
   Terragrunt's `dependency` blocks encode the real graph (VPCs → EKS
   clusters → Karpenter/peering), so `run --all` applies everything in the
   right order automatically — confirmed directly against this repo's own
   dependency graph, including that a failure in one unit correctly cascades
   to and skips its dependents rather than plowing ahead. PRs only ever
   plan, so a PR from an untrusted fork can never apply anything for real.
4. **Deploy** (push only): `aws eks update-kubeconfig` for both clusters
   under distinct `kubectl` contexts, then wait for Karpenter's own
   Deployment to be ready on both clusters before touching the apps at all.
   Both apps land on Karpenter-provisioned nodes — the only other node
   group is tainted `CriticalAddonsOnly`, off-limits to regular pods — and
   `terraform apply` installing Karpenter's `helm_release` only means "the
   Deployment object exists," not "the controller is up and reconciling."
   Skipping this wait risks deploying an app before anything can actually
   provision it a node. Then `helm upgrade --install` for the backend chart
   (`--wait --timeout 6m`, generous enough to cover a cold first-time
   Karpenter node launch: notice the pending pod, request and launch a new
   EC2 instance, join the cluster, bring the CNI up, only then schedule the
   pod), poll the resulting internal NLB for a hostname (Helm's `--wait`
   tracks pod readiness, not an async AWS load balancer provisioning, so
   this has to be polled separately), then `helm upgrade --install` the
   gateway chart with that hostname.
5. **Validate**: poll the gateway's public NLB for a hostname, then `curl`
   it and check the response actually contains `Hello from backend` — a
   real end-to-end check that the peering, routing, security group rule,
   and both charts all actually work together, not just that each piece
   applied without error.

## Trade-offs, given the time limit

- **Terraform CLI is pinned at 1.5.7, not the actual latest (1.16.4).**
  HashiCorp relicensed Terraform from open-source MPL 2.0 to BUSL starting
  at 1.6.0. 1.5.7 is the last MPL release, and staying on it reads as a
  deliberate choice already baked into this repo, not an oversight — so
  every other tool here (Terragrunt, kubeconform, the
  `terraform-aws-modules` registry modules, the Karpenter chart, container
  images, GitHub Actions, the EKS-supported Kubernetes version) was bumped
  to its real current latest, verified against the actual registry/API/
  changelog for each rather than assumed, but this one specifically was
  left alone pending an explicit call on the license question.
- **Single NAT gateway per VPC**, not one per AZ. Cheaper, and an
  acceptable availability trade-off for a PoC; a NAT outage would only
  affect new outbound connections from whichever AZ it sits in, not
  existing traffic. `one_nat_gateway_per_az` is a one-line flag flip in
  either `vpc-backend`'s or `vpc-gateway`'s `terragrunt.hcl` if that
  trade-off isn't acceptable later.
- **No Terraform state locking.** The deploy account's identity hit a real
  `dynamodb:DescribeTable` permission denial trying to use a DynamoDB lock
  table, and per the assignment's own instruction ("If you encounter a
  permission limitation, do not attempt to bypass it") the response was to
  remove the lock table requirement rather than work around the denial,
  documented in `root.hcl`. This is fine today because nothing runs `apply`
  outside the single CI pipeline (concurrency-limited to one run per branch
  already), but real locking (Terraform ≥ 1.10's native S3 `use_lockfile`,
  no DynamoDB needed) should come back before more than one entry point can
  run `apply`.
- **The system node group's AMI release version is pinned for this account,
  not looked up dynamically.** Same root cause: the deploy identity lacks
  `ssm:GetParameter` on the AWS-published EKS AMI parameter — confirmed by
  testing, and this is the account actually used for the deployment, not a
  disposable one. `deploy/modules/eks/variables.tf`'s
  `system_node_ami_release_version` defaults to `null`, the module's normal
  dynamic SSM lookup, and only `eks-backend/cluster` and
  `eks-gateway/cluster`'s own `terragrunt.hcl` set it explicitly to a real
  value sourced from AWS's public `amazon-eks-ami` GitHub releases (not
  invented). Trade-off: this needs a manual bump by hand on every future
  Kubernetes/AMI version change, instead of always tracking AWS's latest
  build automatically, for as long as this account's SSM restriction
  stands.
- **One CI job, sequential steps**, not split into parallel/dependent jobs
  with artifacts. Simpler to reason about for a 3-day scope; splitting it
  (e.g. a `terraform` job, then a `deploy-backend` job, then a
  `deploy-gateway` job depending on it) would parallelize the lint/validate
  work and make the pipeline's own structure mirror the infrastructure's
  dependency graph more explicitly.
- **No custom container images / registry.** Both apps run stock images
  (`hashicorp/http-echo`, `nginxinc/nginx-unprivileged`) configured entirely
  through Helm values and a ConfigMap. This sidesteps needing a build-and-push CI
  stage or a registry at all, a reasonable scope cut since the assignment's
  actual bulleted requirements never mandate a custom image (only the
  Background section's flavor text mentions a registry).
- **The nginx proxy does not run with `readOnlyRootFilesystem: true`**,
  unlike the backend's `http-echo` container. It runs non-root
  (`nginxinc/nginx-unprivileged`, `runAsNonRoot: true`), but still needs to
  write to its default cache/run paths, and locking the root filesystem
  down would mean adding `emptyDir` volumes for those specific paths.
  Deferred as a smaller remaining hardening step, not attempted here.

## Cost notes

- NAT gateways are the dominant fixed cost here (two, one per VPC, each
  billed hourly plus per-GB processed) — `single_nat_gateway = true` on both
  already halves what `one_nat_gateway_per_az` would cost.
- Two EKS control planes (a fixed hourly cost each, independent of node
  count) is inherent to the two-cluster architecture the assignment asks
  for, not something to optimize away here.
- The `system` node groups use `t3.small` by default (see
  `deploy/modules/eks/variables.tf`), sized for running just the system
  add-ons and Karpenter, not application workloads. Karpenter is provisions
  the actual workload capacity on demand instead of a statically-sized
  second node group, and defaults to spot-first (`karpenter.sh/capacity-type
  In [spot, on-demand]`), which is the main lever for keeping application
  compute cheap.
- Both load balancers are NLBs (Layer 4, cheaper and simpler than an ALB),
  appropriate since neither needs L7 routing, TLS termination, or
  path-based rules for this PoC.

## What's next

- **TLS/mTLS**: terminate TLS at the gateway's NLB (ACM cert on an ALB, or a
  TLS-passthrough NLB with cert-manager inside the cluster) for the public
  edge, and mTLS or at least VPC-scoped security groups (already partly
  there) for the gateway-to-backend hop.
- **Ingress controller**: replace the bare `LoadBalancer` Services with the
  AWS Load Balancer Controller and a real `Ingress`/`Gateway API` resource
  once there's more than one route to expose.
- **Observability**: metrics-server plus Prometheus/Grafana or AWS Managed
  Prometheus, and centralized logging (Fluent Bit → CloudWatch or an
  aggregator), neither of which exists yet.
- **GitOps**: Argo CD or Flux watching `helm/*` instead of CI
  directly running `helm upgrade`, so cluster state is reconciled
  continuously rather than only on push.
- **NetworkPolicy**: as described above.
- **Service mesh**: only worth it once there are more than two services;
  noted as an option, not a gap, at this scale.
- **Secrets management**: nothing here handles secrets today (neither app
  needs any); Vault or AWS Secrets Manager plus the Secrets Store CSI
  driver would be the addition point once one does.
- **Split the CI pipeline into dependent jobs** for parallelism and clearer
  failure isolation, as noted in trade-offs.
- **Real state locking**, once more than one entry point can run `apply`.
