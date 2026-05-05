# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language Rule

All communication with the user must be in Korean (한글). Even if the user writes in English, always respond in Korean. Code, policies, and technical identifiers remain in English.

## What This Repo Is

A public template repository that generalizes the Auto-Flow methodology from `ontology-platform` into a reusable framework. The generalization is intentionally narrow:

1. **Name generalization** — upstream's numeric `STEP 0~9` (and sub-step `5a/5b/5c/5d/5.5/5.7`) identifiers are replaced by semantic phase names (`PREFLIGHT`, `DIAGNOSE`, `GATE:HYPOTHESIS`, `ARCHITECT`, `GATE:PLAN`, `DISPATCH`, `RED`, `GREEN`, `VERIFY`, `REFINE`, `VALIDATE`, `AUDIT`, `GATE:QUALITY`, `DELIVER`, `INTEGRATE`, `LAND`). Each generalized name maps 1:1 to an upstream STEP — no phase is added or removed.
2. **Identifier placeholders** — service-specific names like `ontology-api`, `saiso`, organization `connev-ontology`, etc. are replaced by `{{REPO_*}}`/`{{GITHUB_ORG}}` placeholders, so users instantiate them through `setup/init.sh`.

Every rule, retry cap, evaluation category, score threshold, and regression path is preserved verbatim from upstream. The methodology evolves in `ontology-platform`; this repository tracks rather than diverges.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: read access to other sub-repositories is allowed; modifications outside the assigned scope are not.
- The orchestrator's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`. The generalized form lists the orchestrator scope by placeholder; see the Repo Structure section below.
- A sub-repo AI's "own scope" is that sub-repo's directory.
- Cross-service changes are coordinated through Agent Teams (`SendMessage`).

For details, see [`docs/repo-boundary-rules.md`](docs/repo-boundary-rules.md).

## Team Structure

### AI Orchestrator (host repo)
- Does not write code directly; coordinates sub-repo AIs.
- Issue analysis, plan synthesis, role assignment, PR management, integration verification.
- Exception: project rules/configuration, infrastructure, and bulk documentation updates may be committed by the orchestrator directly.

### Evaluation AI (subagent)
- Independent evaluator that does not participate in planning or implementation.
- Bias prevention: a fresh agent is spawned every call.

#### Evaluation AI Prompt Rules
1. **[MUST]** Include in the prompt: evaluation type, instruction to consult `CLAUDE.md`, target file paths.
2. **[MUST]** Do NOT copy evaluation criteria into the prompt — instruct the AI to read `CLAUDE.md > [section]` directly.
3. **[MUST]** The orchestrator-authored portion is 5 lines or fewer (excluding target file contents).
4. **[DENY]** No opinions, interpretations, or leading phrases ("consider that ~", "note that ~", "this is ~ so").

### Test AI (testing teammate)
- Participates in plan synthesis (ARCHITECT) from a verification perspective — "how will this design be verified?"
- Authors the verification design document: acceptance criteria → verification method (automated / manual / environment-dependent / requires design change).
- Writes test code before implementation (Test First) and confirms Red.
- For untestable items: states the reason and proposes alternatives (design change / manual scenario / mock).
- Performs minimal-implementation verification after implementation: detects code outside test coverage.
- Operates independently from the Developer AI — tests are written from acceptance criteria, not from the developer's intended implementation.

### Submodule AI (per sub-repo, Developer AI)
- Understands and implements the assigned sub-repo's code.
- Writes the minimum code that passes the tests written by the Test AI (does not implement behavior outside tests).
- Has read access to other sub-repos; modifications stay within the assigned sub-repo.
- Pushes only to its fork branch (in the fork-and-PR model). PR creation is performed by the orchestrator.
- Common rules: see [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md).

In single-repo deployments (no submodules), the Submodule AI degenerates to the Developer AI working in the same repository as the orchestrator. The role contract is unchanged — only fork/upstream distinctions disappear.

## Communication — Agent Teams

Communication with sub-repo AIs uses **Agent Teams**.

- The Lead (orchestrator) runs `TeamCreate`, then spawns Teammates via `Agent` with `team_name` and `name`.
- Teammates communicate via `SendMessage` (push-based delivery).
- `SendMessage(to: "*")` broadcasts.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

### Discussion Protocol

→ Single source of truth: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Discussion Protocol

The orchestrator and sub-repo AIs follow the same rules. Core: UNDERSTAND → VERIFY → EVALUATE → RESPOND (ACCEPT / COUNTER / PARTIAL / ESCALATE). No groundless agreement, no evaluation without reading the relevant files, devil's advocate required on the first exchange.

## Development Lifecycle — Auto-Flow

When the user files an issue, the flow below executes in order. Each phase auto-transitions when its completion conditions are met. The flow only stops to wait for human input at the points explicitly marked.

**PREFLIGHT cannot be skipped.** If PREFLIGHT's completion conditions (clean Git state, remote sync) are not met, DIAGNOSE does not begin. Resolve the dirty state first and report.

```
PREFLIGHT       : Pre-Work          — Git clean check, remote sync, dirty-state cleanup, dev branch creation
DIAGNOSE        : Issue Analysis    — affected scope, hypothesis classification, lightweight verification, task decomposition, affected docs
GATE:HYPOTHESIS : Hypothesis Eval   — Evaluation AI (3 items × 10 points), bug/incident issues only
ARCHITECT       : Plan Synthesis    — Agent Teams discussion (Developer AI + Test AI), feature design + verification design
GATE:PLAN       : Plan Evaluation   — Evaluation AI (5 items × 10 points)
DISPATCH        : Task Assignment   — TaskCreate + SendMessage to Test AI and Developer AI (acceptance criteria + verification design)
RED             : Test Writing      — Test AI writes tests from acceptance criteria; Red confirmation
GREEN           : Implementation    — Developer AI writes minimum code that passes the tests
VERIFY          : Test Run + Check  — Green confirmation; on failure, branch by cause; minimal-implementation check
REFINE          : Refactor          — Developer AI cleanup; Test AI re-confirms Green
VALIDATE        : Verification Done — automated tests all PASS + manual checklist itemized + maintained docs updated
AUDIT           : Security Audit    — independent Evaluation AI (5 items × 10 points), project-specific security checklist
GATE:QUALITY    : Completion Eval   — Evaluation AI (10 items × 10 points)
DELIVER         : Sub-Repo Push     — each Submodule AI pushes its fork branch; Teammate shutdown
INTEGRATE       : Integration Test  — system build, health check, functional test (single-repo: project-level integration test)
LAND            : PR + Merge + Close — sub-repo PRs first → pointer bump → host PR → merge → Git Clean Check → local deploy
```

### Flow Control

| Transition | Condition |
|------|------|
| PREFLIGHT → DIAGNOSE | Git clean, remote sync done |
| DIAGNOSE (structure eval) → close | GATE:HYPOTHESIS structure FAIL → issue auto-closed + Auto-Flow terminated |
| DIAGNOSE (structure eval) → DIAGNOSE (cause) | GATE:HYPOTHESIS structure PASS (code change required) |
| DIAGNOSE → GATE:HYPOTHESIS (cause) | hypothesis classification + lightweight verification done (bug/incident issues) |
| DIAGNOSE → ARCHITECT | affected scope identified (feat issues — skip GATE:HYPOTHESIS cause) |
| GATE:HYPOTHESIS → ARCHITECT | cause analysis PASS + code change required |
| GATE:HYPOTHESIS → user | non-code root cause confirmed → report to user |
| ARCHITECT → GATE:PLAN | feature design + verification design agreed |
| GATE:PLAN → DISPATCH | plan evaluation PASS |
| DISPATCH → RED | task instructions delivered (Test AI starts first) |
| RED → GREEN | tests written + Red confirmed (all fail) |
| GREEN → VERIFY | implementation done |
| VERIFY → REFINE | all tests PASS + minimal-implementation check passes |
| REFINE → VALIDATE | refactor done + Green re-confirmed |
| VERIFY → GREEN | implementation issue → Developer AI re-implements |
| VERIFY → RED | test issue → Test AI fixes test → re-Red → GREEN re-entry |
| VERIFY → Evaluation AI | deadlock (both claim "no problem") → Evaluation AI arbitrates |
| VALIDATE → AUDIT | automated tests all PASS + manual checklist itemized |
| AUDIT → GATE:QUALITY | security audit PASS |
| GATE:QUALITY → DELIVER | completion evaluation PASS |
| DELIVER → INTEGRATE | sub-repo push + Teammate shutdown done |
| INTEGRATE → LAND | integration tests pass |
| LAND → done | sub-repo PRs merged → pointer bump → host PR merged → Git Clean Check → local deploy decision/verification |
| LAND → LAND (retry) | environment / transient error or merge conflict → internal retry (max 2) |
| LAND → RED | code issue (CI failure) → fix tests/implementation and re-flow |
| LAND → user | LAND internal retry exhausted (2×) |

**Regressions**: GATE:HYPOTHESIS cause FAIL → DIAGNOSE (max 2×). GATE:PLAN FAIL → ARCHITECT (max 3×). VERIFY FAIL → cause-branched fix (max 3 round-trips). REFINE FAIL → Developer AI fixes and re-runs (max 2×; on second failure, abandon refactor and proceed to VALIDATE with the Green state). AUDIT FAIL → fix and re-evaluate (max 2×). GATE:QUALITY FAIL → RED (max 3×). INTEGRATE FAIL → RED. LAND failure → cause classification: code issue → RED; environment / conflict → LAND internal retry (max 2×).
**Human escalation**: 3 regressions without pass. VERIFY deadlock unresolved by Evaluation AI arbitration → human. LAND internal retry exhausted → human.
**PR auto-creation**: at LAND, the orchestrator opens PRs and confirms auto-merge.

### PREFLIGHT — Pre-Work (auto)

Run Git Clean Check → if not clean, DIAGNOSE does not begin.

→ Procedure: see Git Workflow > Git Clean Check
→ Plus: `git checkout -b dev/YYYY-MM-DD main` (create dev branch)

### DIAGNOSE — Issue Analysis (extended)

When an issue arrives, classify cause hypotheses **before** code analysis.

```
1. Identify affected sub-repos.
2. Independent structure analysis (3-Phase).

   [AI limitation] An AI given an issue tends to focus on clearing the
   stated case and proposes code changes even when the existing structure
   already addresses the concern. To prevent this, structure analysis is
   isolated from issue analysis, and the structure-analysis AI scores the
   necessity of each proposed resolution from an architectural perspective.

   Phase A + Phase B: run in parallel.

   AI-A (structure analysis): is NOT given the issue content
     - Input: affected sub-repo + functional area (e.g., "{{REPO_BACKEND}}'s normalization pipeline").
     - Instruction: "Analyze how this area currently works — pipeline structure, design intent, data flow."
     - Output: factual description of the area as it stands.
     - [MUST] Do NOT include the issue number, title, or problem description in the prompt.
     - [MUST] Do NOT use words like "problem", "fix", "missing", "insufficient" in the prompt.

   AI-B (issue analysis): does NOT see the code
     - Input: issue body.
     - Instruction:
       1. List the concrete cases mentioned in the issue.
       2. Identify the higher-level problem type these cases share.
       3. Propose resolution approaches (what mechanism is needed).
     - Output: cases + problem types + resolution approaches.
     - [MUST] Do NOT use code search/read tools.

   Phase 3: AI-A evaluates AI-B's resolution approaches from an architectural perspective.

   The orchestrator re-spawns AI-A:
     - Input: Phase A structure analysis + AI-B's resolution list.
     - Instruction: "For each proposed resolution, evaluate whether the existing system structure already handles it."
     - [MUST] Do NOT include the issue body (only AI-B's resolution list).

   Issue type classification:
     - Type 1 (code change): bug fix, new feature, script change, pattern extension, hook change.
     - Type 2 (documentation/consistency): content sync, doc update, cross-file consistency.
     - Mixed/unclear → default to Type 1 (conservative).

   Scoring (3 items × 10 points, by issue type):

   Type 1 (code change):

   | Item | Criterion |
   |------|-----------|
   | Structural overlap     | Does the proposal duplicate an existing mechanism? (high = no overlap) |
   | Code-change necessity  | Is actual code change required, vs. data/config addition? (high = code change needed) |
   | New-mechanism necessity | Is this a new problem type the existing framework cannot handle? (high = new mechanism needed) |

   Type 2 (documentation/consistency):

   | Item | Criterion |
   |------|-----------|
   | Content gap        | Is there an actual content gap or inconsistency? (high = gap exists) |
   | Consistency impact | Does the inconsistency affect users or AI behavior? (high = significant impact) |
   | Propagation scope  | Is the change scope appropriate — not too broad, not missing targets? (high = appropriate scope) |

   PASS criteria: avg ≥ 7.5, each ≥ 7.
     - PASS → code change required → continue to step 3.
     - FAIL → existing structure handles the concern → issue auto-closed + Auto-Flow terminated.
       - Close comment records the structure-evaluation scores + summary of existing mechanisms.
       - Auto-Flow state file: active → false.
       - Re-filing as a new issue is the natural re-entry path.

3. Cause hypotheses (at least 3; "not a code bug" must be one).
   - Code bug: logic error, missing exception handling.
   - Missing data: required data is not in the data store.
   - Environment / configuration: env var missing, service not running, network.
   - External dependency: external API outage.
   - Already fixed: resolved in a recent commit.
4. Lightweight verification (when a dev environment is available):
   - API calls, queries, service status, log inspection.
   - Items that cannot be verified are marked "unverified".
5. Hypothesis verdict notes: per hypothesis, eliminated / likely / unverified, with evidence.
6. Task decomposition (only if code change is required).
7. Identify affected docs (from the maintained-docs registry).
```

**Structure-analysis bias prevention**: Phase A's information isolation prevents the AI from reading the issue and overlooking existing structure. Phase B defines the problem without code influence.

**Confirmation-bias prevention**: "the code may not be buggy" must be one hypothesis. Concluding that code change is required requires evidence that other causes have been ruled out.

### GATE:HYPOTHESIS — Hypothesis Evaluation (bug/incident issues only)

Feat issues skip this gate. Bug/incident issues only.

**Evaluator**: independent Evaluation AI (same convention as GATE:PLAN / GATE:QUALITY — fresh spawn per call).
**Input**: the orchestrator's hypothesis list + lightweight-verification results + verdict notes.

**Scoring (3 items × 10 points)**:

| Item | Criterion |
|------|-----------|
| Hypothesis diversity | Are non-code causes (data, environment, already-fixed) sufficiently considered? |
| Verification sufficiency | Was lightweight verification actually performed? Are unverified items justified? |
| Verdict evidence | Is the conclusion (code change required / not required) logically supported? |

**PASS** → ARCHITECT.
**FAIL** → DIAGNOSE (max 2×). Two FAILs → human decision.
**Non-code root cause confirmed** → report to user, pause Auto-Flow.

### ARCHITECT — Plan Synthesis (Developer AI + Test AI)

Both the Developer AI and the Test AI participate in the Agent Teams discussion.

**Roles**:
- **Developer AI**: feature design (changed files, API interface, data structures).
- **Test AI**: verification design (acceptance criteria → verification method, testability assessment).
- **Orchestrator**: discussion facilitation, agreement adjudication.

**Two output artifacts**:

1. **Feature Design Document** (Developer-AI-led): files to change, API interface, data structures, dependencies.
2. **Verification Design Document** (Test-AI-led):

   | Acceptance criterion | Verification type | Method |
   |----------------------|-------------------|--------|
   | (criterion 1) | automated | pytest / API test / etc. |
   | (criterion 2) | manual    | scenario doc (delegated to user) |
   | (criterion 3) | environment-dependent | introduce mock or propose design change |

   - For untestable items: state the reason and the alternative (design change / manual delegation / mock).
   - Design-change request: parts of the feature design that should be revised so they become testable.

**Testability-driven design**: when the Test AI flags an item as "not automatable", the team discusses whether a feature-design change makes it testable. If not, the item stays as a manual scenario with a stated reason.

**Agreement criteria**: both documents reach ACCEPT from both teammates. The Discussion Protocol applies.

### GATE:PLAN — Plan Evaluation

**Evaluator**: fresh-spawned Evaluation AI.
**Input**: feature design + verification design from ARCHITECT.

**Scoring (5 items × 10 points)**: Feasibility, Dependencies, Scope, Security, Test plan.

**PASS**: avg ≥ 7.5, each ≥ 7 → DISPATCH.
**FAIL**: → ARCHITECT (max 3×).

### DISPATCH — Task Assignment (Developer AI + Test AI)

`TaskCreate` + `SendMessage` to **both teammates**.

- **Test AI**: verification-design "automated" items → test-writing tasks.
- **Developer AI**: feature-design implementation tasks (**starts after RED is complete**).
- Both receive: acceptance criteria + verification design + affected docs.

### RED — Test Writing (Test First)

The Test AI writes test code from the verification design.

```
1. Convert acceptance criteria → test code (only items typed "automated").
2. Run tests → all must FAIL (Red).
   - A test that does not fail means the criterion is already met or the test is wrong → investigate.
3. For untestable items → write a manual verification scenario document.
4. Hand the test code + scenario document to the Developer AI.
```

**Completion**: all automated tests Red + manual scenarios written.

### GREEN — Implementation

The Developer AI writes the minimum code that passes the tests.

```
1. Read the test code authored by the Test AI.
2. Write the minimum code that passes the tests.
   - [MUST] Do NOT implement behavior not covered by tests.
3. Commit (feat/fix branch).
```

### VERIFY — Test Run + Verification

Run the tests; on failure, branch by cause.

```
1. Run all tests.
2. Branch on result:

   All PASS → step 3.

   Some FAIL → cause branching:
     The orchestrator hands the failure log + test code + implementation code to both AIs.

     Test AI:      "Does my test accurately reflect the acceptance criterion?" — self-check.
     Developer AI: "Does my implementation meet the acceptance criterion?"     — self-check.

     Collect both responses:
       ├─ Test AI says "fix the test"  → fix test → re-confirm Red → re-enter GREEN
       ├─ Developer AI says "fix impl" → fix implementation → re-run VERIFY
       ├─ Both say "fix"               → fix test first → Red → fix impl → Green
       └─ Both say "no problem"        → deadlock: Evaluation AI judges against acceptance criteria

3. Minimal-implementation check (Test AI):
   diff analysis: are there parts of the implementation diff not covered by any test?
     ├─ All covered → PASS
     ├─ Uncovered code exists → ask Developer AI to remove it, or add a test
     └─ Infrastructure / config / non-testable code → exception allowed (state reason)
```

**Deadlock resolution**: Evaluation AI judges against the acceptance criteria as the objective baseline.
**Max round-trips**: GREEN ↔ VERIFY max 3. After 3 unresolved → human.

### REFINE — Refactor (Green maintained)

```
1. Developer AI: run /simplify
   - Three parallel agents (reuse / quality / efficiency).
   - Apply the suggested fixes (no behavior change — tests must pass without modification).
   - If /simplify finds nothing, proceed to step 2 (do NOT skip).
2. [MUST] Re-run all tests → confirm Green.
   - Run even when step 1 made no changes.
   - On FAIL → revert /simplify changes → Developer AI fixes (max 2×).
3. Commit (refactor type; skip if step 1 made no changes).
```

**Why /simplify?** Removes the AI's "nothing to clean up" skip bias by mechanically analysing the code.
**Max retries**: REFINE FAIL → fix and retry max 2×. After 2×, abandon refactor and proceed to VALIDATE with the Green state from VERIFY.

### VALIDATE — Verification Done

```
1. Automated tests: all PASS confirmed (achieved in VERIFY).
2. Minimal-implementation check: PASS confirmed (achieved in VERIFY step 3).
3. Manual checklist: list the manual scenarios from the Test AI (mark "delegated to user").
4. Maintained-docs check: confirm impacted docs are updated.
```

**Verdict**: automated tests all PASS + minimal-implementation PASS + manual scenarios listed. Manual items marked "delegated to user" do not block VALIDATE.

### AUDIT — Security Audit (independent evaluation)

After VALIDATE, run a project-specific security audit on the change. Complements GATE:QUALITY's `Security` item with 5 dedicated, project-specific items.

**Evaluator**: fresh-spawned Evaluation AI.
**Input**: change diff + the project-specific security checklist (`docs/security-checklist.md`).

**Scoring (5 items × 10 points)** — items adapt to the project's threat surface; defaults below:

| Item | Criterion |
|------|-----------|
| Authn/Authz       | Are auth flows on changed endpoints complete? |
| Input validation  | Are external inputs (queries, parameters, payloads) validated/escaped? |
| Data exposure     | Are tokens / passwords / PII kept out of logs and responses? |
| Infra isolation   | Are internal ports/services not exposed externally? |
| Dependencies      | No known vulnerabilities in changed external dependencies? |

**PASS**: standard PASS criteria (avg ≥ 7.5, each ≥ 7, security ≤ 3 → immediate block).
**FAIL**: fix and re-evaluate (max 2×). Two FAILs → human.
**GATE:QUALITY linkage**: GATE:QUALITY's `Security` item references AUDIT to avoid duplicate checks.

### GATE:QUALITY — Completion Evaluation

**Evaluator**: fresh-spawned Evaluation AI.
**Input**: full change set + test results + AUDIT result.

**Scoring (10 items × 10 points)**: Completeness, Quality, Test coverage, Test quality, Security (references AUDIT), Fit, Impact scope, Minimal implementation, Commit conventions, Doc updates.

**PASS**: avg ≥ 7.5, each ≥ 7, security ≤ 3 → block → DELIVER.
**FAIL**: → RED (max 3×).

### DELIVER — Sub-Repo Push (Auto-Flow → handoff)

```
1. Each Submodule AI pushes its branch to its fork (`git push origin <branch>`).
2. Teammate shutdown — Submodule AIs report completion and stop.
3. The dev branch in the host repo is NOT pushed yet (that happens at LAND, after sub-repo PRs are merged and the pointer is bumped).
```

In single-repo deployments, DELIVER reduces to a single `git push -u origin <branch>` and the Developer AI shuts down. There is no fork distinction.

### INTEGRATE — Integration Verification

Build the system in the dev environment and verify cross-sub-repo behavior.

```
1. Build all affected sub-repos in dev (e.g., docker compose -f docker-compose.dev.yml up -d --build <services>).
2. Health checks pass for each service.
3. Functional integration tests pass.
4. Cross-cutting concerns (auth, network ingress, etc.) verified.
```

In single-repo deployments, INTEGRATE runs the project-level integration test suite (or a smoke test). Projects with no integration layer report "INTEGRATE: no-op (single-repo / no integration suite)" in the completion notes — this is a registry-driven no-op, not a discretionary skip.

**Failure**: INTEGRATE FAIL → RED (existing GREEN↔VERIFY round-trip rules apply).

### LAND — PR + Merge + Close (Auto-Flow last phase)

Sub-repo PRs are merged **before** the host PR is created. Squash merge changes the commit hash, so the host PR's submodule pointer must reference a commit that exists in the sub-repo's main.

```
1. Change summary (per-sub-repo changed files, commit hashes).
2. Test results report.
3. Sub-repo PRs created (each sub-repo: fork → upstream).
4. Sub-repo PRs CI passes + auto-merge (squash) confirmed.
   - gh pr view --json state,mergedAt
   - Do NOT run `gh pr merge` directly (the fork account lacks upstream merge permission).
5. Submodule pointer bump (reflect the squash commits).
   - git submodule foreach 'git checkout main && git fetch upstream && git merge upstream/main && git push origin main'
   - git add <sub-repos> && git commit (host dev branch)
   - git push -u origin dev/YYYY-MM-DD
6. Host PR created (the pointer now references main's squash commit).
7. Host PR CI passes + auto-merge confirmed.
   - gh pr view --json state,mergedAt
8. Git Clean Check (→ Git Workflow > Git Clean Check).
9. Local deployment decision + execution + verification.
   - Skip if no runtime impact (docs/tests-only).
   - For runtime-impacting changes: rebuild affected services, run health checks, verify external access, run feature-level verification.
10. Completion report.
```

**[MUST]** Do NOT create the host PR before sub-repo PRs are merged. Squash merge would otherwise leave the submodule pointer referencing a commit not present in the sub-repo's main, requiring an additional cleanup PR.

**[MUST]** Sub-repo PR bodies do NOT use the `Closes` keyword (sub-repo PRs merge first; using `Closes` would close the issue prematurely). Sub-repo PRs reference with `Part of {{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}#N`. Only the host PR uses `Closes #N`.

In single-repo deployments, steps 3-7 collapse to: open one PR with `Closes #N`, wait for auto-merge. Steps 5 (pointer bump) and the sub-repo/host distinction disappear.

#### LAND failure → regression

Classify the cause and regress along the matching path.

```
Sub-repo PR step (4) failure:
  CI failure (code issue)     → RED (test/impl fix, existing rules apply)
  CI failure (env / transient) → CI retry, then step 4 retry (max 2)
  Merge conflict              → sub-repo branch rebase + force push → step 3 retry (max 2)
  Partial merge (some succeeded) → only un-merged sub-repos are re-classified (already-merged PRs stay merged)
    - Detect un-merged: gh pr list --repo {{GITHUB_ORG}}/<sub-repo> --author <ACCOUNT> --state open
    - Apply the rules above to each un-merged PR

Host PR step (7) failure:
  CI failure (code issue)     → RED (existing rules apply)
  CI failure (pointer issue)  → step 5 retry (re-bump the pointer and push)
  Merge conflict              → dev branch rebase + force push → step 6 retry (max 2)
```

**Max retries**: LAND internal retry max 2. Two failures → human.
**RED regression**: existing GREEN↔VERIFY round-trip rules (max 3) apply. Already-merged sub-repo PRs are kept; new PRs are created for the fixes.
**[MUST]** Do NOT revert already-merged sub-repo PRs in a partial-merge state. Only the un-merged work is re-flowed.

### Execution Principles

- **Safety first**: accurate flow execution beats fast response. Accuracy over speed.
- **Verify before transition**: re-confirm completion conditions before moving on.
- **Every phase is mandatory**: no skipping based on perceived simplicity.
- **Teammate idle handling**: do not re-prompt on idle notifications. Inspect the summary and wait for the report.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.

### Auto-Flow State Tracking (Hook integration)

While Auto-Flow is in progress, an issue-scoped state file lives under `.autoflow/`. The hook computes pass/fail directly from `scores` to enforce gates.

**File naming**: `.autoflow/issue-{N}.json`

**Creation**: at PREFLIGHT completion.

```json
{
  "active": true,
  "issue": "#N",
  "title": "Issue title",
  "date": "YYYY-MM-DD",
  "phases": {
    "gate_hypothesis_structure": { "evaluator": "", "scores": {} },
    "gate_hypothesis_cause":     { "evaluator": "", "scores": {}, "verdict": "pending" },
    "gate_plan":                 { "evaluator": "", "scores": {} },
    "audit":                     { "evaluator": "", "scores": {} },
    "gate_quality":              { "evaluator": "", "scores": {} }
  }
}
```

**`verdict` rule** (gate_hypothesis_cause only):

| Issue type | When | `verdict` value |
|------------|------|-----------------|
| Bug / incident | Created at PREFLIGHT | `"pending"` |
| Bug / incident | After GATE:HYPOTHESIS evaluation | `"evaluated"` |
| Feat | Set at DIAGNOSE | `"skipped (feat issue)"` |

If `verdict` is empty or contains `skip`, the gate is not triggered for the cause-analysis form. Bug issues must be initialised as `"pending"` so the gate fires.

**Score recording**: write the Evaluation AI's `scores` verbatim (score + reason format).

**Hook gates** (script computes from `scores`):

- `Agent` (planning spawn) → GATE:HYPOTHESIS pass required (bug issue) or `verdict` contains `skip` (feat).
- `Agent` (test-writing spawn) → GATE:PLAN pass required.
- `Agent` (implementation spawn) → GATE:PLAN pass required.
- `git push` → AUDIT + GATE:QUALITY pass required.
- `gh pr create` → AUDIT + GATE:QUALITY pass required.

**Completion**: at LAND, set `active` to `false` (the file is preserved as history).
**Forced termination**: also set `active` to `false`.

## Evaluation System

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
| Structure evaluation | Type 1: Structural overlap, Code-change necessity, New-mechanism necessity (3) — Type 2: Content gap, Consistency impact, Propagation scope (3) | none (PASS/FAIL single verdict) |
| Hypothesis evaluation | Hypothesis diversity, Verification sufficiency, Verdict evidence (3) | max 2× |
| Plan evaluation | Feasibility, Dependencies, Scope, Security, Test plan (5) | max 3× |
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

## Git Workflow — Rules

> **Procedural details (bash, branch structure, dev cycle)**: [`docs/git-workflow.md`](docs/git-workflow.md)

### PR Wait Rule

**[MUST]** Do not start new work until the auto-merge of the previous PR is confirmed. Verified at LAND's Git Clean Check.

### Git Clean Check

Used at PREFLIGHT (entry) and LAND (completion). → see `docs/git-workflow.md` > Git Clean Check.

### Post-Merge Cleanup

Performed at LAND after the host PR is confirmed merged. → see `docs/git-workflow.md` > Post-Merge Cleanup.

**[MUST]** The submodule pointer bump happens at LAND step 5 (before the host PR is created). If a Post-Merge step ever requires an additional pointer-bump commit, that is a procedural error.

### Commit Rules

```
<type>(#<issue>): <description>

Next: <next action>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

`type`: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`.

- No direct commits to main — always branch + PR.
- No `feat`/`fix` commit while tests fail → use `wip`.
- `git status` before every commit.

### Commit Ownership

| Work type | Committer | PR opener |
|-----------|-----------|-----------|
| Feature (implementation, sub-repo) | Submodule AI (Developer)         | Orchestrator |
| Feature (tests, sub-repo)          | Test AI (sub-repo)                | Orchestrator |
| Rules / config / infra / bulk docs | Orchestrator                      | Orchestrator |

### PR Flow

**Feature (sub-repo change included)**: Submodule AI commit → push to fork → sub-repo PR created and merged (squash) → submodule pointer bump → host PR created and merged.
**Feature (host-only)**: orchestrator commit → push → PR created → auto-merge confirmed.
**Rules / infrastructure**: orchestrator direct commit → push → PR created → auto-merge confirmed.

### PR Issue Auto-Close

The host PR includes the close keyword so that merging closes the issue automatically.

```
# Host PR (merges last — closes the issue)
Closes #N

# Sub-repo PR (merges first — references only, does NOT close)
Part of {{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}#N
```

- Close keywords: `Closes`, `Fixes`, `Resolves` (case-insensitive).
- Cross-repo references are recognised in PR bodies only (commit messages do not trigger cross-repo close).
- **[MUST]** Sub-repo PRs do NOT use `Closes` — sub-repo PRs merge first, so `Closes` would prematurely close the issue.
- **[MUST]** Only the host PR uses `Closes #N`.

### Issue Management

- All issues are filed against the host repository (`{{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}`).
- Per-sub-repo issues are tracked centrally in the host (the orchestrator dispatches by role).
- Issue labels: `claude` (automation target), sub-repo name, priority.
- Forks do not host issues.

### Document Rules

- Code/policy: English.
- Markdown docs: English (source of truth).
- HTML docs: Korean (translation), if maintained.
- MD↔HTML pairs are kept in sync.
- Cross-project docs: `services/{{REPO_DOCS}}` (or analogue).
- Per-sub-repo docs: each sub-repo's `docs/`.
- Numbering convention: `00N-<name>` within the cross-project docs repo.

## Reference Documents

- **Auto-Flow phase guide**: [`docs/autoflow-guide.md`](docs/autoflow-guide.md)
- **Evaluation system**: [`docs/evaluation-system.md`](docs/evaluation-system.md)
- **Design rationale (why every rule exists)**: [`docs/design-rationale.md`](docs/design-rationale.md)
- **Git procedures**: [`docs/git-workflow.md`](docs/git-workflow.md)
- **Repo boundary rules**: [`docs/repo-boundary-rules.md`](docs/repo-boundary-rules.md)
- **Sub-repo common rules**: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md)
- **Maintained docs registry**: [`docs/maintained-docs.md`](docs/maintained-docs.md)
- **Security checklist**: [`docs/security-checklist.md`](docs/security-checklist.md)
