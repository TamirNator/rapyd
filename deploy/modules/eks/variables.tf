variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "ID of the VPC hosting the EKS cluster"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs for EKS control plane and nodes"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Whether the EKS Kubernetes API endpoint is publicly accessible"
  type        = bool
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Whether to grant the cluster creator administrator permissions"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to EKS resources"
  type        = map(string)
  default     = {}
}

variable "node_ami_type" {
  description = "AMI type for EKS managed node groups"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "system_node_instance_types" {
  description = "EC2 instance types for the bootstrap system node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "system_node_min_size" {
  description = "Minimum size of the bootstrap system node group"
  type        = number
  default     = 2
}

variable "system_node_max_size" {
  description = "Maximum size of the bootstrap system node group"
  type        = number
  default     = 4
}

variable "system_node_desired_size" {
  description = "Desired size of the bootstrap system node group"
  type        = number
  default     = 2
}
