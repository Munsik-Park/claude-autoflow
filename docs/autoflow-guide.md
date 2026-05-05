# Auto-Flow Guide — Phase-by-Phase Development Lifecycle

> Auto-Flow is a structured, evaluation-gated development lifecycle for AI-assisted
> software engineering with Claude Code. This guide walks through each phase in
> order; the rules of record live in [`CLAUDE.md`](../CLAUDE.md).

---

## Overview

Auto-Flow defines 16 phases (`PREFLIGHT` → `LAND`) that guide every code change
from issue analysis to merge. Each phase has explicit entry/exit criteria, and
evaluation gates prevent low-quality work from reaching production.

Key principles:

- **No shortcuts** — every phase is executed in order.
- **Multi-agent separation** — distinct roles handle implementation, testing, and evaluation.
- **Bias prevention** — 3-phase independent analysis before coding.
- **Quantified quality** — 10-point evaluation with a defined PASS threshold.

The phase names generalize upstream's numeric `STEP 0~9` identifiers; the
mapping is preserved 1:1 below.

| upstream | this guide |
|----------|------------|
| STEP 0 | PREFLIGHT |
| STEP 1 | DIAGNOSE |
| STEP 1.5 | GATE:HYPOTHESIS |
| STEP 2 | ARCHITECT |
| STEP 3 | GATE:PLAN |
| STEP 4 | DISPATCH |
| STEP 5a | RED |
| STEP 5b | GREEN |
| STEP 5c | VERIFY |
| STEP 5d | REFINE |
| STEP 5.5 | VALIDATE |
| STEP 5.7 | AUDIT |
| STEP 6 | GATE:QUALITY |
| STEP 7 | DELIVER |
| STEP 8 | INTEGRATE |
| STEP 9 | LAND |

---

## PREFLIGHT — Pre-Work

**Goal**: ensure a clean Git state before any analysis or coding begins.

| Step | Action |
|------|--------|
| 1 | `git status` — confirm no uncommitted changes or untracked files in the working area |
| 2 | `git fetch origin` — sync with remote |
| 3 | Resolve any dirty state (stash, commit, or discard with user approval) |
| 4 | `git checkout -b dev/YYYY-MM-DD main` — create a dev branch |

**Hard stop**: if the Git state is not clean after resolution attempts, **stop and report to the user**. Do NOT proceed to DIAGNOSE.

---

## DIAGNOSE — Issue Analysis

When an issue arrives, classify cause hypotheses **before** code analysis.

### 1. Identify affected sub-repos.

### 2. Independent structure analysis (3-Phase)

Phase A and Phase B run in parallel; Phase 3 cross-checks them.

#### Phase A — AI-A: structure analysis (does NOT see the issue)

- Input: affected sub-repo + functional area.
- Instruction: "Analyze how this area currently works — pipeline structure, design intent, data flow."
- Output: factual description of the area as it stands.
- `[MUST]` Do NOT include the issue number, title, or problem description in the prompt.
- `[MUST]` Do NOT use words like "problem", "fix", "missing", "insufficient" in the prompt.

#### Phase B — AI-B: issue analysis (does NOT see the code)

- Input: issue body.
- Instruction:
  1. List the concrete cases mentioned in the issue.
  2. Identify the higher-level problem type these cases share.
  3. Propose resolution approaches.
- `[MUST]` Do NOT use code search/read tools.

#### Phase 3 — AI-A re-spawned to evaluate AI-B's resolution approaches

- Input: Phase A structure analysis + AI-B's resolution list.
- Instruction: "For each proposed resolution, evaluate whether the existing system structure already handles it."
- `[MUST]` Do NOT include the issue body.

#### Issue type classification

- **Type 1 (code change)**: bug fix, new feature, script change, pattern extension, hook change.
- **Type 2 (documentation/consistency)**: content sync, doc update, cross-file consistency.
- Mixed/unclear → default to Type 1.

#### Scoring (3 items × 10 points, by issue type)

**Type 1**:

| Item | Criterion |
|------|-----------|
| Structural overlap     | Does the proposal duplicate an existing mechanism? (high = no overlap) |
| Code-change necessity  | Is actual code change required, vs. data/config addition? (high = code change needed) |
| New-mechanism necessity | Is this a new problem type the existing framework cannot handle? (high = new mechanism needed) |

**Type 2**:

| Item | Criterion |
|------|-----------|
| Content gap        | Is there an actual content gap or inconsistency? (high = gap exists) |
| Consistency impact | Does the inconsistency affect users or AI behavior? (high = significant impact) |
| Propagation scope  | Is the change scope appropriate? (high = appropriate scope) |

PASS: avg ≥ 7.5, each ≥ 7.

- **PASS** → continue.
- **FAIL** → issue auto-closed + Auto-Flow terminated.

### 3. Cause hypotheses (≥ 3; "not a code bug" must be one)

### 4. Lightweight verification (when a dev environment is available)

### 5. Hypothesis verdict notes (eliminated / likely / unverified, with evidence)

### 6. Task decomposition (only if code change is required)

### 7. Identify affected docs (from the maintained-docs registry)

---

## GATE:HYPOTHESIS — Hypothesis Evaluation (bug/incident issues only)

Feat issues skip this gate.

**Evaluator**: independent Evaluation AI, fresh-spawned per call.
**Input**: hypothesis list + lightweight-verification results + verdict notes.

### Scoring (3 items × 10 points)

| Item | Criterion |
|------|-----------|
| Hypothesis diversity | Are non-code causes (data, environment, already-fixed) sufficiently considered? |
| Verification sufficiency | Was lightweight verification actually performed? Are unverified items justified? |
| Verdict evidence | Is the conclusion (code change required / not required) logically supported? |

- **PASS** → ARCHITECT.
- **FAIL** → DIAGNOSE (max 2×). Two FAILs → human decision.
- **Non-code root cause confirmed** → report to user, pause Auto-Flow.

---

## ARCHITECT — Plan Synthesis (Developer AI + Test AI)

Both teammates participate in the Agent Teams discussion.

### Output artifacts

1. **Feature Design Document** (Developer-AI-led).
2. **Verification Design Document** (Test-AI-led):

| Acceptance criterion | Verification type | Method |
|----------------------|-------------------|--------|
| (criterion 1) | automated | pytest / API test / etc. |
| (criterion 2) | manual    | scenario doc (delegated to user) |
| (criterion 3) | environment-dependent | introduce mock or propose design change |

### Testability-driven design

When the Test AI flags an item as "not automatable", the team discusses whether a feature-design change makes it testable. If not, the item stays as a manual scenario with a stated reason.

### Agreement criteria

Both documents reach ACCEPT from both teammates. The Discussion Protocol applies.

---

## GATE:PLAN — Plan Evaluation

**Evaluator**: fresh-spawned Evaluation AI.

### Scoring (5 items × 10 points)

| Item | Criterion |
|------|-----------|
| Feasibility   | Can this plan be implemented with the current structure? |
| Dependencies  | Are affected files and side effects identified? |
| Scope         | Appropriate — not too broad, not missing requirements? |
| Security      | Any security implications introduced? |
| Test plan     | Are acceptance criteria testable? |

- **PASS** → DISPATCH.
- **FAIL** → ARCHITECT (max 3×).

---

## DISPATCH — Task Assignment

`TaskCreate` + `SendMessage` to **both teammates**:

- **Test AI**: verification-design "automated" items → test-writing tasks.
- **Developer AI**: feature-design implementation tasks (starts after RED is complete).
- Both receive: acceptance criteria + verification design + affected docs.

---

## RED — Test Writing (Test First)

```
1. Convert acceptance criteria → test code (only items typed "automated").
2. Run tests → all must FAIL (Red).
3. For untestable items → write a manual verification scenario document.
4. Hand the test code + scenario document to the Developer AI.
```

---

## GREEN — Implementation

```
1. Read the test code authored by the Test AI.
2. Write the minimum code that passes the tests.
   - [MUST] Do NOT implement behavior not covered by tests.
3. Commit (feat/fix branch).
```

---

## VERIFY — Test Run + Verification

```
1. Run all tests.
2. Branch on result:
   All PASS → step 3.
   Some FAIL → cause branching:
     Test AI:      "Does my test reflect the criterion?" — self-check.
     Developer AI: "Does my impl meet the criterion?"   — self-check.
       ├─ Test AI says "fix the test"  → fix test → re-Red → re-enter GREEN
       ├─ Developer AI says "fix impl" → fix impl → re-run VERIFY
       ├─ Both say "fix"               → test first → Red → impl → Green
       └─ Both say "no problem"        → deadlock: Evaluation AI judges
3. Minimal-implementation check (Test AI):
   diff analysis: are there parts of the impl diff not covered by any test?
     ├─ All covered → PASS
     ├─ Uncovered code → ask Developer AI to remove it, or add a test
     └─ Infrastructure / config / non-testable code → exception (state reason)
```

**Deadlock resolution**: Evaluation AI judges against the acceptance criteria.
**Max round-trips**: GREEN ↔ VERIFY max 3. After 3 unresolved → human.

---

## REFINE — Refactor (Green maintained)

```
1. Developer AI: run /simplify
   - Three parallel agents (reuse / quality / efficiency).
   - Apply suggested fixes (no behavior change — tests must pass without modification).
   - If /simplify finds nothing, proceed to step 2 (do NOT skip).
2. [MUST] Re-run all tests → confirm Green.
   - Run even when step 1 made no changes.
   - On FAIL → revert /simplify changes → Developer AI fixes (max 2×).
3. Commit (refactor type; skip if step 1 made no changes).
```

**Why /simplify?** Removes the AI's "nothing to clean up" skip bias.
**Max retries**: 2; on second failure, abandon refactor and proceed to VALIDATE
with the Green state from VERIFY.

---

## VALIDATE — Verification Done

```
1. Automated tests: all PASS confirmed (achieved in VERIFY).
2. Minimal-implementation check: PASS confirmed (achieved in VERIFY step 3).
3. Manual checklist: list the manual scenarios (mark "delegated to user").
4. Maintained-docs check: confirm impacted docs are updated.
```

Manual items marked "delegated to user" do not block VALIDATE.

---

## AUDIT — Security Audit (independent evaluation)

After VALIDATE, run a project-specific security audit on the change. Complements
GATE:QUALITY's `Security` item with 5 dedicated, project-specific items.

**Evaluator**: fresh-spawned Evaluation AI.
**Input**: change diff + the project-specific security checklist
(`docs/security-checklist.md`).

### Scoring (5 items × 10 points)

| Item | Criterion |
|------|-----------|
| Authn/Authz       | Are auth flows on changed endpoints complete? |
| Input validation  | Are external inputs validated/escaped? |
| Data exposure     | Are tokens / passwords / PII kept out of logs and responses? |
| Infra isolation   | Are internal ports/services not exposed externally? |
| Dependencies      | No known vulnerabilities in changed external dependencies? |

- **PASS** (avg ≥ 7.5, each ≥ 7, security ≤ 3 → block) → GATE:QUALITY.
- **FAIL** → fix, re-evaluate (max 2×). Two FAILs → human.

GATE:QUALITY's `Security` item references the AUDIT result to avoid duplicate work.

---

## GATE:QUALITY — Completion Evaluation

**Evaluator**: fresh-spawned Evaluation AI.
**Input**: full change set + test results + AUDIT result.

### Scoring (10 items × 10 points)

Completeness, Quality, Test coverage, Test quality, Security (references AUDIT),
Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates.

- **PASS** (avg ≥ 7.5, each ≥ 7, security ≤ 3 → block) → DELIVER.
- **FAIL** → RED (max 3×).

---

## DELIVER — Sub-Repo Push

```
1. Each Submodule AI pushes its branch to its fork (`git push origin <branch>`).
2. Teammate shutdown — Submodule AIs report completion and stop.
3. The host's dev branch is NOT pushed yet (that happens at LAND, after sub-repo PRs are merged).
```

In single-repo deployments, DELIVER reduces to a single `git push -u origin <branch>` and the Developer AI shuts down.

---

## INTEGRATE — Integration Verification

```
1. Build all affected sub-repos in dev (e.g., docker compose -f docker-compose.dev.yml up -d --build <services>).
2. Health checks pass for each service.
3. Functional integration tests pass.
4. Cross-cutting concerns (auth, network ingress, etc.) verified.
```

In single-repo deployments, INTEGRATE runs the project-level integration test
suite (or a smoke test). Projects with no integration layer report "INTEGRATE:
no-op (single-repo / no integration suite)" — this is a registry-driven no-op,
not a discretionary skip.

**Failure**: INTEGRATE FAIL → RED (existing GREEN↔VERIFY round-trip rules apply).

---

## LAND — PR + Merge + Close

Sub-repo PRs are merged **before** the host PR is created. Squash merge changes the commit hash, so the host PR's submodule pointer must reference a commit that exists in the sub-repo's main.

```
1. Change summary (per-sub-repo changed files, commit hashes).
2. Test results report.
3. Sub-repo PRs created (each sub-repo: fork → upstream).
4. Sub-repo PRs CI passes + auto-merge (squash) confirmed.
   - gh pr view --json state,mergedAt
   - Do NOT run `gh pr merge` directly.
5. Submodule pointer bump.
   - git submodule foreach 'git checkout main && git fetch upstream && git merge upstream/main && git push origin main'
   - git add <sub-repos> && git commit (host dev branch)
   - git push -u origin dev/YYYY-MM-DD
6. Host PR created.
7. Host PR CI passes + auto-merge confirmed.
8. Git Clean Check.
9. Local deployment decision + execution + verification.
10. Completion report.
```

**[MUST]** Do NOT create the host PR before sub-repo PRs are merged.
**[MUST]** Sub-repo PR bodies use `Part of <host-org>/<host-repo>#N` (no `Closes`); only the host PR uses `Closes #N`.

In single-repo deployments, steps 3-7 collapse to: open one PR with `Closes #N`, wait for auto-merge.

### LAND failure → regression

```
Sub-repo PR (step 4) failure:
  CI failure (code issue)     → RED (existing rules apply)
  CI failure (env / transient) → CI retry, then step 4 retry (max 2)
  Merge conflict              → sub-repo branch rebase + force push → step 3 retry (max 2)
  Partial merge               → only un-merged sub-repos are re-classified

Host PR (step 7) failure:
  CI failure (code issue)     → RED (existing rules apply)
  CI failure (pointer issue)  → step 5 retry
  Merge conflict              → dev branch rebase + force push → step 6 retry (max 2)
```

**Max retries**: LAND internal retry max 2. Two failures → human.
**RED regression**: existing GREEN↔VERIFY round-trip rule (max 3) applies.

---

## Execution Principles

- **Safety first** — accurate flow execution beats fast response.
- **Verify before transition** — re-confirm completion conditions before moving on.
- **Every phase is mandatory** — no skipping based on perceived simplicity.
- **Teammate idle handling** — do not re-prompt on idle notifications; inspect the summary and wait for the report.
- **Stop on error** — do not act on errors or omissions until the situation is fully understood.

---

## See Also

- [`CLAUDE.md`](../CLAUDE.md) — single source of truth for rules.
- [`design-rationale.md`](design-rationale.md) — why every rule exists.
- [`evaluation-system.md`](evaluation-system.md) — scoring and PASS thresholds.
- [`submodule-common-rules.md`](submodule-common-rules.md) — Discussion Protocol, sub-repo rules.
- [`repo-boundary-rules.md`](repo-boundary-rules.md) — cross-repo coordination.
- [`git-workflow.md`](git-workflow.md) — bash procedures, branch structure.
