environment  = "prod"
aws_region   = "eu-north-1"
project_name = "serverless-health-check-api"
repository   = "github.com/zeka66/serverless-health-check-api"

allowed_account_ids = ["101528376191"]

# Sizing: more headroom and longer retention than staging.
lambda_memory_mb            = 512
lambda_timeout_seconds      = 15
lambda_reserved_concurrency = -1
log_retention_days          = 90
item_ttl_days               = 90

throttling_rate_limit  = 100
throttling_burst_limit = 200
