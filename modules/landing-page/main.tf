# One app's landing page: a Cloudflare Pages project that builds a directory of
# the app's repository on every push, served on the app's own domain.
#
# Creating the project fails unless the Cloudflare Workers & Pages GitHub App
# is installed on the repository's owner with access to the repository.

locals {
  env_vars = { for name, value in var.build_env : name => { type = "plain_text", value = value } }
}

resource "cloudflare_pages_project" "this" {
  account_id        = var.account_id
  name              = var.project_name
  production_branch = var.production_branch

  source = {
    type = "github"
    config = {
      owner             = var.repository_owner
      repo_name         = var.repository
      production_branch = var.production_branch
      # Build watch paths: a push that changes none of these skips the build.
      path_includes = var.watch_paths
    }
  }

  build_config = {
    root_dir        = var.root_dir
    build_command   = var.build_command
    destination_dir = var.output_dir
  }

  # Previews build the same way, so they get the same variables.
  deployment_configs = {
    production = { env_vars = local.env_vars }
    preview    = { env_vars = local.env_vars }
  }
}

resource "cloudflare_pages_domain" "this" {
  account_id   = var.account_id
  project_name = cloudflare_pages_project.this.name
  name         = var.domain
}

# Attaching the domain does not create its DNS record. The record points at
# the project's pages.dev host, which Cloudflare picks when it creates the
# project (with a suffix if the name is taken). It is created after the domain
# is attached: Cloudflare documents that a record pointing at Pages for a
# domain the project does not have answers 522.
resource "cloudflare_dns_record" "this" {
  zone_id = var.zone_id
  name    = var.domain
  type    = "CNAME"
  content = cloudflare_pages_project.this.subdomain
  proxied = true
  ttl     = 1
  comment = "Pages project ${var.project_name}, managed by aloong-planet/infra"

  depends_on = [cloudflare_pages_domain.this]
}
