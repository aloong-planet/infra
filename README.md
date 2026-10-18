# aloong-planet infra

Terraform for aloong-planet's cloud resources. Today it manages the R2 mirror
behind agentshed's formal releases (agentshed ADR-0031,
`docs/specs/mac-distribution.md`).

## What this manages

| Resource | Details |
|---|---|
| R2 bucket `agentshed-releases` | Standard storage class, default jurisdiction |
| Bucket CORS | `GET` only, from `https://agentshed.aloongplanet.com` only |
| R2 custom domain `dl.agentshed.aloongplanet.com` | TLS 1.2 or later. ADR-0031 falls back to `dl-agentshed.aloongplanet.com` if the certificate is not valid from outside Cloudflare |
| Account API token `agentshed-releases-writer` | Read, write and list objects in `agentshed-releases`, nothing else |
| Four Actions secrets in `aloong-planet/agentshed` | See below |

### Secrets written to `aloong-planet/agentshed`

The names match Transfer's, so its release workflow and R2 runbook carry over.

| Secret | Value |
|---|---|
| `R2_ACCOUNT_ID` | Cloudflare account ID |
| `R2_ACCESS_KEY_ID` | ID of the `agentshed-releases-writer` token |
| `R2_SECRET_ACCESS_KEY` | Lowercase hex SHA-256 of that token's value |
| `R2_BUCKET` | `agentshed-releases` |

S3 clients use the endpoint `https://<R2_ACCOUNT_ID>.r2.cloudflarestorage.com`
with region `auto`. Terraform owns these four secrets: a change made to them
outside Terraform is overwritten by the next apply.

### Not managed here

- Transfer's bucket, `dl.aloongplanet.com`, and the `transfer.aloongplanet.com`
  Pages project and DNS. They share the account and the zone; nothing here
  touches zone-wide settings, and the zone is only read.
- agentshed's signing and notarization secrets (`CSC_LINK`, `CSC_KEY_PASSWORD`,
  `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID`). Terraform would
  keep them in plaintext in the state; the owner sets them with
  `gh secret set NAME < file`.
- agentshed's `main` ruleset (id `20237985`). To manage it later, import it
  first and plan to zero changes; declaring it would create a second ruleset.
- The state bucket `aloong-planet-tfstate` and its token, which have to exist
  before Terraform can run. Both were created once through the Cloudflare API
  with the Terraform token. The bucket is private and holds only state; it is
  kept apart from every release bucket because those are served publicly.

## State

State is in the R2 bucket `aloong-planet-tfstate` under
`infra/terraform.tfstate`, locked with Terraform's S3 lockfile
(`use_lockfile`). R2 has no object versioning and two of the resources above
(`cloudflare_r2_bucket_cors`, `cloudflare_r2_custom_domain`) cannot be
imported again, so every apply in CI also copies the state to
`history/<UTC timestamp>.tfstate` in the same bucket.

State and saved plans hold secrets in plaintext. They are never committed and
never uploaded as workflow artifacts; this repository is public, and so are
its workflow logs. Logs pass through `scripts/redact.sh`, which hides
Cloudflare account, zone and token IDs.

## How a change ships

1. **Pull request.** The `Check` workflow runs `terraform fmt -check` and
   `terraform validate` without any credentials.
2. **Merge to `main`.** The `Terraform` workflow starts, and every job in it
   runs in the `production` environment, which needs the owner's approval:
   1. Approve **Plan**. The plan appears in the run summary.
   2. If it has changes, approve **Apply** after reading it. Apply plans
      again, stops unless that plan matches the approved one, applies it,
      snapshots the state, and fails unless a follow-up plan is empty.
3. **Drift check.** Run the `Terraform` workflow manually. With nothing to
   change, it stops after Plan.

Runs are serialized: while one runs, the newest waiting run replaces older
waiting ones. A job left unapproved fails after 30 days and holds up later
runs until then, so cancel runs you will not approve.

## Credentials

Five values, with the same names in the local env file and as secrets of the
`production` environment:

| Name | What it is | Scope |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | Account API token `terraform-aloong-planet-infra` | Account: Workers R2 Storage Write, Account API Tokens Write, Pages Write. Zone `aloongplanet.com` only: DNS Write, Zone Read |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID | |
| `REPO_SECRETS_TOKEN` | Fine-grained PAT `aloong-planet-infra-secrets`, resource owner `aloong-planet` | Secrets read and write on `agentshed` and `vlm-snapper`. Nothing here writes to `vlm-snapper` yet; it is in scope for later use |
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
workflow does. Apply only through the workflow.

```sh
scripts/with-credentials.sh terraform init
scripts/with-credentials.sh scripts/plan.sh plan.tfplan plan.result
```

Delete `plan.tfplan` when done; it holds secrets.

## Checking the download host's certificate

ADR-0031 keeps the download host open until its certificate is checked from
outside Cloudflare:

```sh
openssl s_client -connect dl.agentshed.aloongplanet.com:443 \
  -servername dl.agentshed.aloongplanet.com </dev/null 2>/dev/null |
  openssl x509 -noout -subject -ext subjectAltName -dates
```

The host is valid if the subject or a SAN covers
`dl.agentshed.aloongplanet.com` and the dates are current.

Checked on 2026-10-17, right after the first apply: the certificate (issued
by Google Trust Services, valid until 2027-01-15) lists
`dl.agentshed.aloongplanet.com` as a SAN, and verification with hostname
checking passed both through the local resolver and directly against a
public-DNS address. The fallback host is not needed.

## Next: the landing page

agentshed's landing page (Cloudflare Pages, root directory `site`, domain
`agentshed.aloongplanet.com`) comes after agentshed #237 and #238 are merged:
until then agentshed has no `site/` directory and the first build would fail.
It also needs the Cloudflare Workers & Pages GitHub App installed on the
`aloong-planet` organization, limited to `agentshed`.
