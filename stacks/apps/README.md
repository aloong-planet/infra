# apps stack

Per-app resources, one module for each kind:

- R2 release mirrors that apps publish their formal releases to, listed in
  `release_mirrors` in `release-mirrors.tf`;
- landing pages on Cloudflare Pages, listed in `landing_pages` in
  `landing-pages.tf`;
- read access to the zone's analytics for apps whose landing page shows a
  download count, listed in `download_counts` in `download-counts.tf`.

It also mints the token the `workers` stack deploys its Workers with
(below).

agentshed is the first app with both (agentshed ADR-0031,
`docs/specs/mac-distribution.md`, and aloong-planet-home's
[`docs/specs/agentshed-site.md`](https://github.com/aloong-planet/aloong-planet-home/blob/main/docs/specs/agentshed-site.md),
`agentshed-site::CON-001`); its landing page is built and deployed by
aloong-planet-home, so its Git builds are off (below). JustSnap has both too,
and its landing page is built and deployed by aloong-planet-home as well
([`docs/specs/justsnap-site.md`](https://github.com/aloong-planet/aloong-planet-home/blob/main/docs/specs/justsnap-site.md),
`justsnap-site::CON-001`), so its Git builds are off too. Transfer has a
landing page only, the entry `transfer-org`; its release bucket is not managed
here.

The stack runs through the `Terraform apps` workflow in the `production`
environment, and its state key is `infra/terraform.tfstate`. The repository
README covers how a change ships, credentials and running locally.

## Release mirrors

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
keep them in plaintext in the state. They are organization secrets of
`aloong-planet`, visible to selected repositories only, which the owner
imports from a local configuration file with `~/apple-signing/import-secrets.sh`.

### Adding a release mirror

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

### Checking a download host's certificate

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

## Download counts

Each entry in `download_counts` gets, in `download-counts.tf`:

| Resource | Details |
|---|---|
| Account API token `<app>-download-count` | Analytics Read on the `aloongplanet.com` zone, nothing else |
| Two Actions secrets in the entry's `repository` | See below |

| Secret | Value |
|---|---|
| `CF_ANALYTICS_API_TOKEN` | The app's `<app>-download-count` token |
| `CF_ZONE_ID` | The `aloongplanet.com` zone's ID |

The app's download count workflow reads its download host's traffic from
Cloudflare's GraphQL Analytics API with these two, and reads and writes its
release bucket with the release mirror's four `R2_*` secrets, so an entry
here needs one in `release_mirrors` too. The zone ID is a secret rather than
a variable because the PAT holds secrets permission only. Terraform owns
both secrets, as it does the `R2_*` ones.

The stack also outputs each entry's zone ID and release bucket
(`download_counts`) and its token (`download_count_tokens`, sensitive). The
`workers` stack binds them to the app's download count Worker, if it has one.

agentshed is the first entry (agentshed ADR-0055, `docs/specs/download-count.md`,
`download-count::REQ-011`).

### Adding a download count

1. Check that the app's repository is in the PAT's repository access; it is
   when the app has a release mirror.
2. Add an entry to `download_counts` in `download-counts.tf`.
3. Open a pull request, merge it, and approve Plan and then Apply in the
   `Terraform apps` run. The plan should add the new entry's 3 resources and
   its values in the two outputs, and change nothing else.
4. Check that `gh secret list -R aloong-planet/<repository>` lists
   `CF_ANALYTICS_API_TOKEN` and `CF_ZONE_ID`.

Removing an entry destroys that app's token and its two secrets. If the app
has a Worker in the `workers` stack, remove that first: its plan fails once
the entry is gone from the outputs.

## The Workers deploy token

`workers-deploy-token.tf` mints it, through `modules/workers-deploy-token`:

| Resource | Details |
|---|---|
| Account API token `workers-deploy` | Workers Scripts Write on the account, nothing else |

The stack outputs its value as `workers_deploy_token` (sensitive), and the
`workers` stack's Cloudflare provider authenticates with it, read from this
stack's state. It is never written anywhere as a secret, and the production
environment's own token keeps no Workers permission. A permission is added
here only when a `workers` plan or apply reports it is missing, naming the
step that needs it.

The token's test (`tests/workers-deploy-token.tftest.hcl`) plans the module
with a stand-in permission group. Nothing tests that the lookup in
`workers-deploy-token.tf` finds the account-level Workers Scripts Write group:
Terraform's mocks give a computed list, such as the lookup's result, no
element, so no test can plan this stack.

## Landing pages

Each entry in `landing_pages` gets, through `modules/landing-page`:

| Resource | Details |
|---|---|
| Pages project, named after the entry's key | Builds `root_dir` of `aloong-planet/<repository>` with `build_command` into `output_dir`, on every push that changes a path in `watch_paths`. Pushes to `production_branch` deploy to the domain; other branches get preview deployments on `pages.dev`. `build_env` goes to production and preview builds alike, as plain text. With the entry's `git_builds_enabled` false, no push builds, on any branch (below) |
| Pages custom domain | The entry's `domain` |
| DNS record | A proxied `CNAME` from `domain` to the project's `pages.dev` host, in the `aloongplanet.com` zone |

Cloudflare runs the builds of the entries whose `git_builds_enabled` is true;
nothing here builds or deploys a site. Pull requests from forks get no preview
deployment. Nothing here reads the build settings of those entries from the
app's repository: when the app's build changes, change the entry (Transfer's
values are described below).

An entry with `git_builds_enabled` false (agentshed's and justsnap's) builds
nothing: its site is built by aloong-planet-home's CI and uploaded to the
project with Wrangler (that repository's
[ADR-0001](https://github.com/aloong-planet/aloong-planet-home/blob/main/docs/adr/0001-app-websites-in-this-repository.md)).
The project stays connected to its repository, because Cloudflare does not
switch a Git project to Direct Upload, and its build settings are kept but
unused. See [Turning off a page's Git builds](#turning-off-a-pages-git-builds).

Transfer's page, the entry `transfer-org`, was made in the dashboard before
this stack existed. `imports.tf` brings its project, domain and DNS record
into the state, and its entry holds the values the project had then, which
differ from the other entries: the `master` branch, Node 20, `pnpm install`
without a frozen lockfile, and a build on every push.

### Connecting a repository

Creating a project fails unless the Cloudflare Workers & Pages GitHub App is
installed on `aloong-planet` with access to the entry's repository; the
plan does not catch this. The owner installs it once, from the Cloudflare
dashboard: Workers & Pages, Create application, Pages, Connect to Git, then
on GitHub install it on `aloong-planet` with "Only select repositories" and
the repository. Leave the wizard there without creating a project: Terraform
creates it. For a later app, add its repository to the App's repository
access in the organization's GitHub Apps settings.

### Adding a landing page

1. Give the GitHub App access to the app's repository (above).
2. Add an entry to `landing_pages` in `landing-pages.tf`. The key names the
   project and its `pages.dev` host, which gets a suffix if the name is taken
   (JustSnap's is `justsnap-ceo.pages.dev`). By convention the domain is
   `<app>.aloongplanet.com`. If the app has a release mirror, its
   `allowed_origins` should list `https://<domain>`. The entry's
   `git_builds_enabled` is required: `true` if Cloudflare builds the site on pushes, as Transfer's
   does, or `false` if the site is built and uploaded elsewhere, as
   agentshed's and JustSnap's are (see below).
3. Open a pull request, merge it, and approve Plan and then Apply in the
   `Terraform apps` run. The plan should add the new entry's 3 resources and
   change nothing else.
4. Check the project (below).

Removing an entry deletes that app's project with all its deployments, its
domain and its DNS record.

### Turning off a page's Git builds

Set the entry's `git_builds_enabled` to `false`. The module then sets the
project's `production_deployments_enabled` to `false` and its
`preview_deployment_setting` to `"none"`, which are the two switches Cloudflare
names for [disabling automatic deployments](https://developers.cloudflare.com/pages/configuration/git-integration/#disable-automatic-deployments).
The plan should change that one project in place and nothing else.

Turn them off before the site's new deployer starts, so two never deploy the
same project and overwrite each other, and leave the entry in place afterwards:
removing it would delete the project. Setting the value back to `true` starts
Git builds again.

The module sets both settings for every entry, the ones whose value is `true`
included (production builds, and previews of the other branches), so a change
made to them in the dashboard shows up as drift in the next plan, and the value
in the entry is the only thing that decides them.

### Checking a project after its first apply

The project should have a production deployment from `production_branch`,
and the domain should be active:

```sh
cd stacks/apps
project=agentshed ../../scripts/with-credentials.sh bash -c '
  api() {
    printf "header = \"Authorization: Bearer %s\"\n" "$CLOUDFLARE_API_TOKEN" |
      curl -s --config - "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/$project$1"
  }
  api "" | jq "{subdomain: .result.subdomain, production: (.result.canonical_deployment | if . == null then null else {created_on, stage: .latest_stage} end)}"
  api /domains | jq "[.result[] | {name, status}]"
'
```

`production` is null until a production build has run. Watch paths skip
pushes that change none of them, so if none has run, start one from the head
of the production branch with the Pages API's
[create deployment](https://developers.cloudflare.com/api/resources/pages/subresources/projects/subresources/deployments/methods/create/).
The domain turns `active` once its certificate is issued.

### Known provider issues

Both were open on 2026-10-19, reported against v5.23.0 (this stack pins
v5.28.0). They concern changes to an existing project, not its creation:

- Changing a binding of an existing project fails: the provider sends the
  second of the production and preview maps empty
  ([#7305](https://github.com/cloudflare/terraform-provider-cloudflare/issues/7305)).
  `build_env` becomes maps of the same shape. Changing a value in it worked
  on 2026-10-19 (`NODE_VERSION` in both maps, #8); adding or removing a
  variable has not been tried. If a change fails, set the variables in the
  dashboard as well, so the next plan is empty.
- An apply that changes a project while one of its deployments is building
  can fail with "Provider produced inconsistent result after apply" after it
  has already made the change
  ([#7303](https://github.com/cloudflare/terraform-provider-cloudflare/issues/7303)).
  Run the workflow again once the deployment is done; its plan should be
  empty.
- The same issue makes a plan that changes a project carry the project's
  latest deployment. Every push to the repository adds one, a push the watch
  paths skip included, so a push between Plan and Apply makes Apply stop at
  the fingerprint check. Approve the two close together, or run the workflow
  again.
