# Authenticates with the Workers deploy token the apps stack mints, never
# with the CLOUDFLARE_API_TOKEN environment variable: the production
# environment's token has no Workers permission, and this stack's workflow
# does not pass it.
provider "cloudflare" {
  api_token = data.terraform_remote_state.apps.outputs.workers_deploy_token
}
