variable "table_name" {
  description = "Name of the DynamoDB table (already env-prefixed)."
  type        = string
}

variable "deletion_protection_enabled" {
  description = "Block accidental table deletion. Enabled for prod only."
  type        = bool
  default     = false
}
