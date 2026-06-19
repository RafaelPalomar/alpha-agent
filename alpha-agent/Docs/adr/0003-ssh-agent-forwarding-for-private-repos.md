# 0003. Forward the SSH agent into alpha's sandbox (clone/push private repos)

- **Status:** Accepted
- **Date:** 2026-06-19
- **Deciders:** Rafael Palomar
- **PR:** (alpha git-ssh)

## Context

alpha's purpose is to work on the user's own projects — most of which are private
GitHub repos (e.g. `OUH-MESHLab/SlicerHyperprobe`). With the provisioning
capability (guix-agentic ADR-0008) alpha can lay out a clone, but the L1 sandbox
has no git credentials, so a private clone fails on authentication. The user
authenticates to GitHub with an SSH agent (gpg-agent ssh socket, keys loaded);
the host can already reach the private repos over SSH.

## Decision

Compose `with-git-ssh` (guix-agentic ADR-0009) onto `alpha`. This adds `openssh`
to alpha's profile and forwards `$SSH_AUTH_SOCK` + `~/.ssh/known_hosts` into the
container at launch, so git over SSH works as the user inside the sandbox.

alpha is the trusted personal agent (cloud network already open, `~/pks`
read-write, `/model` unlocked), so granting it the same git reach the user has is
consistent with its posture — not a new class of trust.

## Alternatives considered

### Alternative A — per-clone HTTPS token

Rejected: handling the user's token into the sandbox per clone is more friction
and more exposure than forwarding the agent socket, and does not cover push.

### Alternative B — host-side clone, agent only works the tree

Rejected for alpha (kept only as a fallback): defeats "have alpha actually clone
and start working"; alpha must be able to fetch/push during the work, not just
read a pre-placed tree.

## Consequences

- alpha can clone, fetch, and push any repo the forwarded agent keys reach — it
  acts as the user for git. This is the intended capability for a personal agent,
  and a real relaxation to keep in mind.
- alpha's profile gains `openssh`; the launcher forwards the agent socket only
  when it exists at runtime.

## Conformance

- **Test:** load `(alpha-agent agent)`; the launcher contains the runtime
  `SSH_FWD` block; `agent-forward-ssh-agent?` of `alpha` is `#t`; `openssh` is on
  `agent-extra-packages`.

## References

- guix-agentic ADR-0009 (`with-git-ssh`), ADR-0008 (provisioning).
- ADR-0001/0002 (alpha's trusted posture and memory authorization).
