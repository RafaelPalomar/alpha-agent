;;; alpha-agent — poppins-bridge: the Mattermost transport for Mary Poppins.
;;;
;;; Packages poppins-bridge.py as a `poppins-bridge' daemon that logs in to the
;;; family Mattermost as the `ms-poppins' bot, listens on the household channel,
;;; and shells out to `poppins -p' per message — transport only, no creds of its
;;; own beyond the bot token (the `poppins' wrapper owns OpenRouter + NextCloud).
;;;
;;; The python deps (requests + websocket-client) are propagated, so a profile
;;; containing just this package gets a complete GUIX_PYTHONPATH from its
;;; etc/profile — that is how the home-shepherd service runs it on the host
;;; (outside any agent tool profile).

(define-module (alpha-agent poppins-bridge)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages bash)         ; bash-minimal (launcher shebang)
  #:use-module (gnu packages python)       ; python-wrapper (python3)
  #:use-module (gnu packages python-web)   ; python-requests, python-websocket-client
  #:export (poppins-bridge))

(define poppins-bridge
  (package
    (name "poppins-bridge")
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
                   (script  (string-append libexec "/poppins-bridge.py"))
                   (cli     (string-append bin "/poppins-bridge")))
              (mkdir-p bin)
              (mkdir-p libexec)
              (copy-file #$(local-file "poppins-bridge.py") script)
              ;; Absolute-shebang launcher; exec python3 from PATH.  GUIX_PYTHONPATH
              ;; for requests + websocket-client comes from the enclosing profile's
              ;; etc/profile (propagated inputs).
              (call-with-output-file cli
                (lambda (port)
                  (format port "#!~a/bin/sh~%exec python3 ~a \"$@\"~%"
                          #$bash-minimal script)))
              (chmod cli #o755))))))
    (propagated-inputs
     (list python-wrapper python-requests python-websocket-client))
    (synopsis "Mattermost transport for the Mary Poppins agent")
    (description "A thin daemon that logs in to the family Mattermost as the
@code{ms-poppins} bot, listens for messages in the allowed channel(s), and shells
out to @code{poppins -p} for each one, posting the reply back in-thread.  It is
transport only: the @code{poppins} wrapper it spawns owns all credentials and the
agent sandbox.  Configured through environment variables (@env{MATTERMOST_URL},
@env{MATTERMOST_TOKEN}, @env{MATTERMOST_ALLOWED_CHANNELS}).")
    (home-page "https://github.com/RafaelPalomar/alpha-agent")
    (license license:gpl3+)))
