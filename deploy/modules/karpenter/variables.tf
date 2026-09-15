variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint of the EKS Kubernetes API"
  type        = string
}

variable "karpenter_chart_version" {
  description = "Karpenter Helm chart version"
  type        = string
}

variable "tags" {
  description = "Tags applied to Karpenter resources"
  type        = map(string)
  default     = {}
}

variable "karpenter_replicas" {
  description = "Number of Karpenter controller replicas"
  type        = number
  default     = 2
}

variable "karpenter_cpu_request" {
  description = "CPU request for the Karpenter controller"
  type        = string
  default     = "1"
}

variable "karpenter_memory_request" {
  description = "Memory request for the Karpenter controller"
  type        = string
  default     = "1Gi"
}

variable "karpenter_cpu_limit" {
  description = "CPU limit for the Karpenter controller"
  type        = string
  default     = "1"
}

variable "karpenter_memory_limit" {
  description = "Memory limit for the Karpenter controller"
  type        = string
  default     = "1Gi"
}

variable "karpenter_node_volume_size" {
  description = "Root volume size for Karpenter-provisioned nodes"
  type        = string
  default     = "50Gi"
}

variable "karpenter_node_expire_after" {
  description = "Maximum lifetime of a Karpenter-provisioned node"
  type        = string
  default     = "720h"
}

variable "karpenter_node_pool_cpu_limit" {
  description = "Total CPU limit for the Karpenter node pool"
  type        = string
  default     = "200"
}

variable "karpenter_node_pool_memory_limit" {
  description = "Total memory limit for the Karpenter node pool"
  type        = string
  default     = "200Gi"
}

variable "karpenter_consolidate_after" {
  description = "How long Karpenter waits before consolidating nodes"
  type        = string
  default     = "5m"
}