# aloong-planet infra

Terraform for aloong-planet's cloud resources, organized into stacks. Today
there is one, `apps`, which manages the R2 release mirrors that apps publish
their formal releases to.

## Layout

```
modules/                 building blocks, one per capability
  release-mirror/        one app's R2 release mirror and its release secrets
stacks/                  one Terraform root each: its own state, credentials, approvals
  apps/                  per-app resources (stacks/apps/README.md)
scripts/                 plan, apply, state snapshots and log redaction, for every stack
.github/workflows/
  check.yml              fmt and validate on every pull request, without credentials
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
| `apps` | Per-app resources: today the R2 release mirrors | `production` | `infra/terraform.tfstate` |

The `apps` key predates the split into stacks and was kept so the state did
not have to move; new stacks use `<stack>/terraform.tfstate`.

### Not managed here

- Transfer's bucket, `dl.aloongplanet.com`, and the `transfer.aloongplanet.com`
  Pages project and DNS. They share the account and the zone; nothing here
  touches zone-wide settings, and the zone is only read.
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
   `terraform validate` on every stack, without any credentials. It also
   fails if a stack has no `terraform-<stack>.yml` workflow.
2. **Merge to `main`.** The `Terraform <stack>` workflow of each stack whose
   Terraform files changed starts; a change to a module or a script starts
   every stack's. Every job runs in the stack's environment, which needs the
   owner's approval:
   1. Approve **Plan**. The plan appears in the run summary.
   2. If it has changes, approve **Apply** after reading it. Apply plans
      again, stops unless that plan matches the approved one, applies it,
      snapshots the state, and fails unless a follow-up plan is empty.
3. **Drift check.** Run a stack's workflow manually. With nothing to change,
   it stops after Plan.

Runs of one stack are serialized: while one runs, the newest waiting run
replaces older waiting ones. A job left unapproved fails after 30 days and
holds up later runs of that stack until then, so cancel runs you will not
approve.

## Adding a stack

Only when the criteria above call for one.

1. Create `stacks/<stack>/` with its own `versions.tf` (copy the backend
   block from `apps`, with the key `<stack>/terraform.tfstate`),
   `providers.tf` and `variables.tf`. Run `terraform init`, then
   `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`,
   and commit `.terraform.lock.hcl`.
2. Add `.github/workflows/terraform-<stack>.yml`: a copy of
   `terraform-apps.yml` with the stack's own paths, the concurrency group
   `terraform-<stack>`, and its environment.
3. If it needs credentials `production` should not hold, create an
   environment for it with the owner as required reviewer, deployments from
   `main` only and "Prevent self-review" off. Give it `CLOUDFLARE_ACCOUNT_ID`
   and the `STATE_R2_*` values for the state backend, plus its own. A secret
   name not mapped yet goes into the step environments of
   `terraform-stack.yml` and into `scripts/with-credentials.sh`.
4. Its first run's plan should show only the new stack's resources.

## Credentials

Every stack's environment holds `CLOUDFLARE_ACCOUNT_ID` and the `STATE_R2_*`
values for the state backend, plus what its resources need. Today there is
one environment, `production`, used by `apps`. These five values have the
same names in the local env file and as its secrets:

| Name | What it is | Scope |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | Account API token `terraform-aloong-planet-infra` | Account: Workers R2 Storage Write, Account API Tokens Write, Pages Write. Zone `aloongplanet.com` only: DNS Write, Zone Read |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID | |
| `REPO_SECRETS_TOKEN` | Fine-grained PAT `aloong-planet-infra-secrets`, resource owner `aloong-planet` | Secrets read and write on every repository in `release_mirrors` (`stacks/apps`, today `agentshed`), plus `vlm-snapper`, which nothing here writes to yet |
| `STATE_R2_ACCESS_KEY_ID`, `STATE_R2_SECRET_ACCESS_KEY` | S3 credentials derived from the account API token `aloong-planet-tfstate` | Workers R2 Storage Bucket Item Write on `aloong-planet-tfstate` only |

The local file is `~/.config/aloong-planet/infra.env` (mode 600, outside the
repository). To load it into the environment:

```sh
gh secret set -f ~/.config/aloong-planet/infra.env --env production -R aloong-planet/infra
```

The PAT expires (fine-grained PATs in this organization last 366 days at
most). To rotate it, or any other value: update the env file, then run the
command above again.

The `production` environment has the owner as its required reviewer, allows
deployments from `main` only, and leaves "Prevent self-review" off so the
owner can approve their own runs.

## Running locally

`scripts/with-credentials.sh` loads the env file and maps it the way the
workflow does. Run it from the stack's directory, and apply only through the
workflow.

```sh
cd stacks/apps
../../scripts/with-credentials.sh terraform init
../../scripts/with-credentials.sh ../../scripts/plan.sh plan.tfplan plan.result
```

Delete `plan.tfplan` when done; it holds secrets.
