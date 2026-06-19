;;; alpha-agent — PKS memory backend
;;;
;;; The opinionated <memory-backend> instance: durable store = the user's PKS
;;; (Denote/org), accessed via denotecli.  This is the half guix-agentic refuses
;;; to hold; it implements the framework's interface and is bound to the agent
;;; with `with-memory`.
;;;
;;; `denotecli` is injected (not imported) so this module loads without the
;;; entelequia channel on the path; agent.scm supplies the package.

(define-module (alpha-agent pks backend)
  #:use-module (guix-agentic capabilities memory backend)
  #:use-module (alpha-agent pks policy)
  #:use-module (alpha-agent pks capture)
  #:use-module (alpha-agent pks onboard)
  #:export (make-pks-memory-backend))

(define* (make-pks-memory-backend
          #:key
          denotecli                                       ; the denotecli package
          (pks-dir "/home/rafael/pks"))
  "A <memory-backend> whose durable layer is the PKS at PKS-DIR, written via
DENOTECLI.  PKS-DIR is mounted read-write into the L1 sandbox by `with-memory`
(folded onto the agent's own sandbox; meet cannot widen it).

This backend owns ONLY the durable layer.  Layer-2 episodic memory is a separate
concern, added with `with-episodic` (guix-agentic capabilities memory episodic)."
  (memory-backend
   (id 'pks)
   (policy pks-capture-policy)
   (skills (list pks-capture-skill pks-project-onboard-skill))
   (tools (if denotecli (list denotecli) '()))
   (shares (list pks-dir))))
