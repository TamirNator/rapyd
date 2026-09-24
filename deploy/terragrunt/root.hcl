locals {
  path_parts = split("/", path_relative_to_include("root"))

  account_name = local.path_parts[0]
  aws_region   = local.path_parts[1]
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket  = "rapyd-tfstate-${get_aws_account_id()}"
    key     = "${path_relative_to_include("root")}/terraform.tfstate"
    region  = local.aws_region
    encrypt = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"

      default_tags {
        tags = {
          Account   = "${local.account_name}"
          ManagedBy = "terragrunt"
        }
      }
    }
  EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.5.0"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = ">= 5.0"
        }
        helm = {
          source  = "hashicorp/helm"
          version = ">= 2.0"
        }
        kubectl = {
          source  = "gavinbunney/kubectl"
          version = ">= 1.14"
        }
      }
    }
  EOF
}

inputs = {
  aws_region = local.aws_region

  tags = {
    Account   = local.account_name
    ManagedBy = "terragrunt"
  }
}
