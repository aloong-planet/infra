# agentshed's download count Worker (download-count.tf), planned against a
# mock Cloudflare provider and stand-ins for the apps stack's outputs. The
# modules are fetched for real from raw.githubusercontent.com at the pinned
# commit, so these runs need the network. Expected hashes are the shasum of
# each module at that commit, written out here rather than read from the
# configuration.
#
# Not covered here:
# - Which token the provider authenticates with: a provider block is not
#   observable in a test, and a Plan does not show it either, because the
#   provider does not check its token and planning new resources calls no
#   API. A wrong wiring shows at the first Apply.
# - Whether Cloudflare accepts the upload, the Cron Trigger and the workers.dev
#   setting: only the Apply shows it.
# - Whether the workflows pass the production environment's
#   RELEASES_READ_TOKEN to releases_read_token: a secret they do not pass
#   arrives empty, which the empty-token run below shows the Plan refuses.
# - Whether GitHub accepts the token: only the check before it is stored
#   (docs/ops/releases-read-token.md) and the Worker's first run after the
#   Apply, in its run record (agentshed's runbook), show it.
# - That a failed precondition prints nothing of the token: Terraform's
#   behaviour, seen by hand, not something a run can assert.

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
  releases_read_token   = "github_pat_stand_in_releases_token"
}

run "the_pinned_modules_are_deployed" {
  command = plan

  assert {
    condition     = sha256(cloudflare_workers_script.download_count.content) == "5dc30a3252d6cdc88a1821df4991aacd6f88c9b1d2519a7fd7eedff898530ff3"
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
    condition     = sha256(base64decode(cloudflare_workers_script.download_count.files["download-count-core.mjs"].content_base64)) == "3a2566b617d1f1a8424f9bd65dd0b62029345953257e37594ebe6785d4860e56"
    error_message = "download-count-core.mjs is not scripts/download-count-core.mjs at the pinned commit."
  }
}

run "a_fetched_main_module_with_other_content_is_refused" {
  command = plan

  override_data {
    target = data.http.download_count_module["download-count-worker.mjs"]
    values = {
      status_code          = 200
      response_body        = "export default {}\n"
      response_body_base64 = "ZXhwb3J0IGRlZmF1bHQge30K"
    }
  }

  expect_failures = [
    data.http.download_count_module["download-count-worker.mjs"],
  ]
}

run "a_fetched_core_module_with_other_content_is_refused" {
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
  # seven: ACCEPT_GAP_FROM is bound only while a gap is to be accepted.
  assert {
    condition = jsonencode({
      for b in cloudflare_workers_script.download_count.bindings :
      b.name => { type = b.type, value = b.type == "r2_bucket" ? b.bucket_name : b.text }
      }) == jsonencode({
      BUCKET                 = { type = "r2_bucket", value = "stand-in-bucket" }
      CF_ANALYTICS_API_TOKEN = { type = "secret_text", value = "stand-in-analytics-token" }
      CF_ZONE_ID             = { type = "plain_text", value = "00000000000000000000000000000002" }
      CORE_SHA256            = { type = "plain_text", value = "3a2566b617d1f1a8424f9bd65dd0b62029345953257e37594ebe6785d4860e56" }
      DOWNLOAD_HOST          = { type = "plain_text", value = "https://dl.agentshed.aloongplanet.com" }
      GITHUB_REPOSITORY      = { type = "plain_text", value = "aloong-planet/agentshed" }
      RELEASES_READ_TOKEN    = { type = "secret_text", value = "github_pat_stand_in_releases_token" }
    })
    error_message = "The Worker's bindings are not exactly the seven of agentshed's runbook, with the apps stack's bucket, analytics token and zone, and the read-only GitHub token from releases_read_token."
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

# The stand-ins above are plain values, as apps' sensitive outputs are when
# read through terraform_remote_state, so the mark has to come from this
# stack. The read-only GitHub token's comes from its variable's declaration.
run "the_tokens_stay_sensitive" {
  command = plan

  assert {
    condition     = issensitive(local.download_count_token)
    error_message = "agentshed's analytics token, read from apps' state, is not sensitive: a plan would print it."
  }

  assert {
    condition     = issensitive(local.workers_deploy_token)
    error_message = "The Workers deploy token, read from apps' state, is not sensitive: a plan would print it."
  }

  assert {
    condition     = issensitive(var.releases_read_token)
    error_message = "The read-only GitHub token is not sensitive: a plan would print it."
  }
}

# A secret the workflow does not pass, or the environment does not hold,
# reaches the stack as an empty string. The Worker fails every run without
# the token (agentshed ADR-0057), so the plan stops instead.
run "an_empty_releases_read_token_deploys_nothing" {
  command = plan

  variables {
    releases_read_token = ""
  }

  expect_failures = [
    cloudflare_workers_script.download_count,
  ]
}

# agentshed ADR-0057 chose a fine-grained personal access token, whose prefix
# is github_pat_ in GitHub's table of token formats; a classic token's is ghp_.
run "a_releases_read_token_of_another_kind_deploys_nothing" {
  command = plan

  variables {
    releases_read_token = "ghp_stand_in_classic_token"
  }

  expect_failures = [
    cloudflare_workers_script.download_count,
  ]
}

# A newline pasted after the token is dropped from the request's header but
# stays in the bound value, which the Worker removes verbatim from a
# failure's text: a failure's text holding the token alone would keep it.
run "a_releases_read_token_with_a_trailing_newline_deploys_nothing" {
  command = plan

  variables {
    releases_read_token = "github_pat_stand_in_releases_token\n"
  }

  expect_failures = [
    cloudflare_workers_script.download_count,
  ]
}

# A space inside the token stays in the request's header, and a bearer token
# holds no space (RFC 6750, b64token), so GitHub is sent no token it issued.
run "a_releases_read_token_with_a_space_inside_deploys_nothing" {
  command = plan

  variables {
    releases_read_token = "github_pat_stand_in releases_token"
  }

  expect_failures = [
    cloudflare_workers_script.download_count,
  ]
}

# A no-break space copied with the token stays in the request's header, as
# any character outside ASCII does, and a bearer token holds none.
run "a_releases_read_token_with_a_no_break_space_after_it_deploys_nothing" {
  command = plan

  variables {
    releases_read_token = "github_pat_stand_in_releases_token\u00a0"
  }

  expect_failures = [
    cloudflare_workers_script.download_count,
  ]
}
