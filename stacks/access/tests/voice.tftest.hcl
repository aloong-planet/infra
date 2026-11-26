mock_provider "cloudflare" {}

variables {
  cloudflare_account_id = "00000000000000000000000000000000"
  voice_owner_policy_id = "00000000-0000-0000-0000-000000000001"
  voice_otp_idp_id      = "00000000-0000-0000-0000-000000000002"
}

run "protect_voice_host" {
  command = plan

  assert {
    condition = (
      cloudflare_zero_trust_access_application.voice.type == "self_hosted" &&
      cloudflare_zero_trust_access_application.voice.domain == "voice.aloongplanet.com" &&
      one(cloudflare_zero_trust_access_application.voice.destinations).uri == "voice.aloongplanet.com" &&
      one(cloudflare_zero_trust_access_application.voice.allowed_idps) == var.voice_otp_idp_id &&
      one(cloudflare_zero_trust_access_application.voice.policies).id == var.voice_owner_policy_id
    )
    error_message = "Protect the whole voice host with the selected policy and OTP provider."
  }
}

run "missing_policy" {
  command = plan
  variables { voice_owner_policy_id = "" }
  expect_failures = [var.voice_owner_policy_id]
}
