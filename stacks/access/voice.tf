provider "cloudflare" {}

variable "cloudflare_account_id" {
  type      = string
  sensitive = true
  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id))
    error_message = "Set the account ID for the voice application."
  }
}

variable "voice_owner_policy_id" {
  description = "ID of the existing reusable Allow policy restricted to the owner."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$", var.voice_owner_policy_id))
    error_message = "Set the UUID of the verified owner-only Allow policy."
  }
}

variable "voice_otp_idp_id" {
  description = "ID of the account's One-time PIN identity provider."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$", var.voice_otp_idp_id))
    error_message = "Set the UUID of the One-time PIN identity provider."
  }
}

locals {
  voice_host = "voice.aloongplanet.com"
}

resource "cloudflare_zero_trust_access_application" "voice" {
  account_id = var.cloudflare_account_id
  name       = "Voice Assistant"
  type       = "self_hosted"
  domain     = local.voice_host
  destinations = [{
    type = "public"
    uri  = local.voice_host
  }]
  allowed_idps = [var.voice_otp_idp_id]
  policies     = [{ id = var.voice_owner_policy_id, precedence = 1 }]
}
