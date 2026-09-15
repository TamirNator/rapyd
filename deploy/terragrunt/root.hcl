locals {
  path_parts = split("/", path_relative_to_include("root"))
  depth      = length(local.path_parts)

  account_name = local.path_parts[0]
  aws_region   = local.path_parts[1]
  environment  = local.path_parts[2]
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket         = "rapyd-tfstate-${get_aws_account_id()}"
    key            = "${path_relative_to_include("root")}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "rapyd-tf-locks"
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
          Account     = "${local.account_name}"
          Environment = "${local.environment}"
          ManagedBy   = "terragrunt"
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
          version = "~> 5.0"
        }
      }
    }
  EOF
}

# Merges with each unit's own `inputs` (and any envcommon inputs in between);
# the most specific one wins on conflicting keys.
inputs = {
  environment = local.environment
  aws_region  = local.aws_region

  tags = {
    Account     = local.account_name
    Environment = local.environment
    ManagedBy   = "terragrunt"
  }
}
