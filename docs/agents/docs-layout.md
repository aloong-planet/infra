# Documentation layout

Where this repository's documents live, and which of them can be relied on.

## Conclusions and process are different things

**Conclusions** answer "what is right now", and any skill may rely on them:

| Location | Question it answers | Maintained by |
|---|---|---|
| `docs/CONTEXT.md` | What a term means exactly, and which synonyms to avoid | `/domain-modeling` |
| `docs/adr/` | Why something was decided, and what was rejected | `/domain-modeling` |
| `docs/specs/<slug>.md` | Which boundaries a feature has worked through, and what it explicitly does not do | `/to-spec` |
| `docs/features/<slug>.md` | The behavior users can see in the current version | `/features-catalog` |
| `docs/prototypes/` | What interfaces and state models look like | `/prototype` |
| `docs/postmortems/` | The causal chain of an incident | `/implement`, step 7 |
| `docs/ops/` | This project's runbooks (the actual values for signing, releases and so on) | Each project |

`docs/specs/` and `docs/features/` **share slugs one to one**: if features has `memory-view.md`, the spec is `docs/specs/memory-view.md`.

**Process** answers "how it was done at the time":

| Location | Contents |
|---|---|
| `docs/.workings/<slug>/` | Construction tickets, `review-code.md`, `review-tests.md` |

**`docs/.workings/` stays out of the repository (the repository's `.gitignore` ignores the whole directory). Its contents are kept, not deleted, but no skill may treat them as a reliable source.** Which checkout to write them in when working in a worktree is set by the "Construction record storage" section of the global instructions. Read them only to answer "why was this done that way at the time", never to infer the present. Where they conflict with a conclusion, the conclusion wins, **and the construction records need not be corrected**: they should stay as they were. The directory is hidden, is not published with the documentation, and is not matched by globs such as `docs/**/*.md`.

## Read these first when exploring

Before changing code or proposing a plan, read:

- the table of contents of `docs/CONTEXT.md`, then single entries for the terms you use (how to read it is in the global instructions, "Reading the project glossary `CONTEXT.md`"). If `docs/CONTEXT-MAP.md` exists, use it to find the `CONTEXT.md` of the context the topic belongs to (format and inference rules are in `/domain-modeling`'s `CONTEXT-FORMAT.md`);
- the ADRs in `docs/adr/` that concern the area being changed; in a multi-context repository, also those under that context's `docs/adr/`.

**Continue silently when these files do not exist.** Do not report them missing or suggest creating them in advance: `/domain-modeling` creates them lazily when a term or decision is actually settled.

## Use the glossary's words

Wherever output mentions a domain concept (issue titles, plans, assumptions, test names), **it must use the word defined in `CONTEXT.md`**, never a synonym its `_Avoid_` list names.

A concept missing from the glossary is a signal: either you are inventing a term this project does not use (reconsider), or an entry is genuinely missing (note it for `/domain-modeling`).

## Conflicts with an existing ADR must be stated

If output contradicts an ADR, **name it; never override it silently**:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_
