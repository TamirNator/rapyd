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

# Gateway domain: public-facing services and proxy layer.
inputs = {
  vpc_name = "rapyd-${local.aws_region}-${local.name}"

  vpc_cidr = "10.0.0.0/16"
  az_count = 2

  public_subnets  = ["10.0.0.0/20", "10.0.16.0/20"]
  private_subnets = ["10.0.128.0/20", "10.0.144.0/20"]

  enable_nat_gateway = true
  private_subnet_tags = {
    "karpenter.sh/discovery" = "rapyd-${local.aws_region}-eks-gateway"
  }
}
