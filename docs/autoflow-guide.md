# Auto-Flow Guide — Phase-by-Phase Development Lifecycle

> Auto-Flow is a structured, evaluation-gated development lifecycle for AI-assisted software engineering with Claude Code.

---

## Overview

Auto-Flow defines **14 phases (PREFLIGHT → LAND)** that guide every code change from issue analysis to merge. Each phase has explicit entry/exit criteria, and an evaluation gate prevents low-quality work from reaching production.

The key principles:
- **No shortcuts** — every phase is executed in order
- **Multi-agent separation** — different roles handle implementation, testing, and evaluation
- **Bias prevention** — 3-phase independent analysis before coding
- **Quantified quality** — 10-point evaluation with defined PASS threshold

---

## PREFLIGHT: Pre-Work

**Goal**: Ensure a clean Git state before any analysis or coding begins.

### Activities
- `git status` — verify no uncommitted changes or untracked files in working area
- `git fetch origin` — sync with remote
- Resolve any dirty state (stash, commit, or discard with user approval)
- `git checkout -b <branch-type>/<issue>-<desc> main` — create feature branch from latest main

### Exit Criteria
- Git working tree is clean
- Branch created from latest main
- `intake.md` created at `.autoflow-state/<sub-repo-id>/<issue-number>/intake.md` recording the sub-repo identifier, branch, and host state location (see [design-rationale.md > Decision 10](design-rationale.md#decision-10-state-tree-is-namespaced-by-sub-repo-identifier))
- Ready for DIAGNOSE analysis

### Hard Stop Rule
If Git state is not clean after resolution attempts, **stop and report to user**. Do NOT proceed to DIAGNOSE. Starting work on a dirty Git state causes merge conflicts, lost changes, and broken state downstream.

### intake.md Format

`intake.md` is the PREFLIGHT artifact that records *where* the orchestrator anchored the work (host repo, sub-repo identifier, branch). The gate hook reads it at DIAGNOSE+ and hard-blocks if absent. The three required section headers are `## Sub-Repo`, `## Branch`, `## State Location`.

```markdown
# Intake — Issue #<issue-number>

## Sub-Repo
<sub-repo-id>

## Branch
<branch-name>

## State Location
.autoflow-state/<sub-repo-id>/<issue-number>/

## Source Issue URL
<github-issue-url>
```

---

## DIAGNOSE: 3-Phase Independent Analysis (Information Isolation)

**Goal**: Prevent tunnel-vision bias through **information isolation** — not just different perspectives, but strictly separated inputs.

> **Design rationale**: AI is biased toward solving the moment it receives an issue. If the structure-analyzing AI knows the issue, it starts looking for "structure that solves this problem" instead of seeing structure as it is. Information asymmetry is what makes cross-verification valid. See [docs/design-rationale.md](design-rationale.md) for full reasoning.

### Phase A: Structure Analysis (AI-A) — NO ISSUE CONTENT

**AI-A receives the codebase only. It does NOT receive the issue text.**

- Analyze the current code structure, architecture, and patterns
- Document how components relate and interact
- Identify structural strengths, weaknesses, and constraints
- Report factual findings about what exists

**Critical rule**: AI-A must never see the issue content. This is not optional. Giving AI-A the issue "for efficiency" destroys the core mechanism of this system.

### Phase B: Issue Analysis (AI-B) — NO CODE ACCESS

**AI-B receives the issue text only. It does NOT access the codebase.**

- Analyze the problem described in the issue
- Identify requirements, constraints, and acceptance criteria
- Propose potential resolution approaches based on the issue text alone
- It is normal for AI-B to use zero tools — analyzing only the issue text is its purpose

**Critical rule**: AI-B must not read code. If it reads code, it shares the same bias as AI-A, making Phase 3 verification purely ceremonial.

### Phase 3: Cross-Verification

**AI-A evaluates AI-B's proposed resolution from a structural perspective.**

- Does the existing structure already handle what the issue describes?
- Are AI-B's proposed approaches structurally sound?
- What are the actual code-level implications of each approach?
- Are there conflicts between what the issue asks for and what the structure supports?

- **Issue Type Classification**:
  - **Type 1 (Code)**: Bug fixes, new features, script improvements, pattern extensions, hook changes
  - **Type 2 (Documentation/Consistency)**: Content sync, template updates, cross-document consistency, prose improvements
  - **Hybrid/unclear → default to Type 1** (more conservative)

- **Scoring** (3 categories × 10 points, selected by issue type):

**Type 1 (Code) Scoring:**

| Category | Measures |
|---|---|
| Structural Overlap | Does the proposed resolution duplicate existing mechanisms? (high = no overlap) |
| Code Change Necessity | Is actual code change needed, vs. data/config addition? (high = code change needed) |
| Structural Change Necessity | Does this require structural change to existing mechanisms? (high = structural change needed — by introducing OR removing a mechanism) |

**Type 2 (Documentation/Consistency) Scoring:**

| Category | Measures |
|---|---|
| Content Gap | Does a real content gap or inconsistency exist? (high = gap exists) |
| Consistency Impact | Does the inconsistency affect users or AI behavior? (high = significant impact) |
| Propagation Scope | Is the propagation scope appropriate — not too broad, not missing targets? (high = appropriate scope) |

- **PASS** (avg >= 7.5, all >= 7): Change needed → proceed to GATE:HYPOTHESIS
- **FAIL**: Existing structure handles it → close issue with rationale

### Exit Criteria
- Phase A analysis documented (structure only, no issue awareness)
- Phase B analysis documented (issue only, no code access)
- Phase 3 cross-verification documented
- Conflicts between phases identified

---

## GATE:HYPOTHESIS: Issue Analysis Evaluation (Gate)

**Goal**: Ensure only well-analyzed issues proceed to implementation. This gate is strict because insufficient analysis at this stage causes larger costs downstream.

> **The Evaluation AI is spawned fresh** for this phase — it carries no prior conversation history. This prevents self-reinforcement bias.

### Process
1. A freshly spawned Evaluation AI receives: Phase A report, Phase B report, Phase 3 cross-verification
2. Evaluates whether the analysis is thorough enough for implementation planning
3. Produces a scored evaluation

### PASS / FAIL
- **PASS** (score >= 7.5): Proceed to ARCHITECT
- **FAIL**: **Close the issue.** If the structure already handles the concern, no code change is needed. This is not a regression — it is the system working correctly. The best code is code that is never written.

### Exit Criteria
- Evaluation report saved
- PASS → proceed to ARCHITECT
- FAIL → issue closed (existing structure sufficient)

---

## ARCHITECT: Plan Synthesis

**Goal**: Merge the three analyses into a single, coherent implementation plan.

### Activities
- Compare findings from Phase A, B, and Phase 3
- Resolve conflicts with explicit rationale
- Create a task breakdown with estimated scope
- Identify risks and mitigation strategies

### Exit Criteria
- Implementation plan documented
- Plan reviewed and approved (by orchestrator or human)
- Task breakdown clear enough for any developer to follow

### Plan Template

```markdown
## Implementation Plan — Issue #<number>

### Summary
[One-paragraph description of what will be done and why]

### Tasks
1. [Task 1] — [File(s) affected]
2. [Task 2] — [File(s) affected]
...

### Risks
- [Risk 1]: Mitigation — [...]
- [Risk 2]: Mitigation — [...]

### Analysis Conflicts Resolved
- [Conflict]: Chose [option] because [rationale]
```

---

## GATE:PLAN: Plan Evaluation

**Goal**: An independent Evaluation AI scores the implementation plan before coding begins.

> **The Evaluation AI is spawned fresh** for this phase — it carries no prior conversation history.

### Process
1. A freshly spawned Evaluation AI receives the implementation plan from ARCHITECT
2. Scores across 5 categories (Feasibility, Dependencies, Scope, Consistency, Test Plan)
3. Produces a scored evaluation

### PASS / FAIL
- **PASS** (score >= 7.5, all categories >= 7): Proceed to DISPATCH
- **FAIL**: Return to ARCHITECT (max 3 revision cycles)

### Exit Criteria
- Evaluation report saved
- PASS → proceed to DISPATCH
- FAIL → return to ARCHITECT for plan revision

---

## Orchestrator Boundaries

The orchestrator coordinates only — it does **not** implement. File-level boundaries enforce this separation:

**The orchestrator may directly modify only:**
- `CLAUDE.md`
- `CLAUDE.local.md.example`
- `.autoflow-state/` (state tracking)
- `.claude/` (hooks, settings)

**All other files require delegation to teammates:**
- Implementation code → Developer AI
- Tests → Test AI
- Documentation → Developer AI

**No exceptions.** If a file is not in the orchestrator's list above, it must go through a teammate — regardless of how simple the change appears.

For the orchestrator's five facilitator facets and four-signal-type outbound surface, see [docs/design-rationale.md > Decision 9](design-rationale.md#decision-9-orchestrator-holds-five-facilitator-facets).

---

## DISPATCH: Task Assignment

**Goal**: The orchestrator delegates implementation work to Test AI and Developer AI teammates.

### Activities
- Spawn Test AI teammate with acceptance criteria
- Spawn Developer AI teammate with implementation plan
- **[MUST]** Create delegation.md as a mandatory artifact in `.autoflow-state/<issue>/`
- Test AI starts first (RED) — Developer AI waits

### delegation.md Format

```markdown
## Team
<team-name>

## Test AI Instructions
<acceptance criteria + verification design for Test AI>

## Developer AI Instructions
<implementation plan + acceptance criteria for Developer AI>
```

### Exit Criteria
- Tasks assigned to teammates
- Test AI and Developer AI have received their instructions
- **[MUST]** delegation.md created and saved

---

## RED: Test Writing (Test AI)

**Goal**: Test AI writes tests from acceptance criteria. Tests must all FAIL (Red confirmation).

**Entry precondition**: delegation.md must exist in `.autoflow-state/<issue>/` before RED begins.

### Activities
- Convert acceptance criteria into test scripts
- Run tests — ALL must FAIL (Red confirmation)
- A test that passes means criteria already met or test is wrong
- For untestable items, write manual verification checklist

### Exit Criteria
- All tests written
- All tests FAIL (Red confirmed)
- Ready for Developer AI implementation (GREEN)

---

## GREEN: Implementation (Developer AI)

**Goal**: Developer AI writes minimum code to pass tests.

### Activities
- Read the tests from RED
- Write minimum code/content to pass tests
- Do not implement behavior not covered by tests
- Commit changes

### Exit Criteria
- Minimum implementation complete
- Ready for VERIFY

---

## VERIFY: Green Verification

**Goal**: All tests pass and implementation is minimal.

### Activities
- Run all tests
- If some fail, analyze failure cause:
  - **Test issue**: Fix test → re-Red → GREEN re-entry
  - **Implementation issue**: Fix implementation → VERIFY retry
  - **Both need fixes**: Fix test first → Red → fix impl → Green
  - **Pattern A/B/C signal observed** (self-reinterpretation, mutual-innocence after round-trip ≥ 1, or counterparty-invalidation): the Teammate that observed the signal emits `transition-request from: VERIFY to: TERMINAL:VERIFY-FAILED`; the Orchestrator spawns a fresh forensic-recorder Teammate (role marker `[role:forensic-recorder]`) which records facts to `detailed-failure-analysis.md`; the run terminates. No retry, no arbitration, no verdict.
- Minimal implementation check: verify no code exists that isn't covered by tests

### Exit Criteria
- All tests pass (Green)
- No uncovered implementation code
- Max round-trips: GREEN↔VERIFY max 3 cycles → human escalation

---

## TERMINAL:VERIFY-FAILED: Forensic Terminal Exit (Conditional)

**Goal**: When a Pattern A/B/C signal fires during VERIFY, exit fail-closed by recording the failure facts and terminating the run. No verdict is computed; no automatic re-classification occurs.

This phase replaces the previous deadlock-arbitration path (where a fresh Evaluation AI was spawned to adjudicate competing claims) with a unified fail-closed handler that covers three patterns:

- **Pattern A — self-reinterpretation**: a Teammate reframes its own RED/GREEN artifact (e.g., "should be SKIPped", "actually belongs in manual", "expected output should be interpreted differently").
- **Pattern B — mutual innocence**: both Teammates emit "no problem on my side" (or equivalent) after at least one GREEN↔VERIFY round-trip while a test still fails.
- **Pattern C — counterparty invalidation**: one Teammate claims the other's RED or GREEN artifact is wrong ("the test is wrong", "RED artifact is incorrect", "must be re-scoped").

### Trigger Detection (Teammate-Side)

When a Teammate emits a matching signal phrase while phase is VERIFY, the Teammate is responsible for also emitting the canonical `transition-request from: VERIFY to: TERMINAL:VERIFY-FAILED` in the same turn. The Orchestrator does not scan message bodies; this preserves the no-interpret-evidence invariant from Decision 8.

### Forensic-Recorder Spawn (Orchestrator-Side)

On receiving the `transition-request`, the Orchestrator:

1. Spawns a fresh **forensic-recorder Teammate** (no team, no history, role marker `[role:forensic-recorder]`).
2. The forensic-recorder writes `.autoflow-state/<sub-repo-id>/<issue>/detailed-failure-analysis.md` with the four required `##` section headers and reports completion.
3. The Orchestrator invokes `.claude/scripts/phase-set TERMINAL:VERIFY-FAILED --note "<verbatim evidence>"`.
4. The Hook validates: phase is VERIFY, the artifact exists and contains the four required headers. If valid, the phase write proceeds; the run is over.

The forensic-recorder is **not** an arbitrator. It records facts only — verdicts, recommendations, scoring numbers, and "next steps" are forbidden contents.

### detailed-failure-analysis.md schema

| Section | Content |
|---------|---------|
| `## Pattern Classification` | One of `self-reinterpretation`, `mutual-innocence`, `counterparty-invalidation`. For `self-reinterpretation` only, a sub-classification line is required: `SKIP attempt`, `manual-checklist relocation`, `expected-behavior redefinition`, `test-invalidation claim`, or `other`. |
| `## Triggering Message` | Verbatim message body and sender identity (Test AI / Developer AI). No paraphrase. |
| `## Failing Test Output` | Verbatim runner stdout/stderr for the failing test, plus the test identifier. |
| `## RED Decision Basis` | Excerpt from `delegation.md` (or the AC list) that justified the original RED artifact. |

### Worked Example — Pattern A: Test AI tries to SKIP its own AC after VERIFY fails

#### Setup

- Issue #99 is in VERIFY. Test AI authored AC 3 in `delegation.md`, asserting that `script foo --bar` exits 0.
- Developer AI implemented `foo`, which exits 1 due to an input-validation guard.
- The VERIFY test for AC 3 fails.

#### Trigger event

Test AI sends to the Orchestrator:

```
@test-ai → @orchestrator
Reviewing AC 3 against the implementation: this assertion should be SKIPped
because the script's exit-1 guard is the by-design fail-safe.

@orchestrator transition-request
from: VERIFY
to: TERMINAL:VERIFY-FAILED
evidence: .autoflow-state/self/99/detailed-failure-analysis.md
```

The phrase "should be SKIPped" combined with the VERIFY phase and Test AI being the original author of AC 3 satisfies Pattern A's guards.

#### Forensic artifact (excerpt of detailed-failure-analysis.md)

```markdown
## Pattern Classification
self-reinterpretation
sub-classification: SKIP attempt

## Triggering Message
sender: test-ai
body: "this assertion should be SKIPped because the script's exit-1 guard is
       the by-design fail-safe."

## Failing Test Output
test_id: AC3 (tests/test-issue-99.sh::ac3_foo_exits_zero)
stdout/stderr:
  + foo --bar
  foo: input validation failed: --bar requires a value
  AssertionError: expected exit 0 got 1

## RED Decision Basis
delegation.md (Test AI Instructions, AC 3): "Running `foo --bar` against a
clean fixture must exit 0. The script must succeed on the documented
default-input case."
```

#### Out-of-band resolution

The human reads `detailed-failure-analysis.md`, decides whether AC 3 was mis-scoped (revise the issue body) or whether the implementation truly violates the contract (re-open with corrected delegation), and re-runs Auto-Flow from PREFLIGHT. The forensic-recorder makes no such determination.

### Worked Example — Pattern B: Both Teammates claim "no problem on my side" after round-trip 1

#### Setup

- Issue #100 is in VERIFY for the second time (one prior GREEN↔VERIFY round-trip recorded in `history.log`).
- A test for AC 5 fails: the function returns `null` where the test expects `[]`.
- Test AI says the test is correct; Developer AI says the implementation is correct.

#### Trigger event

Within the current VERIFY entry:

```
@dev-ai → @orchestrator
Re-checked the implementation; no problem on my side.

@test-ai → @orchestrator
Re-ran the assertion; nothing to fix on my side.

@orchestrator transition-request
from: VERIFY
to: TERMINAL:VERIFY-FAILED
evidence: .autoflow-state/self/100/detailed-failure-analysis.md
```

Both Teammates have emitted the Pattern B phrase since the most recent `*->VERIFY` line in `history.log`, and the round-trip count is ≥ 1. Guards satisfied. The forensic-recorder is spawned (NOT an arbitration Evaluation AI).

#### Forensic artifact (excerpt of detailed-failure-analysis.md)

```markdown
## Pattern Classification
mutual-innocence

## Triggering Message
sender: dev-ai
body: "Re-checked the implementation; no problem on my side."

sender: test-ai
body: "Re-ran the assertion; nothing to fix on my side."

## Failing Test Output
test_id: AC5 (tests/test-issue-100.sh::ac5_returns_empty_list)
stdout/stderr:
  Expected: []
  Actual:   null

## RED Decision Basis
delegation.md (Test AI Instructions, AC 5): "On the empty-input path, the
function must return an empty list (`[]`). A null return is a contract
violation."
```

#### Out-of-band resolution

The human reads the artifact and decides whether the contract should be relaxed to allow `null`, whether the implementation should normalize `null` to `[]`, or whether the AC needs to be split into two separate cases. Auto-Flow is re-entered from PREFLIGHT after the issue body is updated. The forensic-recorder issued no verdict; the previous "Evaluator arbitrates" path is no longer available.

### Exit Criteria
- `detailed-failure-analysis.md` written by the fresh forensic-recorder Teammate
- All four required `##` section headers present (Hook-verified)
- Phase set to `TERMINAL:VERIFY-FAILED`
- Run terminated; no retry

---

## REFINE: Refactor

**Goal**: Code cleanup without changing behavior. Tests must pass without modification.

### Activities
- Developer AI runs `/simplify` (automatically analyzes reuse, quality, and efficiency with 3 parallel agents)
- Applies suggested fixes (no behavior change — tests must pass without modification)
- If `/simplify` finds nothing → proceed to re-run (DO NOT SKIP)
- **[MUST]** Re-run ALL tests → Green maintained
  - This phase is NEVER skipped, even when `/simplify` made no changes
  - "No changes were made so tests will pass" is not a valid reason to skip
  - The re-run confirms that no accidental state changes occurred between VERIFY and REFINE
- If simplify breaks tests → revert changes, fix (max 2 attempts, then keep pre-refactor state)
- Commit (refactor type, or skip commit if no changes)

**Why /simplify?** Manual "refactoring needed?" judgment was routinely skipped. `/simplify` removes this bias by mechanically analyzing the code.

### Exit Criteria
- `/simplify` analysis completed (changes applied or "nothing found" documented)
- **[MUST]** All tests re-run and still pass (Green maintained)
- Ready for evaluation

---

## Evaluation AI Prompt Rules

When spawning the Evaluation AI (at GATE:HYPOTHESIS, GATE:PLAN, and GATE:QUALITY), the orchestrator's prompt must follow these rules:

1. **[MUST]** Include: evaluation type, `CLAUDE.md > [section]` reference, target file paths
2. **[MUST]** Do NOT copy evaluation criteria into the prompt — instruct the AI to read CLAUDE.md directly
3. **[MUST]** Orchestrator-written portion must be 5 lines or fewer (excluding target file contents)
4. **[MUST]** State observations as direct facts — cite file paths and line numbers. Prohibited forms: "consider that ~", "note that ~", "this is ~ so".

---

## GATE:QUALITY: Evaluation

**Goal**: An independent Evaluation AI scores the work objectively.

> **The Evaluation AI is spawned fresh** for every evaluation — it carries no prior conversation history. This is mandatory. Reusing an evaluation agent creates self-reinforcement bias. See [docs/design-rationale.md](design-rationale.md#decision-2-evaluation-ai-is-spawned-fresh-every-time).

### Process
1. A **freshly spawned** Evaluation AI receives: issue requirements, implementation plan, code diff, test results
2. Scores across 5 categories (see Evaluation System)
3. Produces a JSON evaluation report

### Scoring Categories

| Category | Weight | What It Measures |
|----------|--------|-----------------|
| Correctness | 25% | Does it fulfill the requirements? |
| Quality | 20% | Clean, readable, maintainable? |
| Test Coverage | 20% | Critical paths tested? |
| Consistency | 20% | Aligned with design-rationale.md principles? |
| Documentation | 15% | Docs updated, links valid, examples accurate? |

### PASS / FAIL
- **PASS**: Overall weighted score >= 7.5 AND no individual category below 7 → proceed to SHIP
- **FAIL**: Overall score < 7.5 OR any category below 7 → return to REVISION (or GATE:PLAN for major issues)
- **AUTO-FAIL**: Consistency score <= 3 → DISPATCH (mandatory rework regardless of other scores)

### Exit Criteria
- Evaluation report saved to `.autoflow-state/<issue>/evaluation.json`
- PASS/FAIL determination made

---

## REVISION: Revision (Conditional)

**Goal**: Address evaluation feedback when GATE:QUALITY results in FAIL.

### Activities
- Review evaluation comments
- Fix identified issues
- Re-run tests
- Request re-evaluation (back to GATE:QUALITY)

### Rules
- Only address issues raised in the evaluation
- Do not introduce new features during revision
- Maximum 3 revision cycles — if still failing, escalate to human

### Exit Criteria
- Fixes implemented
- Tests pass
- Ready for re-evaluation

---

## SHIP: PR & Review

**Goal**: Create a pull request for human review.

### PR Contents
- Clear title referencing the issue
- Description with summary of changes
- Link to evaluation report
- Test results summary
- Consistency with design-rationale.md confirmed

### Exit Criteria
- PR created and linked to issue
- All CI checks pass
- Awaiting human review

---

## LAND: Merge & Close

**Goal**: Human merges the PR and closes the issue.

### This Phase Is Human-Only
- Human reviews the PR
- Human approves or requests changes
- If changes requested → return to REVISION
- If approved → merge and close issue

### Exit Criteria
- PR merged to {{DEFAULT_BRANCH}}
- Issue closed
- Auto-Flow state cleaned up

---

## Regression Rules

When a phase fails, the flow regresses — or terminates:

| Failure Point | Action | Reason |
|--------------|--------|--------|
| GATE:HYPOTHESIS (structure eval FAIL) | **Close issue** | Existing structure already handles it |
| GATE:PLAN (plan eval FAIL) | → ARCHITECT (max 3x) | Plan revision needed |
| GREEN↔VERIFY cycle (tests fail) | → GREEN (max 3 round-trips) | Fix implementation or tests |
| REFINE (refactor breaks tests) | Fix (max 2 attempts) | Keep pre-refactor state |
| GATE:QUALITY (score < 7.5) | → REVISION | Revision needed |
| GATE:QUALITY (consistency <= 3) | → DISPATCH | Mandatory major rework |
| SHIP (CI fails) | → RED | Re-test |
| LAND (human rejects) | → REVISION | Address human feedback |
| TERMINAL:VERIFY-FAILED | **Run terminates** (0 retries) | Forensic-recorder wrote `detailed-failure-analysis.md`; human reads it and revises issue body before re-running |

---

## State File Structure

`.autoflow-state/` lives in the orchestrator's host repo working tree only — never in a sub-repo. The layout is uniformly namespaced by sub-repo identifier; single-repo deployments use `self`. See [design-rationale.md > Decision 10](design-rationale.md#decision-10-state-tree-is-namespaced-by-sub-repo-identifier).

```
.autoflow-state/                                # in host repo only
├── current-issue                               # contains: <sub-repo-id>/<issue-number>
└── <sub-repo-id>/                              # e.g., autoflow-upstream, or "self"
    └── <issue-number>/
        ├── phase                               # current phase name
        ├── intake.md                           # PREFLIGHT artifact (sub-repo, branch, state location)
        ├── requirements.md                     # DIAGNOSE output (issue requirements)
        ├── analysis/
        │   ├── phase-a.md                      # Structure analysis
        │   ├── phase-b.md                      # Issue analysis
        │   └── phase-3.md                      # Cross-verification
        ├── plan.md                             # ARCHITECT output
        ├── delegation.md                       # DISPATCH output (task assignments)
        ├── evaluation.json                     # GATE:QUALITY output
        └── history.log                         # Phase transition log
```

> **Note**: Add `.autoflow-state/` to `.gitignore` — these are working files, not committed. `current-issue` is a single line of the form `<sub-repo-id>/<issue-number>`. Legacy bare-integer values (e.g., `42`) are honored as `self/42` for backward compatibility; new issues should use the slash-qualified form.
