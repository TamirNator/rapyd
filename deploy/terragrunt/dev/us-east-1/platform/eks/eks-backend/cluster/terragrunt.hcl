include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/deploy/modules/eks"
}

locals {
  path_parts = split("/", path_relative_to_include("root"))
  account    = local.path_parts[0]
  aws_region = local.path_parts[1]
  name       = basename(dirname(get_terragrunt_dir()))
}

dependency "vpc" {
  config_path                             = "${get_repo_root()}/deploy/terragrunt/${local.account}/${local.aws_region}/network/vpcs/vpc-backend"
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    private_subnets = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
}

inputs = {
  cluster_name = "rapyd-${local.aws_region}-${local.name}"

  vpc_id          = dependency.vpc.outputs.vpc_id
  private_subnets = dependency.vpc.outputs.private_subnets

  # Real apply confirmed a genuine architecture-vs-tooling conflict: a
  # fully private API endpoint means GitHub Actions runners (public
  # internet hosts, no network path into vpc-backend) can never reach it
  # to run helm/kubectl against this cluster at all — not just for
  # Karpenter, but for the actual hello-backend deploy too, since that's
  # the same CI job talking to the same API server. This doesn't weaken
  # the requirement that actually matters here (the backend *application*
  # staying off the internet): hello-backend still sits behind a purely
  # internal NLB regardless of this setting. This only affects reachability
  # of the EKS control-plane management API, still gated by IAM auth on
  # top of network access — a public endpoint grants no access by itself.
  endpoint_public_access = true
}
