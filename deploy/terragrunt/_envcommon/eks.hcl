locals {
  path_parts = split("/", path_relative_to_include("root"))
  depth      = length(local.path_parts)

  aws_region  = local.path_parts[local.depth - 6]
  environment = local.path_parts[local.depth - 5]
  component   = local.path_parts[local.depth - 2]
}

terraform {
  source = "${get_repo_root()}/deploy/modules/eks"
}

inputs = {
  cluster_name = "rapyd-${local.environment}-${local.aws_region}-${local.component}"
}