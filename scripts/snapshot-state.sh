#!/usr/bin/env bash
# Run from a stack directory, stacks/<name>. Copies that stack's current state
# to history/<name>/<UTC timestamp>.tfstate in the state bucket. R2 has no
# object versioning, and some resources cannot be imported again, so these
# copies are the only way back to an earlier state.
# Credentials reach curl through stdin, never through its arguments.
set -euo pipefail

: "${AWS_ACCESS_KEY_ID:?}" "${AWS_SECRET_ACCESS_KEY:?}" "${AWS_ENDPOINT_URL_S3:?}"

# Must match the bucket in the backend block of every stack's versions.tf.
state_bucket="aloong-planet-tfstate"

stack_dir="$(pwd -P)"
if [[ "$(basename "$(dirname "$stack_dir")")" != "stacks" ]]; then
  echo "snapshot-state.sh: run this from a stack directory, stacks/<name>" >&2
  exit 1
fi
stack="$(basename "$stack_dir")"

state="$(mktemp)"
trap 'rm -f "$state"' EXIT
terraform state pull >"$state"

key="history/$stack/$(date -u +%Y%m%dT%H%M%SZ).tfstate"
code="$(printf 'user = "%s:%s"\n' "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" |
  curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    --aws-sigv4 "aws:amz:auto:s3" --config - \
    --upload-file "$state" "$AWS_ENDPOINT_URL_S3/$state_bucket/$key")"

if [[ "$code" != "200" ]]; then
  echo "snapshot-state.sh: upload of $key failed with HTTP $code" >&2
  exit 1
fi
echo "State snapshot: $key"
