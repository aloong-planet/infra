# apps stack

Per-app resources. Today these are the R2 release mirrors that apps publish
their formal releases to, one per app, listed in `release_mirrors` in
`release-mirrors.tf`. agentshed is the first (agentshed ADR-0031,
`docs/specs/mac-distribution.md`).

The stack runs through the `Terraform apps` workflow in the `production`
environment, and its state key is `infra/terraform.tfstate`. The repository
README covers how a change ships, credentials and running locally.

## What this manages

Each entry in `release_mirrors` gets, through `modules/release-mirror`:

| Resource | Details |
|---|---|
| R2 bucket | The entry's `bucket`. Standard storage class, default jurisdiction |
| Bucket CORS | `GET` only, from the entry's `allowed_origins` only |
| R2 custom domain | The entry's `download_host`, in the `aloongplanet.com` zone. TLS 1.2 or later |
| Account API token `<bucket>-writer` | Read, write and list objects in that bucket, nothing else |
| Four Actions secrets in the entry's `repository` | See below |

### Secrets written to each app's repository

The names match Transfer's, so its release workflow and R2 runbook carry over,
and every app's release workflow reads the same names.

| Secret | Value |
|---|---|
| `R2_ACCOUNT_ID` | Cloudflare account ID |
| `R2_ACCESS_KEY_ID` | ID of the app's `<bucket>-writer` token |
| `R2_SECRET_ACCESS_KEY` | Lowercase hex SHA-256 of that token's value |
| `R2_BUCKET` | The app's bucket |

S3 clients use the endpoint `https://<R2_ACCOUNT_ID>.r2.cloudflarestorage.com`
with region `auto`. Terraform owns these four secrets: a change made to them
outside Terraform is overwritten by the next apply.

### Not managed here

agentshed's signing and notarization secrets (`CSC_LINK`, `CSC_KEY_PASSWORD`,
`APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID`). Terraform would
keep them in plaintext in the state; the owner sets them with
`gh secret set NAME < file`.

## Adding an app

1. Add the app's repository to the repository access of the PAT
   `aloong-planet-infra-secrets` (see Credentials in the repository README).
   Otherwise Apply creates the Cloudflare resources and then fails writing
   the secrets.
2. Add an entry to `release_mirrors` in `release-mirrors.tf`. By convention
   the bucket is `<app>-releases` and the download host is
   `dl.<app>.aloongplanet.com`. `allowed_origins` lists the origins that read
   the bucket from a browser, normally the app's landing page.
3. Open a pull request, merge it, and approve Plan and then Apply in the
   `Terraform apps` run. The plan should add the new entry's 8 resources and
   change nothing else.
4. Check the download host's certificate (below).
5. Point the app's release workflow at the four `R2_*` secrets; agentshed's
   or Transfer's workflow can be copied.

Removing an entry destroys that app's bucket, custom domain, token and
secrets.

## Checking a download host's certificate

Check each new download host from outside Cloudflare after its first apply.
For agentshed this was a condition of ADR-0031, which kept a fallback host
until the check passed.

```sh
host=dl.agentshed.aloongplanet.com
openssl s_client -connect "$host:443" -servername "$host" </dev/null 2>/dev/null |
  openssl x509 -noout -subject -ext subjectAltName -dates
```

The host is valid if the subject or a SAN covers it and the dates are current.

`dl.agentshed.aloongplanet.com`, checked on 2026-10-17 right after its first
apply: the certificate (issued by Google Trust Services, valid until
2027-01-15) lists the host as a SAN, and verification with hostname checking
passed both through the local resolver and directly against a public-DNS
address. agentshed's fallback host is not needed.

## Next: the landing page

agentshed's landing page (Cloudflare Pages, root directory `site`, domain
`agentshed.aloongplanet.com`) belongs in this stack, as a module next to
`release-mirror`. It comes after agentshed #237 and #238 are merged: until
then agentshed has no `site/` directory and the first build would fail. It
also needs the Cloudflare Workers & Pages GitHub App installed on the
`aloong-planet` organization, limited to `agentshed`.
