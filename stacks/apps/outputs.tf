output "download_hosts" {
  description = "Custom domain serving each app's release bucket."
  value       = { for app, mirror in module.release_mirror : app => mirror.download_host }
}

output "landing_page_domains" {
  description = "Custom domain serving each app's landing page."
  value       = { for app, page in module.landing_page : app => page.domain }
}

# The outputs below are read by the workers stack (stacks/workers/apps.tf).

output "workers_deploy_token" {
  description = "Value of the workers-deploy token, which can write Workers scripts on the account."
  value       = module.workers_deploy_token.value
  sensitive   = true
}

# Not sensitive, so the workers plan shows the bucket each Worker is bound to.
output "download_counts" {
  description = "Per app with a download count: the zone ID and the app's release bucket."
  value = {
    for app in keys(local.download_counts) : app => {
      zone_id = data.cloudflare_zone.aloongplanet.id
      bucket  = local.release_mirrors[app].bucket
    }
  }
}

output "download_count_tokens" {
  description = "Per app with a download count: the value of its analytics token."
  value       = { for app in keys(local.download_counts) : app => cloudflare_account_token.download_count[app].value }
  sensitive   = true
}
