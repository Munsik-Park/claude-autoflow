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
| `docs/autoflow-guide.md` | Phase-by-phase Auto-Flow lifecycle |
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

## Auto-Flow Lifecycle (PREFLIGHT → LAND)

This project follows Auto-Flow with Agent Teams. Even though this is a single repo, **the orchestrator does not implement**. The orchestrator coordinates, and spawns teammates to do the actual work.

### Agent Roles

| Role | How | Constraint |
|------|-----|-----------|
| **Orchestrator** | Main session (you) | Coordinates only — does NOT write code, tests, or templates |
| **Test AI** | Teammate (`Agent` with `team_name`) | Writes tests from acceptance criteria (RED) |
| **Developer AI** | Teammate (`Agent` with `team_name`) | Writes minimum code to pass tests (GREEN) |
| **Evaluation AI** | Fresh `Agent` (no team, no history) | Scores work at GATE:HYPOTHESIS, GATE:PLAN, GATE:QUALITY — **spawned fresh every time** |

### Evaluation AI Prompt Rules

1. **[MUST]** Include: evaluation type, `CLAUDE.md > [section]` reference, target file paths
2. **[MUST]** Do NOT copy evaluation criteria into the prompt — instruct the AI to read CLAUDE.md directly
3. **[MUST]** Orchestrator-written portion must be 5 lines or fewer (excluding target file contents)
4. **[MUST]** State observations as direct facts — cite file paths and line numbers. Prohibited forms: "consider that ~", "note that ~", "this is ~ so".
5. **[MUST]** Evaluation AI output MUST include `evaluator.role_marker` with the gate-specific value: `[role:eval-hypothesis]`, `[role:eval-plan]`, or `[role:eval-quality]`. The hook will block evaluation JSON writes that omit this field.

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

**State location is host-only.** `.autoflow-state/` lives in the orchestrator's host repo working tree, never inside a sub-repo. When the orchestrator session executes from inside a sub-repo working tree (i.e., `git -C "$CLAUDE_PROJECT_DIR" rev-parse --show-superproject-working-tree` returns a non-empty path), `phase-set` refuses to write — see [docs/design-rationale.md > Decision 10](docs/design-rationale.md#decision-10-state-tree-is-namespaced-by-sub-repo-identifier). The escape hatch `AUTOFLOW_ALLOW_SUBMODULE_STATE=1` is reserved for testing/CI only.

**The Orchestrator does not interpret evidence content.** When a Teammate emits a `transition-request`, the Orchestrator's only action is to invoke the `phase-set` helper passing the `evidence` field verbatim. Reading, summarizing, or judging the evidence is out of scope — that judgment belongs to the Hook (mechanical prerequisite checks) or to a fresh Evaluation AI (gate scoring).

**Five Facilitator Roles.** The Orchestrator's mechanical-pass-through stance decomposes into five simultaneous facets — Space Holder, Flow Observer, Signal Responder, Time Steward, Result Receiver — bound by a closed four-signal-type outbound surface (transition-request acknowledgment, dispute arbitration trigger, deadline reminder, gate evaluator spawn). For full role definitions, the four signal types tied to existing flow events, and the rejected alternatives, see [docs/design-rationale.md > Decision 9](docs/design-rationale.md#decision-9-orchestrator-holds-five-facilitator-facets).

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

### Phase Transition Protocol

Phase transitions follow a three-party split — see [docs/design-rationale.md > Decision 8](docs/design-rationale.md#decision-8-phase-transitions-use-a-three-party-split-teammate--orchestrator--hook).

| Party | Responsibility at a phase transition |
|-------|--------------------------------------|
| Teammate | Produces the artifact required by the current phase and emits a `transition-request` to the Orchestrator citing the next phase and evidence. |
| Orchestrator | Mechanical pass-through — invokes the `phase-set` helper with the `evidence` field passed verbatim. Does not interpret evidence content. |
| Hook | Mechanical prerequisite verification (artifacts exist, GATE PASS where applicable, role marker correct); allows or blocks the transition. |

A Teammate requests a transition by sending the Orchestrator a message in this canonical format:

```
@orchestrator transition-request
from: <CURRENT_PHASE>
to: <NEXT_PHASE>
evidence: <artifact path or short factual statement>
```

- **[MUST]** A `transition-request` must address the Orchestrator. Sibling-to-sibling transition messages between Teammates are forbidden.
- **[MUST]** The Orchestrator's response is to invoke the `phase-set` helper (see Item 2 / #28) with the `evidence` field passed verbatim — no reading, summarizing, or judging of the evidence content.
- The `phase-set` helper is the mechanical pass-through that will be introduced by Item 2 (#28); until then, Orchestrators emulate it by writing the phase file directly while preserving the no-interpretation contract.

### Phase Definitions

```
PREFLIGHT:       Pre-Work         → Git Clean Check, branch creation
DIAGNOSE:        Issue Analysis    → 3-Phase independent analysis (bias prevention)
GATE:HYPOTHESIS: Structure Eval   → Evaluation AI (fresh spawn): PASS → continue, FAIL → close issue
ARCHITECT:       Plan Synthesis    → Merge analyses into implementation plan + acceptance criteria
GATE:PLAN:       Plan Evaluation   → Evaluation AI (fresh spawn): 5 categories × 10 points
DISPATCH:        Task Assignment   → TeamCreate + SendMessage to Test AI and Developer AI
RED:             Test Writing      → Test AI writes tests → Red confirmation
GREEN:           Implementation    → Developer AI writes minimum code to pass tests
VERIFY:          Green + Verify    → All tests pass + minimal implementation check
REFINE:          Refactor          → Developer AI code cleanup, Green re-confirmation
GATE:QUALITY:    Evaluation        → Evaluation AI (fresh spawn): scored quality assessment
REVISION:        Revision          → Fix evaluation feedback (if GATE:QUALITY FAIL)
SHIP:            PR & Review       → Create PR for human review
LAND:            Merge & Close     → Human approves and merges
```

### Execution Principles

1. **Never skip phases.** Every phase executes regardless of change size. "This one is simple" is itself a biased judgment.
2. **PREFLIGHT is mandatory.** If Git state is not clean, DIAGNOSE does not begin.
3. **GATE:HYPOTHESIS FAIL = issue close.** Existing structure handles the concern — no code change needed.
4. **Orchestrator does not implement.** The orchestrator coordinates — teammates do the work.
5. **Evaluator is always fresh.** Never reuse an evaluation agent — self-reinforcement bias.
6. **All loops terminate.** Every retry has a maximum count and human escalation point.
7. **Pipeline is stateless.** Past evaluations do not influence current analysis.

---

## Flow Control

| Current State | Condition | Next State |
|---|---|---|
| PREFLIGHT | Git clean, branch created | → DIAGNOSE |
| DIAGNOSE | 3 isolated analyses done | → GATE:HYPOTHESIS |
| GATE:HYPOTHESIS PASS | Score >= 7.5 | → ARCHITECT |
| GATE:HYPOTHESIS FAIL | Existing structure sufficient | → **Issue closed** |
| ARCHITECT | Plan documented | → GATE:PLAN |
| GATE:PLAN PASS | Score >= 7.5, all >= 7 | → DISPATCH |
| GATE:PLAN FAIL | Below threshold | → ARCHITECT (max 3x) |
| DISPATCH | Tasks assigned, delegation.md created | → RED |
| RED | Tests written, all Red | → GREEN |
| GREEN | Minimum implementation done | → VERIFY |
| VERIFY PASS | All Green + minimal impl check | → REFINE |
| VERIFY FAIL (test issue) | Test incorrect | → RED (fix test → re-Red) |
| VERIFY FAIL (impl issue) | Implementation incorrect | → GREEN (fix impl) |
| VERIFY DEADLOCK | Both claim "no problem" | → Evaluation AI arbitrates |
| REFINE | Refactor done, Green maintained | → GATE:QUALITY |
| GATE:QUALITY PASS | Score >= 7.5, all >= 7 | → SHIP |
| GATE:QUALITY FAIL | Below threshold | → REVISION |
| GATE:QUALITY AUTO-FAIL | Consistency <= 3 | → DISPATCH (major rework) |
| REVISION | Revisions done | → GATE:QUALITY (re-eval, max 3x) |
| SHIP | PR created | → LAND (human) |
| LAND | Merged | → Done |

### Regression Rules

| Failure | Max Retries | Escalation |
|---|---|---|
| GATE:HYPOTHESIS FAIL | 0 | Issue closed (by design) |
| GATE:PLAN FAIL | 3 → ARCHITECT | Human intervention |
| GREEN↔VERIFY cycle | 3 round-trips | Human intervention |
| REFINE FAIL | 2 | Skip refactor, keep Green state |
| GATE:QUALITY FAIL | 3 → REVISION | Human intervention |

---

## PREFLIGHT: Pre-Work

**[MUST]** Git Clean Check before any work begins.

```
0-1. git status — no uncommitted changes, no untracked files in working area
0-2. git fetch origin — sync with remote
0-2b. If this repo tracks an upstream sub-repo via patch-apply (parent-repo / sub-repo layout), bring the host working tree current with the just-fetched sub-repo state per the host's local procedure (e.g., `CLAUDE.local.md`). Skip if the project is single-repo.
0-3. Resolve any dirty state (stash, commit, or discard with user approval)
0-4. git checkout -b <branch-type>/<issue>-<desc> main
```

If Git state is not clean after 0-3, stop and report to user. Do NOT proceed to DIAGNOSE.

---

## DIAGNOSE: 3-Phase Independent Analysis

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

> **Note**: "Structural Change Necessity" is intentionally direction-symmetric — additive, extending, reverting, and removing proposals all reach the same numerical ceiling on this axis when the structural change is justified.

**Type 2 (Documentation/Consistency) Scoring:**

| Category | Measures |
|---|---|
| Content Gap | Does a real content gap or inconsistency exist? (high = gap exists) |
| Consistency Impact | Does the inconsistency affect users or AI behavior? (high = significant impact) |
| Propagation Scope | Is the propagation scope appropriate — not too broad, not missing targets? (high = appropriate scope) |

- **PASS** (avg >= 7.5, all >= 7): Change needed → proceed to GATE:HYPOTHESIS
- **FAIL**: Existing structure handles it → close issue with rationale

---

## ARCHITECT: Plan Synthesis

Merge Phase A, B, and 3 into an implementation plan.

**Output**:
- Changed files list
- Approach description
- Risk identification
- Acceptance criteria (testable statements)

---

## GATE:PLAN: Plan Evaluation

**Evaluator**: Fresh-spawned Evaluation AI.

**Input**: Implementation plan from ARCHITECT.

**5 categories × 10 points**:

| Category | Measures |
|---|---|
| Feasibility | Can this plan be implemented with the current structure? |
| Dependencies | Are affected files and side effects identified? |
| Scope | Appropriate — not too broad, not missing requirements? |
| Consistency | Does this align with design-rationale.md principles? |
| Test Plan | Are acceptance criteria testable? |

**PASS**: avg >= 7.5, all >= 7 → DISPATCH.
**FAIL**: → ARCHITECT (max 3x).

---

## DISPATCH: Task Assignment

The orchestrator creates a team and spawns teammates to execute the plan.

**[MUST]** The orchestrator must create delegation.md as a mandatory artifact before RED begins.

```
4-1. TeamCreate — create a team for this issue
4-2. Spawn Test AI teammate (Agent with team_name, name="test-ai")
     - SendMessage: acceptance criteria + verification design
     - Instruction: "Write tests for these acceptance criteria. Do NOT implement."
4-3. Spawn Developer AI teammate (Agent with team_name, name="dev-ai")
     - SendMessage: implementation plan + acceptance criteria
     - Instruction: "Wait for Test AI to complete tests (RED). Then implement minimum code to pass."
4-4. Both teammates receive: plan.md, acceptance criteria, affected files list
4-5. Create delegation.md in .autoflow-state/<issue>/ with the following sections:
```

### delegation.md Format

```markdown
## Team
<team-name>

## Test AI Instructions
<acceptance criteria + verification design for Test AI>

## Developer AI Instructions
<implementation plan + acceptance criteria for Developer AI>
```

**[MUST]** DISPATCH produces delegation.md — it is a mandatory artifact for RED entry.
**[MUST]** Test AI starts first (RED). Developer AI waits until tests are written and Red-confirmed.
**[MUST]** The orchestrator does not write code — it sends instructions and monitors progress.

---

## TDD Cycle (RED → GREEN → VERIFY → REFINE)

### What Is Testable in This Project

| Change Type | Testable? | Method |
|---|---|---|
| `init.sh` | Yes | Shell script test: run with mock inputs, verify output files |
| `check-autoflow-gate.sh` | Yes | Shell script test: mock `.autoflow-state/` JSON, verify exit codes |
| Placeholder completeness | Yes | `grep -r '{{' .` after init.sh run — must return empty |
| Template syntax | Yes | Validate generated CLAUDE.md has no broken markdown |
| Documentation content | Partial | Verify internal links resolve, code blocks are valid |
| Pure prose changes | No | Skip TDD cycle, proceed directly to GATE:QUALITY evaluation |

### RED: Test Writing (Test AI)

**Entry precondition**: delegation.md must exist in `.autoflow-state/<issue>/` before RED begins.

Test AI teammate writes tests from acceptance criteria.

```
5a-1. Convert acceptance criteria → test scripts (tests/ directory)
5a-2. Run tests → ALL must FAIL (Red confirmation)
      - A test that passes means criteria already met or test is wrong
5a-3. For untestable items → write manual verification checklist
5a-4. Report to orchestrator: "Tests written, Red confirmed"
```

### GREEN: Implementation (Developer AI)

Developer AI teammate writes minimum code to pass tests. This is the **only** phase where implementation code is written.

```
5b-1. Read the tests from RED
5b-2. Write minimum code/content to pass tests
      - [MUST] Do not implement behavior not covered by tests
      - [MUST] Do not write code before RED tests exist — that defeats Test First
5b-3. Commit (feat/fix branch)
5b-4. Report to orchestrator: "Implementation complete"
```

### VERIFY: Green Verification

```
5c-1. Run all tests
5c-2. Results:

  All PASS → 5c-3

  Some FAIL → Failure cause analysis:
    ├─ Test issue → fix test → re-Red → GREEN re-entry
    ├─ Implementation issue → fix implementation → VERIFY retry
    ├─ Both need fixes → fix test first → Red → fix impl → Green
    └─ Deadlock (both claim "no problem") → fresh Evaluation AI arbitrates

5c-3. Minimal implementation check:
    Diff analysis: is there code NOT covered by any test?
    ├─ All covered → PASS
    ├─ Uncovered code exists → remove or add test
    └─ Config/infra changes → exception allowed (document reason)
```

**Max round-trips**: GREEN↔VERIFY max 3 cycles → human escalation.

### REFINE: Refactor

```
5d-1. Developer AI teammate runs /simplify
      - Automatically analyzes reuse, quality, and efficiency (3 parallel agents)
      - Applies suggested fixes (no behavior change — tests must pass without modification)
      - If /simplify finds nothing → proceed to 5d-2 (DO NOT SKIP)
5d-2. [MUST] Re-run ALL tests → Green maintained
      - This phase is NEVER skipped, even when 5d-1 made no changes
      - FAIL → simplify broke something → revert simplify changes (max 2 attempts, then keep pre-refactor state)
5d-3. Commit (refactor type, or skip commit if no changes in 5d-1)
```

**Why /simplify instead of manual judgment?** Previously, the Developer AI decided "refactoring needed?" — but this judgment was routinely skipped with "no cleanup needed." `/simplify` removes this bias by mechanically analyzing the code. The AI no longer decides IF to refactor; a dedicated tool decides WHAT to refactor.

**[MUST]** 5d-2 is mandatory. "No changes were made so tests will pass" is not a valid reason to skip. The re-run confirms that no accidental state changes occurred between VERIFY and REFINE.

### Pure Documentation Changes

When the change is purely prose (no scripts, no templates with placeholders):
- Skip DISPATCH and the TDD cycle (RED–REFINE) entirely
- Orchestrator delegates the writing to a teammate, then proceed to GATE:QUALITY
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

### GATE:QUALITY Evaluation Categories

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

> See `docs/evaluation-system.md` for the full schema. This is the abbreviated reference.

```json
{
  "phase": "GATE:QUALITY",
  "issue": "#N",
  "evaluator": {
    "role_marker": "[role:eval-quality]",
    "session_id": "<session-id>"
  },
  "scores": {
    "correctness": { "score": 8, "reason": "..." },
    "quality": { "score": 7, "reason": "..." },
    "test_coverage": { "score": 7, "reason": "..." },
    "consistency": { "score": 9, "reason": "..." },
    "documentation": { "score": 8, "reason": "..." }
  },
  "average": 7.8,
  "verdict": "PASS",
  "blocking_issues": [],
  "suggestions": ["..."],
  "rationale": "..."
}
```

The Hook calculates pass/fail from raw `scores` — it does NOT trust AI's `verdict`, `pass`, or `average` fields.

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

The `check-autoflow-gate.sh` hook enforces phase progression:

- **Trigger**: Before commit or PR creation
- **Checks**: Calculates scores from raw `scores` in evaluation JSON
- **Does NOT trust**: AI-generated `pass` field — computes independently
- **State files**: `.autoflow-state/` directory

### Gate Points

| Action | Requires |
|---|---|
| Commit (GATE:QUALITY+) | Evaluation PASS |
| PR creation | Evaluation PASS |
| PREFLIGHT–REFINE commits | No gate restriction |
| REVISION commits | Allowed (revision in progress) |

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

### Git Clean Check (PREFLIGHT and LAND)

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

State files in `.autoflow-state/` track progress per issue. The directory lives in the orchestrator's **host repo only** — never inside a sub-repo working tree (see [docs/design-rationale.md > Decision 10](docs/design-rationale.md#decision-10-state-tree-is-namespaced-by-sub-repo-identifier)). The layout is uniformly namespaced by sub-repo identifier; single-repo deployments use `self`.

**File structure**:
```
.autoflow-state/                                # in host repo only
├── current-issue                               # contains: <sub-repo-id>/<issue-number>
└── <sub-repo-id>/                              # e.g., autoflow-upstream, or "self" for single-repo
    └── <issue-number>/
        ├── phase                               # Current phase name
        ├── intake.md                           # PREFLIGHT artifact (sub-repo, branch, state location)
        ├── requirements.md                     # PREFLIGHT–DIAGNOSE output
        ├── analysis/
        │   ├── phase-a.md                      # Structure analysis
        │   ├── phase-b.md                      # Issue analysis
        │   └── phase-3.md                      # Cross-verification
        ├── plan.md                             # ARCHITECT output
        ├── delegation.md                       # DISPATCH output (task assignments)
        ├── evaluation.json                     # GATE:QUALITY output
        └── history.log                         # Phase transition log
```

**Creation**: PREFLIGHT completion (writes `intake.md` first, then `phase-set` populates the namespaced subtree).
**Completion**: LAND → clean up or archive.
**`.gitignore`**: `.autoflow-state/` must be gitignored.

**`current-issue` format**: a single line `<sub-repo-id>/<issue-number>` (slash-separated, no `#`). Legacy bare-integer values are honored as `self/<integer>` for backward compatibility.

**Sub-repo identifier source**: the orchestrator (or external setup) sets `AUTOFLOW_SUBREPO_ID` to the submodule path basename — typically computed as `basename "$(git rev-parse --show-toplevel)"`. The `phase-set` script defaults to `self` and does NOT auto-compute the basename.

---

## Maintained Documents

Changes to any of these files require checking if related documents need updating:

| Document | Update When |
|---|---|
| `CLAUDE.md` | This file — process rules change |
| `CLAUDE.md.template` | Template for users — process/placeholder changes |
| `docs/design-rationale.md` | New design decisions or principle changes |
| `docs/autoflow-guide.md` | Phase definitions change |
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
3. GATE:QUALITY evaluation with Consistency score >= 8

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
