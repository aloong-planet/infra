output "domain" {
  description = "Custom domain serving the landing page."
  value       = cloudflare_pages_domain.this.name
}
