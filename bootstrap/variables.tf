variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "state_bucket_name" {
  type = string
}

variable "github_repository" {
  type = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be my-org/my-repo."
  }
}

variable "github_oidc_thumbprints" {
  type = list(string)
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

variable "allowed_account_ids" {
  type    = list(string)
  default = []
}
