include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/deploy/modules/karpenter"
}

locals {
  path_parts = split("/", path_relative_to_include("root"))
  aws_region = local.path_parts[1]
  name       = basename(dirname(get_terragrunt_dir()))
}

dependency "cluster" {
  config_path                             = "../cluster"
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    cluster_endpoint = "https://mock-eks-backend.eks.us-east-1.amazonaws.com"
  }
}

inputs = {
  cluster_name     = "rapyd-${local.aws_region}-${local.name}"
  cluster_endpoint = dependency.cluster.outputs.cluster_endpoint
}
