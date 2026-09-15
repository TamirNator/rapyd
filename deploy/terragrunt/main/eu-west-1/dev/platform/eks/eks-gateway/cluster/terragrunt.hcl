include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = find_in_parent_folders("_envcommon/eks.hcl")
}

dependency "vpc" {
  config_path = "../../../../network/vpcs/vpc-gateway"
}

inputs = {
  vpc_id          = dependency.vpc.outputs.vpc_id
  private_subnets = dependency.vpc.outputs.private_subnets

  endpoint_public_access = true
}