# workers stack

Cloudflare Workers that run on a schedule and answer no request. Today there
is one: agentshed's download count Worker, in its shadow period (agentshed
ADR-0056, `docs/specs/download-count.md`).

The stack runs through the `Terraform workers` workflow in the `production`
environment, and its state key is `workers/terraform.tfstate`. It deploys
with the `workers-deploy` token that the `apps` stack mints, read from apps'
state, never with the environment's Cloudflare token (`stacks/apps/README.md`,
"The Workers deploy token"). The one secret of the environment it binds to
a Worker is `RELEASES_READ_TOKEN` (below). The repository README covers how a
change ships, credentials and running locally.

## agentshed's download count Worker

`download-count.tf` deploys:

| Resource | Details |
|---|---|
| Workers script `agentshed-download-count` | Two ES modules from agentshed at the pinned commit: `download-count-worker.mjs`, the main module, and `download-count-core.mjs` beside it, under the names the main module imports |
| Cron Trigger | Minute 31 of every hour |
| workers.dev setting | Off, previews included: the Worker answers no request |

The provider warns that it cannot destroy the Cron Trigger: "If you create
this resource, it will be present in the API until manually deleted." Whoever
removes the Worker from this stack checks in Cloudflare that its schedule is
gone too.

Its bindings are the ones agentshed's `docs/ops/download-count.md` lists
("The Worker in the shadow period"), with these values:

| Binding | Value |
|---|---|
| `BUCKET` | R2 binding to agentshed's release bucket, from apps' `download_counts` output |
| `CF_ANALYTICS_API_TOKEN` | Secret: agentshed's analytics token, from apps' `download_count_tokens` output |
| `CF_ZONE_ID` | The `aloongplanet.com` zone, from apps' `download_counts` output |
| `CORE_SHA256` | The core module's pinned SHA-256 |
| `DOWNLOAD_HOST` | `https://dl.agentshed.aloongplanet.com` |
| `GITHUB_REPOSITORY` | `aloong-planet/agentshed` |
| `RELEASES_READ_TOKEN` | Secret: the read-only GitHub token (agentshed ADR-0057), the `production` environment's `RELEASES_READ_TOKEN`, which the workflow passes as `releases_read_token` |

### The read-only GitHub token

The Worker fails every run without it, so the plan fails, and nothing is
deployed, when `releases_read_token` is empty, as it is when the environment
does not hold the secret or the workflow does not pass it. It fails too when
the value does not start with `github_pat_`, the prefix of a fine-grained
personal access token, the kind ADR-0057 chose, or holds after the prefix a
character a bearer token cannot hold (RFC 6750's b64token: letters, digits
and `-._~+/`, then any `=` padding), which includes every kind of
whitespace. A space or tab inside the token, or a character outside ASCII
anywhere in it, reaches GitHub as part of it, and a newline inside it fails
the request. A space, tab or line break after it is dropped from the
request's header (a form feed or vertical tab is not), but not from the bound
value, which the Worker removes verbatim from a failure's text (agentshed's
`scripts/download-count-worker.mjs`).

Both checks are preconditions on the Worker, not a validation on the
variable, because whether a failing validation prints a sensitive value
depends on the Terraform version and on where the value comes from, and the
logs are public. Terraform 1.16.6 prints a value set in a `.tfvars` or a test
file, and not one from `TF_VAR_`, the workflow's source; 1.11.2 printed one
from `TF_VAR_` too. A failing precondition printed nothing of it in either.

Terraform does not create the token. What it is, how long it may last, and
how it is made, stored and renewed are in its runbook,
`docs/ops/releases-read-token.md`.

### The pinned modules

`download-count.tf` pins an agentshed commit and the SHA-256 of each module at
that commit. The plan fetches each module from
`raw.githubusercontent.com` at that commit and fails at its postcondition
when the content's hash is not the pinned one, so nothing is deployed.

To change the Worker, merge the agentshed pull request first. Then, in one
pull request here, set the commit to its merge commit and both hashes to
the output of this command at that commit in agentshed:

```sh
shasum -a 256 scripts/download-count-worker.mjs scripts/download-count-core.mjs
```

`tests/download-count.tftest.hcl` writes the same hashes out, so change them
there too.

When a hash is wrong, that test fails in the pull request's `Check` run, and
its output gives the fetched content's hash beside the pinned one. In a
Plan's log `scripts/redact.sh` replaces every 32-character hex run, so each
hash shows as `<id><id>` and the commit as `<id>` and its last 8 characters.

### Accepting a gap

When every run fails because its cursor is older than the analytics hold
(agentshed's runbook, "A stalled Worker count"), a pull request adds a
binding `ACCEPT_GAP_FROM`, plain text, set to that cursor, and adds it to
the bindings `tests/download-count.tftest.hcl` expects; otherwise `Check`
fails. The next run accepts the gap. The pull request after that removes the
binding again, from both.

### After an apply

The first apply needs apps' outputs, so apps is applied first (repository
README, "How a change ships"). After each apply, check the run record's
newest entries, one an hour with `written` true, with the command in
agentshed's runbook.

### Tests

`tests/download-count.tftest.hcl` plans the stack against a mock Cloudflare
provider and stand-ins for apps' outputs, with the modules fetched for real.
It checks that the pinned modules are what is uploaded, that either module
with other content is refused, and the bindings, schedule and workers.dev
setting. It also checks that both tokens read from apps' state are
sensitive: the state does not keep apps' sensitive mark, so this stack marks
them again (`apps.tf`). The read-only GitHub token is sensitive too, and the
plan refuses it empty, of another kind, with a trailing newline, with a
space inside it or with a no-break space after it. It does
not show which token the provider uses, or whether Cloudflare accepts the
upload. A Plan does not show them either: the provider does not check its
token, and planning new resources calls no API. The first Apply shows both.
Whether GitHub accepts the read-only token shows only in the check its
runbook makes before the token is stored (`docs/ops/releases-read-token.md`)
and in the Worker's run record after the Apply.
