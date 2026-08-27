variable "table_name" {
  type = string
}

variable "deletion_protection_enabled" {
  description = "Block table deletion. Enabled for PROD."
  type        = bool
  default     = false
}
