# Read only: the zone is shared with other projects and its settings stay out
# of this configuration. Every download host and landing page domain is in
# this zone.
data "cloudflare_zone" "aloongplanet" {
  filter = {
    name = "aloongplanet.com"
  }
}
