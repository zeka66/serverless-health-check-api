// CORE REQUIREMENT: an endpoint exposing /health for GET and POST, with
// throttling to blunt DDoS attempts.
//
// REST API (v1) rather than HTTP API (v2). Both satisfy the requirement; v1
// is chosen because the optional extras that would come next - gateway-level
// request validation and native API keys - exist only on v1, so this avoids
// rewriting the endpoint later. See the README for the trade-off.

resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = "Health check API for ${var.environment}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    # Replace before removing, so a forced replacement does not leave the
    # endpoint unreachable between destroy and create.
    create_before_destroy = true
  }
}

resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "health"
}

locals {
  http_methods = toset(["GET", "POST"])
}

resource "aws_api_gateway_method" "health" {
  for_each = local.http_methods

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = each.value
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "health" {
  for_each = local.http_methods

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health[each.value].http_method

  # AWS_PROXY integrations are always invoked with POST regardless of the
  # client's method; the client's method is carried inside the event.
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn

  timeout_milliseconds = var.integration_timeout_ms
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # Scoped to this API and this path only, not to any caller in the service.
  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*/health"
}

# ---------------------------------------------------------------------------
# Deployment and stage
# ---------------------------------------------------------------------------

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Forces a redeployment whenever the routing surface changes; without this a
  # config change would apply cleanly but never reach the live stage.
  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.health,
      aws_api_gateway_method.health,
      aws_api_gateway_integration.health,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "access_logs" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access_logs.arn

    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationErr = "$context.integration.error"
    })
  }
}

# ---------------------------------------------------------------------------
# CORE REQUIREMENT: throttling. Applied at the stage so it covers every caller
# and every method on the endpoint.
# ---------------------------------------------------------------------------

resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false # Would write full request bodies to logs.
  }
}
