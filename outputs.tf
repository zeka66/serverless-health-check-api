output "health_endpoint" {
  value = module.api_gateway.health_endpoint
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "lambda_log_group" {
  value = module.lambda.log_group_name
}

output "lambda_role_arn" {
  value = module.iam.role_arn
}

output "curl_example" {
  value = format(
    "curl -i -X POST '%s' -H 'content-type: application/json' -d '{\"payload\":{\"source\":\"manual-test\"}}'",
    module.api_gateway.health_endpoint
  )
}
