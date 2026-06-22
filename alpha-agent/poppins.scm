;;; alpha-agent — the `poppins` agent (household, personal domain)
;;;
;;; Mary Poppins: the family's household assistant, re-homed from the Hermes
;;; estate onto the pi/guix-agentic colony (consolidation decision, PKS
;;; [[denote:20260621T154600]]).  She is the PERSONAL-DOMAIN queen: her durable
;;; memory is a personal PKS root, kept HARD-SEPARATE from the work PKS (~/pks).
;;;
;;; First slice (this file): the agent itself — persona + the stage-don't-commit
;;; guardrail + personal-scoped memory + an isolating sandbox.  NOT yet wired:
;;; the NextCloud calendar/Deck tools (a credentialed CalDAV/Deck skill, the
;;; plan's no-new-dep fallback) and the thin Mattermost bridge — both follow-ons.
;;; A personalised (family-vocab) capture policy also comes later; the first
;;; slice gives the durable store + denotecli, which is the missing memory layer.

(define-module (alpha-agent poppins)
  #:use-module (guix-agentic agents core)
  #:use-module (guix-agentic agents backends)
  #:use-module (guix-agentic guardrails sandbox)
  #:use-module (guix-agentic capabilities memory backend)   ; memory-backend, with-memory
  #:use-module (guix-agentic packages personas)             ; make-pi-fragment
  #:use-module (alpha-agent denotecli)                      ; denotecli (vendored, channel-safe)
  #:use-module (guix-agentic packages skills)               ; make-pi-skill
  #:use-module (alpha-agent family-cal)                     ; family-cal (NextCloud calendar tool)
  #:use-module (alpha-agent mcp)                            ; pi-mcp-extension (MCP-client)
  #:use-module (guix gexp)                                  ; local-file, plain-file
  #:export (poppins poppins-launcher))

;;; PERSONAL domain root — NEVER the work PKS (~/pks).  Provisional path on this
;;; (work) box; the real root is the personal NextCloud account per ADR-0008,
;;; wired when Poppins deploys on the personal side.
(define %personal-root "/home/rafael/pks-personal")

;;; Lean personal-domain durable memory: denotecli over the personal root,
;;; folded onto Poppins's sandbox by `with-memory`.  Deliberately does NOT reuse
;;; alpha's work-PKS capture policy / code-project onboarding (those are
;;; work-domain); a family-vocab capture policy is a follow-on.
(define personal-memory
  (memory-backend
   (id 'poppins-personal)
   (tools (list denotecli))
   (shares (list %personal-root))))

(define %poppins-md
  (plain-file "poppins.md" "\
You are Mary Poppins, the household assistant for the Palomar family
(Maria; Rafael; Leandro, 10; Adrian, 8).

Voice: warm, brief, and familial — never corporate, never a wall of text.

Language: reply in the family member's own language — Norwegian, Spanish, or
English — and code-switch naturally.

Domain wall (hard): you serve the PERSONAL / household domain ONLY. Your durable
memory is the family's personal store. You have NO access to work or
professional data, calendars, or repositories, and you must never ask for them.
If a request is about work, say plainly that it's outside your domain.

Guardrail (hard): never auto-commit a change to the family's calendar, tasks, or
files. Instead STAGE the change — state exactly what you would do, tag it with
the target family member and the request that triggered it — and ask a human to
confirm before anything happens."))

(define poppins-steer
  (make-pi-fragment
   #:name "poppins"
   #:kind "append-system"
   #:content %poppins-md
   #:synopsis "Mary Poppins household persona + personal-domain wall + stage-don't-commit guardrail"))

(define %poppins-cal-md
  (plain-file "SKILL.md" "\
---
name: family-calendar
description: Read the family agenda and STAGE proposed changes (never commit).
---

# family-calendar

To read or propose changes to the family's NextCloud calendar, use `family-cal`:

    family-cal agenda [--days N]                 # read the agenda
    family-cal stage <summary> <start> [<end>] --member <who> --note <why>
                                                 # PROPOSE a change (staged for a human)

Times are CalDAV UTC stamps, e.g. 20260625T150000Z.

You only ever STAGE.  A change is NOT applied until a human runs
`family-cal commit <id>` — NEVER run `commit` yourself.  After staging, tell the
family member what you've proposed and that it's awaiting their confirmation.
"))

(define poppins-cal-skill
  (make-pi-skill
   #:name "family-calendar"
   #:skill-md %poppins-cal-md
   #:synopsis "Read the family agenda; stage calendar changes for human confirmation"))

(define %poppins-deck-md
  (plain-file "SKILL.md" "\
---
name: family-deck
description: Manage the family's NextCloud Deck task boards (create/share/cards).
---

# family-deck

You manage the family's NextCloud Deck (task boards) with your `nc_nextcloud_*`
tools.  You have full powers over boards you OWN: create boards, create
stacks/lists, create/move/delete cards, and SHARE boards with family members.

VISIBILITY (the golden rule): a task card is only useful if the family can SEE
it.  Always put family cards on a board that is SHARED with the family.  A board
you own but have NOT shared (e.g. \"Family Tasks\", \"Welcome to Nextcloud Deck!\")
is INVISIBLE to everyone else — putting a card there looks done to you but the
family never sees it.

How to work:
- Keep ONE canonical family task board that YOU own and have SHARED with the
  family.  If \"Family Tasks\" exists, share it with rafael and maria (Edit) and
  use it.  If none exists, create one and share it.
- When you create any family board, immediately SHARE it with rafael and maria
  (Edit); add the kids (leandro, adrian) when the board is for them.
- You have full control on boards YOU own (create stacks + cards freely there).
  On boards OTHERS own (e.g. rafael's \"Family\" board) you only have Edit: you may
  add cards to EXISTING stacks, but you CANNOT create stacks (it returns 403) —
  so don't try; use a board you own and have shared instead.
- After creating or sharing, tell the family member the board name and confirm
  it's shared so they know where to look.

Safety: you may create, share, and edit cards directly.  But CONFIRM with a human
before DELETING an entire board or stack (that destroys all the cards in it).
"))

(define poppins-deck-skill
  (make-pi-skill
   #:name "family-deck"
   #:skill-md %poppins-deck-md
   #:synopsis "Manage the family Deck: own + share family boards so cards are visible"))

;;; MCP servers for the pi-mcp-extension.  One server: the nextcloud-mcp sidecar
;;; on edison (host loopback, slice 3), giving the NextCloud hands
;;; (Deck/Calendar/Files/Contacts/Sharing).  `eager' = the extension connects +
;;; discovers tools at session_start; `lazy' would require a manual `/mcp:start'
;;; command, which `poppins -p' (one-shot) never issues — so eager is required
;;; for an always-on chat agent.  Reachable because Poppins's sandbox shares the
;;; host net namespace (network 'open).  Tools surface as nc_nextcloud_<tool>.
;;; TODO: the server exposes ~110 tools eagerly — scope its enabled apps to keep
;;; the context manageable for gemini-3.1-flash-lite.
(define %poppins-mcp-json
  (plain-file "mcp.json" "\
{
  \"settings\": { \"toolPrefix\": \"nc\", \"requestTimeoutMs\": 30000 },
  \"mcpServers\": {
    \"nextcloud\": {
      \"transport\": \"streamable-http\",
      \"url\": \"http://127.0.0.1:8000/mcp\",
      \"lifecycle\": \"eager\"
    }
  }
}
"))

(define base-poppins
  (agent
   (name "poppins")
   (backend pi-backend)
   (append-system (list poppins-steer))
   (settings (local-file "settings.poppins.json"))
   (extra-packages (list family-cal))            ; the NextCloud calendar tool
   (skills (list poppins-cal-skill poppins-deck-skill))
   (extensions (list pi-mcp-extension))          ; MCP client (-> nextcloud-mcp)
   (mcp-config %poppins-mcp-json)                ; the server config (CFGDIR/mcp.json)
   ;; Personal-domain sandbox: open network (the LLM + NextCloud); NO cwd
   ;; mapping (not a coding agent); NO work PKS, NO SSH-agent.  Crossing in:
   ;; the OpenRouter key, DENOTECLI_DIRS (personal root), and the NextCloud
   ;; calendar env (NC_APPPW value + NC_USER/URL/CALENDAR) set by the wrapper.
   ;; with-memory folds the personal root share on top.
   (sandbox (sandbox (network 'open) (no-cwd? #t)
                     (preserve '("^OPENROUTER_API_KEY$" "^DENOTECLI_DIRS$"
                                 "^NC_APPPW$" "^NC_USER$" "^NC_URL$" "^NC_CALENDAR$"))))))

(define poppins (with-memory base-poppins personal-memory))
(define poppins-launcher (agent->package poppins))
