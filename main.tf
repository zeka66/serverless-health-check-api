// Composition root. Module order reflects the dependency chain:
//   dynamodb -> iam -> lambda -> api_gateway

# --- CORE: request store, encrypted at rest -------------------------------
module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = local.table_name
  # Guard real data in prod; staging must stay disposable.
  deletion_protection_enabled = var.environment == "prod"
}

# --- CORE: least-privilege execution role ---------------------------------
module "iam" {
  source = "./modules/iam"

  name_prefix   = local.name_prefix
  role_name     = local.role_name
  function_name = local.function_name
  account_id    = local.account_id
  region        = local.region

  # Constructed from the known name rather than referenced from the lambda
  # module, which would create a cycle: the function needs the role, and the
  # role needs the function's log group.
  log_group_arn      = local.lambda_log_group_arn
  dynamodb_table_arn = module.dynamodb.table_arn
}

# --- CORE: the function itself --------------------------------------------
module "lambda" {
  source = "./modules/lambda"

  function_name = local.function_name
  environment   = var.environment
  source_dir    = "${path.module}/src"

  role_arn   = module.iam.role_arn
  table_name = module.dynamodb.table_name

  memory_mb            = var.lambda_memory_mb
  timeout_seconds      = var.lambda_timeout_seconds
  reserved_concurrency = var.lambda_reserved_concurrency
  log_retention_days   = var.log_retention_days
  item_ttl_days        = var.item_ttl_days
}

# --- CORE: the public endpoint, with throttling ---------------------------
module "api_gateway" {
  source = "./modules/api_gateway"

  api_name    = local.api_name
  environment = var.environment

  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name

  throttling_rate_limit  = var.throttling_rate_limit
  throttling_burst_limit = var.throttling_burst_limit
  log_retention_days     = var.log_retention_days
}
