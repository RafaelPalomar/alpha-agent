# alpha-agent — agent instructions

A **consumer Guix channel**: the user's personal pi agent bound to a PKS
durable-memory backend. The framework lives in `guix-agentic`; this repo holds
only the org/Denote-opinionated half + the agent definition.

## Conventions
- Modules at repo root: `(alpha-agent <subdir> NAME)` → `alpha-agent/<subdir>/NAME.scm`.
- `define-record-type*` / package house style follows guix-agentic + entelequia.
- The PKS backend implements guix-agentic's `<memory-backend>` interface — treat
  that interface as a contract; if it changes upstream, update here.

## Decisions are ADRs
Record decisions under `alpha-agent/Docs/adr/` (ivs-infrastructure format:
Status / Date / Deciders / Context / Decision / Alternatives / Consequences /
Conformance / References; `NNNN-kebab.md`; append-only, supersede don't edit).

## Guix on this host
Missing tools → `guix shell <pkg> -- <cmd>`. Load/build with the three `-L`
flags (guix-agentic + alpha-agent + ~/.dotfiles for denotecli). Validate by
loading `(alpha-agent agent)` and inspecting the composed `alpha`.

## Safety (PKS)
The agent writes to PKS unprompted **only** as capture into `fleeting/`, with a
provenance property drawer. Never regenerate Denote IDs, never bulk-rename/
delete, never write into `permanent/`/`projects/`/`reference/` unprompted — those
are human-confirmed promotions. These rules live in `pks/policy.scm` and
`pks/capture.scm`, not in ad-hoc tool use.
