include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/deploy/modules/karpenter"
}

locals {
  path_parts = split("/", path_relative_to_include("root"))
  aws_region = local.path_parts[1]
  # One level up: this unit's sibling "cluster" unit shares this same name.
  name = basename(dirname(get_terragrunt_dir()))
}

dependency "cluster" {
  config_path = "../cluster"

  # Lets `plan`/`validate` (never `apply`) succeed before the cluster has
  # actually been applied, e.g. a fresh `run-all plan` in CI.
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    cluster_endpoint = "https://mock-eks-gateway.eks.us-east-1.amazonaws.com"
  }
}

inputs = {
  cluster_name     = "rapyd-${local.aws_region}-${local.name}"
  cluster_endpoint = dependency.cluster.outputs.cluster_endpoint
}
