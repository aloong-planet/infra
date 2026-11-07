# zone stack

Settings of the shared `aloongplanet.com` zone. Today there is one: the
Browser Cache TTL, which is set to 0, "Respect Existing Headers"
(`docs/specs/zone-settings.md`).

The stack runs through the `Terraform zone` workflow in the `production`
environment, the same environment and token as the apps stack, and its state
key is `zone/terraform.tfstate`. The repository README covers how a change
ships, credentials and running locally.

## Why the Browser Cache TTL is 0

Cloudflare's default is 4 hours, and it replaces any shorter `max-age` an
origin sends. The Pages projects in the zone send `max-age=0,
must-revalidate`, so on their custom domains a stylesheet went out with
`max-age=14400` while the HTML that links to it was checked on every visit.
After a homepage deploy that changed both, visitors from the previous 4 hours
got the new pages with the old stylesheet. With 0, browsers are told what each
origin sends.

## What the setting reaches

It is zone-wide, so it applies to every host in the zone, including the ones
this repository does not manage:

| Host | Effect |
|---|---|
| The homepage, `aloongplanet.com` and `www` | Static files are checked again on every visit, so a deploy reaches visitors on their next page load |
| `transfer.aloongplanet.com`, `agentshed.aloongplanet.com` | Their files, renamed on every build, are checked again on every visit (304 when unchanged) instead of kept for 4 hours. A long cache for them belongs in their own projects' headers |
| Download hosts | A file with its own longer Cache-Control is unaffected (`dl.aloongplanet.com` sends one year, immutable). A file without one gets no Cache-Control from Cloudflare |

Only what browsers are told changes; Cloudflare's own edge caching does not.

## Changing or removing a setting

Change the value and ship it as any change. To go back to 4 hours, set
`browser_cache_ttl` to `14400`.

Removing the resource does not restore anything: the provider's delete does
nothing, so the zone keeps its last value. Set the value you want first, then
remove the resource if it should no longer be managed.

The setting is imported rather than created, because it exists before
Terraform manages it. The import block stays: once the setting is in state it
does nothing, and it imports the setting again if the state is ever lost.

## A setting changed in the dashboard

It shows up in the next run of the workflow. Run it manually as a drift
check: the plan sets the value back to the one declared here.

## Adding a zone setting

Each new setting is its own decision, because it reaches every host in the
zone. Add it beside `browser_cache_ttl`, import it the same way, and add it to
this README and the spec. The zone settings API takes Zone Settings Read and
Edit, which the production token already has.
