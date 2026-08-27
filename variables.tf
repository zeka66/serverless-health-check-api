variable "environment" {
  type = string
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be one of: staging, prod."
  }
}

variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "project_name" {
  type    = string
  default = "serverless-health-check-api"
}

variable "repository" {
  type = string
}

variable "allowed_account_ids" {
  type    = list(string)
  default = []
}

# Environment-specific defaults (staging, prod).

variable "lambda_memory_mb" {
  type    = number
  default = 128
}

variable "lambda_timeout_seconds" {
  type    = number
  default = 15
}

variable "lambda_reserved_concurrency" {
  type    = number
  default = 5
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "item_ttl_days" {
  type    = number
  default = 20
}

variable "throttling_rate_limit" {
  type    = number
  default = 20
}

variable "throttling_burst_limit" {
  type    = number
  default = 30
}
