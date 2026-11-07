# Browsers follow each origin's own Cache-Control. 0 is Cloudflare's "Respect
# Existing Headers". The default, 4 hours, overrides any shorter max-age, so the
# Pages sites' static files went out with max-age=14400 while their HTML was
# checked on every visit, and a deploy could pair new pages with an old
# stylesheet. The setting covers every host in the zone; docs/specs/zone-settings.md
# lists what that means for Transfer, agentshed and the download hosts.
resource "cloudflare_zone_setting" "browser_cache_ttl" {
  zone_id    = data.cloudflare_zone.aloongplanet.id
  setting_id = "browser_cache_ttl"
  value      = 0
}

# The setting exists before Terraform manages it, so it is imported and the
# first plan shows its current value changing to 0. Once the setting is in state
# this does nothing; it imports the setting again if the state is ever lost.
# Removing the resource would leave the zone as it is, because the provider's
# delete does nothing: to go back to 4 hours, set the value to 14400.
import {
  to = cloudflare_zone_setting.browser_cache_ttl
  id = "${data.cloudflare_zone.aloongplanet.id}/browser_cache_ttl"
}
