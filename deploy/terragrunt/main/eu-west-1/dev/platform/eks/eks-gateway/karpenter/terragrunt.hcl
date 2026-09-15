include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = find_in_parent_folders("_envcommon/karpenter.hcl")
}

dependency "cluster" {
  config_path = "../cluster"
}

inputs = {
  cluster_endpoint = dependency.cluster.outputs.cluster_endpoint
}