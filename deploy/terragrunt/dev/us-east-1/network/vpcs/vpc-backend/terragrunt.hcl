include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/deploy/modules/vpc"
}

locals {
  path_parts = split("/", path_relative_to_include("root"))
  aws_region = local.path_parts[1]
  name       = basename(get_terragrunt_dir())
}

# Backend domain: internal services and sensitive workloads only. No
# workload ever runs in the public subnets below; they exist solely to give
# the NAT gateway a home, since nodes still need egress to pull images and
# reach the EKS API. A NAT gateway is not an EC2 instance and accepts no
# inbound traffic, so this doesn't conflict with "no public EC2s".
inputs = {
  vpc_name = "rapyd-${local.aws_region}-${local.name}"

  vpc_cidr = "10.1.0.0/16"
  az_count = 2

  public_subnets  = ["10.1.0.0/24", "10.1.16.0/24"]
  private_subnets = ["10.1.128.0/20", "10.1.144.0/20"]

  # Single NAT rather than one per AZ: this is a POC, and the cost/resilience
  # trade-off is documented in the README.
  enable_nat_gateway = true
  single_nat_gateway = true

  # Karpenter's EC2NodeClass discovers launchable subnets by this tag
  # (confirmed by a real apply: without it, Karpenter fails with "no
  # subnets found" and never provisions any node). The cluster name is
  # computed directly rather than via a dependency on the eks-backend
  # unit — it's a fully deterministic string, matching the same
  # rapyd-<region>-<unit-name> pattern every other unit already derives.
  private_subnet_tags = {
    "karpenter.sh/discovery" = "rapyd-${local.aws_region}-eks-backend"
  }
}
