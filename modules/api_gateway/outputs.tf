output "invoke_url" {
  description = "Base invoke URL of the deployed stage."
  value       = aws_api_gateway_stage.this.invoke_url
}

output "health_endpoint" {
  description = "Full URL of the /health endpoint."
  value       = "${aws_api_gateway_stage.this.invoke_url}/health"
}

output "rest_api_id" {
  description = "ID of the REST API."
  value       = aws_api_gateway_rest_api.this.id
}

output "stage_name" {
  description = "Name of the deployed stage."
  value       = aws_api_gateway_stage.this.stage_name
}
