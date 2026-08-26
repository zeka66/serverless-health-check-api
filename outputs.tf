output "health_endpoint" {
  description = "Full URL of the deployed /health endpoint."
  value       = module.api_gateway.health_endpoint
}

output "dynamodb_table_name" {
  description = "Name of the request store table."
  value       = module.dynamodb.table_name
}

output "lambda_function_name" {
  description = "Name of the deployed Lambda function."
  value       = module.lambda.function_name
}

output "lambda_log_group" {
  description = "CloudWatch log group for the function."
  value       = module.lambda.log_group_name
}

output "lambda_role_arn" {
  description = "ARN of the least-privilege execution role."
  value       = module.iam.role_arn
}

output "curl_example" {
  description = "Ready-to-run smoke test command."
  value = format(
    "curl -i -X POST '%s' -H 'content-type: application/json' -d '{\"payload\":{\"source\":\"manual-test\"}}'",
    module.api_gateway.health_endpoint
  )
}
