variable "requester_vpc_id" {
  description = "VPC ID initiating the peering connection"
  type        = string
}

variable "requester_cidr" {
  description = "CIDR block of the requester VPC"
  type        = string
}

variable "requester_route_table_ids" {
  description = "Route table IDs in the requester VPC that need a route to the accepter"
  type        = list(string)
}

variable "accepter_vpc_id" {
  description = "VPC ID accepting the peering connection"
  type        = string
}

variable "accepter_cidr" {
  description = "CIDR block of the accepter VPC"
  type        = string
}

variable "accepter_route_table_ids" {
  description = "Route table IDs in the accepter VPC that need a route to the requester"
  type        = list(string)
}

variable "accepter_node_security_group_id" {
  description = "Security group ID shared by the accepter side's EKS nodes, so the requester side can be allow-listed into it"
  type        = string
}

variable "requester_node_security_group_id" {
  description = "Security group ID shared by the requester side's EKS nodes. Referenced directly (not its CIDR) in the accepter's ingress rule: AWS supports referencing a peer VPC's security group ID for same-region peering, which scopes access to the actual nodes making the request, not every host in that VPC's whole CIDR block."
  type        = string
}

variable "allowed_port" {
  description = "TCP port on the accepter side's nodes that the requester side is allowed to reach"
  type        = number
}

variable "name" {
  description = "Name for the peering connection and its tags"
  type        = string
}

variable "tags" {
  description = "Tags applied to peering resources"
  type        = map(string)
  default     = {}
}
