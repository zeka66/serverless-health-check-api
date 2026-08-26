variable "api_name" {
  description = "Name of the REST API (already env-prefixed)."
  type        = string
}

variable "environment" {
  description = "Environment name, also used as the stage name."
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda to integrate with."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function, for the invoke permission."
  type        = string
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second allowed on the stage."
  type        = number
  default     = 20
}

variable "throttling_burst_limit" {
  description = "Burst capacity allowed on the stage."
  type        = number
  default     = 40
}

variable "integration_timeout_ms" {
  description = "Integration timeout in milliseconds."
  type        = number
  default     = 15000
}

variable "log_retention_days" {
  description = "Access log retention in days."
  type        = number
  default     = 14
}
