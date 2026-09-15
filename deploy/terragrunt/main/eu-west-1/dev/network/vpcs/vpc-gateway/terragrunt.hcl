include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = find_in_parent_folders("_envcommon/vpc.hcl")
}

# Gateway domain: public-facing services and proxy layer.
inputs = {
  vpc_cidr = "10.0.0.0/16"
  az_count = 2

  public_subnets  = ["10.0.0.0/20", "10.0.16.0/20"]
  private_subnets = ["10.0.128.0/20", "10.0.144.0/20"]

  enable_nat_gateway = true
}