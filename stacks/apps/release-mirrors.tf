# R2 release mirrors, one per app (modules/release-mirror). To add an app, add
# an entry to release_mirrors; this stack's README lists the steps around it.
#
# Transfer's bucket, dl.aloongplanet.com and its Pages project live in the same
# account and zone and are not managed here.

locals {
  release_mirrors = {
    # agentshed ADR-0031, docs/specs/mac-distribution.md. The landing page
    # reads the latest pointer cross-origin (mac-distribution::REQ-004/AC-03).
    # The download host passed the outside certificate check, so ADR-0031's
    # fallback dl-agentshed.aloongplanet.com is not used.
    agentshed = {
      repository      = "agentshed"
      bucket          = "agentshed-releases"
      download_host   = "dl.agentshed.aloongplanet.com"
      allowed_origins = ["https://agentshed.aloongplanet.com"]
    }
  }
}

# Permission group IDs are looked up by name because Cloudflare documents the
# IDs, not the names, as stable; one() fails the plan if the name stops
# matching exactly one group.
data "cloudflare_account_api_token_permission_groups_list" "r2_bucket_item_write" {
  account_id = var.cloudflare_account_id
  name       = "Workers%20R2%20Storage%20Bucket%20Item%20Write"
}

module "release_mirror" {
  source   = "../../modules/release-mirror"
  for_each = local.release_mirrors

  account_id                 = var.cloudflare_account_id
  zone_id                    = data.cloudflare_zone.aloongplanet.id
  writer_permission_group_id = one(data.cloudflare_account_api_token_permission_groups_list.r2_bucket_item_write.result).id
  repository                 = each.value.repository
  bucket                     = each.value.bucket
  download_host              = each.value.download_host
  allowed_origins            = each.value.allowed_origins
}
