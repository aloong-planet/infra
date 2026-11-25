variable "cloudflare_account_id" {
  description = "Cloudflare account that runs the Workers and owns the R2 buckets they are bound to."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be a 32-character lowercase hex account ID."
  }
}

# No validation block: whether a failing validation prints a sensitive
# variable's value depends on the Terraform version and on where the value
# comes from (this stack's README, "The read-only GitHub token"), and the
# workflow logs are public. The checks on it are preconditions on the Worker
# in download-count.tf, which printed nothing of it in every case tried.
variable "releases_read_token" {
  description = "The read-only GitHub token agentshed's download count Worker reads GitHub's releases with (agentshed ADR-0057): the production environment's RELEASES_READ_TOKEN."
  type        = string
  sensitive   = true
}
