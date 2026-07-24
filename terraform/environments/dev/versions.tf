terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Local state for this assessment — see README "Production Considerations"
  # for why a remote backend (S3 + DynamoDB lock table) is the right call
  # once more than one person or CI job touches this state.
  # backend "local" {} is the implicit default when no backend block is set.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
