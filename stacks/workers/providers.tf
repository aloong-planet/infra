# Authenticates with the Workers deploy token the apps stack mints, never
# with the CLOUDFLARE_API_TOKEN environment variable: the production
# environment's token has no Workers permission, and this stack's workflow
# does not pass it.
provider "cloudflare" {
  api_token = local.workers_deploy_token
}
