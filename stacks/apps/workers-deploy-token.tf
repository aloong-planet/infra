# The token the workers stack deploys its Workers with (stacks/workers,
# modules/workers-deploy-token). The production environment's token has no
# Workers permission and stays without one. The workers stack reads this
# token from this stack's state (outputs.tf), so it is never stored as a
# secret anywhere. A permission is added only when a workers plan or apply
# reports it is missing.

# Looked up by name, as in release-mirrors.tf, and by scope as well, as in
# download-counts.tf. one() fails the plan unless exactly one account-level
# group has this name.
data "cloudflare_account_api_token_permission_groups_list" "workers_scripts_write" {
  account_id = var.cloudflare_account_id
  name       = "Workers%20Scripts%20Write"
  scope      = "com.cloudflare.api.account"
}

module "workers_deploy_token" {
  source = "../../modules/workers-deploy-token"

  account_id          = var.cloudflare_account_id
  permission_group_id = one(data.cloudflare_account_api_token_permission_groups_list.workers_scripts_write.result).id
}
