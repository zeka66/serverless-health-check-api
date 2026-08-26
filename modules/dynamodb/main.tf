// CORE REQUIREMENT: a single table storing request data, with server-side
// encryption enabled.

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST" # No capacity to tune, no idle cost.
  hash_key     = "id"

  # Only key attributes are declared. DynamoDB is schemaless otherwise, so the
  # handler's other fields (received_at, source_ip, payload, ...) need no
  # declaration here and can change without a Terraform change.
  attribute {
    name = "id"
    type = "S"
  }

  # [sec] Encryption Everywhere. enabled = true uses the AWS managed key
  # (aws/dynamodb), which satisfies the SSE requirement.
  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  # A health endpoint writes a row per request forever, so items self-expire
  # via the expires_at attribute the handler sets.
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  deletion_protection_enabled = var.deletion_protection_enabled
}
