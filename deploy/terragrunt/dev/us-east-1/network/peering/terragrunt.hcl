include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/deploy/modules/vpc-peering"
}

# Gateway is the "requester": it's the side that initiates traffic toward
# the backend (the proxy calling the internal backend service), so the
# ingress rule this module creates lives on the backend's node security
# group, scoped to the gateway's own node security group specifically.
dependency "vpc_gateway" {
  config_path = "../vpcs/vpc-gateway"

  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    vpc_id                  = "vpc-00000000000000001"
    vpc_cidr_block          = "10.0.0.0/16"
    private_route_table_ids = ["rtb-00000000000000001"]
  }
}

dependency "vpc_backend" {
  config_path = "../vpcs/vpc-backend"

  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    vpc_id                  = "vpc-00000000000000000"
    vpc_cidr_block          = "10.1.0.0/16"
    private_route_table_ids = ["rtb-00000000000000000"]
  }
}

dependency "eks_backend_cluster" {
  config_path = "../../platform/eks/eks-backend/cluster"

  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    node_security_group_id = "sg-00000000000000000"
  }
}

# Needed so the ingress rule can reference the requester's actual node
# security group instead of its whole VPC CIDR.
dependency "eks_gateway_cluster" {
  config_path = "../../platform/eks/eks-gateway/cluster"

  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    node_security_group_id = "sg-00000000000000002"
  }
}

inputs = {
  name = "vpc-peering-gateway-backend"

  requester_vpc_id                 = dependency.vpc_gateway.outputs.vpc_id
  requester_cidr                   = dependency.vpc_gateway.outputs.vpc_cidr_block
  requester_route_table_ids        = dependency.vpc_gateway.outputs.private_route_table_ids
  requester_node_security_group_id = dependency.eks_gateway_cluster.outputs.node_security_group_id

  accepter_vpc_id                 = dependency.vpc_backend.outputs.vpc_id
  accepter_cidr                   = dependency.vpc_backend.outputs.vpc_cidr_block
  accepter_route_table_ids        = dependency.vpc_backend.outputs.private_route_table_ids
  accepter_node_security_group_id = dependency.eks_backend_cluster.outputs.node_security_group_id

  # The backend "Hello from backend" web server's port.
  allowed_port = 80
}
