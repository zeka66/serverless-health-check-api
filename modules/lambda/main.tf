// CORE REQUIREMENT: a Python function triggered by the /health endpoint.

data "archive_file" "package" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.build/${var.function_name}.zip"

  excludes = ["__pycache__", "*.pyc", "requirements.txt"]
}

resource "aws_cloudwatch_log_group" "lambda" {
  # Created explicitly rather than letting Lambda auto-create it, so retention
  # is managed as code and the execution role does not need
  # logs:CreateLogGroup.
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = "Health check endpoint: logs the request and stores it in DynamoDB"

  role    = var.role_arn
  handler = "handler.handler"
  runtime = var.runtime

  filename = data.archive_file.package.output_path
  # Redeploys only when the source actually changes, not on every apply.
  source_code_hash = data.archive_file.package.output_base64sha256

  memory_size = var.memory_mb
  timeout     = var.timeout_seconds

  # Caps blast radius and spend if the endpoint is flooded.
  reserved_concurrent_executions = var.reserved_concurrency

  environment {
    variables = {
      TABLE_NAME  = var.table_name
      ENVIRONMENT = var.environment
      TTL_DAYS    = tostring(var.item_ttl_days)
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}
