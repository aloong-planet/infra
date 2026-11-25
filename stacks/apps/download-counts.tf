# Read access to the zone's analytics for apps whose landing page shows a
# download count, one entry per app. Each gets an account API token that can
# read the aloongplanet.com zone's analytics and nothing else, written with
# the zone ID to the app's repository as Actions secrets. The app's workflow
# reads its download host's traffic from Cloudflare's GraphQL Analytics API
# with them; it reaches the release bucket with the release mirror's R2_*
# secrets. This stack's README lists the steps around adding an app.

locals {
  download_counts = {
    # agentshed ADR-0055, docs/specs/download-count.md (download-count::REQ-011).
    # Its download host, dl.agentshed.aloongplanet.com, is in this zone
    # (release-mirrors.tf).
    agentshed = {
      repository = "agentshed"
    }
  }
}

# Looked up by name, as in release-mirrors.tf, and by scope as well: the
# scope keeps the account-level "Account Analytics Read" out. one() fails the
# plan unless exactly one zone-level group has this name.
data "cloudflare_account_api_token_permission_groups_list" "zone_analytics_read" {
  account_id = var.cloudflare_account_id
  name       = "Analytics%20Read"
  scope      = "com.cloudflare.api.account.zone"
}

resource "cloudflare_account_token" "download_count" {
  for_each = local.download_counts

  account_id = var.cloudflare_account_id
  name       = "${each.key}-download-count"

  policies = [{
    effect = "allow"
    permission_groups = [{
      id = one(data.cloudflare_account_api_token_permission_groups_list.zone_analytics_read.result).id
    }]
    resources = jsonencode({
      "com.cloudflare.api.account.zone.${data.cloudflare_zone.aloongplanet.id}" = "*"
    })
  }]
}

resource "github_actions_secret" "download_count_token" {
  for_each = local.download_counts

  repository  = each.value.repository
  secret_name = "CF_ANALYTICS_API_TOKEN"
  value       = cloudflare_account_token.download_count[each.key].value
}

# A secret rather than a variable: the token that writes to the app's
# repository holds secrets permission only (README, Credentials).
resource "github_actions_secret" "download_count_zone" {
  for_each = local.download_counts

  repository  = each.value.repository
  secret_name = "CF_ZONE_ID"
  value       = data.cloudflare_zone.aloongplanet.id
}
