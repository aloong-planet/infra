# Issue tracker: GitHub

This repository's tickets are GitHub Issues.

**Every `gh` operation follows the "Issue operations" rules in `/github-ops` (issues.md)**: command forms, when to pass `-R`, heredocs for multi-line bodies and recipes for reading data are there. **This file does not repeat them**, so the two cannot drift apart.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant tickets"

`gh issue view <n> --comments` (with `-R` when not inside a clone of this repository).

## Label for tickets an agent may take

`ready-for-agent`.

Tickets cut by `/to-tickets` get this label by default: by construction, an unattended agent can pick them up. If this repository's tracker already uses another string (such as `agent-ready`), change this line to the one in use; skills follow it and do not create a duplicate label.
