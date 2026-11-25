variable "cloudflare_account_id" {
  description = "Cloudflare account that runs the Workers and owns the R2 buckets they are bound to."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "cloudflare_account_id must be a 32-character lowercase hex account ID."
  }
}

# No validation block: a failing validation prints the variable's value, even
# a sensitive one (Terraform 1.16.6), and the workflow logs are public. The
# checks on it are preconditions on the Worker in download-count.tf, which
# print nothing of it.
variable "releases_read_token" {
  description = "The read-only GitHub token agentshed's download count Worker reads GitHub's releases with (agentshed ADR-0057): the production environment's RELEASES_READ_TOKEN."
  type        = string
  sensitive   = true
}
