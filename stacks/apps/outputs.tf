output "download_hosts" {
  description = "Custom domain serving each app's release bucket."
  value       = { for app, mirror in module.release_mirror : app => mirror.download_host }
}

output "landing_page_domains" {
  description = "Custom domain serving each app's landing page."
  value       = { for app, page in module.landing_page : app => page.domain }
}
