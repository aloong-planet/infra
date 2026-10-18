#!/usr/bin/env bash
# Runs a command locally (terraform, or one of the scripts next to this one)
# with credentials from an untracked env file: ~/.config/aloong-planet/infra.env
# by default, or the path in INFRA_ENV_FILE. The file uses the same names as
# the production environment's secrets, and maps them as the workflow does.
# Run it from the stack directory the command is for:
#
#   cd stacks/apps
#   ../../scripts/with-credentials.sh terraform init
#   ../../scripts/with-credentials.sh ../../scripts/plan.sh plan.tfplan plan.result
set -euo pipefail

env_file="${INFRA_ENV_FILE:-$HOME/.config/aloong-planet/infra.env}"
if [[ ! -r "$env_file" ]]; then
  echo "with-credentials.sh: cannot read $env_file" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

for name in CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID REPO_SECRETS_TOKEN \
  STATE_R2_ACCESS_KEY_ID STATE_R2_SECRET_ACCESS_KEY; do
  if [[ -z "${!name:-}" ]]; then
    echo "with-credentials.sh: $name is empty in $env_file" >&2
    exit 1
  fi
done

# GITHUB_OWNER would override the provider's owner; a stray AWS profile would
# compete with the state credentials below.
unset GITHUB_TOKEN GITHUB_OWNER GITHUB_ORGANIZATION AWS_PROFILE AWS_SESSION_TOKEN

export TF_VAR_cloudflare_account_id="$CLOUDFLARE_ACCOUNT_ID"
export TF_VAR_github_token="$REPO_SECRETS_TOKEN"
export AWS_ACCESS_KEY_ID="$STATE_R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$STATE_R2_SECRET_ACCESS_KEY"
export AWS_ENDPOINT_URL_S3="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"
export AWS_CONFIG_FILE=/dev/null
export AWS_SHARED_CREDENTIALS_FILE=/dev/null

exec "$@"
