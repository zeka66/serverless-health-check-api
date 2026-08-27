
data "archive_file" "package" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.build/${var.function_name}.zip"
  excludes    = ["__pycache__", "*.pyc", "requirements.txt"]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  function_name                  = var.function_name
  role                           = var.role_arn
  handler                        = "handler.handler"
  runtime                        = var.runtime
  filename                       = data.archive_file.package.output_path
  source_code_hash               = data.archive_file.package.output_base64sha256
  memory_size                    = var.memory_mb
  timeout                        = var.timeout_seconds
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
