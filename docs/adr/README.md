# Architecture Decision Records

This directory records architecture decisions that affect implementation,
deployment, repository boundaries, tenant isolation, agent workflow, or
operational responsibility.

## Status Values

- `Proposed`: Drafted for review or owner confirmation.
- `Accepted`: Confirmed as project policy.
- `Deprecated`: No longer recommended, but kept for history.
- `Superseded`: Replaced by a later ADR.

## When to Create an ADR

Create or update an ADR before implementation when a change affects:

- Host/submodule responsibility boundaries.
- Deployment topology or CI/CD authority.
- Tenant isolation, accounting ownership, file visibility, or access control.
- Secret/config management.
- Agent workflow gates, evaluation policy, or merge authority.
- External service dependencies.

Start from [0000-adr-template.md](0000-adr-template.md).

## Current Drafts

| ADR | Status | Topic |
| --- | --- | --- |
| [0001-host-orchestrator-and-submodule-boundary.md](0001-host-orchestrator-and-submodule-boundary.md) | Proposed | Host/submodule ownership boundary. |
| [0003-autoflow-ends-at-handoff.md](0003-autoflow-ends-at-handoff.md) | Proposed | AutoFlow creates PRs and hands off; external reviewer merges. |

See the project's ADR candidates list for additional candidates
that still need owner confirmation or prioritization.
