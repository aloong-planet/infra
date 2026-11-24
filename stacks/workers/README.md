# workers stack

Cloudflare Workers that run on a schedule and answer no request. Today there
is one: agentshed's download count Worker, in its shadow period (agentshed
ADR-0056, `docs/specs/landing-page.md`).

The stack runs through the `Terraform workers` workflow in the `production`
environment, and its state key is `workers/terraform.tfstate`. It deploys
with the `workers-deploy` token that the `apps` stack mints, read from apps'
state, never with the environment's Cloudflare token (`stacks/apps/README.md`,
"The Workers deploy token"). The repository README covers how a change
ships, credentials and running locally.

## agentshed's download count Worker

`download-count.tf` deploys:

| Resource | Details |
|---|---|
| Workers script `agentshed-download-count` | Two ES modules from agentshed at the pinned commit: `download-count-worker.mjs`, the main module, and `download-count-core.mjs` beside it, under the names the main module imports |
| Cron Trigger | Minute 31 of every hour |
| workers.dev setting | Off, previews included: the Worker answers no request |

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

### Accepting a gap

When every run fails because its cursor is older than the analytics hold
(agentshed's runbook, "A stalled Worker count"), a pull request adds a
binding `ACCEPT_GAP_FROM`, plain text, set to that cursor. The next run
accepts the gap. The pull request after that removes the binding again.

### After an apply

The first apply needs apps' outputs, so apps is applied first (repository
README, "How a change ships"). After each apply, check the run record's
newest entries, one an hour with `written` true, with the command in
agentshed's runbook.

### Tests

`tests/download-count.tftest.hcl` plans the stack against a mock Cloudflare
provider and stand-ins for apps' outputs, with the modules fetched for real.
It checks that the pinned modules are what is uploaded, that a module with
other content is refused, and the bindings, schedule and workers.dev setting.
It does not show which token the provider uses, or whether Cloudflare
accepts the upload: the first Plan and Apply do.
