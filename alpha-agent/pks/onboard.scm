;;; alpha-agent — PKS project-onboarding skill
;;;
;;; At the start of work in a project, identify whether the project already has
;;; a registered note in the PKS `projects/` silo and, if it does NOT, drop a
;;; lightweight project STUB into the `fleeting/` capture zone — automatically,
;;; without asking.  This is the agent half of the user's pks-project-context /
;;; pks-project-register workflow, reshaped to honour the standing authorization
;;; (ADR-0001/0002): the agent reads `projects/` but writes only to `fleeting/`.
;;; Promotion of the stub into a real `projects/` note stays human-confirmed.

(define-module (alpha-agent pks onboard)
  #:use-module (guix gexp)
  #:use-module (guix-agentic packages skills)
  #:use-module (guix-agentic packages personas)   ; make-pi-fragment
  #:export (pks-project-onboard-skill
            pks-onboard-steer))

(define %skill
  (plain-file "SKILL.md" "\
---
name: pks-project-onboard
description: At the start of substantive work in a project, identify its PKS project note (read-only) or, if none exists, auto-stub one into the fleeting zone with provenance. Read projects/, write only fleeting/.
---

# pks-project-onboard

Run this once, early, when you begin substantive work in a project directory
(implementing, refactoring, planning) — not for read-only or scratch sessions.
It mirrors the user's pks-project-context flow, but obeys the agent's standing
authorization: you READ `projects/` and WRITE only `fleeting/`.

## 1. Identify (read-only) — search BROADLY, then JUDGE the match

The project is the GIT REPO you are working in, NOT necessarily `$PWD`.  If you
just cloned/provisioned a repo into a subdirectory, `cd` into it (a worktree)
first.  Derive the project name from the repo, falling back to the directory:

    root=\"$(git rev-parse --show-toplevel 2>/dev/null || echo \"$PWD\")\"
    url=\"$(git -C \"$root\" remote get-url origin 2>/dev/null || true)\"
    proj=\"$(basename \"${url%.git}\")\"; [ -n \"$proj\" ] && [ \"$proj\" != / ] || proj=\"$(basename \"$root\")\"

A PKS project note is often titled DIFFERENTLY from the repo (e.g. repo
`SlicerHyperprobe` -> note `project-hyperprobe`; repo `Slicer-Liver` -> note
`slicer-liver`).  So do NOT rely on an exact-name match — search broadly with
the full name AND its meaningful sub-tokens (split CamelCase / `-` / `_`, drop
generic words like `Slicer`, `Module`, `project`), then JUDGE the hits:

    denotecli search \"$proj\" --dirs ~/pks/projects --tags project --max 5
    # plus a core token if the full name returned nothing, e.g.:
    denotecli search \"hyperprobe\" --dirs ~/pks/projects --tags project --max 5

If ANY hit plausibly refers to THIS project (use judgement — matching core
token, same domain), treat it as REGISTERED.  Only if nothing plausibly matches
is it UNREGISTERED.  When genuinely unsure, prefer REGISTERED + load over
creating a possibly-duplicate stub.

### Registered

Load it for context and stop — do NOT stub or duplicate:

    denotecli read <ID> --dirs ~/pks/projects --outline

Carry its Status / Log / Architecture / References as implicit session context.
A single line — `(loaded PKS context for <proj>)` — is enough; do not re-announce.

## 2. If UNREGISTERED — auto-stub into fleeting (no asking)

First dedup against any existing stub so you never create a second one:

    denotecli search \"$proj\" --dirs ~/pks/fleeting --title-only --max 3

If a stub already exists, APPEND to it instead.  Otherwise create ONE stub in
the fleeting domain (`work` or `personal`, chosen from context):

    denotecli create \"PROJECT <proj> (stub)\" \\
      --dirs ~/pks/fleeting/work --tags project

Keywords come ONLY from the closed vocabulary; `_project` is the marker here.
Then write the stub body with a provenance drawer so the human can review and
promote it:

    :PROPERTIES:
    :SOURCE: agent
    :SESSION: <session id>
    :CONFIDENCE: low
    :END:

    Auto-stub created on first substantive work in <repo path>.
    Remote: <git remote url, if any>.  One line on what this project is.
    Promote to ~/pks/projects/ (pks-project-register) when it proves durable.

## Hard limits

- NEVER create or write the note in `projects/` — that is the human-confirmed
  promotion step.  You only ever read it.
- ONE stub per project; search first, append don't duplicate.
- Never regenerate a Denote ID; no bulk operations.
- Skip onboarding for transient sessions (single commands, read-only queries,
  obvious scratch dirs).
"))

(define pks-project-onboard-skill
  (make-pi-skill
   #:name "pks-project-onboard"
   #:skill-md %skill
   #:synopsis "Identify a project's PKS note, or auto-stub one into fleeting"))

;;; --- always-in-context steer -----------------------------------------------
;;; The memory policy mentions onboarding, but buried in a long doc it gets
;;; skipped under task focus (observed: alpha cloned + worked SlicerHyperprobe
;;; without ever touching the PKS).  A short, dedicated, imperative fragment —
;;; the same pattern that made provisioning stick — keeps the session-start step
;;; front-of-context so it actually fires.

(define %steer
  (plain-file "pks-session-start.md" "\
# At the start of substantive project work — onboard the PKS FIRST

Before exploring or planning a project, RUN the `pks-project-onboard` skill once.
It is the FIRST thing you do, not an afterthought, and it is NOT optional for
real project work (skip it only for one-off commands or read-only questions):

1. Determine the project = the git repo you are working in (its remote name),
   NOT `$PWD` — if you just cloned into a subdir, `cd` into it first.
2. Search `~/pks/projects` BROADLY (full name + core token — the note may be
   named differently from the repo) and JUDGE: if any hit is plausibly this
   project, load it and say `(loaded PKS context)`.
3. Only if nothing plausibly matches, auto-stub one into `~/pks/fleeting/` with a
   provenance drawer.  When unsure, prefer loading over stubbing.

You read `projects/`; you only ever write `fleeting/`.  Do this even when the
user's request is purely about code — the memory step is part of the job.
"))

(define pks-onboard-steer
  (make-pi-fragment
   #:name "pks-session-start"
   #:kind "append-system"
   #:content %steer
   #:synopsis "Run PKS project onboarding first thing in substantive work"))
