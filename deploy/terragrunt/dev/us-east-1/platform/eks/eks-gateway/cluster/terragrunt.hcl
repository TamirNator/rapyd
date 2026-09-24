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
  # One level up: "cluster" and its sibling "karpenter" unit share this name.
  name = basename(dirname(get_terragrunt_dir()))
}

dependency "vpc" {
  # Absolute, built from the same derived account/region this file already
  # computes, not a relative ../../../.. climb: this survives the eks unit
  # itself moving to a different nesting depth without silently pointing at
  # the wrong directory.
  config_path = "${get_repo_root()}/deploy/terragrunt/${local.account}/${local.aws_region}/network/vpcs/vpc-gateway"

  # Lets `plan`/`validate` (never `apply`) succeed before vpc-gateway has
  # actually been applied, e.g. a fresh `run-all plan` in CI.
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    vpc_id          = "vpc-00000000000000001"
    private_subnets = ["subnet-00000000000000003", "subnet-00000000000000004"]
  }
}

inputs = {
  cluster_name = "rapyd-${local.aws_region}-${local.name}"

  vpc_id          = dependency.vpc.outputs.vpc_id
  private_subnets = dependency.vpc.outputs.private_subnets

  endpoint_public_access = true
}
