variable "name_prefix" {
  description = "Environment prefix for resource naming."
  type        = string
}

variable "role_name" {
  description = "Name of the Lambda execution role."
  type        = string
}

variable "function_name" {
  description = "Name of the Lambda function this role is scoped to."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "log_group_arn" {
  description = "ARN of the function's CloudWatch log group."
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table the function writes to."
  type        = string
}
