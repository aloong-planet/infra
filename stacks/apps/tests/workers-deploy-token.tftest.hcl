# The Workers deploy token (modules/workers-deploy-token), planned against a
# mock Cloudflare provider with stand-in IDs.
#
# Not covered here, because a test cannot plan this stack: Terraform's mocks
# cannot give a computed list such as a permission group lookup's result any
# element, and every token here takes its group from one. So the lookup's
# name and scope (workers-deploy-token.tf) and this stack's outputs for the
# workers stack (outputs.tf) are checked by review and by the plans: the
# apps plan shows the token, the workers plan shows the bucket it binds.

mock_provider "cloudflare" {}

run "the_deploy_token_can_write_workers_scripts_on_this_account_and_nothing_else" {
  command = plan

  module {
    source = "../../modules/workers-deploy-token"
  }

  variables {
    account_id          = "00000000000000000000000000000001"
    permission_group_id = "0000000000000000000000000000000b"
  }

  assert {
    condition     = length(cloudflare_account_token.this.policies) == 1 && cloudflare_account_token.this.policies[0].effect == "allow"
    error_message = "The deploy token does not have exactly one allow policy."
  }

  assert {
    condition     = jsonencode([for g in cloudflare_account_token.this.policies[0].permission_groups : g.id]) == jsonencode(["0000000000000000000000000000000b"])
    error_message = "The deploy token's permission groups are not exactly the given one."
  }

  assert {
    condition     = jsondecode(cloudflare_account_token.this.policies[0].resources) == { "com.cloudflare.api.account.00000000000000000000000000000001" = "*" }
    error_message = "The deploy token's resources are not exactly the given account."
  }
}
