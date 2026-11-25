# Read access to the zone's analytics for apps whose landing page shows a
# download count, one entry per app. Each gets an account API token that can
# read the aloongplanet.com zone's analytics and nothing else. The stack
# outputs it, with the zone ID and the app's release bucket, to the workers
# stack, which binds them to the app's download count Worker (outputs.tf).
# This stack's README lists the steps around adding an app.

locals {
  download_counts = {
    # agentshed ADR-0055, docs/specs/download-count.md (download-count::REQ-011).
    # Its download host, dl.agentshed.aloongplanet.com, is in this zone
    # (release-mirrors.tf).
    agentshed = {}
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
