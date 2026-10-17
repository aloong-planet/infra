output "agentshed_download_host" {
  description = "Custom domain serving agentshed-releases."
  value       = cloudflare_r2_custom_domain.agentshed_download.domain
}

output "agentshed_download_host_status" {
  description = "Ownership and certificate status Cloudflare reports for the download host."
  value       = cloudflare_r2_custom_domain.agentshed_download.status
}
