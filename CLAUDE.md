# Claude AutoFlow Template — Claude Code Operating Manual

This file is the single source of truth for how Claude Code operates in this repository.

**Read [docs/design-rationale.md](docs/design-rationale.md) FIRST.**
It explains _why_ every rule exists. Understanding design intent takes priority over following rules.

---

## What This Repo Is

A public template repository that generalizes the Auto-Flow methodology from `ontology-platform` into a reusable framework. This repo contains **templates, documentation, and shell scripts** — no application services.

### Key Files

| File | Role |
|------|------|
| `CLAUDE.md.template` | Core template users will generate CLAUDE.md from |
| `docs/design-rationale.md` | Design philosophy — why every rule exists |
| `docs/autoflow-guide.md` | Step-by-step Auto-Flow lifecycle |
| `.claude/hooks/check-autoflow-gate.sh` | Hook script enforcing evaluation gates |
| `setup/init.sh` | Interactive project setup wizard |
| `subrepo-templates/` | Sub-repo CLAUDE.md templates |
| `docs/*.md` | Supporting documentation |

### What Changes Look Like

- **Template changes**: `CLAUDE.md.template`, `subrepo-templates/`
- **Process logic**: `docs/autoflow-guide.md`, `docs/evaluation-system.md`
- **Tooling**: `check-autoflow-gate.sh`, `init.sh`
- **Documentation**: `README.md`, `docs/*.md`

---

## Language Rule

All communication with the user must be in Korean. Code, documentation content, and technical identifiers remain in English.

---

## Auto-Flow Lifecycle (STEP 0-9)

This project follows Auto-Flow with Agent Teams. Even though this is a single repo, **the orchestrator does not implement**. The orchestrator coordinates, and spawns teammates to do the actual work.

### Agent Roles

| Role | How | Constraint |
|------|-----|-----------|
| **Orchestrator** | Main session (you) | Coordinates only — does NOT write code, tests, or templates |
| **Test AI** | Teammate (`Agent` with `team_name`) | Writes tests from acceptance criteria (STEP 5a) |
| **Developer AI** | Teammate (`Agent` with `team_name`) | Writes minimum code to pass tests (STEP 5b) |
| **Evaluation AI** | Fresh `Agent` (no team, no history) | Scores work at STEPs 1.5, 3, 6 — **spawned fresh every time** |

### Orchestrator Boundaries

The orchestrator may **directly modify** only these files:
- `CLAUDE.md`
- `CLAUDE.local.md.example`
- `.autoflow-state/` (state tracking)
- `.claude/` (hooks, settings)

All other files require delegation to teammates:
- `CLAUDE.md.template` → Developer AI
- `setup/` → Developer AI
- `subrepo-templates/` → Developer AI
- `tests/` → Test AI
- `docs/` → Developer AI
- `README.md`, `LICENSE` → Developer AI

**No exceptions.** The previous "documentation bulk updates" exception was removed because it allowed the orchestrator to bypass delegation for nearly any file. If a file is not in the orchestrator's list above, it must go through a teammate — regardless of how simple the change appears.

### Communication — Agent Teams

```
Orchestrator → TeamCreate (team for this issue)
Orchestrator → Agent (team_name, name="test-ai")   : spawn Test AI teammate
Orchestrator → Agent (team_name, name="dev-ai")     : spawn Developer AI teammate
Orchestrator → SendMessage (to teammates)           : task instructions + acceptance criteria
Teammates   → SendMessage (to orchestrator)         : status reports, questions
Orchestrator → Agent (fresh, no team)               : spawn Evaluation AI (independent)
```

All teammates work on the **same repository** (single repo — no submodule navigation needed).

### STEP Definitions

```
STEP 0: Pre-Work         → Git Clean Check, branch creation
STEP 1: Issue Analysis    → 3-Phase independent analysis (bias prevention)
STEP 1.5: Structure Eval  → Evaluation AI (fresh spawn): PASS → continue, FAIL → close issue
STEP 2: Plan Synthesis    → Merge analyses into implementation plan + acceptance criteria
STEP 3: Plan Evaluation   → Evaluation AI (fresh spawn): 5 categories × 10 points
STEP 4: Task Assignment   → TeamCreate + SendMessage to Test AI and Developer AI
STEP 5a: Test Writing     → Test AI writes tests → Red confirmation
STEP 5b: Implementation   → Developer AI writes minimum code to pass tests
STEP 5c: Green + Verify   → All tests pass + minimal implementation check
STEP 5d: Refactor         → Developer AI code cleanup, Green re-confirmation
STEP 6: Evaluation        → Evaluation AI (fresh spawn): scored quality assessment
STEP 7: Revision          → Fix evaluation feedback (if STEP 6 FAIL)
STEP 8: PR & Review       → Create PR for human review
STEP 9: Merge & Close     → Human approves and merges
```

### Execution Principles

1. **Never skip steps.** Every STEP executes regardless of change size. "This one is simple" is itself a biased judgment.
2. **STEP 0 is mandatory.** If Git state is not clean, STEP 1 does not begin.
3. **STEP 1.5 FAIL = issue close.** Existing structure handles the concern — no code change needed.
4. **Orchestrator does not implement.** The orchestrator coordinates — teammates do the work.
5. **Evaluator is always fresh.** Never reuse an evaluation agent — self-reinforcement bias.
6. **All loops terminate.** Every retry has a maximum count and human escalation point.
7. **Pipeline is stateless.** Past evaluations do not influence current analysis.

---

## Flow Control

| Current State | Condition | Next State |
|---|---|---|
| STEP 0 | Git clean, branch created | → STEP 1 |
| STEP 1 | 3 isolated analyses done | → STEP 1.5 |
| STEP 1.5 PASS | Score >= 7.5 | → STEP 2 |
| STEP 1.5 FAIL | Existing structure sufficient | → **Issue closed** |
| STEP 2 | Plan documented | → STEP 3 |
| STEP 3 PASS | Score >= 7.5, all >= 7 | → STEP 4 |
| STEP 3 FAIL | Below threshold | → STEP 2 (max 3x) |
| STEP 4 | Tasks assigned to teammates | → STEP 5a |
| STEP 5a | Tests written, all Red | → STEP 5b |
| STEP 5b | Minimum implementation done | → STEP 5c |
| STEP 5c PASS | All Green + minimal impl check | → STEP 5d |
| STEP 5c FAIL (test issue) | Test incorrect | → STEP 5a (fix test → re-Red) |
| STEP 5c FAIL (impl issue) | Implementation incorrect | → STEP 5b (fix impl) |
| STEP 5c DEADLOCK | Both claim "no problem" | → Evaluation AI arbitrates |
| STEP 5d | Refactor done, Green maintained | → STEP 6 |
| STEP 6 PASS | Score >= 7.5, all >= 7 | → STEP 8 |
| STEP 6 FAIL | Below threshold | → STEP 7 |
| STEP 6 AUTO-FAIL | Consistency <= 3 | → STEP 4 (major rework) |
| STEP 7 | Revisions done | → STEP 6 (re-eval, max 3x) |
| STEP 8 | PR created | → STEP 9 (human) |
| STEP 9 | Merged | → Done |

### Regression Rules

| Failure | Max Retries | Escalation |
|---|---|---|
| STEP 1.5 FAIL | 0 | Issue closed (by design) |
| STEP 3 FAIL | 3 → STEP 2 | Human intervention |
| STEP 5b↔5c cycle | 3 round-trips | Human intervention |
| STEP 5d FAIL | 2 | Skip refactor, keep Green state |
| STEP 6 FAIL | 3 → STEP 7 | Human intervention |

---

## STEP 0: Pre-Work

**[MUST]** Git Clean Check before any work begins.

```
0-1. git status — no uncommitted changes, no untracked files in working area
0-2. git fetch origin — sync with remote
0-3. Resolve any dirty state (stash, commit, or discard with user approval)
0-4. git checkout -b <branch-type>/<issue>-<desc> main
```

If Git state is not clean after 0-3, stop and report to user. Do NOT proceed to STEP 1.

---

## STEP 1: 3-Phase Independent Analysis

> **Why information isolation?** See [docs/design-rationale.md](docs/design-rationale.md#decision-1-ai-a-does-not-receive-the-issue-content-3-phase-independent-analysis)

### Phase A: Structure Analysis (AI-A) — DOES NOT SEE THE ISSUE

Spawn a fresh agent. Give it only the affected file area, NOT the issue content.

- **Input**: File/directory name + functional area (e.g., "the init.sh setup wizard")
- **Instruction**: "Analyze how this area currently works — structure, data flow, design intent"
- **Output**: Factual description of what exists
- **[MUST]** Do not include issue number, title, or problem description in the prompt
- **[MUST]** Do not use words like "problem," "fix," "missing," "insufficient" in the prompt

### Phase B: Issue Analysis (AI-B) — DOES NOT SEE THE CODE

Spawn a fresh agent. Give it only the issue text, NO code access.

- **Input**: Issue body text
- **Instruction**: List concrete cases, identify the higher-level problem type, propose resolution approaches
- **Output**: Cases + problem types + resolution approaches
- **[MUST]** Do not use code search/read tools

### Phase 3: Cross-Verification

Spawn AI-A again with Phase A results + AI-B's resolution approaches.

- **Input**: Phase A structure analysis + AI-B resolution list (NOT the issue text)
- **Instruction**: "Evaluate whether each proposed resolution is already handled by existing structure"
- **Scoring** (3 categories × 10 points):

| Category | Measures |
|---|---|
| Structural Overlap | Does the proposed resolution duplicate existing mechanisms? (high = no overlap) |
| Code Change Necessity | Is actual code change needed, vs. data/config addition? (high = code change needed) |
| New Mechanism Necessity | Does this require a new type of mechanism? (high = new mechanism needed) |

- **PASS** (avg >= 7.5, all >= 7): Code change needed → proceed to STEP 1.5
- **FAIL**: Existing structure handles it → close issue with rationale

---

## STEP 2: Plan Synthesis

Merge Phase A, B, and 3 into an implementation plan.

**Output**:
- Changed files list
- Approach description
- Risk identification
- Acceptance criteria (testable statements)

---

## STEP 3: Plan Evaluation

**Evaluator**: Fresh-spawned Evaluation AI.

**Input**: Implementation plan from STEP 2.

**5 categories × 10 points**:

| Category | Measures |
|---|---|
| Feasibility | Can this plan be implemented with the current structure? |
| Dependencies | Are affected files and side effects identified? |
| Scope | Appropriate — not too broad, not missing requirements? |
| Consistency | Does this align with design-rationale.md principles? |
| Test Plan | Are acceptance criteria testable? |

**PASS**: avg >= 7.5, all >= 7 → STEP 4.
**FAIL**: → STEP 2 (max 3x).

---

## STEP 4: Task Assignment

The orchestrator creates a team and spawns teammates to execute the plan.

```
4-1. TeamCreate — create a team for this issue
4-2. Spawn Test AI teammate (Agent with team_name, name="test-ai")
     - SendMessage: acceptance criteria + verification design
     - Instruction: "Write tests for these acceptance criteria. Do NOT implement."
4-3. Spawn Developer AI teammate (Agent with team_name, name="dev-ai")
     - SendMessage: implementation plan + acceptance criteria
     - Instruction: "Wait for Test AI to complete tests (STEP 5a). Then implement minimum code to pass."
4-4. Both teammates receive: plan.md, acceptance criteria, affected files list
```

**[MUST]** Test AI starts first (STEP 5a). Developer AI waits until tests are written and Red-confirmed.
**[MUST]** The orchestrator does not write code — it sends instructions and monitors progress.

---

## STEP 5a-5d: Test-Driven Development Cycle

### What Is Testable in This Project

| Change Type | Testable? | Method |
|---|---|---|
| `init.sh` | Yes | Shell script test: run with mock inputs, verify output files |
| `check-autoflow-gate.sh` | Yes | Shell script test: mock `.autoflow-state/` JSON, verify exit codes |
| Placeholder completeness | Yes | `grep -r '{{' .` after init.sh run — must return empty |
| Template syntax | Yes | Validate generated CLAUDE.md has no broken markdown |
| Documentation content | Partial | Verify internal links resolve, code blocks are valid |
| Pure prose changes | No | Skip TDD cycle, proceed directly to STEP 6 evaluation |

### STEP 5a: Test Writing (Test AI)

Test AI teammate writes tests from acceptance criteria.

```
5a-1. Convert acceptance criteria → test scripts (tests/ directory)
5a-2. Run tests → ALL must FAIL (Red confirmation)
      - A test that passes means criteria already met or test is wrong
5a-3. For untestable items → write manual verification checklist
5a-4. Report to orchestrator: "Tests written, Red confirmed"
```

### STEP 5b: Implementation (Developer AI)

Developer AI teammate writes minimum code to pass tests. This is the **only** step where implementation code is written.

```
5b-1. Read the tests from 5a
5b-2. Write minimum code/content to pass tests
      - [MUST] Do not implement behavior not covered by tests
      - [MUST] Do not write code before 5a tests exist — that defeats Test First
5b-3. Commit (feat/fix branch)
5b-4. Report to orchestrator: "Implementation complete"
```

### STEP 5c: Green Verification

```
5c-1. Run all tests
5c-2. Results:

  All PASS → 5c-3

  Some FAIL → Failure cause analysis:
    ├─ Test issue → fix test → re-Red → STEP 5b re-entry
    ├─ Implementation issue → fix implementation → STEP 5c retry
    ├─ Both need fixes → fix test first → Red → fix impl → Green
    └─ Deadlock (both claim "no problem") → fresh Evaluation AI arbitrates

5c-3. Minimal implementation check:
    Diff analysis: is there code NOT covered by any test?
    ├─ All covered → PASS
    ├─ Uncovered code exists → remove or add test
    └─ Config/infra changes → exception allowed (document reason)
```

**Max round-trips**: STEP 5b↔5c max 3 cycles → human escalation.

### STEP 5d: Refactor

```
5d-1. Refactoring needed?
      ├─ Yes → code cleanup (no behavior change) → 5d-2
      └─ No  → document reason ("no cleanup needed") → 5d-2 (DO NOT SKIP)
5d-2. [MUST] Re-run ALL tests → Green maintained
      - This step is NEVER skipped, even when 5d-1 found nothing to refactor
      - FAIL → refactor broke something → fix (max 2 attempts, then keep pre-refactor state)
5d-3. Commit (refactor type, or skip commit if no changes in 5d-1)
```

**[MUST]** 5d-2 is mandatory. "No changes were made so tests will pass" is not a valid reason to skip. The re-run confirms that no accidental state changes occurred between STEP 5c and 5d.

### Pure Documentation Changes

When the change is purely prose (no scripts, no templates with placeholders):
- Skip STEP 4, 5a-5d entirely
- Orchestrator delegates the writing to a teammate, then proceed to STEP 6
- Document the skip reason: "Pure prose change — no testable behavior"

---

## Evaluation System

### 10-Point Scale

| Score | Meaning | Action |
|---|---|---|
| 9-10 | Excellent | Proceed |
| 7-8 | Good | Proceed |
| 5-6 | Insufficient | Rework recommended |
| 3-4 | Poor | Rework required |
| 1-2 | Failing | Redesign |

### PASS Criteria

- **[MUST]** Average >= 7.5
- **[MUST]** Every individual category >= 7
- **[MUST]** Consistency (design principles) <= 3 → automatic FAIL

### STEP 6 Evaluation Categories

| Category | Weight | Description |
|---|---|---|
| Correctness | 25% | Does it fulfill the issue requirements? |
| Quality | 20% | Clean, readable, consistent with existing style? |
| Test Coverage | 20% | Are testable behaviors covered? |
| Consistency | 20% | Aligned with design-rationale.md principles? |
| Documentation | 15% | Are docs updated, links valid, examples accurate? |

**Why "Consistency" replaces "Security"**: This is a template project. The critical risk is not security vulnerabilities but **violating core design principles** (e.g., giving AI-A the issue content "for efficiency"). Consistency scoring catches this.

**Consistency <= 3 → AUTO-FAIL**: If a change undermines a core principle from design-rationale.md, it must be reworked regardless of other scores.

### Evaluation Output Format

```json
{
  "step": 6,
  "issue": "#N",
  "evaluator": "evaluation-ai",
  "scores": {
    "correctness": { "score": 8, "reason": "..." },
    "quality": { "score": 7, "reason": "..." },
    "test_coverage": { "score": 7, "reason": "..." },
    "consistency": { "score": 9, "reason": "..." },
    "documentation": { "score": 8, "reason": "..." }
  }
}
```

The Hook calculates pass/fail from raw `scores` — it does NOT trust AI's `pass` field.

---

## Discussion Protocol

When ambiguity or disagreement arises:

### Process

```
1. UNDERSTAND — Read and comprehend the claim
2. VERIFY    — Check against actual files/data (mandatory — cannot evaluate without reading)
3. EVALUATE  — Form judgment with evidence
4. RESPOND   — One of:
   - ACCEPT: with specific evidence (no groundless agreement)
   - COUNTER: with alternative + evidence
   - PARTIAL: accept parts, counter others
   - ESCALATE: to human with context
```

### Rules

- **No agreement without evidence.** "That sounds right" is not ACCEPT. Cite specific files or data.
- **First exchange devil's advocate.** On the first interaction about a proposal, include at least one counter-argument. This prevents premature consensus.
- **Cannot evaluate without reading.** Opinions about code/templates require having read the relevant files.

---

## Hook Gate

The `check-autoflow-gate.sh` hook enforces STEP progression:

- **Trigger**: Before commit or PR creation
- **Checks**: Calculates scores from raw `scores` in evaluation JSON
- **Does NOT trust**: AI-generated `pass` field — computes independently
- **State files**: `.autoflow-state/` directory

### Gate Points

| Action | Requires |
|---|---|
| Commit (STEP 6+) | Evaluation PASS |
| PR creation | Evaluation PASS |
| STEP 0-5 commits | No gate restriction |
| STEP 7 commits | Allowed (revision in progress) |

---

## Git Workflow

### Branch Naming

```
feature/<issue>-<description>
fix/<issue>-<description>
docs/<issue>-<description>
chore/<issue>-<description>
```

### Commit Format

```
<type>(#<issue>): <description>

[optional body — explain WHY, not WHAT]

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`

### Rules

- **No direct commits to main.** Always branch + PR.
- **No commits with failing tests** (use `wip` type if needed).
- **`git status` before every commit.**
- **PR closes issue**: PR body includes `Closes #N`.

### Git Clean Check (STEP 0 and STEP 9)

```bash
# 1. No uncommitted changes
git status  # must be clean

# 2. Synced with remote
git fetch origin
git log HEAD..origin/main --oneline  # must be empty or handled

# 3. Branch from latest main
git checkout -b <branch> main
```

---

## Auto-Flow State Tracking

State files in `.autoflow-state/` track progress per issue.

**File structure**:
```
.autoflow-state/
├── current-issue          # Contains: issue number
└── <issue-number>/
    ├── step               # Current STEP number
    ├── requirements.md    # STEP 0-1 output
    ├── analysis/
    │   ├── phase-a.md     # Structure analysis
    │   ├── phase-b.md     # Issue analysis
    │   └── phase-3.md     # Cross-verification
    ├── plan.md            # STEP 2 output
    ├── evaluation.json    # STEP 6 output
    └── history.log        # STEP transition log
```

**Creation**: STEP 0 completion.
**Completion**: STEP 9 → clean up or archive.
**`.gitignore`**: `.autoflow-state/` must be gitignored.

---

## Maintained Documents

Changes to any of these files require checking if related documents need updating:

| Document | Update When |
|---|---|
| `CLAUDE.md` | This file — process rules change |
| `CLAUDE.md.template` | Template for users — process/placeholder changes |
| `docs/design-rationale.md` | New design decisions or principle changes |
| `docs/autoflow-guide.md` | STEP definitions change |
| `docs/evaluation-system.md` | Scoring categories or thresholds change |
| `README.md` | Features, structure, or usage changes |
| `setup/SETUP-GUIDE.md` | Setup procedure changes |

### Consistency Rule

When `CLAUDE.md.template` changes, verify that `docs/autoflow-guide.md` and `docs/evaluation-system.md` remain consistent. These three files describe the same system — contradictions break user trust.

---

## Project-Specific Rules

### Design Rationale Is Sacred

`docs/design-rationale.md` documents **why** every rule exists. Changes to this file require:

1. Explicit justification for why the existing rationale is wrong or incomplete
2. Evidence from actual usage (not theoretical improvement)
3. STEP 6 evaluation with Consistency score >= 8

### Template Changes Require User Perspective

When modifying `CLAUDE.md.template` or `subrepo-templates/`:

- Consider: "Will a new user understand this without reading the source repo?"
- Placeholder count should be minimized — too many raises adoption barrier
- Optional sections use `<!-- BEGIN/END: OPTIONAL -->` comments

### Shell Script Cross-Platform Compatibility

`init.sh` and `check-autoflow-gate.sh` must work on both macOS (BSD) and Linux (GNU):

- `sed -i`: Use OS detection or avoid in-place editing
- `grep`: Use POSIX-compatible flags
- `awk`: Use basic awk, not gawk extensions
- Test on both platforms before merge
