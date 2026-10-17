#!/usr/bin/env bash
# Filters stdin to stdout, replacing 32-character hex strings with <id>.
# Cloudflare account, zone and token IDs all have this form, and Terraform
# prints resource IDs on every refresh and create; the R2 access key ID is
# such a token ID.
set -euo pipefail
sed -E 's/[0-9a-f]{32}/<id>/g'
