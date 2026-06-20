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
  #:use-module (guix-agentic capabilities memory episodic)
  #:use-module (guix-agentic capabilities structural)
  #:use-module (guix-agentic capabilities provisioning)
  #:use-module (guix-agentic capabilities git-ssh)
  #:use-module (alpha-agent pks backend)
  #:use-module (alpha-agent pks onboard)                 ; pks-onboard-steer
  #:use-module (alpha-agent denotecli)                   ; vendored (channel-safe)
  #:use-module (guix gexp)                               ; local-file
  #:use-module (gnu packages version-control)            ; git
  #:use-module (gnu packages rust-apps)                  ; ripgrep
  #:export (alpha alpha-launcher))

(define pks (make-pks-memory-backend #:denotecli denotecli))

;; Posture: a trusted personal agent.  Cloud API (open network), the launch
;; cwd mapped in so it can work in the current project, and git/ripgrep on PATH.
;; `with-memory` adds denotecli + the ~/pks and episodic shares on top.
;; The sandbox posture (what beyond cwd + memory the agent may touch) is the
;; key per-agent decision — tune `share`/`expose` here.
;;
;; `preserve` carries OPENROUTER_API_KEY into the L1 container: the `alpha'
;; wrapper (entelequia home service) reads the sops-decrypted key into the host
;; env, but `guix shell -C` scrubs everything not explicitly preserved.  Without
;; this the launcher only preserves PI_CODING_AGENT_DIR/TERM/SSL_CERT and pi
;; can never authenticate to OpenRouter inside the sandbox.
(define base-alpha
  (agent
   (name "alpha")
   (backend pi-backend)
   (extra-packages (list git ripgrep))
   ;; A short, dedicated session-start steer so PKS project onboarding actually
   ;; fires under task focus (the long memory policy alone got skipped) — same
   ;; always-in-context pattern that made provisioning stick.  with-memory
   ;; prepends the PKS policy fragment ahead of this.
   (append-system (list pks-onboard-steer))
   ;; OpenRouter provider + a sensible default model, but NO enabledModels
   ;; lock — alpha is the trusted personal agent, so `/model' ranges freely.
   (settings (local-file "settings.json"))
   (sandbox (sandbox (network 'open) (no-cwd? #f)
                     (preserve '("^OPENROUTER_API_KEY$"))))))

;; Compose all three memory layers: durable PKS (Layer 3) + episodic working
;; memory (Layer 2) + structural code index (Layer 1).  L2/L3 fold their rw
;; stores onto alpha's own sandbox; L1's index lives in cwd (already mapped).
;; `with-provisioning` adds the bare+worktrees project-provisioning capability
;; (cwd-only, no extra share) so "clone X and start working" produces a
;; multi-agent-ready layout — paired with PKS project onboarding (ADR-0002).
;; `with-git-ssh` forwards the SSH agent + known_hosts into the sandbox so alpha
;; can clone/push the user's PRIVATE repos (a deliberate relaxation — alpha is
;; the trusted personal agent; ADR-0003).
(define alpha
  (with-git-ssh
   (with-provisioning
    (with-structural (with-episodic (with-memory base-alpha pks))))))
(define alpha-launcher (agent->package alpha))
