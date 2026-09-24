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

  vpc_id                 = dependency.vpc.outputs.vpc_id
  private_subnets        = dependency.vpc.outputs.private_subnets
  endpoint_public_access = true
}
