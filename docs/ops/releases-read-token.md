# The read-only GitHub token

The runbook of `RELEASES_READ_TOKEN`: what the token is, how long it may
last, which Workers bind it, and how to renew it. Why agentshed's download
count Worker reads GitHub's releases with a token, and never without one, is
agentshed ADR-0057
(<https://github.com/aloong-planet/agentshed/blob/main/docs/adr/0057-download-count-reads-github-with-a-read-only-token.md>).

## What it is

| What | Value |
|---|---|
| Token | `public-releases-count`, a fine-grained personal access token on the owner's GitHub account: repository access "Public repositories", read-only, and no permissions. It reads only what anyone can |
| Expiration | Within 366 days ("Its expiration" below) |
| Secret | `RELEASES_READ_TOKEN` in this repository's `production` environment, which the workflow passes to the `workers` stack as `releases_read_token`. Terraform does not create the token, and the env file does not hold it (`README.md`, "Credentials") |
| Its value | Never in this repository, a run record or a log |

## Its expiration

The token must expire within 366 days. GitHub's documentation says: "For
fine-grained personal access tokens, the default the maximum lifetime policy
for organizations is set to expire within 366 days", and a member's token
whose lifetime does not comply is blocked from accessing the organization
("Enforcing a maximum lifetime policy for personal access tokens",
<https://docs.github.com/en/organizations/managing-programmatic-access-to-your-organization/setting-a-personal-access-token-policy-for-your-organization>,
2026-11-25).

That holds for the organization's public repositories too. Two tokens with
no expiration were refused in the download count Worker's runs at
2026-11-25T07:31Z and 08:31Z, both with "page 1 of GitHub's releases
answered HTTP 403", which is not GitHub's rate limit: the run record shows
that one as `rate-limited`. A token that expires in a year read the releases
locally with HTTP 200. Bound to the Worker at 08:36Z, it read them in the
Worker's run at 09:31Z too, whose entry has `github` `ok`.

## Which Workers bind it

| Worker | Binding | Its run record |
|---|---|---|
| agentshed's download count Worker (`stacks/workers/download-count.tf`) | The secret binding `RELEASES_READ_TOKEN` | <https://dl.agentshed.aloongplanet.com/stats/worker-runs.json>, read as agentshed's runbook says ("The Worker in the shadow period", <https://github.com/aloong-planet/agentshed/blob/main/docs/ops/download-count.md#the-worker-in-the-shadow-period>) |

A new Worker that reads GitHub binds the same secret, and is added here.

The `workers` stack's plan refuses the token empty or not alone
(`stacks/workers/README.md`, "The read-only GitHub token"). Once a Worker
runs with it, its run record shows when GitHub does not take it, and every
run fails until the token is replaced: for the download count Worker, an
entry with `github` `failed`.

## Renewing or replacing it

Before it expires, or once GitHub refuses it:

1. On GitHub, Settings → Developer settings → Personal access tokens →
   Fine-grained tokens, generate a new token on the owner's account with the
   settings above and an expiration within 366 days.
2. Before storing it, read GitHub's releases with it once. These commands
   work in bash and in zsh. They read the token from hidden input, never
   from the command line, and print only the status and, when GitHub refuses
   the token, its reason:

   ```sh
   printf 'token: '; read -rs T; echo
   F=$(mktemp); printf 'Authorization: Bearer %s\n' "$T" | curl -sS -o "$F" -w 'HTTP %{http_code}\n' -H @- -H 'User-Agent: agentshed-download-count' 'https://api.github.com/repos/aloong-planet/agentshed/releases?per_page=1'; unset T; jq -r 'if type=="object" then .message else "ok, \(length) release" end' "$F"; rm -f "$F"
   ```

   Store it only when the first line is `HTTP 200`. Any other status is
   GitHub refusing it, for the reason on the second line: a token GitHub
   does not know is answered `HTTP 401` and "Bad credentials".
3. Store it in the environment, pasting it when the command asks, never on
   the command line:

   ```sh
   gh secret set RELEASES_READ_TOKEN --env production -R aloong-planet/infra
   ```

4. A secret changes no file in this repository, so start the `workers`
   stack's run by hand, then approve its Plan and its Apply:

   ```sh
   gh workflow run terraform-workers.yml -R aloong-planet/infra
   ```

   A Plan that stops at `releases_read_token` refuses the value stored: it
   is empty, or it is not the token alone (a token of another kind, or the
   token with a space, a line break or another character a token cannot
   hold). Nothing is deployed, and every Worker keeps the token it has.
   Store the token again (step 3), then start the run again.

5. Delete the old token on GitHub only once every Worker that binds it has
   read GitHub with the new one: its run record has an entry, from a run
   after the Apply, whose read of GitHub succeeded. For the download count
   Worker, that entry has `github` `ok`.
