# agentshed's download count Worker (download-count.tf), planned against a
# mock Cloudflare provider and stand-ins for the apps stack's outputs. The
# modules are fetched for real from raw.githubusercontent.com at the pinned
# commit, so these runs need the network. Expected hashes are the shasum of
# each module at that commit, written out here rather than read from the
# configuration.
#
# Not covered here:
# - Which token the provider authenticates with: a provider block is not
#   observable in a test. A wrong wiring shows at the first Plan, because the
#   production environment's token has no Workers permission.
# - Whether Cloudflare accepts the upload, the Cron Trigger and the workers.dev
#   setting: only the Apply shows it.

mock_provider "cloudflare" {}

override_data {
  target = data.terraform_remote_state.apps
  values = {
    outputs = {
      workers_deploy_token = "stand-in-deploy-token"
      download_counts = {
        agentshed = {
          zone_id = "00000000000000000000000000000002"
          bucket  = "stand-in-bucket"
        }
      }
      download_count_tokens = {
        agentshed = "stand-in-analytics-token"
      }
    }
  }
}

variables {
  cloudflare_account_id = "00000000000000000000000000000001"
}

run "the_pinned_modules_are_deployed" {
  command = plan

  assert {
    condition     = sha256(cloudflare_workers_script.download_count.content) == "5ffbd0e003145ba42b08aa5be22af6eddf295dcb913d5a75e12c2cbcd96aa5ef"
    error_message = "The script's content is not scripts/download-count-worker.mjs at the pinned commit."
  }

  assert {
    condition     = cloudflare_workers_script.download_count.main_module == "download-count-worker.mjs"
    error_message = "The main module is not download-count-worker.mjs."
  }

  assert {
    condition     = keys(cloudflare_workers_script.download_count.files) == tolist(["download-count-core.mjs"])
    error_message = "The script's other files are not exactly download-count-core.mjs, the name the main module imports."
  }

  assert {
    condition     = cloudflare_workers_script.download_count.files["download-count-core.mjs"].content_type == "application/javascript+module"
    error_message = "download-count-core.mjs is not uploaded as an ES module."
  }

  assert {
    condition     = sha256(base64decode(cloudflare_workers_script.download_count.files["download-count-core.mjs"].content_base64)) == "730b4b71fa4b591483060c5ece324f8c431f2ccfa4eb817f6f8fee97462465b5"
    error_message = "download-count-core.mjs is not scripts/download-count-core.mjs at the pinned commit."
  }
}

run "a_fetched_module_with_other_content_is_refused" {
  command = plan

  override_data {
    target = data.http.download_count_module["download-count-core.mjs"]
    values = {
      status_code          = 200
      response_body        = "export const changed = true\n"
      response_body_base64 = "ZXhwb3J0IGNvbnN0IGNoYW5nZWQgPSB0cnVlCg=="
    }
  }

  expect_failures = [
    data.http.download_count_module["download-count-core.mjs"],
  ]
}

run "the_worker_is_bound_scheduled_and_kept_off_workers_dev" {
  command = plan

  # Every binding by name, with its type and its bucket or text. Exactly these
  # six: ACCEPT_GAP_FROM is bound only while a gap is to be accepted.
  assert {
    condition = jsonencode({
      for b in cloudflare_workers_script.download_count.bindings :
      b.name => { type = b.type, value = b.type == "r2_bucket" ? b.bucket_name : b.text }
      }) == jsonencode({
      BUCKET                 = { type = "r2_bucket", value = "stand-in-bucket" }
      CF_ANALYTICS_API_TOKEN = { type = "secret_text", value = "stand-in-analytics-token" }
      CF_ZONE_ID             = { type = "plain_text", value = "00000000000000000000000000000002" }
      CORE_SHA256            = { type = "plain_text", value = "730b4b71fa4b591483060c5ece324f8c431f2ccfa4eb817f6f8fee97462465b5" }
      DOWNLOAD_HOST          = { type = "plain_text", value = "https://dl.agentshed.aloongplanet.com" }
      GITHUB_REPOSITORY      = { type = "plain_text", value = "aloong-planet/agentshed" }
    })
    error_message = "The Worker's bindings are not exactly the six of agentshed's runbook, with the apps stack's bucket, analytics token and zone."
  }

  assert {
    condition     = cloudflare_workers_cron_trigger.download_count.script_name == "agentshed-download-count"
    error_message = "The Cron Trigger is not on agentshed-download-count."
  }

  assert {
    condition     = jsonencode([for s in cloudflare_workers_cron_trigger.download_count.schedules : s.cron]) == jsonencode(["31 * * * *"])
    error_message = "The Worker is not scheduled at minute 31 of every hour, and only then."
  }

  assert {
    condition     = cloudflare_workers_script_subdomain.download_count.script_name == "agentshed-download-count"
    error_message = "The workers.dev setting is not on agentshed-download-count."
  }

  assert {
    condition     = cloudflare_workers_script_subdomain.download_count.enabled == false && cloudflare_workers_script_subdomain.download_count.previews_enabled == false
    error_message = "The Worker or its previews are reachable on workers.dev."
  }
}
