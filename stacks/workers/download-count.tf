# agentshed's download count Worker in the shadow period (agentshed ADR-0056,
# docs/specs/landing-page.md, landing-page::REQ-011): every hour it runs the
# download count's core over its binding to agentshed's release bucket. What
# it writes, and how to read its runs, is in agentshed's
# docs/ops/download-count.md, "The Worker in the shadow period".
#
# The modules are agentshed's, deployed from the commit pinned below and
# checked against their pinned SHA-256 before anything is planned. To change
# the Worker, merge the agentshed change first, then change the commit and
# both hashes here in one pull request (this stack's README).

locals {
  agentshed_commit = "0c3a509afdcdf084ca9f7b3fb3b0d6cd843974c1"

  # Keyed by the name each module is uploaded under, which is the name the
  # main module imports the core by.
  download_count_modules = {
    "download-count-worker.mjs" = {
      path   = "scripts/download-count-worker.mjs"
      sha256 = "5ffbd0e003145ba42b08aa5be22af6eddf295dcb913d5a75e12c2cbcd96aa5ef"
    }
    "download-count-core.mjs" = {
      path   = "scripts/download-count-core.mjs"
      sha256 = "730b4b71fa4b591483060c5ece324f8c431f2ccfa4eb817f6f8fee97462465b5"
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
      # Recorded in every run, and compared with the workflow's core.
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
  ]
}

# Minute 31, so that each run reaches the cursor the Download count workflow's
# run at minute 47 reaches (agentshed's runbook).
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
