terraform {
  # >= 1.10 is required for native S3 state locking (use_lockfile), which
  # removes the need for a separate DynamoDB lock table.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Refuse to operate against any account not listed. Guards against a wrong
  # AWS_PROFILE on a machine that also has work credentials configured.
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = var.repository
    }
  }
}
