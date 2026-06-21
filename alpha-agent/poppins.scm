;;; alpha-agent — the `poppins` agent (household, personal domain)
;;;
;;; Mary Poppins: the family's household assistant, re-homed from the Hermes
;;; estate onto the pi/guix-agentic colony (consolidation decision, PKS
;;; [[denote:20260621T154600]]).  She is the PERSONAL-DOMAIN queen: her durable
;;; memory is a personal PKS root, kept HARD-SEPARATE from the work PKS (~/pks).
;;;
;;; First slice (this file): the agent itself — persona + the stage-don't-commit
;;; guardrail + personal-scoped memory + an isolating sandbox.  NOT yet wired:
;;; the NextCloud calendar/Deck tools (a credentialed CalDAV/Deck skill, the
;;; plan's no-new-dep fallback) and the thin Mattermost bridge — both follow-ons.
;;; A personalised (family-vocab) capture policy also comes later; the first
;;; slice gives the durable store + denotecli, which is the missing memory layer.

(define-module (alpha-agent poppins)
  #:use-module (guix-agentic agents core)
  #:use-module (guix-agentic agents backends)
  #:use-module (guix-agentic guardrails sandbox)
  #:use-module (guix-agentic capabilities memory backend)   ; memory-backend, with-memory
  #:use-module (guix-agentic packages personas)             ; make-pi-fragment
  #:use-module (alpha-agent denotecli)                      ; denotecli (vendored, channel-safe)
  #:use-module (guix gexp)                                  ; local-file
  #:export (poppins poppins-launcher))

;;; PERSONAL domain root — NEVER the work PKS (~/pks).  Provisional path on this
;;; (work) box; the real root is the personal NextCloud account per ADR-0008,
;;; wired when Poppins deploys on the personal side.
(define %personal-root "/home/rafael/pks-personal")

;;; Lean personal-domain durable memory: denotecli over the personal root,
;;; folded onto Poppins's sandbox by `with-memory`.  Deliberately does NOT reuse
;;; alpha's work-PKS capture policy / code-project onboarding (those are
;;; work-domain); a family-vocab capture policy is a follow-on.
(define personal-memory
  (memory-backend
   (id 'poppins-personal)
   (tools (list denotecli))
   (shares (list %personal-root))))

(define %poppins-md
  (plain-file "poppins.md" "\
You are Mary Poppins, the household assistant for the Palomar family
(Maria; Rafael; Leandro, 10; Adrian, 8).

Voice: warm, brief, and familial — never corporate, never a wall of text.

Language: reply in the family member's own language — Norwegian, Spanish, or
English — and code-switch naturally.

Domain wall (hard): you serve the PERSONAL / household domain ONLY. Your durable
memory is the family's personal store. You have NO access to work or
professional data, calendars, or repositories, and you must never ask for them.
If a request is about work, say plainly that it's outside your domain.

Guardrail (hard): never auto-commit a change to the family's calendar, tasks, or
files. Instead STAGE the change — state exactly what you would do, tag it with
the target family member and the request that triggered it — and ask a human to
confirm before anything happens."))

(define poppins-steer
  (make-pi-fragment
   #:name "poppins"
   #:kind "append-system"
   #:content %poppins-md
   #:synopsis "Mary Poppins household persona + personal-domain wall + stage-don't-commit guardrail"))

(define base-poppins
  (agent
   (name "poppins")
   (backend pi-backend)
   (append-system (list poppins-steer))
   (settings (local-file "settings.poppins.json"))
   ;; Personal-domain sandbox: open network (the LLM); NO cwd mapping (not a
   ;; coding agent); NO work PKS, NO SSH-agent.  Only the OpenRouter key and
   ;; DENOTECLI_DIRS (pointed at the PERSONAL root by the wrapper) cross in.
   ;; with-memory folds the personal root share on top.
   (sandbox (sandbox (network 'open) (no-cwd? #t)
                     (preserve '("^OPENROUTER_API_KEY$" "^DENOTECLI_DIRS$"))))))

(define poppins (with-memory base-poppins personal-memory))
(define poppins-launcher (agent->package poppins))
