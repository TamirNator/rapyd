include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = find_in_parent_folders("_envcommon/vpc.hcl")
}

# Backend domain: internal services and sensitive workloads only.
inputs = {
  vpc_cidr = "10.1.0.0/16"
  az_count = 2

  public_subnets  = []
  private_subnets = ["10.1.128.0/20", "10.1.144.0/20"]

  enable_nat_gateway = false
}