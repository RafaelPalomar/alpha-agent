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
  #:use-module (alpha-agent nc-deck-share)                  ; nc-deck-share (Deck board ACL)
  #:use-module (alpha-agent mcp)                            ; pi-mcp-extension (MCP-client)
  #:use-module (gnu packages nss)                           ; nss-certs (CA bundle for HTTPS tools)
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

Guardrail: you manage the family's calendar and task boards (Deck) directly with
your NextCloud tools — read, create, update, and share as your family-calendar
and family-deck skills describe; that is your job. Always CONFIRM with a human
before a DESTRUCTIVE delete: an entire Deck board or stack, or a calendar event."))

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
description: Read and manage the family's NextCloud calendar via the MCP tools.
---

# family-calendar

Manage the family's NextCloud calendar with your `nc_nextcloud_*` calendar tools
(list calendars, read the agenda/events, create and update events).  Use them
directly — that is your job.

- When you add an event, put it on a calendar the relevant family members can
  see, and tell them what you added.
- Always CONFIRM with a human before DELETING an event or any destructive change.
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

Sharing a board (CRITICAL — read carefully): the MCP `nc_share_*` tools share
FILES, not Deck boards; calling them on a board fails with 404.  NEVER use an
`nc_share_*` tool to share a board.  Instead you MUST run the shell command
`nc-deck-share` with your bash/shell tool:

    nc-deck-share acl   <board-id>                     # see who a board is shared with
    nc-deck-share share <board-id> <user> [--manage]   # share (edit by default)

It is a normal command-line program on your PATH — run it through bash, do not
look for an MCP tool by that name.  Usernames are: rafael, maria, leandro, adrian.
So to share board 7 with the parents you literally run, via bash:
    nc-deck-share share 7 rafael
    nc-deck-share share 7 maria

How to work:
- Keep ONE canonical family task board that YOU own and have shared.  If
  \"Family Tasks\" exists, run `nc-deck-share share <its id> rafael` and
  `nc-deck-share share <its id> maria`, then use it.  If none exists, create one
  (MCP create_board) and share it the same way.
- Whenever you create a family board, immediately share it with rafael and maria
  (add leandro/adrian when it is for them).
- You have full control on boards YOU own (create stacks + cards freely there).
  On boards OTHERS own (e.g. rafael's \"Family\" board) you only have Edit: add
  cards to EXISTING stacks, but do NOT try to create stacks there (it 403s) —
  use a board you own and have shared instead.
- After creating/sharing, tell the family member the board name and that it's
  shared, so they know where to look.

Actions: creating boards/stacks/cards, sharing, and editing cards you may do
DIRECTLY (this is your job — no staging).  Only CONFIRM with a human before
DELETING an entire board or stack (that destroys all the cards in it).
"))

(define poppins-deck-skill
  (make-pi-skill
   #:name "family-deck"
   #:skill-md %poppins-deck-md
   #:synopsis "Manage the family Deck: own + share family boards so cards are visible"))

(define %poppins-search-md
  (plain-file "SKILL.md" "\
---
name: web-search
description: Search the web and read pages via the family's private SearxNG.
---

# web-search

You can search the internet with your MCP search tools (from the `search`
server): `searxng_web_search` (returns web results — title, url, snippet) and
`web_url_read` (fetch a page as markdown).  They query the family's OWN
self-hosted SearxNG — private and Mullvad-routed — so use them freely.

- Reach for web search whenever a question needs current or factual information
  you don't already know (news, opening hours, prices, how-to, local events,
  recommendations).  Don't guess when you can look it up.
- Mention the source when it matters.  Keep the answer brief and familial.
"))

(define poppins-search-skill
  (make-pi-skill
   #:name "web-search"
   #:skill-md %poppins-search-md
   #:synopsis "Search the web + read pages via the family's private SearxNG (MCP)"))

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
    },
    \"search\": {
      \"transport\": \"streamable-http\",
      \"url\": \"http://127.0.0.1:3000/mcp\",
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
   ;; nss-certs: the tool profile must carry a CA bundle, else the python HTTPS
   ;; tools (family-cal, nc-deck-share) can't verify TLS inside the L1 sandbox
   ;; (the host's SSL_CERT_FILE path isn't valid there).  The wrapper points
   ;; SSL_CERT_FILE at this profile's bundle.
   (extra-packages (list nc-deck-share nss-certs))
   (skills (list poppins-cal-skill poppins-deck-skill poppins-search-skill))
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
