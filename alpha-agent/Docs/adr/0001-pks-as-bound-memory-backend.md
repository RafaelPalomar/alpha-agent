# 0001. Bind PKS as the durable memory backend; capture to fleeting unprompted

- **Status:** Accepted
- **Date:** 2026-06-11
- **Deciders:** Rafael Palomar
- **PR:** (alpha-agent scaffold)

## Context

`alpha` is the user's personal agent. It needs durable memory that is
human-readable, -reviewable, and -contributable — which is exactly why the
durable store is the user's existing PKS (a Denote/org Zettelkasten), not a new
machine-native store. The user wants the agent to contribute to PKS
*systematically, without being asked* — but PKS is a curated knowledge base, and
unsupervised writes to it would destroy the curation discipline (the fleeting
inbox is already behind).

guix-agentic (ADR-0007) defines `<memory-backend>` and refuses to hold
org-mode/denotecli opinions. This channel holds them.

## Decision

Implement `pks-memory-backend` (`make-pks-memory-backend`) as a `<memory-backend>`
whose durable layer is `~/pks`, accessed via the `denotecli` package (injected,
so the module loads without the entelequia channel). It bundles a capture policy
fragment and a `pks-capture` skill. `agent.scm` binds it to `alpha` with
`with-memory`.

Resolve "systematic + unprompted" vs. "curatable" with a **confined capture
zone + standing authorization**:

- The agent may write to PKS unprompted **only** as capture into `fleeting/`,
  stamped with an org property drawer (`:SOURCE: agent` `:SESSION:`
  `:CONFIDENCE:`) — provenance, not a new keyword (the vocabulary is closed).
- It must search first and append/link rather than duplicate.
- It captures only at trigger events (decision+rationale, rejected approach,
  crystallised pattern, non-obvious constraint), never routine work.
- Writes to `permanent/`/`projects/`/`reference/`, renames, deletes, and
  archiving stay **human-confirmed**. Denote IDs are never regenerated; no bulk
  operations.

## Alternatives considered

### Alternative A — let the agent write anywhere in PKS unprompted

Rejected: destroys curation; pollutes the backlink graph; removes the human
review gate that makes a Zettelkasten valuable.

### Alternative B — a generic markdown store, promote to PKS later

Rejected (guix-agentic ADR-0007 Alt-C): two sources of truth and a sync gap. PKS
is chosen *because* it is human-contributable, so the agent writes Denote
directly.

## Consequences

- Org-mode/denotecli opinionation is contained in this channel; guix-agentic
  stays content-free.
- The capture rate must be matched by the user's fleeting-review cadence; the
  skill enforces dedup + a confidence floor to limit volume.
- `with-memory` mounts `~/pks` read-write into `alpha`'s L1 sandbox — a
  deliberate confinement relaxation (guix-agentic ADR-0007).

## Conformance

- **Test:** load `(alpha-agent agent)` and inspect `alpha`.
- **Asserts:** `agent-sandbox` share list contains `~/pks` and the episodic dir;
  `agent-skills` includes `pi-skill-pks-capture`; `denotecli` is on
  `agent-extra-packages`; exactly one append-system policy fragment.

## References

- guix-agentic ADR-0007 (`<memory-backend>` indirection), ADR-0004 (sandbox rw
  intersection). Design discussion 2026-06-11.
