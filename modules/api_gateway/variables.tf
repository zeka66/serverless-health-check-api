variable "api_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_invoke_arn" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "throttling_rate_limit" {
  type    = number
  default = 20
}

variable "throttling_burst_limit" {
  type    = number
  default = 30
}

variable "integration_timeout_ms" {
  type    = number
  default = 10000
}

variable "log_retention_days" {
  type    = number
  default = 10
}
