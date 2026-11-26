# aloong-planet infra

Terraform for aloong-planet's cloud resources, organized into stacks. Today
there are four. `apps` manages per-app resources: the R2 release mirrors that
apps publish their formal releases to, the apps' landing pages, and read
access to the zone's analytics for the apps that count their downloads. It
also mints the token the `workers` stack deploys with. `workers` manages
Cloudflare Workers that run on a schedule: today agentshed's download count
Worker. `zone` manages the one setting of the shared `aloongplanet.com` zone
that is under Terraform, its Browser Cache TTL. The `access` stack protects the voice assistant.

## Layout

```
modules/                 building blocks, one per capability
  release-mirror/        one app's R2 release mirror and its release secrets
  landing-page/          one app's landing page on Cloudflare Pages, on its domain
  workers-deploy-token/  the token the workers stack deploys Workers with
stacks/                  one Terraform root each: its own state, credentials, approvals
  apps/                  per-app resources (stacks/apps/README.md)
  workers/               scheduled Cloudflare Workers (stacks/workers/README.md)
  access/                the voice assistant Access application (stacks/access/README.md)
  zone/                  settings of the shared aloongplanet.com zone (stacks/zone/README.md)
  <stack>/tests/         the stack's terraform test files, if it has any
scripts/                 plan, apply, state snapshots and log redaction, for every stack
  tests/                 tests of the scripts, run by Check without credentials
.github/workflows/
  check.yml              fmt, validate and the stacks' and scripts' tests on every pull request, without credentials
  terraform-stack.yml    plan and apply for one stack
  terraform-<stack>.yml  one per stack: when it runs, and in which environment
```

## How resources are organized

Resources are grouped by what they are for, not by provider. One app's
release mirror is Cloudflare R2 plus GitHub secrets derived from a Cloudflare
token; split by provider, one change would span two states.

A new kind of resource goes into an existing stack, as a module or as a file
named for what it does. It starts a new stack only when one of these holds:

1. It needs credentials an existing stack should not hold, such as an admin
   token for organization settings.
2. A mistake in it reaches further than the existing stack's resources, such
   as zone-wide DNS records that Transfer also depends on.
3. It changes on a different schedule, or someone else approves it.

| Stack | Manages | Environment | State key |
|---|---|---|---|
| `apps` | Per-app resources: R2 release mirrors, landing pages and download counts' analytics tokens; the Workers deploy token | `production` | `infra/terraform.tfstate` |
| `workers` | Scheduled Cloudflare Workers: today agentshed's download count Worker | `production` | `workers/terraform.tfstate` |
| `zone` | Settings of the shared `aloongplanet.com` zone: today only its Browser Cache TTL | `production` | `zone/terraform.tfstate` |
| `access` | Voice assistant self-hosted Access application | `production` | `access/terraform.tfstate` |

The `apps` key predates the split into stacks and was kept so the state did
not have to move; new stacks use `<stack>/terraform.tfstate`.

### Not managed here

- Transfer's bucket and `dl.aloongplanet.com`. They share the account and the
  zone. Transfer's landing page is managed: the Pages project `transfer-org`
  on `transfer.aloongplanet.com`, imported into the apps stack. The only
  zone-wide setting declared here is the zone stack's Browser Cache TTL, and
  the only DNS records are the landing pages' own.
- The personal homepage (`aloongplanet.com`, `www`) and its Pages project. Its
  own repository deploys it; it is in the zone, so the Browser Cache TTL
  applies to it too.
- agentshed's `main` ruleset (id `20237985`). To manage it later, import it
  first and plan to zero changes; declaring it would create a second ruleset.
- The state bucket `aloong-planet-tfstate` and its token, which have to exist
  before Terraform can run. Both were created once through the Cloudflare API
  with the Terraform token. The bucket is private and holds only state; it is
  kept apart from every release bucket because those are served publicly.

## State

Each stack's state is in the R2 bucket `aloong-planet-tfstate` under its own
key, locked with Terraform's S3 lockfile (`use_lockfile`). R2 has no object
versioning and some resources (R2 CORS rules and custom domains among them)
cannot be imported again, so every apply in CI also copies the stack's state
to `history/<stack>/<UTC timestamp>.tfstate` in the same bucket. Snapshots
taken before the split into stacks are directly under `history/` and belong
to `apps`.

State and saved plans hold secrets in plaintext. They are never committed and
never uploaded as workflow artifacts; this repository is public, and so are
its workflow logs. Logs pass through `scripts/redact.sh`, which hides
Cloudflare account, zone and token IDs.

## How a change ships

1. **Pull request.** The `Check` workflow runs `terraform fmt -check` and
   `terraform validate` on every stack, and `terraform test` on every stack
   with test files in `tests/`, without any credentials. It also runs the
   scripts' tests in `scripts/tests/`, which plan throwaway configurations
   with no credentials and apply only to their local state. It fails if a
   stack has no `terraform-<stack>.yml` workflow.
2. **Merge to `main`.** The `Terraform <stack>` workflow of each stack whose
   Terraform files changed starts. A change to a script starts every stack's
   (a change only to the scripts' tests in `scripts/tests/` starts none), and
   a change to a module starts those of the stacks that use modules (today
   `apps`). Every job runs in the stack's environment, which needs the owner's
   approval:
   1. Approve **Plan**. The plan appears in the run summary.
   2. If it has changes, approve **Apply** after reading it. Apply plans
      again, stops unless that plan matches the approved one, applies it,
      snapshots the state, and fails unless a follow-up plan is empty.
3. **Drift check.** Run a stack's workflow manually. With nothing to change,
   it stops after Plan.

The `workers` stack's plan reads the `apps` stack's outputs from apps' state.
When one change touches both, approve apps' Plan and Apply first, then the
workers' Plan. A workers Plan approved before apps' Apply sees the old
outputs, or fails on an output that does not exist yet; run its workflow
again.

Runs of one stack are serialized: while one runs, the newest waiting run
replaces older waiting ones. A job left unapproved fails after 30 days and
holds up later runs of that stack until then, so cancel runs you will not
approve.

## Adding a stack

Only when the criteria above call for one.

1. Create `stacks/<stack>/` with its own `versions.tf` (copy the backend
   block from `apps`, with the key `<stack>/terraform.tfstate`),
   `providers.tf` and, if it takes inputs, `variables.tf`. Run
   `terraform init`, then
   `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`,
   and commit `.terraform.lock.hcl`. Tests go in `stacks/<stack>/tests/`,
   where `Check` finds them.
2. Add `.github/workflows/terraform-<stack>.yml`: a copy of
   `terraform-apps.yml` with the stack's own paths, the concurrency group
   `terraform-<stack>`, its environment, and the secrets it uses. The called
   workflow only sees secrets its caller passes by name: one left out is
   empty, without an error.
3. If it needs credentials `production` should not hold, create an
   environment for it with the owner as required reviewer, deployments from
   `main` only and "Prevent self-review" off. Give it `CLOUDFLARE_ACCOUNT_ID`
   and the `STATE_R2_*` values for the state backend, plus its own. A secret
   name not used yet goes into `on.workflow_call.secrets` and the step
   environments of `terraform-stack.yml`, and, if the env file holds it, into
   `scripts/with-credentials.sh`.
4. Its first run's plan should show only the new stack's resources.

## Credentials

Every stack's environment holds `CLOUDFLARE_ACCOUNT_ID` and the `STATE_R2_*`
values for the state backend, plus what its resources need. All four stacks use
`production`. The five credentials below have the same names in the local env
file and in the environment:

| Name | What it is | Scope |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | Account API token `terraform-aloong-planet-infra` | Account: Workers R2 Storage Write, Account API Tokens Write, Pages Write. Zone `aloongplanet.com` only: DNS Write, Zone Read, and Zone Settings Read and Edit, which only the `zone` stack uses |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID | |
| `REPO_SECRETS_TOKEN` | Fine-grained PAT `aloong-planet-infra-secrets`, resource owner `aloong-planet` | Secrets read and write on every repository in `release_mirrors` (`stacks/apps`, today `agentshed` and `justsnap`). Only the `apps` stack uses it |
| `STATE_R2_ACCESS_KEY_ID`, `STATE_R2_SECRET_ACCESS_KEY` | S3 credentials derived from the account API token `aloong-planet-tfstate` | Workers R2 Storage Bucket Item Write on `aloong-planet-tfstate` only |

The `workers` stack uses none of the Cloudflare token's permissions, which
include no Workers permission. It deploys with the account API token
`workers-deploy`, which the `apps` stack mints with Workers Scripts Write on
the account only and which the workers stack reads from apps' state. That
token is not in the env file or in any environment.

The `access` stack uses a dedicated `CLOUDFLARE_ACCESS_API_TOKEN` secret in
`production` for its Cloudflare provider. Its login variables and token scope
are documented in `stacks/access/README.md`. Plan this stack through its workflow.

The environment also holds `RELEASES_READ_TOKEN`,
the read-only GitHub token (agentshed ADR-0057) that the `workers` stack
binds to agentshed's download count Worker. It is a fine-grained PAT on the
owner's account, read-only on public repositories and with no permissions,
and Terraform does not create it. Its runbook,
`docs/ops/releases-read-token.md`, stores it straight into the environment
and renews it there; kept out of the env file, it is never written over by
the command below.

The local file is `~/.config/aloong-planet/infra.env` (mode 600, outside the
repository). To load it into the environment:

```sh
gh secret set -f ~/.config/aloong-planet/infra.env --env production -R aloong-planet/infra
```

The PAT in the env file expires (fine-grained PATs in this organization
last 366 days at most). To rotate it, or any other value in the env file:
update the env file, then run the command above again.

The `production` environment has the owner as its required reviewer, allows
deployments from `main` only, and leaves "Prevent self-review" off so the
owner can approve their own runs.

## Running locally

`scripts/with-credentials.sh` loads the env file and maps it the way the
workflow does. Run it from the stack's directory, `stacks/<stack>`, and
apply only through the workflow.

```sh
cd stacks/apps
../../scripts/with-credentials.sh terraform init
../../scripts/with-credentials.sh ../../scripts/plan.sh plan.tfplan plan.result
```

Delete `plan.tfplan` when done; it holds secrets.

The env file does not hold `RELEASES_READ_TOKEN`, so a local plan of the
`workers` stack stops with no value for `releases_read_token`. Plan that
stack through its workflow.
