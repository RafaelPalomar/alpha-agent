;;; alpha-agent — family-cal: Poppins's household calendar tool (NextCloud CalDAV)
;;;
;;; Packages family-cal.py as a `family-cal' CLI: read the family agenda and
;;; STAGE proposed changes to a pending area for human confirmation (never writes
;;; to the live calendar — `commit' is a separate human-invoked step).  Reads the
;;; NextCloud app-password from a file path (NC_APPPW_FILE), the same way the
;;; OpenRouter key is handled; at deploy that path is the sops-decrypted
;;; mary-poppins app-password.

(define-module (alpha-agent family-cal)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages bash)         ; bash-minimal (launcher shebang)
  #:use-module (gnu packages python)       ; python-wrapper (python3)
  #:use-module (gnu packages python-web)   ; python-requests
  #:export (family-cal))

(define family-cal
  (package
    (name "family-cal")
    (version "0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:builder
      (with-imported-modules '((guix build utils))
        #~(begin
            (use-modules (guix build utils) (ice-9 format))
            (let* ((bin     (string-append #$output "/bin"))
                   (libexec (string-append #$output "/libexec"))
                   (script  (string-append libexec "/family-cal.py"))
                   (cli     (string-append bin "/family-cal")))
              (mkdir-p bin)
              (mkdir-p libexec)
              (copy-file #$(local-file "family-cal.py") script)
              ;; Absolute-shebang launcher; exec python3 from PATH (the agent
              ;; tool profile provides python-wrapper + sets GUIX_PYTHONPATH so
              ;; `requests' resolves inside the L1 container).
              (call-with-output-file cli
                (lambda (port)
                  (format port "#!~a/bin/sh~%exec python3 ~a \"$@\"~%"
                          #$bash-minimal script)))
              (chmod cli #o755))))))
    (propagated-inputs (list python-wrapper python-requests))
    (synopsis "Poppins household calendar tool (NextCloud CalDAV: read agenda, stage changes)")
    (description "A small CLI over the family NextCloud calendar: read the agenda
(CalDAV REPORT) and STAGE proposed changes to a pending area for a human to
confirm.  It never writes to the live calendar on its own — @code{commit} is a
separate, human-invoked step (the stage-don't-commit guardrail).  Credentials
are read from a file path (@env{NC_APPPW_FILE}).")
    (home-page "https://github.com/RafaelPalomar/alpha-agent")
    (license license:gpl3+)))
