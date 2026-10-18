# Versions are pinned in each stack that uses this module; the provider
# configurations are inherited from it.
terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    github = {
      source = "integrations/github"
    }
  }
}
