#!/usr/bin/env bash
# Plans again, refuses to continue unless the plan's fingerprint equals the
# approved one, applies that saved plan, snapshots the state, and then
# requires a follow-up plan with no changes.
set -euo pipefail

approved="${1:?usage: apply.sh <approved-fingerprint>}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

"$script_dir/plan.sh" "$work/apply.tfplan" "$work/apply.result"
actual="$(sed -n 's/^fingerprint=//p' "$work/apply.result")"
if [[ "$actual" != "$approved" ]]; then
  echo "apply.sh: the plan differs from the approved plan; not applying." >&2
  echo "apply.sh: approved $approved, now $actual. Re-run the workflow to plan again." >&2
  exit 1
fi

set +e
terraform apply -input=false -lock-timeout=5m -no-color "$work/apply.tfplan" >"$work/apply.log" 2>&1
apply_rc=$?
set -e
"$script_dir/redact.sh" <"$work/apply.log"

# Snapshot even after a failed apply: the state then records what was created.
"$script_dir/snapshot-state.sh"

if [[ "$apply_rc" -ne 0 ]]; then
  exit "$apply_rc"
fi

echo "Follow-up plan (must have no changes):"
"$script_dir/plan.sh" "$work/verify.tfplan" "$work/verify.result"
if ! grep -qx 'changes=false' "$work/verify.result"; then
  echo "apply.sh: the follow-up plan still has changes." >&2
  exit 1
fi
