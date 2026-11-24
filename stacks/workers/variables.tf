variable "cloudflare_account_id" {
  description = "Cloudflare account that runs the Workers and owns the R2 buckets they are bound to."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be a 32-character lowercase hex account ID."
  }
}
