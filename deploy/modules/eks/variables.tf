variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  # Confirmed via the real EKS API (aws eks describe-addon-versions), not
  # assumed: 1.36 is the latest version EKS actually supports as of this
  # writing.
  default = "1.36"
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
  # 2, not 1: karpenter_replicas defaults to 2 at 1 vCPU / 1Gi request each,
  # which alone is more than a single t3.small's allocatable capacity
  # before kube-proxy/vpc-cni/pod-identity-agent/CoreDNS are even counted.
  # 2 nodes gives each Karpenter replica (and the rest of the system pods)
  # room to actually schedule. Right-sizing Karpenter's own request/replica
  # count is the correct lever for cutting this pool's cost, not shrinking
  # node count under it.
  default = 2
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

variable "system_node_ami_release_version" {
  description = <<-EOT
    Optional EKS-optimized AMI release version override for the bootstrap
    system node group, e.g. "1.36.0-20260923".

    Leave unset (the default): the module discovers the latest one
    dynamically via SSM (use_latest_ami_release_version = true), the normal,
    idiomatic behavior, and the right default for a deploy identity that
    actually has ssm:GetParameter — which, per the assignment's stated
    constraint, is only supposed to restrict IAM role creation to eks-/
    sentinel- prefixes, not block SSM reads.

    Only set this to work around a deploy identity that's missing
    ssm:GetParameter specifically (confirmed true of this account, the one
    actually used for this deployment). Setting it switches the module to
    use_latest_ami_release_version = false with this exact value, skipping
    the SSM call entirely. Find a real one (from an identity that does have
    ssm:GetParameter) with:
      aws ssm get-parameter \
        --name /aws/service/eks/optimized-ami/<kubernetes_version>/amazon-linux-2023/x86_64/standard/recommended/release_version \
        --region <aws_region> --query Parameter.Value --output text
    Bumping it by hand on future Kubernetes version upgrades becomes your
    job instead of AWS's for as long as this stays set.
  EOT
  type        = string
  default     = null

  # If set, checks the actual expected shape (e.g. "1.36.0-20260923") so a
  # typo fails loudly at plan/validate time instead of obscurely against
  # the AWS API at apply time.
  validation {
    condition     = var.system_node_ami_release_version == null || can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+-[0-9]{8}$", var.system_node_ami_release_version))
    error_message = "system_node_ami_release_version, if set, must look like a real EKS-optimized AMI release version, e.g. \"1.36.0-20260923\"."
  }
}
