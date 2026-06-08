# Teammate Contracts

> This document defines the role contracts for the teammates that the AI Orchestrator dispatches in AutoFlow: **Evaluation AI**, **Test AI**, and **Submodule AI (Developer AI)**, plus the consolidated **Evaluation System** scoring. The Orchestrator's own coordination responsibilities remain in [`CLAUDE.md`](../CLAUDE.md) > Team Structure. Per-phase spawn model policy: see [`CLAUDE.md`](../CLAUDE.md) > Spawn Model — Phase-by-Phase.

---

## Evaluation AI (subagent)
- Independent evaluator that does not participate in planning or implementation.
- Bias prevention: a fresh agent is spawned every call.
- Default spawn model: `sonnet` (rubric-scored gates — GATE:HYPOTHESIS, GATE:PLAN, AUDIT, GATE:QUALITY). Revert to `opus` if the score distribution drifts by ≥ ±0.5 from the Opus baseline.

### Evaluation AI Prompt Rules
1. **[MUST]** Include in the prompt: evaluation type, instruction to consult `docs/teammate-contracts.md`, target file paths.
2. **[MUST]** Do NOT copy evaluation criteria or other reference document bodies into the prompt — instruct the AI to read `docs/teammate-contracts.md > [section]` or `.autoflow/*` file paths directly. The same principle (file-path-only references) applies to all teammate dispatches; see [`CLAUDE.md`](../CLAUDE.md#cost-control) > Cost Control.
3. **[MUST]** The orchestrator-authored portion is 5 lines or fewer (excluding target file contents).
4. **[DENY]** No opinions, interpretations, or leading phrases ("consider that ~", "note that ~", "this is ~ so").

### Finding coverage (model-recall guard)
- **[MUST]** Surface every issue found, including low-severity and uncertain ones — list them in `recommendations` (or `blocking_issues` when score-blocking). Severity and confidence are expressed through the `score` and `reason`, never by silently omitting a finding. The rubric score is the filter; the finding stage prioritizes coverage.
- **[DENY]** Do not instruct the Evaluation AI to "only report important/high-severity issues" or to "be conservative" at the finding stage. Recent Claude models follow such filtering instructions literally — they investigate just as deeply but drop sub-bar findings instead of reporting them, which lowers recall. Let it report all findings and let the score rank them.

---

## Test AI (testing teammate)
- Participates in plan synthesis (ARCHITECT) from a verification perspective — "how will this design be verified?"
- Authors the verification design document: acceptance criteria → verification method (automated / manual / environment-dependent / requires design change).
- Writes test code before implementation (Test First) and confirms Red.
- For untestable items: states the reason and proposes alternatives (design change / manual scenario / mock).
- Performs minimal-implementation verification after implementation: detects code outside test coverage.
- Operates independently from the Developer AI — tests are written from acceptance criteria, not from the developer's intended implementation.
- Default spawn model: `sonnet` at RED (acceptance criteria → test code). Complex test scenarios fall back to `opus`, with the rationale recorded in the Test AI report.

---

## Submodule AI (per sub-repo, Developer AI)
- Understands and implements the assigned sub-repo's code.
- Writes the minimum code that passes the tests written by the Test AI (does not implement behavior outside tests).
- Has read access to other sub-repos; modifications stay within the assigned sub-repo.
- Pushes only to its fork branch (in the fork-and-PR model). PR creation is performed by the orchestrator.
- Common rules: see [`docs/submodule-common-rules.md`](submodule-common-rules.md).
- Default spawn model: `opus` at GREEN and VERIFY (implementation surface, self-check sycophancy risk). REFINE uses `sonnet` (mechanical `/simplify` application) — spawned fresh on the VERIFY → REFINE boundary, since mid-lifetime model switching is not supported.

In single-repo deployments (no submodules — see [`CLAUDE.md`](../CLAUDE.md) > Team Structure), the Submodule AI operates as the Developer AI in the orchestrator's repository. The role contract is unchanged — only fork/upstream distinctions disappear.

---

## Evaluation System

The orchestrator keeps an inline copy of this scoring system in [`CLAUDE.md`](../CLAUDE.md) > Evaluation System; the operational context (design intent, hook trust boundary, state-file linkage) is in [`docs/evaluation-system.md`](evaluation-system.md). This section is the consolidated reference the Evaluation AI is pointed at.

### Scoring (10-point scale)

| Score | Meaning | Action |
|------|------|------|
| 9-10 | Excellent | Proceed |
| 7-8  | Good      | Proceed |
| 5-6  | Insufficient | Rework recommended |
| 3-4  | Poor      | Rework required |
| 1-2  | Failing   | Redesign or human decision |

### PASS Criteria

- **[MUST]** Average ≥ 7.5
- **[MUST]** Each item ≥ 7
- **[MUST]** Security ≤ 3 → automatic rework

### Evaluation Types

| Type | Items | Retry |
|------|-------|-------|
| Structure evaluation | Type 1: Behavior gap, Code-change necessity (2) — Type 2: Content gap, Consistency impact, Propagation scope (3) | none (PASS/FAIL single verdict; reuse-neutral necessity gate; gap-low → close (new issue), non-code lever → report to user + pause; no retry) |
| Hypothesis evaluation | Hypothesis diversity, Verification sufficiency, Verdict evidence (3) | max 2× |
| Plan evaluation | Feasibility, Dependencies, Scope, Security, Test plan (5) — Feasibility/Scope carry structural-fit & over-engineering (not scored at DIAGNOSE) | max 3× |
| Security audit | Authn/Authz, Input validation, Data exposure, Infra isolation, Dependencies (5) | max 2× |
| Quality evaluation | Completeness, Quality, Test coverage, Test quality, Security, Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates (10) | max 3× |
| Doc evaluation | Accuracy, Completeness, Clarity, Format compliance (4) | one revision |

### Evaluation Output Format

```json
{
  "type": "hypothesis_evaluation | plan_evaluation | security_audit | quality_evaluation | doc_evaluation",
  "target": "scope name",
  "issue": "#N",
  "scores": { "item": { "score": 8, "reason": "evidence" } },
  "summary": "overall assessment",
  "blocking_issues": ["items ≤ 3"],
  "recommendations": ["items 5-6"]
}
```
