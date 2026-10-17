# agentshed release line: the R2 mirror for formal releases (agentshed ADR-0031,
# docs/specs/mac-distribution.md). Transfer's bucket, dl.aloongplanet.com and
# its Pages project live in the same account and zone and are not managed here.

locals {
  agentshed_landing_origin = "https://agentshed.aloongplanet.com"

  # ADR-0031: dl.agentshed.aloongplanet.com if its certificate checks out from
  # outside Cloudflare, otherwise dl-agentshed.aloongplanet.com.
  agentshed_download_host = "dl.agentshed.aloongplanet.com"
}

# Read only: the zone is shared with other projects and its settings stay out
# of this configuration.
data "cloudflare_zone" "aloongplanet" {
  filter = {
    name = "aloongplanet.com"
  }
}

resource "cloudflare_r2_bucket" "agentshed_releases" {
  account_id    = var.cloudflare_account_id
  name          = "agentshed-releases"
  storage_class = "Standard"
}

# The landing page reads the latest pointer cross-origin with GET only
# (mac-distribution::REQ-004/AC-03).
resource "cloudflare_r2_bucket_cors" "agentshed_releases" {
  account_id  = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.agentshed_releases.name

  rules = [{
    id = "landing-page-get"
    allowed = {
      methods = ["GET"]
      origins = [local.agentshed_landing_origin]
    }
    max_age_seconds = 3600
  }]
}

resource "cloudflare_r2_custom_domain" "agentshed_download" {
  account_id  = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.agentshed_releases.name
  domain      = local.agentshed_download_host
  zone_id     = data.cloudflare_zone.aloongplanet.id
  enabled     = true
  min_tls     = "1.2"
}

# Permission group IDs are looked up by name because Cloudflare documents the
# IDs, not the names, as stable; one() fails the plan if the name stops
# matching exactly one group.
data "cloudflare_account_api_token_permission_groups_list" "r2_bucket_item_write" {
  account_id = var.cloudflare_account_id
  name       = "Workers%20R2%20Storage%20Bucket%20Item%20Write"
}

# The release workflow's credential: object read, write and list in
# agentshed-releases only.
resource "cloudflare_account_token" "agentshed_releases_writer" {
  account_id = var.cloudflare_account_id
  name       = "agentshed-releases-writer"

  policies = [{
    effect = "allow"
    permission_groups = [{
      id = one(data.cloudflare_account_api_token_permission_groups_list.r2_bucket_item_write.result).id
    }]
    resources = jsonencode({
      "com.cloudflare.edge.r2.bucket.${var.cloudflare_account_id}_default_${cloudflare_r2_bucket.agentshed_releases.name}" = "*"
    })
  }]
}

locals {
  # Names match Transfer's so the release workflow and runbook carry over.
  # R2's S3 credentials derive from the token: the access key ID is the token
  # ID and the secret access key is the hex SHA-256 of the token value.
  agentshed_r2_secrets = {
    R2_ACCOUNT_ID        = var.cloudflare_account_id
    R2_ACCESS_KEY_ID     = cloudflare_account_token.agentshed_releases_writer.id
    R2_SECRET_ACCESS_KEY = sha256(cloudflare_account_token.agentshed_releases_writer.value)
    R2_BUCKET            = cloudflare_r2_bucket.agentshed_releases.name
  }
}

resource "github_actions_secret" "agentshed_r2" {
  # A literal set keeps the instance keys free of sensitive marks.
  for_each = toset(["R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET"])

  repository  = "agentshed"
  secret_name = each.key
  value       = local.agentshed_r2_secrets[each.key]
}
