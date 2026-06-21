;;; alpha-agent — poppins launch manifest (MODULE; see manifests/alpha.scm).
;;; Exports the launcher + tool closure (denotecli) and a tool profile to point
;;; GUIX_ENVIRONMENT at, so denotecli lands on PATH inside Poppins's L1 container.

(define-module (alpha-agent manifests poppins)
  #:use-module (alpha-agent poppins)
  #:use-module (guix-agentic agents core)
  #:use-module (guix profiles)
  #:export (poppins-packages
            poppins-manifest
            poppins-tool-profile))

(define poppins-packages
  (agent->manifest-entries poppins))

(define poppins-manifest
  (packages->manifest poppins-packages))

(define poppins-tool-profile
  (profile (content poppins-manifest)))
