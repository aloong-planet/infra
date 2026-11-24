# aloong-planet infra

Cross-skill project facts are declared in the repository-root `capabilities.toml`.

## Agent skills

### Issue tracker

Tickets are this repository's GitHub Issues. See `docs/agents/issue-tracker.md`.

### Documentation layout

This repository uses one documentation context. See `docs/agents/docs-layout.md`.

## Invariants

- Never build an import ID from a secret other than the 32-hex IDs `scripts/redact.sh` masks (`scripts/plan.sh`).
