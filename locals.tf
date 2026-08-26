data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Single source of truth for the env-resource-name convention required by
  # the brief. Every resource name is derived from this prefix, so no
  # environment string is ever hardcoded in a module.
  name_prefix = var.environment

  function_name = "${local.name_prefix}-health-check-function"
  table_name    = "${local.name_prefix}-requests-db"
  api_name      = "${local.name_prefix}-health-check-api"
  role_name     = "${local.name_prefix}-health-check-lambda-role"

  # Constructed rather than referenced, to keep the IAM module free of a
  # dependency cycle with the Lambda it grants access to.
  lambda_log_group_arn = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.function_name}"
}
