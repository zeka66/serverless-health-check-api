variable "function_name" {
  description = "Name of the Lambda function (already env-prefixed)."
  type        = string
}

variable "environment" {
  description = "Environment name, passed to the function as ENVIRONMENT."
  type        = string
}

variable "source_dir" {
  description = "Directory containing the Lambda source."
  type        = string
}

variable "role_arn" {
  description = "ARN of the execution role."
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name, passed to the function as TABLE_NAME."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "python3.12"
}

variable "memory_mb" {
  description = "Memory allocated to the function."
  type        = number
  default     = 256
}

variable "timeout_seconds" {
  description = "Function timeout."
  type        = number
  default     = 10
}

variable "reserved_concurrency" {
  description = "Reserved concurrent executions."
  type        = number
  default     = 5
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 14
}

variable "item_ttl_days" {
  description = "TTL in days for stored items."
  type        = number
  default     = 30
}
