# Zone settings

> Related: [features](../features/zone-settings.md)

## Problem Statement

Browsers keep static files from every site in the aloongplanet.com zone for 4 hours, whatever the site itself asks for. Cloudflare's zone-wide Browser Cache TTL defaults to 4 hours and replaces any shorter `max-age` an origin sends. The Pages projects in the zone send `public, max-age=0, must-revalidate`, so on their custom domains a stylesheet goes out with `max-age=14400`, while the HTML that links to it is always checked again.

After a deploy that changes the personal homepage's stylesheet together with its pages, a visitor from the previous 4 hours gets the new pages with the old stylesheet, and the layout breaks until the copy expires or the visitor forces a reload. Every later deploy that changes the stylesheet opens the same window.

The setting is not in Terraform. The apps stack reads the zone but leaves its settings alone, and its token cannot even read them.

## Solution

A new `zone` stack declares the zone's Browser Cache TTL as 0, which Cloudflare calls "Respect Existing Headers". Every host in the zone then passes on the Cache-Control its origin sends.

The stack has its own state and workflow, apart from the apps stack, so a change to one never plans changes in the other. It runs in the same `production` environment with the same token. That token gains Zone Settings Read and Edit on the zone, and nothing else changes. Plan and Apply wait for the owner's approval, as they do for every stack, and local runs use the same env file as the apps stack.

## User Stories

### zone-settings::US-001 Returning visitors get the stylesheet that matches the pages

As the owner of the personal homepage, I want a deploy that changes the stylesheet to reach returning visitors on their next page load, so that new pages never render with an old stylesheet.

- zone-settings::US-001/AC-01: Once the zone stack is applied, a static file of the homepage requested from aloongplanet.com or www.aloongplanet.com carries the Cache-Control the Pages project sends (`public, max-age=0, must-revalidate`), not `max-age=14400`.

### zone-settings::US-002 The zone's browser cache changes only through a reviewed plan

As the owner, I want the zone's Browser Cache TTL in Terraform, so that a change to it ships through a pull request and an approved plan, and a change made anywhere else shows up.

- zone-settings::US-002/AC-01: The zone stack's first plan imports the zone's existing Browser Cache TTL and shows one change, from its current value to 0, and nothing else.
- zone-settings::US-002/AC-02: After Apply, the follow-up plan has no changes.
- zone-settings::US-002/AC-03: When the setting has been changed outside Terraform, the next run of the zone stack's workflow plans it back to 0.
- zone-settings::US-002/AC-04: The zone stack's Plan and Apply each wait for the owner's approval in the `production` environment, which accepts deployments from `main` only.

## Functional Requirements

### zone-settings::REQ-001 The zone respects each origin's cache headers (direct acceptance)

The zone stack declares the aloongplanet.com zone's Browser Cache TTL as 0 (Respect Existing Headers). The value applies to every host in the zone, Transfer, agentshed and the download hosts included.

## Constraints

### zone-settings::CON-001 Zone settings permissions stay narrow (direct acceptance)

Applies to: the production environment's Cloudflare token and both stacks. The token gains only Zone Settings Read and Zone Settings Edit, on the aloongplanet.com zone only; none of its other permissions change. Only the zone stack declares zone settings, and the apps stack still only reads the zone.

### zone-settings::CON-002 One setting only (direct acceptance)

Applies to: the zone stack. It manages the zone's Browser Cache TTL and nothing else: no other zone setting, no DNS record, cache rule or Page Rule.

### zone-settings::CON-003 The delivery path every stack uses (direct acceptance)

Applies to: the zone stack. It has its own state key, named after the stack, in the existing state bucket. Its own workflow is serialized per stack and runs Plan and Apply through the shared stack workflow and scripts: the approved-plan fingerprint check, the state snapshot and the empty follow-up plan. The Check workflow formats and validates it on every pull request.

## Failure modes and boundaries

Setting up:

- The production token does not yet have the Zone Settings permissions: Plan fails at the import with Cloudflare's authentication error, and nothing changes.
- The shared stack workflow always sets the GitHub token and the account ID as Terraform variables. The zone stack declares neither, and Terraform ignores environment values for variables a configuration does not declare. The zone stack's workflow does not pass the GitHub token at all.

Merging:

- The change that adds the stack starts only the zone stack's workflow. The apps stack's files, the modules and the scripts are unchanged, so the apps workflow does not start.
- A Plan is approved, then the setting is changed in the dashboard before Apply: Apply plans again, finds a different fingerprint and stops without changing anything. Run the workflow again.
- Apply sets the value, but the follow-up plan still has changes (for example, Cloudflare returns the value in another form): Apply fails after the state snapshot, and the difference is investigated before another run.
- Cloudflare rejects the value: Plan passes, because the setting's value has no fixed type in the provider, and Apply fails with Cloudflare's error after the state snapshot.

After Apply:

- A browser that stored a file with the 4-hour lifetime before the change keeps it until that copy expires, at most 4 hours. Only responses after the change carry the origin's header.
- Transfer and agentshed rename their static files on every build, so they never had the stale-stylesheet problem. Their files are now checked again on every visit, and answered 304 when unchanged, instead of being kept for 4 hours. The pages still display correctly. A long cache for those files belongs in their own projects.
- Download hosts: a file that sets its own longer Cache-Control is unaffected; `dl.aloongplanet.com` sets one year, immutable. A file without a Cache-Control header gets none from Cloudflare, and browsers fall back to their own heuristics. `dl.agentshed.aloongplanet.com` was not sampled.
- The setting changes only what browsers are told. Cloudflare's own edge caching of these files is unchanged.

Drift and removal:

- A change made in the dashboard is not noticed until the zone stack's workflow runs. A manual run is the drift check, and it plans the value back to 0 (zone-settings::US-002/AC-03).
- Removing the setting from the configuration leaves the zone at 0, because the provider's delete does nothing. To go back to 4 hours, set the value to 14400 and apply.
- If the stack's state is lost or recreated, the import brings the setting back into state instead of failing.

Credentials:

- The production token now can change any setting of the zone, not only this one. Only the zone stack's reviewed configuration uses that, and the token already had DNS Write on the zone, so a leaked token reached every host before this change too.
- A local run of the zone stack reads the same env file as the apps stack. The GitHub token in it is passed as a variable the zone stack does not declare, and is ignored.

Running at the same time:

- Zone and apps runs use separate concurrency groups, state keys and lockfiles, so they do not wait on or interfere with each other. Both run in the `production` environment, and each job still waits for its own approval.

Content brought in from elsewhere: the stack loads no external content into anything a person interacts with, so no boundary of this kind applies.

## Implementation Decisions

- A new stack root beside `apps`, with the Cloudflare provider only: no GitHub provider and no input variables. The zone is looked up by name, as in the apps stack, so its ID never appears in the repository.
- The setting is imported with an import block. Its ID is built from the looked-up zone ID and the setting's name, so the first plan shows the current value rather than a blind create. The block stays in place: once the setting is in state it does nothing, and it re-imports the setting if the state is ever lost.
- No module: one resource, in a file named for what it does.
- The stack's workflow has the apps workflow's shape. It runs on changes to the stack's own Terraform and lock files, the scripts, the Terraform version file, its own workflow and the shared stack workflow. It does not run on module changes, because it uses no module. It runs in the `production` environment and passes only the account ID, the two state credentials and the Cloudflare token.
- The provider is locked to the same release as the apps stack, so both stacks run the version whose behaviour this spec was checked against.
- Credentials: the owner adds Zone Settings Read and Edit, on aloongplanet.com only, to the existing production token in the Cloudflare dashboard; editing permissions keeps the token's value. There is no new token, environment, env file or credentials-script change.
- The repository README says that the zone stack is the only place zone settings are declared, and only this one.
- No ADR: the decision is cheap to reverse (one value), so it does not meet the ADR bar. Its reasons live here and in the zone stack's README.

## Testing Decisions

- The repository has no test runner, and adding one for this change is out of scope. The existing gates for Terraform changes are the prior art. The Check workflow runs `fmt` and `validate` on every stack, and fails a stack that has no workflow. The apply script refuses a plan that differs from the approved one, and fails unless a follow-up plan is empty.
- Seams:
  - The Check workflow, for the new stack's formatting and validity.
  - A local plan of the zone stack with the production credentials, before merging: exactly one import, the value change, and nothing else (zone-settings::US-002/AC-01).
  - The workflow's Apply and follow-up plan (zone-settings::US-002/AC-02).
  - Read-only HEAD requests after Apply: to the homepage's three hosts (zone-settings::US-001/AC-01), and to Transfer and agentshed (the boundaries above).
  - The production environment's protection rules, read back from the GitHub API (zone-settings::US-002/AC-04).

## Out of Scope

- Any other zone setting, DNS records beyond the landing pages' own, cache rules and Page Rules.
- Managing the homepage's Pages project or its custom domains in Terraform.
- A long browser cache for Transfer's and agentshed's per-build files. That belongs in their own projects' headers.
- Renaming the homepage's stylesheet on every deploy.
- Scheduled drift detection: the drift check stays a manual run.
- A separate token or environment for the zone stack.
- A linter for this repository.

## Further Notes

Facts this spec rests on, checked on 2026-11-07:

- Cloudflare's Browser Cache TTL documentation: the default is 4 hours on every plan, and Cloudflare overrides an origin's cache expiration that is shorter than the setting.
- Cloudflare's zone settings API: "Setting a TTL of 0 is equivalent to selecting Respect Existing Headers". Reading and editing the setting take Zone Settings Read and Zone Settings Write.
- Cloudflare provider 5.28.0:
  - `cloudflare_zone_setting` takes a zone ID, a setting ID and a value;
  - its import ID is `<zone_id>/<setting_id>`;
  - its delete does nothing.
- Terraform 1.16.6 ignores `TF_VAR_` environment values for variables a configuration does not declare, without a warning.
- Response headers on 2026-11-07:
  - on the `pages.dev` hosts, every file is served with `max-age=0`;
  - on the custom domains, static files are served with `max-age=14400` and HTML with `max-age=0`;
  - `dl.aloongplanet.com` downloads are served with `max-age=31536000, immutable`.
- The first plan of the zone stack, on 2026-11-07, read the current value: 14400, the 4-hour default.
