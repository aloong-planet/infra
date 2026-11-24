output "value" {
  description = "The token's value."
  value       = cloudflare_account_token.this.value
  sensitive   = true
}
