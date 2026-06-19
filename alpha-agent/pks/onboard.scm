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
  #:export (pks-project-onboard-skill))

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

## 1. Identify (read-only)

    proj=\"$(basename \"$PWD\")\"
    denotecli search \"$proj\" --dirs ~/pks/projects --tags project --title-only --max 1

Parse the JSON.  One hit = REGISTERED; empty array = UNREGISTERED.

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
