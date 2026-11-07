# Specs

Each spec is the current requirement picture for one capability, for people changing that part of the infrastructure. It lists the failure modes and boundaries that were worked through, and what is explicitly out of scope.

A spec shares its slug with its page in `docs/features/` and describes the implementation as it stands. It is rewritten in place, and its history is in Git. When a capability is removed, its spec is removed with it.

| Spec | Capability |
|---|---|
| [Zone settings](zone-settings.md) | The aloongplanet.com zone's browser cache follows each origin's own headers, managed by the `zone` stack. |
