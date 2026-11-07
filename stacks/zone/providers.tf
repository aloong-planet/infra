# Authenticates with the CLOUDFLARE_API_TOKEN environment variable: the
# production environment's token, the same one the apps stack uses. Its Zone
# Settings Read and Edit permissions on aloongplanet.com are there for this stack.
provider "cloudflare" {}
