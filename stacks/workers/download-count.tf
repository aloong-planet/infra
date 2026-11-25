# agentshed's download count Worker (agentshed ADR-0056,
# docs/specs/download-count.md, download-count::REQ-011): every hour it runs the
# download count's core over its binding to agentshed's release bucket and
# writes the statistics file. What it writes, and how to read its runs, is in
# agentshed's docs/ops/download-count.md, "What a Worker run does".
#
# The modules are agentshed's, deployed from the commit pinned below and
# checked against their pinned SHA-256 before anything is planned. To change
# the Worker, merge the agentshed change first, then change the commit and
# both hashes here in one pull request (this stack's README).

locals {
  agentshed_commit = "735f3ebd90bde67a303dda5f0f6100cf72ca68a7"

  # Keyed by the name each module is uploaded under, which is the name the
  # main module imports the core by.
  download_count_modules = {
    "download-count-worker.mjs" = {
      path   = "scripts/download-count-worker.mjs"
      sha256 = "5dc30a3252d6cdc88a1821df4991aacd6f88c9b1d2519a7fd7eedff898530ff3"
    }
    "download-count-core.mjs" = {
      path   = "scripts/download-count-core.mjs"
      sha256 = "3a2566b617d1f1a8424f9bd65dd0b62029345953257e37594ebe6785d4860e56"
    }
  }

  download_count_settings = data.terraform_remote_state.apps.outputs.download_counts["agentshed"]

  # Sensitive again: apps' state does not keep the mark (apps.tf).
  download_count_token = sensitive(data.terraform_remote_state.apps.outputs.download_count_tokens["agentshed"])
}

data "http" "download_count_module" {
  for_each = local.download_count_modules

  url = "https://raw.githubusercontent.com/aloong-planet/agentshed/${local.agentshed_commit}/${each.value.path}"

  # A dropped connection or a 5xx is tried again, up to three times in all,
  # rather than failing the plan.
  retry {
    attempts     = 2
    min_delay_ms = 1000
  }

  lifecycle {
    postcondition {
      condition     = sha256(self.response_body) == each.value.sha256
      error_message = "${self.url} answered ${self.status_code} with content whose SHA-256 is ${sha256(self.response_body)}, not the pinned ${each.value.sha256}; nothing is deployed."
    }
  }
}

resource "cloudflare_workers_script" "download_count" {
  account_id  = var.cloudflare_account_id
  script_name = "agentshed-download-count"

  main_module = "download-count-worker.mjs"
  content     = data.http.download_count_module["download-count-worker.mjs"].response_body
  files = {
    "download-count-core.mjs" = {
      content_type   = "application/javascript+module"
      content_base64 = data.http.download_count_module["download-count-core.mjs"].response_body_base64
    }
  }

  compatibility_date = "2026-11-01"

  # The settings agentshed's runbook lists. ACCEPT_GAP_FROM is added only by a
  # pull request that accepts a stalled count's gap, and removed by the next.
  # RELEASES_READ_TOKEN is the read-only GitHub token the Worker reads GitHub's
  # releases with (agentshed ADR-0057), from the production environment.
  bindings = [
    {
      name        = "BUCKET"
      type        = "r2_bucket"
      bucket_name = local.download_count_settings.bucket
    },
    {
      name = "CF_ANALYTICS_API_TOKEN"
      type = "secret_text"
      text = local.download_count_token
    },
    {
      name = "CF_ZONE_ID"
      type = "plain_text"
      text = local.download_count_settings.zone_id
    },
    {
      # Recorded in every run.
      name = "CORE_SHA256"
      type = "plain_text"
      text = local.download_count_modules["download-count-core.mjs"].sha256
    },
    {
      name = "DOWNLOAD_HOST"
      type = "plain_text"
      text = "https://dl.agentshed.aloongplanet.com"
    },
    {
      name = "GITHUB_REPOSITORY"
      type = "plain_text"
      text = "aloong-planet/agentshed"
    },
    {
      name = "RELEASES_READ_TOKEN"
      type = "secret_text"
      text = var.releases_read_token
    },
  ]

  # The token's checks are here, not on its variable: a failing precondition
  # prints nothing of a sensitive value (variables.tf).
  lifecycle {
    precondition {
      condition     = var.releases_read_token != ""
      error_message = "releases_read_token is empty: the production environment does not hold RELEASES_READ_TOKEN, or the workflow does not pass it. The Worker fails every run without it (agentshed ADR-0057), so nothing is deployed."
    }

    # Empty is the precondition above's to report. GitHub documents the
    # prefix of each kind of token, not the characters after it, so what
    # follows the prefix is held to the characters a bearer token may hold
    # (RFC 6750, b64token), which leaves out every kind of whitespace. A space
    # or tab inside the token, or a character outside ASCII anywhere in it,
    # reaches GitHub, and a newline inside it fails the request. A trailing
    # space, tab or line break is dropped from the request's header but not
    # from the bound value, which the Worker removes verbatim from a failure's
    # text.
    precondition {
      condition     = var.releases_read_token == "" || can(regex("^github_pat_[0-9A-Za-z._~+/-]+=*$", var.releases_read_token))
      error_message = "releases_read_token is not a fine-grained personal access token and nothing else: the kind agentshed ADR-0057 chose starts with github_pat_, followed only by characters a bearer token may hold (RFC 6750: letters, digits and -._~+/, then any = padding), so no whitespace. Nothing is deployed."
    }
  }
}

# Minute 31, so that each run counts to the last full hour (agentshed's
# runbook, "What a Worker run does"); the Download count workflow, its
# watchdog, reads the file at minute 47.
resource "cloudflare_workers_cron_trigger" "download_count" {
  account_id  = var.cloudflare_account_id
  script_name = cloudflare_workers_script.download_count.script_name

  schedules = [{
    cron = "31 * * * *"
  }]
}

# Off: the Worker runs only on its Cron Trigger and answers no request.
resource "cloudflare_workers_script_subdomain" "download_count" {
  account_id       = var.cloudflare_account_id
  script_name      = cloudflare_workers_script.download_count.script_name
  enabled          = false
  previews_enabled = false
}
