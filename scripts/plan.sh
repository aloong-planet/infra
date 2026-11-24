#!/usr/bin/env bash
# Saves a plan to <plan-file>, prints it with Cloudflare identifiers redacted,
# and writes `changes=<true|false>` and `fingerprint=<sha256>` to <result-file>.
# The fingerprint covers every planned resource action, import, move and output
# change, sensitive values included, so a later plan can be checked against the
# one that was approved. A resource with no action counts only if it moves or
# is imported, and then only by its old and new address and what it is imported
# from: its refreshed read-only attributes (such as a custom domain's
# certificate status) can change between two plans without any change to what
# would be applied.
# Neither the plan file nor its JSON form is ever printed or uploaded.
set -euo pipefail

plan_file="${1:?usage: plan.sh <plan-file> <result-file>}"
result_file="${2:?usage: plan.sh <plan-file> <result-file>}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

set +e
terraform plan -input=false -lock-timeout=5m -no-color -detailed-exitcode -out="$plan_file" >"$log" 2>&1
rc=$?
set -e

# Terraform 1.16.6 prints an import's ID in plain text in this log, even when
# the ID comes from a sensitive variable, and redact.sh masks only 32-hex
# identifiers.
"$script_dir/redact.sh" <"$log"

case "$rc" in
  0) changes=false ;;
  2) changes=true ;;
  *) exit "$rc" ;;
esac

fingerprint="$(terraform show -json "$plan_file" | jq -S '{
  resources: [.resource_changes[]?
    | select(.change.actions != ["no-op"] or .previous_address != null
        or .change.importing != null)
    | {address, previous_address, actions: .change.actions}
      + (if .change.actions == ["no-op"] then {} else {change} end)
      + (if .change.actions == ["no-op"] and .change.importing != null
         then {importing: .change.importing} else {} end)],
  outputs: [(.output_changes // {}) | to_entries[] | select(.value.actions != ["no-op"])]
}' | shasum -a 256 | cut -d ' ' -f 1)"

printf 'changes=%s\nfingerprint=%s\n' "$changes" "$fingerprint" >"$result_file"
printf 'changes=%s\nfingerprint=%s\n' "$changes" "$fingerprint"
