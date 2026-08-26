variable "environment" {
  description = "Deployment environment. Used as the prefix for every resource name."
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be one of: staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project identifier, used in tags."
  type        = string
  default     = "serverless-health-check-api"
}

variable "repository" {
  description = "Source repository, used in tags for traceability."
  type        = string
  default     = "github.com/OWNER/REPO"
}

variable "allowed_account_ids" {
  description = <<-EOT
    Guard rail. If set, Terraform refuses to run against any other AWS account.
    Recommended when the same machine has work profiles configured: a wrong
    AWS_PROFILE then fails immediately instead of deploying somewhere it
    should not. Empty list disables the check.
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Per-environment sizing and limits. These are the values that legitimately
# differ between staging and prod, which is what the .tfvars files set.
# ---------------------------------------------------------------------------

variable "lambda_memory_mb" {
  description = "Memory allocated to the Lambda function."
  type        = number
  default     = 256
}

variable "lambda_timeout_seconds" {
  description = "Lambda execution timeout."
  type        = number
  default     = 10
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrent executions. -1 disables reservation, required on accounts with a low concurrency quota."
  type        = number
  default     = -1
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 14
}

variable "item_ttl_days" {
  description = "Days after which stored request items expire via DynamoDB TTL."
  type        = number
  default     = 30
}

variable "throttling_rate_limit" {
  description = "Steady-state request rate (req/s) allowed on the stage. Core DDoS control."
  type        = number
  default     = 20
}

variable "throttling_burst_limit" {
  description = "Burst capacity allowed on the stage."
  type        = number
  default     = 40
}
