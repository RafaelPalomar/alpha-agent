;;; alpha-agent — launch manifest for the `alpha` agent.
;;;
;;; Validation command (local dev):
;;;   guix shell -L ~/src/guix-agentic -L ~/src/alpha-agent -L ~/.dotfiles \
;;;     -m ~/src/alpha-agent/alpha-agent/manifests/alpha.scm -- alpha
;;;
;;; Pi is taken from the user's guix-home profile (pi-backend launcher #f) until
;;; guix-agentic owns pi from-source (follow-up #1).

(use-modules (guix-agentic agents core)
             (alpha-agent agent))

(packages->manifest (agent->manifest-entries alpha))
