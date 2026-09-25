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

  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    cluster_endpoint                   = "https://mock-eks-gateway.eks.us-east-1.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
  }
}

generate "k8s_providers" {
  path      = "k8s_providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "helm" {
      kubernetes = {
        host                   = "${dependency.cluster.outputs.cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.cluster.outputs.cluster_certificate_authority_data}")
        token                  = data.aws_eks_cluster_auth.this.token
      }
    }

    provider "kubectl" {
      host                   = "${dependency.cluster.outputs.cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.cluster.outputs.cluster_certificate_authority_data}")
      token                  = data.aws_eks_cluster_auth.this.token
      load_config_file       = false
    }
  EOF
}

inputs = {
  cluster_name     = "rapyd-${local.aws_region}-${local.name}"
  cluster_endpoint = dependency.cluster.outputs.cluster_endpoint
}
