;;; alpha-agent — forager launch manifest (as a MODULE).
;;;
;;; Mirrors (alpha-agent manifests alpha): the channel's `.guix-channel' puts
;;; modules at the repo root, so a bare `-m' manifest breaks the channel build.
;;; Exports `forager-packages' (the launcher + its tool closure) and
;;; `forager-tool-profile' (a profile to point GUIX_ENVIRONMENT at, so the
;;; forager's tools — codegraph/git/ripgrep/findutils — land on PATH inside the
;;; L1 container instead of pi trying to download them).
;;;
;;;   guix shell -L ~/src/guix-agentic -L ~/src/guix-codegraph -L ~/src/alpha-agent \
;;;     -e '(@ (alpha-agent manifests forager) forager-packages)' -- forager

(define-module (alpha-agent manifests forager)
  #:use-module (alpha-agent forager)
  #:use-module (guix-agentic agents core)
  #:use-module (guix profiles)
  #:export (forager-packages
            forager-manifest
            forager-tool-profile))

(define forager-packages
  (agent->manifest-entries forager))

(define forager-manifest
  (packages->manifest forager-packages))

(define forager-tool-profile
  (profile (content forager-manifest)))
