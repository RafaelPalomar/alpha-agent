# 0002. Project onboarding: auto-stub to fleeting, identify from projects

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** Rafael Palomar
- **PR:** (alpha project-onboarding)

## Context

The user wants `alpha`, when it starts work in a project, to make project
awareness *automatic* — ideally registering the project in the PKS without being
asked, the way the user's own `pks-project-context` / `pks-project-register`
Claude skills bootstrap awareness. But ADR-0001 confines the agent's standing
(unprompted) authorization to the `fleeting/` capture zone and explicitly forbids
unprompted writes to `projects/`, because `projects/` is curated and a project
note is a durable, structured artifact (Status / Log / Architecture / References)
the human owns.

So "automatic registration" and "no unprompted writes to `projects/`" appear to
conflict.

## Decision

Resolve the tension by splitting *read* from *write*:

- **Identify (read):** onboarding searches `projects/` and, if a project note
  exists, loads it for session context. Reading the curated silo is always
  allowed.
- **Stub (write):** if no project note exists, the agent **auto-creates a single
  project STUB in `fleeting/`** — unprompted, deduplicated, stamped with the same
  `:SOURCE: agent` provenance drawer as any capture. This is *within* the
  ADR-0001 standing authorization (fleeting-only), not an exception to it.
- **Promotion stays human-confirmed:** turning the stub into a real `projects/`
  note is the user's `pks-project-register` step. The agent never writes
  `projects/`.

Mechanism: a new `pks-project-onboard` skill (`alpha-agent/pks/onboard.scm`),
added to the backend's skill list, plus a "Project onboarding" trigger paragraph
in the capture policy fragment.

## Alternatives considered

### Alternative A — extend standing authorization to write `projects/` directly

Rejected: re-opens exactly the curation hole ADR-0001 closed. A malformed or
premature project note in the curated silo is costly to clean up and pollutes
the backlink graph; the human review gate is the point.

### Alternative B — keep it fully human-confirmed (propose, user confirms)

Rejected by the user: defeats the "should be automatic, you should not need to
ask" goal. The confirm-per-project friction is what they want gone.

### Alternative C — auto-stub to fleeting, promote later (CHOSEN)

The fleeting stub gives immediate, automatic awareness with zero prompts, while
the durable artifact still lands in `projects/` only under human curation. The
fleeting inbox already has a review cadence, so the stub is seen.

## Consequences

- Onboarding adds at most one fleeting note per new project; dedup + the
  read-first identify step keep it idempotent across sessions.
- The user's fleeting-review cadence now also surfaces project stubs to promote;
  this is additional inbox volume, bounded by "one per project".
- `projects/` remains agent-read / human-write — ADR-0001's hard limit is intact
  and reinforced, not weakened.

## Conformance

- **Test:** load `(alpha-agent agent)` and inspect `alpha`.
- **Asserts:** `agent-skills` includes `pi-skill-pks-project-onboard`; the
  capture policy fragment contains a "Project onboarding" section; the onboard
  skill text never creates in `projects/`.

## References

- ADR-0001 (PKS as bound memory backend; capture-to-fleeting authorization).
- User's `~/.claude/skills/pks-project-context.md`, `pks-project-register.md`
  (the human-side workflow this mirrors). Design decision 2026-06-19.
