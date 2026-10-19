# Versions are pinned in each stack that uses this module; the provider
# configuration is inherited from it.
terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}
