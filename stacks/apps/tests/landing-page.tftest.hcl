# The landing page module's switch for Git builds (modules/landing-page),
# planned against a mock Cloudflare provider with stand-in values.
#
# Not covered here: that the provider sends these two settings to Cloudflare as
# the dashboard's "Enable automatic production branch deployments" and preview
# branch "None". The apps plan shows them, and Cloudflare answers the apply.

mock_provider "cloudflare" {}

variables {
  account_id        = "00000000000000000000000000000001"
  zone_id           = "00000000000000000000000000000002"
  project_name      = "example"
  repository_owner  = "example-org"
  repository        = "example-repo"
  production_branch = "main"
  root_dir          = "site"
  build_command     = "pnpm build"
  output_dir        = "dist"
  watch_paths       = ["site/*"]
  domain            = "example.aloongplanet.com"
}

run "with_git_builds_on_a_push_builds_on_every_branch" {
  command = plan

  module {
    source = "../../modules/landing-page"
  }

  variables {
    git_builds_enabled = true
  }

  assert {
    condition     = cloudflare_pages_project.this.source.config.production_deployments_enabled == true
    error_message = "A push to the production branch does not start a production build."
  }

  assert {
    condition     = cloudflare_pages_project.this.source.config.preview_deployment_setting == "all"
    error_message = "A push to another branch does not start a preview build."
  }
}

run "with_git_builds_off_no_push_builds_and_the_project_stays_connected" {
  command = plan

  module {
    source = "../../modules/landing-page"
  }

  variables {
    git_builds_enabled = false
  }

  assert {
    condition     = cloudflare_pages_project.this.source.config.production_deployments_enabled == false
    error_message = "A push to the production branch still starts a production build."
  }

  assert {
    condition     = cloudflare_pages_project.this.source.config.preview_deployment_setting == "none"
    error_message = "A push to another branch still starts a preview build."
  }

  # Cloudflare does not switch a Git-connected project to Direct Upload, so the
  # connection itself must stay.
  assert {
    condition     = cloudflare_pages_project.this.source.type == "github" && cloudflare_pages_project.this.source.config.repo_name == "example-repo"
    error_message = "The project is no longer connected to its repository."
  }
}
