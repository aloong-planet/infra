# Looked up by name, so the zone ID never appears in the repository. The zone
# is shared with Transfer and the apps stack; this stack manages only the
# settings declared next to this file.
data "cloudflare_zone" "aloongplanet" {
  filter = {
    name = "aloongplanet.com"
  }
}
