;;; alpha-agent — pi-mcp-extension: MCP-client capability for pi agents.
;;;
;;; pi-core has no MCP, but the ecosystem ships MCP-client EXTENSIONS.  This
;;; packages `pi-mcp-extension' (github irahardianto/pi-mcp-extension) as a
;;; guix-agentic pi extension so an agent (Poppins) can reach an MCP server
;;; (the nextcloud-mcp sidecar → Deck/Calendar/Files/Contacts/Sharing).
;;;
;;; The extension is multi-file TS with two real npm deps (@modelcontextprotocol/
;;; sdk + zod) and three pi-PROVIDED peers (@mariozechner/pi-*, typebox).  We
;;; esbuild-bundle index.ts — inlining the SDK + zod (resolved via a profile of
;;; the guix-openclaw node packages on NODE_PATH), externalizing the peers + node
;;; builtins — into one self-contained ESM file, then wrap it with
;;; make-pi-extension (installs share/pi/extensions/mcp/index.ts).  No runtime
;;; node_modules needed: everything is either inlined or pi-provided.

(define-module (alpha-agent mcp)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module (guix profiles)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages web)                          ; esbuild
  #:use-module (guix-openclaw packages node-openclaw-deps)  ; node-modelcontextprotocol-sdk, node-zod
  #:use-module (guix-agentic packages extensions)           ; make-pi-extension
  #:export (pi-mcp-extension))

(define %pi-mcp-commit "8a01fc53f3289d2e8eb492d67ba45cd84d64e7f2")

(define pi-mcp-extension-source
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/irahardianto/pi-mcp-extension")
          (commit %pi-mcp-commit)))
    (file-name (string-append "pi-mcp-extension-"
                              (string-take %pi-mcp-commit 7) "-checkout"))
    (sha256
     (base32 "1svrxaqzxrqlal0k2xw3w4s4r27xz06c9lgdzjgvzjf0wp0q6x3a"))))

;; Union the two real npm deps (+ their transitive closures) into one
;; lib/node_modules tree so esbuild's NODE_PATH resolves @modelcontextprotocol/
;; sdk/* and zod while bundling.
(define mcp-deps-profile
  (profile
   (content (packages->manifest
             (list node-modelcontextprotocol-sdk-1.29.0 node-zod-3.25.76)))))

;; esbuild src/index.ts -> one self-contained ESM file at <out>/index.js.
;; Inlines the SDK + zod; leaves the pi-provided peers + node builtins as bare
;; imports (pi resolves them at load time; --platform=node externalises builtins).
(define mcp-bundle
  (package
    (name "pi-mcp-extension-bundle")
    (version "1.5.0")
    (source pi-mcp-extension-source)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      (with-imported-modules '((guix build utils))
        #~(begin
            (use-modules (guix build utils))
            (setenv "NODE_PATH"
                    (string-append #$mcp-deps-profile "/lib/node_modules"))
            (copy-recursively #$source "src-tree")
            ;; The extension reads mcp.json from homedir()/.pi/agent or <cwd>/.pi
            ;; — neither reachable inside an L1 container.  Make it prefer
            ;; $PI_CODING_AGENT_DIR/mcp.json (the dir guix-agentic creates,
            ;; shares, and writes), so the launcher can drop the config there.
            (substitute* "src-tree/src/config.ts"
              (("join\\(homedir\\(\\), \"\\.pi\", \"agent\", \"mcp\\.json\"\\)")
               "(process.env.PI_CODING_AGENT_DIR ? join(process.env.PI_CODING_AGENT_DIR, \"mcp.json\") : join(homedir(), \".pi\", \"agent\", \"mcp.json\"))"))
            (mkdir-p #$output)
            (invoke #$(file-append esbuild "/bin/esbuild")
                    "src-tree/src/index.ts"
                    "--bundle" "--platform=node" "--format=esm"
                    "--external:@mariozechner/*" "--external:typebox"
                    (string-append "--outfile=" #$output "/index.js"))))))
    (synopsis "Bundled pi MCP-client extension (esbuild, deps inlined)")
    (description "esbuild bundle of pi-mcp-extension: a self-contained ESM module
with @modelcontextprotocol/sdk + zod inlined and the pi-provided peers
externalised.  Consumed by @code{pi-mcp-extension} via make-pi-extension.")
    (home-page "https://github.com/irahardianto/pi-mcp-extension")
    (license license:expat)))

(define pi-mcp-extension
  (make-pi-extension
   #:name "mcp"
   #:version "1.5.0"
   #:index-ts (file-append mcp-bundle "/index.js")
   #:synopsis "MCP-client extension for pi (NextCloud hands via nextcloud-mcp)"
   #:description "A pi extension that bridges MCP server tools into the agent.
Configured via an mcp.json in the agent's config dir; used to give Poppins the
NextCloud hands (Deck/Calendar/Files/Contacts/Sharing) through the nextcloud-mcp
server."
   #:home-page "https://github.com/irahardianto/pi-mcp-extension"
   #:license license:expat))
