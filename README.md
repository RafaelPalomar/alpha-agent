# alpha-agent

A **consumer channel** defining the user's personal pi agent, `alpha`, bound to
a **PKS (Denote/org) durable-memory backend**.

`alpha-agent` depends on the [`guix-agentic`](https://github.com/OUH-MESHLab/guix-agentic)
framework channel. It holds the *opinionated* half of the memory design that the
framework refuses to carry: the `pks-memory-backend` (denotecli, `~/pks`, org
property-drawer provenance) and the agent that binds it.

## Layout

```
alpha-agent/
  pks/
    policy.scm     append-system fragment — three-layer navigation + unprompted
                   capture-to-fleeting policy
    capture.scm    pks-capture skill — denotecli workflow with dedup + provenance
    backend.scm    make-pks-memory-backend — the <memory-backend> instance
  agent.scm        the `alpha` <agent>; binds the PKS backend with with-memory
  manifests/alpha.scm
  Docs/adr/        this channel's decision records
```

## Memory model

Three layers, navigated by the policy fragment:

1. **Structural** — regenerable code index (derived; never hand-edited).
2. **Episodic** — short-lived per-project session notes (not the PKS).
3. **Durable** — the PKS, written via `denotecli`. The agent contributes
   **systematically and unprompted**, but only as *capture into `fleeting/`*,
   stamped with provenance. Promotion to `permanent/` and any rename/delete stay
   human-confirmed.

`with-memory` (from `guix-agentic`) folds the backend's `~/pks` + episodic
read-write shares onto the agent's own L1 sandbox — `sandbox-meet` intersects rw
shares and could never widen them (guix-agentic ADR-0004/0007), so enabling
memory deliberately relaxes confinement.

## Launch (local dev)

```sh
guix shell -L ~/src/guix-agentic -L ~/src/alpha-agent -L ~/.dotfiles \
  -e '(@ (alpha-agent manifests alpha) alpha-packages)' -- alpha
```

(The manifest is a module, not a bare `-m` file — `guix shell -e` takes the
exported package list.  See the docstring in `manifests/alpha.scm`.)

`pi` comes from the user's guix-home profile (`pi-backend` launcher `#f`) until
`guix-agentic` owns pi from-source. `denotecli` is supplied by the entelequia
load path (`~/.dotfiles`).
