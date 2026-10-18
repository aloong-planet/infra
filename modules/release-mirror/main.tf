# One app's release mirror: an R2 bucket served from its own download host, and
# a writer token whose S3 credentials go to the app's repository as Actions
# secrets for its release workflow.

resource "cloudflare_r2_bucket" "this" {
  account_id    = var.account_id
  name          = var.bucket
  storage_class = "Standard"
}

# The landing page reads the latest pointer cross-origin, with GET only.
resource "cloudflare_r2_bucket_cors" "this" {
  account_id  = var.account_id
  bucket_name = cloudflare_r2_bucket.this.name

  rules = [{
    id = "landing-page-get"
    allowed = {
      methods = ["GET"]
      origins = var.allowed_origins
    }
    max_age_seconds = 3600
  }]
}

resource "cloudflare_r2_custom_domain" "this" {
  account_id  = var.account_id
  bucket_name = cloudflare_r2_bucket.this.name
  domain      = var.download_host
  zone_id     = var.zone_id
  enabled     = true
  min_tls     = "1.2"
}

# The release workflow's credential: object read, write and list in this
# bucket only.
resource "cloudflare_account_token" "writer" {
  account_id = var.account_id
  name       = "${var.bucket}-writer"

  policies = [{
    effect = "allow"
    permission_groups = [{
      id = var.writer_permission_group_id
    }]
    resources = jsonencode({
      "com.cloudflare.edge.r2.bucket.${var.account_id}_default_${cloudflare_r2_bucket.this.name}" = "*"
    })
  }]
}

locals {
  # Names match Transfer's so the release workflow and runbook carry over.
  # R2's S3 credentials derive from the token: the access key ID is the token
  # ID and the secret access key is the hex SHA-256 of the token value.
  r2_secrets = {
    R2_ACCOUNT_ID        = var.account_id
    R2_ACCESS_KEY_ID     = cloudflare_account_token.writer.id
    R2_SECRET_ACCESS_KEY = sha256(cloudflare_account_token.writer.value)
    R2_BUCKET            = cloudflare_r2_bucket.this.name
  }
}

resource "github_actions_secret" "r2" {
  # A literal set keeps the instance keys free of sensitive marks.
  for_each = toset(["R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET"])

  repository  = var.repository
  secret_name = each.key
  value       = local.r2_secrets[each.key]
}
