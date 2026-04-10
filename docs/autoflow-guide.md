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
- Ready for DIAGNOSE analysis

### Hard Stop Rule
If Git state is not clean after resolution attempts, **stop and report to user**. Do NOT proceed to DIAGNOSE. Starting work on a dirty Git state causes merge conflicts, lost changes, and broken state downstream.

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
| New Mechanism Necessity | Does this require a new type of mechanism? (high = new mechanism needed) |

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
  - **Deadlock** (both claim "no problem"): Fresh Evaluation AI arbitrates
- Minimal implementation check: verify no code exists that isn't covered by tests

### Exit Criteria
- All tests pass (Green)
- No uncovered implementation code
- Max round-trips: GREEN↔VERIFY max 3 cycles → human escalation

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
4. **[DENY]** No opinions, interpretations, or leading phrases ("consider that ~", "note that ~", "this is ~ so")

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

---

## State File Structure

```
.autoflow-state/
├── current-issue          # Contains: issue number
└── <issue-number>/
    ├── phase              # Contains: current phase name
    ├── requirements.md    # DIAGNOSE output (issue requirements)
    ├── analysis/
    │   ├── phase-a.md     # Structure analysis
    │   ├── phase-b.md     # Issue analysis
    │   └── phase-3.md     # Cross-verification
    ├── plan.md            # ARCHITECT output
    ├── delegation.md      # DISPATCH output (task assignments)
    ├── evaluation.json    # GATE:QUALITY output
    └── history.log        # Phase transition log
```

> **Note**: Add `.autoflow-state/` to `.gitignore` — these are working files, not committed.
