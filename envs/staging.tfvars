environment  = "staging"
aws_region   = "eu-north-1"
project_name = "serverless-health-check-api"
repository   = "github.com/zeka66/serverless-health-check-api"

# Guard rail: set to your AWS account ID so Terraform refuses to run anywhere
# else. Leave as [] to disable.
allowed_account_ids = ["101528376191"]

# Sizing: staging is deliberately small and cheap.
lambda_memory_mb            = 256
lambda_timeout_seconds      = 10
lambda_reserved_concurrency = 5
log_retention_days          = 14
item_ttl_days               = 7

# Throttling: tighter than prod, so load problems surface here first.
throttling_rate_limit  = 20
throttling_burst_limit = 40
