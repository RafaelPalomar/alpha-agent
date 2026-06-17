;;; alpha-agent — launch manifest (as a MODULE).
;;;
;;; This MUST be a module: the channel's `.guix-channel` puts modules at the
;;; repo root, so the channel build compiles every .scm — a bare `-m` manifest
;;; (no define-module) breaks it with "no code for module …".  It therefore
;;; exports `alpha-packages` and is launched via `-e`, not `-m`:
;;;
;;;   guix shell -L ~/src/guix-agentic -L ~/src/alpha-agent -L ~/.dotfiles \
;;;     -e '(@ (alpha-agent manifests alpha) alpha-packages)' -- alpha
;;;
;;; (`guix shell -e` takes a package list, not a <manifest>.)  Pi comes from the
;;; user's guix-home profile; denotecli from the entelequia load path.  The kids'
;;; / curie's deployment does NOT use this — the home service builds the launcher.

(define-module (alpha-agent manifests alpha)
  #:use-module (alpha-agent agent)
  #:use-module (guix-agentic agents core)
  #:use-module (guix profiles)
  #:export (alpha-packages
            alpha-manifest))

(define alpha-packages
  (agent->manifest-entries alpha))

(define alpha-manifest
  (packages->manifest alpha-packages))
