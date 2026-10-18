output "download_hosts" {
  description = "Custom domain serving each app's release bucket."
  value       = { for app, mirror in module.release_mirror : app => mirror.download_host }
}
