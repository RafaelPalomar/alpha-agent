;;; alpha-agent — vendored `denotecli` package.
;;;
;;; The PKS durable store is written with denotecli.  This channel is published
;;; and consumed on curie, but as a *channel* it cannot import from the user's
;;; private `entelequia' load path — so denotecli is vendored here (rather than
;;; imported from `(entelequia packages denotecli)') to keep alpha-agent
;;; self-contained, exactly as archimedes-agent does.
;;;
;;; Source of truth: entelequia/packages/denotecli.scm.  If that changes
;;; (version/commit/hash/patch), sync this copy.

(define-module (alpha-agent denotecli)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system go)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages golang)
  #:export (denotecli))

(define denotecli
  (let ((commit "d1c02d07d99e6a23ae00393e01c3b487e020527f")
        (revision "2"))
    (package
      (name "denotecli")
      (version (git-version "0.8.0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/junghan0611/denotecli")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "0aixcmfcqvmd6qgxx6zd7p4vpy1xb82dqq3r82b0rpxgqq9k5pgm"))
         ;; Make `denotecli create --content -' read the body from stdin.
         (snippet
          '(begin
             (use-modules (guix build utils))
             (substitute* "denotecli/main.go"
               (("\t\"fmt\"\n")
                "\t\"fmt\"\n\t\"io\"\n"))
             (substitute* "denotecli/main.go"
               (("\tcontent := getFlag\\(args, \"--content\", \"\"\\)\n")
                (string-append
                 "\tcontent := getFlag(args, \"--content\", \"\")\n"
                 "\tif content == \"-\" {\n"
                 "\t\tdata, err := io.ReadAll(os.Stdin)\n"
                 "\t\tif err != nil {\n"
                 "\t\t\tfatal(\"read stdin: \" + err.Error())\n"
                 "\t\t}\n"
                 "\t\tcontent = string(data)\n"
                 "\t}\n")))))))
      (build-system go-build-system)
      (arguments
       (list #:go go-1.25
             #:import-path "github.com/junghan0611/denotecli/denotecli"
             #:unpack-path "github.com/junghan0611/denotecli"
             #:install-source? #f
             #:tests? #f))
      (home-page "https://github.com/junghan0611/denotecli")
      (synopsis "Command-line companion for Denote notes")
      (description
       "denotecli is a Go CLI that operates on note collections following the
Denote file-name convention.  Search, read, create, rename, graph, timeline, and
keyword operations with JSON output suitable for AI-agent integration.")
      (license license:asl2.0))))
