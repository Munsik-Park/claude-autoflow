# Evaluation System

> The Auto-Flow evaluation system provides quantified quality assessment at the
> three gates (`GATE:HYPOTHESIS`, `GATE:PLAN`, `GATE:QUALITY`) and at `AUDIT`,
> ensuring consistent standards across all changes.

---

## Overview

The Evaluation AI is an **independent agent** that scores completed work before
it reaches human review. This separation keeps judgment objective — the agent
that wrote the work never evaluates it.

### Critical Rule: Fresh Spawn Every Time

The Evaluation AI must be **spawned fresh for every evaluation** — at
GATE:HYPOTHESIS, GATE:PLAN, AUDIT, and GATE:QUALITY. It carries no prior
conversation history. This is mandatory.

**Why**: when the same agent creates a plan and evaluates it, it struggles to
reject its own work. A freshly spawned agent sees only the deliverable — it has
no investment in the process. Bias elimination takes priority over token cost.
See [`design-rationale.md`](design-rationale.md#decision-2-evaluation-ai-is-spawned-fresh-every-time).

---

## 10-Point Scale

| Score | Meaning | Action |
|-------|---------|--------|
| 9-10  | Excellent | Proceed |
| 7-8   | Good      | Proceed |
| 5-6   | Insufficient | Rework recommended |
| 3-4   | Poor      | Rework required |
| 1-2   | Failing   | Redesign or human decision |

---

## PASS Criteria

A change passes evaluation when **all** of the following hold:

- **[MUST]** Average ≥ 7.5
- **[MUST]** Each item ≥ 7
- **[MUST]** Security ≤ 3 → automatic rework

If any condition fails, the change fails.

### Why these thresholds are strict

Lenient criteria create a pattern of "scoring high on easy items to raise the
average while passing weak items." The per-item minimum (≥ 7) prevents this
gaming. Security ≤ 3 triggers mandatory rework because security failures cannot
be diluted by averaging.

---

## Evaluation Types

| Type | Items (count) | Retry |
|------|---------------|-------|
| Structure evaluation (GATE:HYPOTHESIS — structure form, runs in DIAGNOSE 3-Phase) | Structural overlap, Code-change necessity, New-mechanism necessity (3) | none — PASS/FAIL single verdict; FAIL → issue auto-closed + Auto-Flow terminated |
| Hypothesis evaluation (GATE:HYPOTHESIS — cause form, bug/incident only) | Hypothesis diversity, Verification sufficiency, Verdict evidence (3) | max 2× → DIAGNOSE |
| Plan evaluation (GATE:PLAN) | Feasibility, Dependencies, Scope, Security, Test plan (5) | max 3× → ARCHITECT |
| Security audit (AUDIT) | Authn/Authz, Input validation, Data exposure, Infra isolation, Dependencies (5) | max 2× |
| Quality evaluation (GATE:QUALITY) | Completeness, Quality, Test coverage, Test quality, Security, Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates (10) | max 3× → RED |
| Doc evaluation | Accuracy, Completeness, Clarity, Format compliance (4) | one revision |

The category sets and weights should be customised per project. They reflect
"what actually matters in this project," not universal standards. As patterns
emerge, humans adjust the criteria.

---

## Evaluation Output Format

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

The `scores` object is what the gate hook reads. Each item is either a number
(`8`) or an object (`{"score": 8, "reason": "..."}`). The hook accepts both.

---

## Hook Trust Boundary

`check-autoflow-gate.sh` does **not** read the AI's `pass`, `avg`, or `min`
fields. It computes them from raw `scores`. The trust chain stops at the script
level — see [`design-rationale.md`](design-rationale.md#decision-3-the-hook-does-not-trust-ais-pass-judgment).

---

## State File Linkage

While Auto-Flow is in progress, `.autoflow/issue-{N}.json` records the score
sets per phase. The hook reads from this file at gate points to allow or block
Agent spawns and `git push`/`gh pr create` actions.

The phase keys used by the hook are:

- `gate_hypothesis_structure` — DIAGNOSE 3-Phase structure evaluation
- `gate_hypothesis_cause` — GATE:HYPOTHESIS cause analysis
- `gate_plan` — GATE:PLAN
- `audit` — AUDIT
- `gate_quality` — GATE:QUALITY

See [`CLAUDE.md`](../CLAUDE.md#auto-flow-state-tracking-hook-integration) for the
full schema.
