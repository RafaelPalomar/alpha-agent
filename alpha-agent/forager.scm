;;; alpha-agent — the `forager` agent
;;;
;;; A forager is a cheap, locked-down colony worker launched by an orchestrator
;;; to execute a single bounded task (research, code-reading, analysis).  It
;;; uses Haiku 4.5 over OpenRouter — cheap, but same trust tier as alpha's
;;; Sonnet (no third-party data crossing), and reliable under tool obstacles
;;; (a discovery bake-off showed cheaper third-party models confabulate file
;;; contents when a tool is missing).  It has no persistent memory and returns
;;; all findings as a structured <report> block for curator review.
;;;
;;; DELIBERATELY ABSENT capabilities vs `alpha`
;;; -------------------------------------------
;;; - with-memory (no durable PKS write access)   ← governance boundary
;;; - with-episodic (no per-session memory store) ← ephemeral by design
;;; - with-git-ssh (no SSH key forwarding)        ← no push rights
;;;
;;; The forager can READ the codebase (codegraph index, ripgrep, git log) and
;;; WRITE into the working tree, but it cannot touch the PKS, authenticate to
;;; remote git hosts, or outlast its task.  `with-reporting` installs the
;;; <report> output contract that enforces the boundary at the model layer.
;;;
;;; Composed chain (innermost → outermost):
;;;   base-forager
;;;     └─ with-codegraph     (structural code index; no extra sandbox share)
;;;     └─ with-provisioning  (bare+worktrees project clone convention)
;;;     └─ with-reporting     (forager <report> output contract; no PKS access)

(define-module (alpha-agent forager)
  #:use-module (guix-agentic agents core)
  #:use-module (guix-agentic agents backends)
  #:use-module (guix-agentic guardrails sandbox)
  #:use-module (guix-agentic capabilities codegraph)
  #:use-module (guix-agentic capabilities provisioning)
  #:use-module (guix-agentic capabilities reporting)
  #:use-module (guix-codegraph packages codegraph)
  #:use-module (guix gexp)
  #:use-module (gnu packages version-control)   ; git
  #:use-module (gnu packages rust-apps)         ; ripgrep
  #:use-module (gnu packages base)              ; findutils (find — avoid gratuitous tool gaps)
  #:export (forager
            forager-launcher))


;;; --- base agent ------------------------------------------------------------

(define base-forager
  (agent
   (name "forager")
   (backend pi-backend)
   (extra-packages (list git ripgrep findutils))  ; codegraph added by with-codegraph
   (settings (local-file "settings.forager.json"))
   ;; Sandbox posture: open network (needs to read public code hosts, APIs)
   ;; but NO pks share and NO DENOTECLI_DIRS — the forager is intentionally
   ;; cut off from the durable knowledge store.  Only the OpenRouter API key
   ;; crosses the sandbox boundary; nothing else is preserved.
   (sandbox (sandbox (network 'open) (no-cwd? #f)
                     (preserve '("^OPENROUTER_API_KEY$"))))))


;;; --- composition -----------------------------------------------------------

;; Note what is DELIBERATELY ABSENT vs alpha:
;;   • no with-memory    — forager never writes directly to the PKS
;;   • no with-episodic  — ephemeral; findings live in the <report> only
;;   • no with-git-ssh   — forager has no push rights (read-only git auth)
;;
;; with-reporting is the outermost wrapper so its append-system fragment arrives
;; last in the context window — the report contract is the most recent
;; instruction the model sees and therefore the most strongly weighted.

(define forager
  (with-reporting
   (with-provisioning
    (with-codegraph base-forager codegraph))))

(define forager-launcher (agent->package forager))
