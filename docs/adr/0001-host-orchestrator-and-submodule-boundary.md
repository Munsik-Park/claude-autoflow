# ADR-0001: Host Orchestrator and Submodule Boundary

## Status

Proposed

## Context

The repository contains host-owned AutoFlow, deployment, client overlay, and
documentation surfaces, while the application implementation lives in the
`services/{{REPO_SUBMODULE}}` submodule. Existing boundary documents state that
agents should operate within assigned repositories and that the orchestrator
coordinates cross-repo work rather than directly implementing sub-repo changes.

## Decision

Treat the host repository as the owner of orchestration, methodology, deployment
config, client overlays, handoff automation, and host-level documentation.
Treat `services/{{REPO_SUBMODULE}}` as the application submodule whose
implementation changes should be handled through sub-repo work unless a
documented carve-out applies.

## Alternatives Considered

- Let the host repository directly modify submodule implementation code.
- Move all implementation and documentation into the host repo.
- Split deployment/client overlays into a separate operations repository.

## Consequences

### Positive

- Keeps repository responsibility clear.
- Reduces accidental cross-repo commits and unreviewed application changes.
- Supports external review sequencing and submodule pointer verification.

### Negative

- Cross-boundary changes require more coordination.
- Some docs inside the submodule need explicit ownership rules.

### Neutral / Trade-Offs

- The host may still need read access to submodule code to understand contracts.

## Related Issues / PRs

- See [`docs/repo-boundary-rules.md`](../repo-boundary-rules.md) for the
  full cross-project boundary rules.

## Notes

- Owner should confirm whether docs under `services/{{REPO_SUBMODULE}}/docs/`
  remain host-maintained carve-outs.
