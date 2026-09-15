locals {
  path_parts = split("/", path_relative_to_include("root"))
  depth      = length(local.path_parts)

  aws_region  = local.path_parts[local.depth - 5]
  environment = local.path_parts[local.depth - 4]
  component   = local.path_parts[local.depth - 1]
}

terraform {
  source = "${get_repo_root()}/deploy/modules/vpc"
}

inputs = {
  vpc_name = "rapyd-${local.environment}-${local.aws_region}-${local.component}"
}