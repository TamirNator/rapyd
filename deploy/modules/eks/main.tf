module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access                   = var.endpoint_public_access
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # Exact name, not a prefix: AWS caps name_prefix at 38 chars (it reserves
  # the rest for its own random suffix, 64 total), and cluster_name here is
  # long enough (env-region-component) that a prefixed name blew past that.
  # Exact names go up to 64 chars, comfortable headroom for these.
  iam_role_name            = "eks-${var.cluster_name}-cluster"
  iam_role_use_name_prefix = false

  addons = {
    coredns = {
      configuration_values = jsonencode({
        tolerations = [
          { key = "CriticalAddonsOnly", operator = "Exists", effect = "NoSchedule" }
        ]
      })
    }
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni = {
      before_compute = true
    }
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  eks_managed_node_groups = {
    system = {
      ami_type       = var.node_ami_type
      instance_types = var.system_node_instance_types

      min_size     = var.system_node_min_size
      max_size     = var.system_node_max_size
      desired_size = var.system_node_desired_size

      # Normal, idiomatic behavior by default: look up the latest AMI via
      # SSM. Only switches to a pinned, manually-bumped value when
      # system_node_ami_release_version is explicitly set, e.g. for a
      # deploy identity that lacks ssm:GetParameter (see that variable's
      # description).
      use_latest_ami_release_version = var.system_node_ami_release_version == null
      ami_release_version            = var.system_node_ami_release_version

      iam_role_name            = "eks-${var.cluster_name}-system"
      iam_role_use_name_prefix = false

      labels = { "role" = "system" }

      taints = {
        critical = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = var.tags
}