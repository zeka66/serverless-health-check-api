terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Deliberately no backend block: this stack creates the state backend, so it
  # keeps local state.
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = {
      Project   = "serverless-health-check-api"
      Component = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}
