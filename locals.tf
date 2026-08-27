data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id           = data.aws_caller_identity.current.account_id
  region               = data.aws_region.current.name
  name_prefix          = var.environment
  function_name        = "${local.name_prefix}-health-check-function"
  table_name           = "${local.name_prefix}-requests-db"
  api_name             = "${local.name_prefix}-health-check-api"
  role_name            = "${local.name_prefix}-health-check-lambda-role"
  lambda_log_group_arn = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.function_name}"
}
