locals {
  # Owner of every repository this stack writes secrets to or builds from.
  github_owner = "aloong-planet"
}

# Authenticates with the CLOUDFLARE_API_TOKEN environment variable.
provider "cloudflare" {}

provider "github" {
  owner = local.github_owner
  # Set explicitly: without a token the provider falls back to `gh auth token`,
  # which would silently act with the local user's own credentials.
  token = var.github_token
}
