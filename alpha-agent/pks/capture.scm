;;; alpha-agent — PKS capture skill
;;;
;;; The how-to + safety wrapper around `denotecli` for systematic, deduplicated,
;;; provenance-stamped capture into the PKS fleeting zone.  Mirrors the user's
;;; pks-* Claude skills: the safety rules live in the skill, not in raw tool use.

(define-module (alpha-agent pks capture)
  #:use-module (guix gexp)
  #:use-module (guix-agentic packages skills)
  #:export (pks-capture-skill))

(define %skill
  (plain-file "SKILL.md" "\
---
name: pks-capture
description: Capture a durable note into the PKS (Denote) fleeting zone via denotecli, with dedup and provenance. Use at the trigger events in the memory policy.
---

# pks-capture

Contribute an atomic note (one claim per file) to the user's PKS.  Trigger only
at the events listed in the memory policy.  Default silo is `fleeting/`.

## 1. Search first (dedup)

    denotecli search \"<topic>\" --dirs ~/pks --max 5

If a note already covers this, APPEND to it (or add a `[[denote:ID]]` link from a
related note) instead of creating a duplicate.

## 2. Create in fleeting, with domain from context

Pick the domain directory from context — `work` or `personal` (the directory is
the domain marker; do not add a keyword for it).

    denotecli create \"<title>\" --dirs ~/pks/fleeting/work --tags <kw>

Keywords come ONLY from the closed vocabulary
(_research _code _learn _project _lit _perm _fleeting _ntnu _ous _agenda _moc
_meeting _hub _idea _review _contact).  Warn the user before extending it.

## 3. Stamp provenance

Add an org property drawer to the new note so the human can review and trust it:

    :PROPERTIES:
    :SOURCE: agent
    :SESSION: <session id>
    :CONFIDENCE: low | med | high
    :END:

Then write the claim.  For decisions/feedback, add **Why:** and
**How to apply:** lines.  Link related notes with `[[denote:ID]]`.

## Hard limits

- NEVER pass anything that regenerates a Denote ID; use `--keep-id` on rename.
- NEVER bulk-create, bulk-delete, or bulk-rename — one note per invocation.
- NEVER create in `permanent/`, `projects/`, or `reference/`.  If the note is
  durable enough for those, PROPOSE a promotion and let the human move it.
- Skip the marginal.  A fleeting inbox that fills with noise stops being
  reviewable (it is already behind).
"))

(define pks-capture-skill
  (make-pi-skill
   #:name "pks-capture"
   #:skill-md %skill
   #:synopsis "Capture to PKS fleeting via denotecli (dedup + provenance)"))
