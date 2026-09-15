variable "vpc_name" {
  description = "Name for the VPC and its resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "az_count" {
  description = "Number of available AZs to use for the VPC"
  type        = number
  default     = 2
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways for private subnet egress"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all AZs instead of one per AZ. Cheaper, less resilient. Prefer false in prod."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources in the VPC"
  type        = map(string)
  default     = {}
}
