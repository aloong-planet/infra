variable "account_id" {
  description = "Cloudflare account whose Workers scripts the token can write."
  type        = string
  sensitive   = true
}

variable "permission_group_id" {
  description = "ID of the account-level Workers Scripts Write permission group."
  type        = string
}
