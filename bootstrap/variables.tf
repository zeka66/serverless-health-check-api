variable "aws_region" {
  description = "AWS region for the bootstrap resources."
  type        = string
  default     = "eu-north-1"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in OWNER/REPO form. Scopes who may assume the deploy roles."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be in OWNER/REPO form."
  }
}

variable "github_oidc_thumbprints" {
  description = "Root CA thumbprints for GitHub's OIDC provider."
  type        = list(string)
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

variable "allowed_account_ids" {
  description = "Guard rail: refuse to run against any other AWS account. Empty disables."
  type        = list(string)
  default     = []
}
