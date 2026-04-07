# Auto-Flow Guide — Step-by-Step Development Lifecycle

> Auto-Flow is a structured, evaluation-gated development lifecycle for AI-assisted software engineering with Claude Code.

---

## Overview

Auto-Flow defines **10 STEPs (0–9)** that guide every code change from issue analysis to merge. Each STEP has explicit entry/exit criteria, and an evaluation gate prevents low-quality work from reaching production.

The key principles:
- **No shortcuts** — every STEP is executed in order
- **Multi-agent separation** — different roles handle implementation, testing, and evaluation
- **Bias prevention** — 3-phase independent analysis before coding
- **Quantified quality** — 10-point evaluation with defined PASS threshold

---

## STEP 0: Issue Analysis

**Goal**: Fully understand what needs to be done before any planning or coding.

### Activities
- Read the issue/request carefully
- Identify acceptance criteria
- Clarify ambiguities (use Discussion Protocol if needed)
- Document requirements summary

### Exit Criteria
- Requirements are documented in `.autoflow-state/<issue>/requirements.md`
- All ambiguities resolved or explicitly noted as assumptions

### Common Mistakes
- Starting to code before fully understanding the issue
- Assuming requirements that aren't stated

---

## STEP 1: 3-Phase Independent Analysis

**Goal**: Prevent tunnel-vision bias by analyzing the problem from three independent perspectives.

### Phase A: Top-Down Analysis
Start from the system architecture and work downward:
- Which components are affected?
- What are the data flow implications?
- Are there cross-service impacts?

### Phase B: Bottom-Up Analysis
Start from the specific code and work upward:
- Which files/functions need to change?
- What are the direct dependencies?
- What edge cases exist at the code level?

### Phase C: Lateral Analysis
Look sideways at the existing codebase:
- Are there similar features already implemented?
- What patterns/conventions should be followed?
- Are there shared utilities to reuse?

### Exit Criteria
- All three analyses documented
- Key findings from each phase recorded
- Conflicts between phases identified

---

## STEP 2: Plan Synthesis

**Goal**: Merge the three analyses into a single, coherent implementation plan.

### Activities
- Compare findings from Phase A, B, and C
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

## STEP 3: Implementation

**Goal**: Write the code according to the approved plan.

### Activities
- Follow the implementation plan from STEP 2
- Write clean, production-quality code
- Follow existing project conventions
- Add inline comments only where logic is non-obvious

### Rules
- Stay within your assigned repository
- Do not modify code outside the plan scope
- If the plan needs adjustment, raise a Discussion before proceeding

### Exit Criteria
- Code compiles/builds successfully
- Basic functionality works as intended
- No linting errors

---

## STEP 4: Self-Review

**Goal**: The Developer AI reviews its own work before handing off to testing.

### Checklist
- [ ] Code matches the implementation plan
- [ ] No debug/temporary code left in
- [ ] No hardcoded secrets or credentials
- [ ] Error handling is appropriate (not excessive)
- [ ] Code follows existing project patterns
- [ ] No unnecessary changes outside scope

### Exit Criteria
- Self-review checklist completed
- Any issues found are fixed
- Code is ready for testing

---

## STEP 5: Testing

**Goal**: Test AI writes and runs tests to verify the implementation.

### Activities
- Write unit tests for new/changed functions
- Write integration tests if cross-component changes exist
- Run the full test suite
- Verify no existing tests are broken

### Exit Criteria
- All new tests pass
- All existing tests pass
- Test coverage for critical paths is adequate

---

## STEP 6: Evaluation

**Goal**: An independent Evaluation AI scores the work objectively.

### Process
1. Evaluation AI receives: issue requirements, implementation plan, code diff, test results
2. Scores across 5 categories (see Evaluation System)
3. Produces a JSON evaluation report

### Scoring Categories

| Category | Weight | What It Measures |
|----------|--------|-----------------|
| Correctness | 30% | Does it fulfill the requirements? |
| Code Quality | 20% | Clean, readable, maintainable? |
| Test Coverage | 20% | Critical paths tested? |
| Security | 15% | No new vulnerabilities? |
| Performance | 15% | No regressions, reasonable efficiency? |

### PASS / FAIL
- **PASS**: Overall score >= 7, no category below 5 → proceed to STEP 8
- **FAIL**: Overall score < 7 or any category below 5 → return to STEP 3

### Exit Criteria
- Evaluation report saved to `.autoflow-state/<issue>/evaluation.json`
- PASS/FAIL determination made

---

## STEP 7: Revision (Conditional)

**Goal**: Address evaluation feedback when STEP 6 results in FAIL.

### Activities
- Review evaluation comments
- Fix identified issues
- Re-run tests
- Request re-evaluation (back to STEP 6)

### Rules
- Only address issues raised in the evaluation
- Do not introduce new features during revision
- Maximum 3 revision cycles — if still failing, escalate to human

### Exit Criteria
- Fixes implemented
- Tests pass
- Ready for re-evaluation

---

## STEP 8: PR & Review

**Goal**: Create a pull request for human review.

### PR Contents
- Clear title referencing the issue
- Description with summary of changes
- Link to evaluation report
- Test results summary
- Security checklist confirmation

### Exit Criteria
- PR created and linked to issue
- All CI checks pass
- Awaiting human review

---

## STEP 9: Merge & Close

**Goal**: Human merges the PR and closes the issue.

### This Step Is Human-Only
- Human reviews the PR
- Human approves or requests changes
- If changes requested → return to STEP 7
- If approved → merge and close issue

### Exit Criteria
- PR merged to {{DEFAULT_BRANCH}}
- Issue closed
- Auto-Flow state cleaned up

---

## Regression Rules

When a STEP fails, the flow regresses to an earlier STEP:

| Failure Point | Regress To | Reason |
|--------------|-----------|--------|
| STEP 5 (tests fail) | STEP 3 | Fix implementation |
| STEP 6 (eval < 7) | STEP 3 | Significant rework needed |
| STEP 6 (eval 5-6) | STEP 7 | Minor revisions needed |
| STEP 8 (CI fails) | STEP 5 | Re-test |
| STEP 9 (human rejects) | STEP 7 | Address human feedback |

---

## State File Structure

```
.autoflow-state/
├── current-issue          # Contains: issue number
└── <issue-number>/
    ├── step               # Contains: current step number
    ├── requirements.md    # STEP 0 output
    ├── analysis/
    │   ├── phase-a.md     # Top-down analysis
    │   ├── phase-b.md     # Bottom-up analysis
    │   └── phase-c.md     # Lateral analysis
    ├── plan.md            # STEP 2 output
    ├── evaluation.json    # STEP 6 output
    └── history.log        # Step transition log
```

> **Note**: Add `.autoflow-state/` to `.gitignore` — these are working files, not committed.
