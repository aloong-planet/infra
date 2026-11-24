#!/usr/bin/env bash
# Runs scripts/plan.sh against throwaway configurations and checks the
# `changes` and `fingerprint` it writes. The configurations use only the
# hashicorp/random provider and local state, need no credentials, and are
# never applied. Every run's printed output is shown, so the job log is the
# evidence of what plan.sh prints.
#
# Covers the approved-plan fingerprint check of zone-settings::CON-003
# (docs/specs/zone-settings.md) and the Apply failure mode of a changed plan in
# that spec's failure modes, by proxy: a dashboard change cannot be made to a
# random resource, so a different planned create stands in for it.
#
# Gaps:
# - The approval path from Plan to Apply in GitHub Actions is not run here; it
#   needs the production environment. Testable only by a real stack run.
# - Imports by resource identity (`importing.identity`) are not driven:
#   random_string has no identity schema. plan.sh fingerprints the whole
#   `importing` object, so an identity is covered with the ID; testable once a
#   provider used here supports identity imports.
#
# Usage: plan-fingerprint.sh [path to plan.sh, default scripts/plan.sh]
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plan_sh="${1:-$script_dir/../scripts/plan.sh}"
plan_sh="$(cd "$(dirname "$plan_sh")" && pwd)/$(basename "$plan_sh")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

cat >versions.tf <<'EOF'
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}
EOF
terraform init -input=false -no-color >/dev/null

failures=()
fail() {
  echo "FAIL: $1" >&2
  failures+=("$1")
}

# plan <label> <configuration>: plans the configuration with plan.sh and sets
# `changes` and `fingerprint` from the result file it writes.
plan() {
  printf '%s\n' "$2" >main.tf
  echo "::group::plan.sh: $1"
  if ! "$plan_sh" "$work/plan.tfplan" "$work/result.txt"; then
    echo "::endgroup::"
    echo "plan.sh failed for: $1" >&2
    exit 1
  fi
  echo "::endgroup::"
  changes="$(sed -n 's/^changes=//p' result.txt)"
  fingerprint="$(sed -n 's/^fingerprint=//p' result.txt)"
}

import_config() { # <resource name> <import ID>
  cat <<EOF
import {
  to = random_string.$1
  id = "$2"
}

resource "random_string" "$1" {
  length = 16
}
EOF
}

create_config() { # <length>
  cat <<EOF
resource "random_string" "c" {
  length = $1
}
EOF
}

# Literals printed by plan.sh before it covered imports (origin/main 742dfa6).
unfixed_empty=95944597c15fe9ed084dcf00f71f1ffabf682e689d47cb128d8b2d1e9f3519f6
unfixed_create8=9c436ec05d060f54eabbeeb3089bf853f7eb0e6f62054666128baae452103f1e

plan "empty configuration" ""
[[ "$changes" == false ]] || fail "a plan with no imports and no changes writes changes=false (got '$changes')"
[[ "$fingerprint" == "$unfixed_empty" ]] || fail "a plan with no changes keeps its fingerprint (got $fingerprint)"
empty="$fingerprint"

plan "import random_string.a, ID alpha" "$(import_config a zzprobeidalphazz)"
[[ "$changes" == true ]] || fail "an import-only plan writes changes=true (got '$changes')"
import_a="$fingerprint"

plan "import random_string.a, ID alpha, again" "$(import_config a zzprobeidalphazz)"
[[ "$fingerprint" == "$import_a" ]] || fail "two plans of the same import have the same fingerprint"

[[ "$import_a" != "$empty" ]] || fail "importing a resource changes the fingerprint"

plan "import random_string.b, ID alpha" "$(import_config b zzprobeidalphazz)"
[[ "$fingerprint" != "$import_a" ]] || fail "an import to another address has another fingerprint"

plan "import random_string.a, ID bravo" "$(import_config a zzprobeidbravozz)"
[[ "$fingerprint" != "$import_a" ]] || fail "an import of another ID has another fingerprint"

plan "create random_string.c, length 8" "$(create_config 8)"
[[ "$changes" == true ]] || fail "a plan with a create writes changes=true (got '$changes')"
[[ "$fingerprint" == "$unfixed_create8" ]] || fail "a plan without imports keeps its fingerprint (got $fingerprint)"
create8="$fingerprint"

plan "create random_string.c, length 9" "$(create_config 9)"
[[ "$fingerprint" != "$create8" ]] || fail "a different planned create has another fingerprint"

if (( ${#failures[@]} > 0 )); then
  echo "${#failures[@]} case(s) failed." >&2
  exit 1
fi
echo "All plan fingerprint cases passed."
