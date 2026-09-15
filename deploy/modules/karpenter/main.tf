module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = var.cluster_name

  enable_pod_identity             = true
  create_pod_identity_association = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = "kube-system"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version

  values = [yamlencode({
    settings = {
      clusterName       = var.cluster_name
      clusterEndpoint   = var.cluster_endpoint
      interruptionQueue = module.karpenter.queue_name
    }
    nodeSelector = { "role" = "system" }
    tolerations  = [{ key = "CriticalAddonsOnly", operator = "Exists" }]
    replicas     = var.karpenter_replicas
    controller = {
      resources = {
        requests = {
          cpu    = var.karpenter_cpu_request
          memory = var.karpenter_memory_request
        }
        limits = {
          cpu    = var.karpenter_cpu_limit
          memory = var.karpenter_memory_limit
        }
      }
    }
  })]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata   = { name = "default" }
    spec = {
      amiFamily                  = "AL2023"
      role                       = module.karpenter.node_iam_role_name
      amiSelectorTerms           = [{ alias = "al2023@latest" }]
      subnetSelectorTerms        = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
      securityGroupSelectorTerms = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
      metadataOptions = {
        httpTokens              = "required"
        httpPutResponseHopLimit = 1
      }
      blockDeviceMappings = [{
        deviceName = "/dev/xvda"
        ebs = {
          volumeSize          = var.karpenter_node_volume_size
          volumeType          = "gp3"
          encrypted           = true
          deleteOnTermination = true
        }
      }]
      tags = var.tags
    }
  })
  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "default" }
    spec = {
      template = {
        spec = {
          nodeClassRef = { group = "karpenter.k8s.aws", kind = "EC2NodeClass", name = "default" }
          expireAfter  = var.karpenter_node_expire_after
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot", "on-demand"] },
            { key = "karpenter.k8s.aws/instance-category", operator = "In", values = ["t"] },
            { key = "karpenter.k8s.aws/instance-generation", operator = "Gt", values = ["3"] },
          ]
        }
      }
      limits = {
        cpu    = var.karpenter_node_pool_cpu_limit
        memory = var.karpenter_node_pool_memory_limit
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = var.karpenter_consolidate_after
      }
    }
  })

  depends_on = [kubectl_manifest.karpenter_node_class]
}