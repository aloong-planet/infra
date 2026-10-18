output "download_host" {
  description = "Custom domain serving the bucket."
  value       = cloudflare_r2_custom_domain.this.domain
}
