# The token a stack deploys Workers with: it can write Workers scripts on
# the account, and nothing else.
resource "cloudflare_account_token" "this" {
  account_id = var.account_id
  name       = "workers-deploy"

  policies = [{
    effect = "allow"
    permission_groups = [{
      id = var.permission_group_id
    }]
    resources = jsonencode({
      "com.cloudflare.api.account.${var.account_id}" = "*"
    })
  }]
}
