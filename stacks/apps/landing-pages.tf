# Landing pages on Cloudflare Pages, one per app (modules/landing-page). To add
# one, add an entry to landing_pages; this stack's README lists the steps
# around it.
#
# Transfer's Pages project and transfer.aloongplanet.com live in the same
# account and zone and are not managed here.

locals {
  landing_pages = {
    # agentshed ADR-0031, docs/specs/landing-page.md (CON-001). The build
    # settings are the ones agentshed's site/README.md lists.
    agentshed = {
      repository        = "agentshed"
      production_branch = "main"
      root_dir          = "site"
      build_command     = "pnpm install --frozen-lockfile && pnpm build"
      output_dir        = "dist"
      build_env = {
        # Astro 7 refuses an older Node; the build image's default is 22.16.0.
        NODE_VERSION = "22.22.0"
        # site/package.json's packageManager. The build image's default pnpm
        # is 10, and it does not take pnpm's version from the lockfile.
        PNPM_VERSION = "9.12.3"
      }
      # site/ is a package of its own, with its own lockfile.
      watch_paths = ["site/*"]
      domain      = "agentshed.aloongplanet.com"
    }
  }
}

module "landing_page" {
  source   = "../../modules/landing-page"
  for_each = local.landing_pages

  account_id        = var.cloudflare_account_id
  zone_id           = data.cloudflare_zone.aloongplanet.id
  project_name      = each.key
  repository_owner  = local.github_owner
  repository        = each.value.repository
  production_branch = each.value.production_branch
  root_dir          = each.value.root_dir
  build_command     = each.value.build_command
  output_dir        = each.value.output_dir
  build_env         = each.value.build_env
  watch_paths       = each.value.watch_paths
  domain            = each.value.domain
}
