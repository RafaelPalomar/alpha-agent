;;; alpha-agent — the `alpha` agent
;;;
;;; The user's personal pi agent, bound to the PKS durable-memory backend via
;;; `with-memory`.  Composing it is the validation bar: one `guix shell` from
;;; this channel launches pi with the PKS capture policy + skill + denotecli on
;;; PATH, and ~/pks mounted read-write into the L1 container.

(define-module (alpha-agent agent)
  #:use-module (guix-agentic agents core)
  #:use-module (guix-agentic agents backends)
  #:use-module (guix-agentic guardrails sandbox)
  #:use-module (guix-agentic capabilities memory backend)
  #:use-module (alpha-agent pks backend)
  #:use-module (entelequia packages denotecli)
  #:use-module (gnu packages version-control)            ; git
  #:use-module (gnu packages rust-apps)                  ; ripgrep
  #:export (alpha alpha-launcher))

(define pks (make-pks-memory-backend #:denotecli denotecli))

;; Posture: a trusted personal agent.  Cloud API (open network), the launch
;; cwd mapped in so it can work in the current project, and git/ripgrep on PATH.
;; `with-memory` adds denotecli + the ~/pks and episodic shares on top.
;; The sandbox posture (what beyond cwd + memory the agent may touch) is the
;; key per-agent decision — tune `share`/`expose` here.
(define base-alpha
  (agent
   (name "alpha")
   (backend pi-backend)
   (extra-packages (list git ripgrep))
   (sandbox (sandbox (network 'open) (no-cwd? #f)))))

(define alpha (with-memory base-alpha pks))
(define alpha-launcher (agent->package alpha))
