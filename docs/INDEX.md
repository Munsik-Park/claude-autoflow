# Documentation Index

Use this page as the first stop before assigning or implementing an issue, and as
the orchestrator's **router for role-scoped document injection** at DIAGNOSE (see
[`phases/analysis.md`](phases/analysis.md) > Per-role document injection whitelist).

**[MUST]** Never inject this index wholesale. It is a router the orchestrator reads to
*select* per-role documents — not a payload to hand to a sub-agent.

## Methodology Documents (this template)

These ship with the AutoFlow template and are the operating source of truth.

| Document | Role |
| --- | --- |
| [CLAUDE.md](../CLAUDE.md) | AutoFlow operating manual and phase router. |
| [AutoFlow Guide](autoflow-guide.md) | Phase-by-phase lifecycle (phase-body source of truth). |
| [DIAGNOSE Analysis Playbook](phases/analysis.md) | Issue analysis and necessity-evaluation procedure. |
| [Design Rationale](design-rationale.md) | Why the AutoFlow rules exist. |
| [Evaluation System](evaluation-system.md) | Scoring scale and PASS thresholds. |
| [Teammate Contracts](teammate-contracts.md) | Evaluation / Test / Submodule AI role contracts. |
| [Submodule Common Rules](submodule-common-rules.md) | Discussion Protocol and sub-repo rules. |
| [Repo Boundary Rules](repo-boundary-rules.md) | Host / submodule / cross-repo responsibility boundaries. |
| [Credentials & Runtime State](credentials.md) | Secret / reference / config tiers. |
| [Git Workflow](git-workflow.md) | Branch structure and bash procedures. |
| [External Review Sequencing](external-review-sequencing.md) | Merge sequencing and the external-review handshake (label gates, `subrepo-merged` dispatch, `handoff-sequence.yml`). |
| [Maintained Documents](maintained-docs.md.template) | Registry of documents that must stay current (rendered to `maintained-docs.md` per project). |
| [Security Checklist](security-checklist.md.template) | Security review checklist for the host scope (rendered to `security-checklist.md` per project). |

## Project Baseline (populate per project)

Each AutoFlow instance supplies its own current-state and decision-readiness
documents. They are **not** shipped with the template — create them for your
repository and register them in `maintained-docs.md`. DIAGNOSE injects them **per
role** through the [`phases/analysis.md`](phases/analysis.md) whitelist; the
`DIAGNOSE injection` column states which role each is allowed in (the problem / risk /
priority docs are denied to every pre-fan-out role by design).

| Suggested doc | Role | DIAGNOSE injection |
| --- | --- | --- |
| `docs/project-context.md` | Product and actor context behind an issue. | Intake triage (optional) |
| `docs/architecture-overview.md` | Compact observed architecture for contributors and agents. | Phase A (area excerpt only) |
| `docs/review/01-inventory.md` | Repository inventory — files, entry points, commands, integrations, unknowns. | Phase A (area excerpt only) |
| `docs/review/02-current-architecture.md` | Observed architecture without target-state redesign. | Phase A (area excerpt only) |
| `docs/review/03-issue-workflow-audit.md` | Issue classification — planning / design / ADR / impl / test / docs / tech-debt. | Intake triage |
| `docs/development-guideline.md` | Work-type, issue, ADR, PR, refactoring, test, and docs policy. | Intake triage |
| `docs/review/04-adr-candidates.md` | ADR priority and owner confirmation. | denied (priority doc) |
| `docs/review/05-risk-analysis.md` | Risk register. | denied (risk doc) |
| `docs/review/06-technical-debt.md` | Technical-debt register. | denied (problem doc) |
| `docs/review/07-refactoring-queue.md` | Refactoring queue. | denied (improvement doc) |
| `docs/adr/README.md`, `docs/adr/0000-adr-template.md` | ADR index and blank template. | ARCHITECT (role-minimal) |

## Quick Routing

| If the issue touches... | Read first |
| --- | --- |
| AutoFlow rules, gates, agent roles, or hook behavior | `CLAUDE.md`, `docs/design-rationale.md`, `docs/phases/analysis.md` |
| Submodule / sub-repo implementation | `docs/repo-boundary-rules.md`, the sub-repo's own `docs/` |
| Issue decomposition or readiness | the project's issue / workflow-audit doc, `docs/development-guideline.md` |
| Security review | `docs/security-checklist.md`, `docs/credentials.md` |
