# Versions are pinned in the root module; the provider configurations are
# inherited from it.
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
