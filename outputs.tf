output "agentshed_download_host" {
  description = "Custom domain serving agentshed-releases."
  value       = cloudflare_r2_custom_domain.agentshed_download.domain
}
