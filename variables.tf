variable "cloudflare_account_id" {
  description = "Cloudflare account that owns the aloongplanet.com zone and the R2 buckets."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be a 32-character lowercase hex account ID."
  }
}

variable "github_token" {
  description = "Fine-grained personal access token that can write Actions secrets in the repositories this configuration manages."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.github_token) > 0
    error_message = "github_token must be set; the GitHub provider would otherwise fall back to the local gh CLI token."
  }
}
