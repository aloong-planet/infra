# Landing pages on Cloudflare Pages, one per app (modules/landing-page). To add
# one, add an entry to landing_pages; this stack's README lists the steps
# around it.
#
# Transfer's page was made in the dashboard before this stack existed;
# imports.tf brings its three resources into the state.

locals {
  landing_pages = {
    # agentshed ADR-0031; aloong-planet-home's docs/specs/agentshed-site.md,
    # agentshed-site::CON-001 (https://github.com/aloong-planet/aloong-planet-home/blob/main/docs/specs/agentshed-site.md).
    # The site is built and deployed by aloong-planet-home's CI, which uploads
    # it to this project (that repository's ADR-0001), so Git builds are off:
    # a push to agentshed builds nothing. The project stays connected to
    # agentshed, and the build settings below are the ones the site had there,
    # a record only: agentshed no longer has site/, so setting
    # git_builds_enabled to true would not bring the site back: the watch path
    # is site/*, so no push starts a build until one changes site/ again.
    agentshed = {
      repository         = "agentshed"
      git_builds_enabled = false
      production_branch  = "main"
      root_dir           = "site"
      build_command      = "pnpm install --frozen-lockfile && pnpm build"
      output_dir         = "dist"
      build_env = {
        # Astro 7 needs 22.22.0 or later, and the corepack the build image
        # installs (0.36.0) wants 22.22.2 or later; the image's default is
        # 22.16.0. 22.23.3 was the latest Node 22 release on 2026-10-19.
        NODE_VERSION = "22.23.3"
        # site/package.json's packageManager. The build image's default pnpm
        # is 10, and it does not take pnpm's version from the lockfile.
        PNPM_VERSION = "9.12.3"
      }
      # site/ is a package of its own, with its own lockfile.
      watch_paths = ["site/*"]
      domain      = "agentshed.aloongplanet.com"
    }

    # JustSnap's landing page: aloong-planet-home's docs/specs/justsnap-site.md,
    # justsnap-site::CON-001 (https://github.com/aloong-planet/aloong-planet-home/blob/main/docs/specs/justsnap-site.md).
    # The site is built and deployed by aloong-planet-home's CI, which uploads
    # it to this project (that repository's ADR-0001), so Git builds are off:
    # a push to justsnap builds nothing. The project stays connected to
    # justsnap, and the build settings below are the ones the site had there
    # while it was built from that repository's site/ directory, the same as
    # agentshed's and a record only for the same reason: justsnap no longer
    # has site/. Its release mirror (release-mirrors.tf) allows this
    # page's origin to read the latest pointer.
    justsnap = {
      repository         = "justsnap"
      git_builds_enabled = false
      production_branch  = "main"
      root_dir           = "site"
      build_command      = "pnpm install --frozen-lockfile && pnpm build"
      output_dir         = "dist"
      build_env = {
        # Same reasons as agentshed's: Astro 7 and the build image's corepack
        # need a newer Node than the image's 22.16.0, and the image's default
        # pnpm (10) is not site/package.json's packageManager.
        NODE_VERSION = "22.23.3"
        PNPM_VERSION = "9.12.3"
      }
      # site/ is a package of its own, with its own lockfile.
      watch_paths = ["site/*"]
      domain      = "justsnap.aloongplanet.com"
    }

    # Transfer's page. The values are what the project had in the dashboard
    # when it was imported (infra #16), not new choices, so they differ from
    # the other entries: the default branch is master, the build is
    # pnpm install without a frozen lockfile on Node 20, and the watch path is
    # the whole repository, so that every push built.
    #
    # Git builds are off so that aloong-planet-home's CI can build and deploy
    # the site to this project instead (that repository's ADR-0001;
    # https://github.com/aloong-planet/aloong-planet-home/issues/27): a push
    # to transfer builds nothing. The project stays connected to transfer,
    # and the build settings are a record of how Cloudflare built it from that
    # repository's site/ directory. Once transfer drops site/, setting
    # git_builds_enabled to true would start builds of a directory that is
    # not there.
    "transfer-org" = {
      repository         = "transfer"
      git_builds_enabled = false
      production_branch  = "master"
      root_dir           = "site"
      build_command      = "pnpm install && pnpm build"
      output_dir         = "dist"
      build_env = {
        NODE_VERSION = "20"
      }
      watch_paths = ["*"]
      domain      = "transfer.aloongplanet.com"
    }
  }
}

module "landing_page" {
  source   = "../../modules/landing-page"
  for_each = local.landing_pages

  account_id         = var.cloudflare_account_id
  zone_id            = data.cloudflare_zone.aloongplanet.id
  project_name       = each.key
  repository_owner   = local.github_owner
  repository         = each.value.repository
  git_builds_enabled = each.value.git_builds_enabled
  production_branch  = each.value.production_branch
  root_dir           = each.value.root_dir
  build_command      = each.value.build_command
  output_dir         = each.value.output_dir
  build_env          = each.value.build_env
  watch_paths        = each.value.watch_paths
  domain             = each.value.domain
}
