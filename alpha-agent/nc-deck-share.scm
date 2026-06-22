;;; alpha-agent — nc-deck-share: share a NextCloud Deck board with the family.
;;;
;;; The nextcloud-mcp server exposes Deck board/stack/card tools but NO board
;;; ACL/share tool (and nc_share_create is the Files API, which 404s on a board).
;;; This thin CLI calls Deck's own ACL endpoint directly so Poppins can create a
;;; board AND share it with the family herself.  Same shape as family-cal: a
;;; python3 script on PATH that reads NC_URL / NC_USER / NC_APPPW from the env
;;; (injected by the poppins wrapper).

(define-module (alpha-agent nc-deck-share)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages bash)         ; bash-minimal (launcher shebang)
  #:use-module (gnu packages python)       ; python-wrapper (python3)
  #:use-module (gnu packages python-web)   ; python-requests
  #:export (nc-deck-share))

(define nc-deck-share
  (package
    (name "nc-deck-share")
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
                   (script  (string-append libexec "/nc-deck-share.py"))
                   (cli     (string-append bin "/nc-deck-share")))
              (mkdir-p bin)
              (mkdir-p libexec)
              (copy-file #$(local-file "nc-deck-share.py") script)
              (call-with-output-file cli
                (lambda (port)
                  (format port "#!~a/bin/sh~%exec python3 ~a \"$@\"~%"
                          #$bash-minimal script)))
              (chmod cli #o755))))))
    (propagated-inputs (list python-wrapper python-requests))
    (synopsis "Share a NextCloud Deck board with a user (Deck ACL API)")
    (description "A small CLI over the NextCloud Deck ACL API: share a board with
a family member (edit/manage), list a board's shares, or remove one.  Fills the
gap the nextcloud-mcp server leaves (no board-sharing tool).  Credentials from
@env{NC_URL}/@env{NC_USER}/@env{NC_APPPW}.")
    (home-page "https://github.com/RafaelPalomar/alpha-agent")
    (license license:gpl3+)))
