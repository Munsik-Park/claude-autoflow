# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language Rule

All communication with the user must be in Korean (한글). Even if the user writes in English, always respond in Korean. Code, policies, and technical identifiers remain in English.

## What This Repo Is

A public template repository that generalizes the AutoFlow methodology from `ontology-platform` into a reusable framework. The generalization is intentionally narrow:

1. **Name generalization** — upstream's numeric `STEP 0~9` (and sub-step `5a/5b/5c/5d/5.5/5.7`) identifiers are replaced by semantic phase names (`PREFLIGHT`, `DIAGNOSE`, `GATE:HYPOTHESIS`, `ARCHITECT`, `GATE:PLAN`, `DISPATCH`, `RED`, `GREEN`, `VERIFY`, `REFINE`, `VALIDATE`, `AUDIT`, `GATE:QUALITY`, `DELIVER`, `INTEGRATE`, `LAND`). Each generalized name maps 1:1 to an upstream STEP — no phase is added or removed.
2. **Identifier placeholders** — service-specific names like `ontology-api`, `saiso`, organization `connev-ontology`, etc. are replaced by `{{REPO_*}}`/`{{GITHUB_ORG}}` placeholders, so users instantiate them through `setup/init.sh`.

Every rule, retry cap, evaluation category, score threshold, and regression path is preserved verbatim from upstream. The methodology evolves in `ontology-platform`; this repository tracks rather than diverges.

## Instruction Conventions

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract — treat it as a literal, non-negotiable rule, not as emphasis to be generalized to nearby cases. **`[DENY]`** marks a prohibited action.
- These tags carry the weight; do not stack extra emphasis on top of them (no "CRITICAL: you MUST…"). Recent Claude models follow instructions more literally and are more responsive to the system prompt, so stacked emphasis over-triggers rather than strengthens a rule.
- A `[MUST]` applies exactly to the scope it names. When a rule must hold across every phase, file, or section, the rule states that scope explicitly — an instruction written for one item is not silently generalized to others.

## Cross-Project Boundary Rules

- **[MUST]** All AIs: read access to other sub-repositories is allowed; modifications outside the assigned scope are not.
- The orchestrator's "own scope" is the host repository — typically `docker-compose.*`, `platform.sh` (or its analogue), `scripts/`, `.env.*`, `docs/`, `CLAUDE.md`. The generalized form lists the orchestrator scope by placeholder; see the Repo Structure section below.
- A sub-repo AI's "own scope" is that sub-repo's directory.
- Cross-service changes are coordinated through Agent Teams (`SendMessage`).

For details, see [`docs/repo-boundary-rules.md`](docs/repo-boundary-rules.md).

## Credentials & Runtime State

Secrets, credential references, and project config are separated into three tiers:

| Tier | Location | Checked in? |
|------|----------|-------------|
| Secret (tokens, passwords) | `.env`, `.env.local`, `.env*.local` | No |
| Credential reference (gh login, ssh key path) | `.autoflow/auth.local.yaml` | No |
| Project config (placeholders, fork↔upstream map) | `.autoflow/config.yaml`, `.autoflow/submodules.yaml` | Yes |

- **[MUST]** No phase reads `.env*` files. No AI output (messages, commits, PR bodies, logs) contains secret values. AUDIT rejects commits whose diff matches secret-shape patterns.
- **[MUST]** LAND switches gh login per role using `.autoflow/auth.local.yaml`: host PRs run under `gh_users.orchestrator`, sub-repo PRs run under `gh_users.submodules.<name>`. This codifies LAND step 4's "fork account lacks upstream merge permission" constraint.
- Sub-repo credential behaviour: see [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Credentials.
- Full schemas, examples, masking patterns, and migration steps: see [`docs/credentials.md`](docs/credentials.md).

## Team Structure

> The detailed role contracts (Evaluation AI, Test AI, Submodule AI) and the consolidated Evaluation System scoring live in [`docs/teammate-contracts.md`](docs/teammate-contracts.md). The summaries below stay here for orchestrator routing.

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

## Spawn Model — Phase-by-Phase

AutoFlow teammate and subagent spawns choose the model by phase work type rather than inheriting the host session model (currently Opus 4.8). Rationale: (a) cost efficiency on rubric- or classification-bound phases (Sonnet 4.6 input/output = 60% of Opus 4.7 per M tokens), (b) Anthropic's official guidance (Opus = "long-horizon agentic, complex reasoning"; Sonnet = "frontier intelligence at scale, agentic tool use"), (c) confining long-session degradation exposure to the phases that genuinely need Opus.

| Phase | Model | Work type |
|---|---|---|
| DIAGNOSE Phase A (structure) | `sonnet` | factual code-structure description (issue-isolated) |
| DIAGNOSE Phase B (issue) | `sonnet` | text classification + logical inference (no code) |
| DIAGNOSE Phase 3 (necessity) | `sonnet` | necessity scoring (3 items × 10 points) |
| GATE:HYPOTHESIS | `sonnet` | rubric, 3 items × 10 points |
| ARCHITECT | `opus` | multi-turn design discussion, devil's advocate (Developer AI + Test AI) |
| ARCHITECT / VERIFY facilitator | `opus` | isolated `Workflow` whose in-script Developer-AI/Test-AI sub-agents run on `opus` (ARCHITECT design discussion; VERIFY self-check) — see Deliberation Isolation |
| GATE:PLAN | `sonnet` | rubric, 5 items × 10 points |
| RED | `sonnet` | acceptance criteria → test code (complex tests fall back to `opus`, with rationale in the Test AI report) |
| GREEN | `opus` | minimum implementation that passes the tests |
| VERIFY | `opus` | self-check + arbitration (sycophancy-risk surface) |
| REFINE | `sonnet` | mechanical `/simplify` application |
| AUDIT | `sonnet` | security rubric, 5 items × 10 points (1-cycle pilot before settling) |
| GATE:QUALITY | `sonnet` | rubric, 10 items × 10 points |

Other phases either have no teammate spawn or are run by the orchestrator: PREFLIGHT (orchestrator), DISPATCH (`TaskCreate` + `SendMessage` only), VALIDATE (automatic gate), DELIVER / INTEGRATE / LAND (orchestrator).

**[MUST]** Every `Agent` spawn (in either `subagent_type` or `team_name` form) declares the `model` parameter explicitly (`model: "sonnet"` or `model: "opus"`). Without it the host session model is inherited and this per-phase policy is bypassed. The orchestrator's own model follows the user's session settings (outside this policy). Note: `SendMessage` is not a spawn — it delivers to an existing teammate — and therefore carries no `model` parameter.

**[MUST]** On the VERIFY → REFINE transition the Developer AI lifetime is shut down and a fresh `sonnet` teammate is spawned at REFINE entry. Mid-lifetime model switching is not supported by the runtime, so the model change requires a phase-boundary respawn (mirrors the DISPATCH-entry respawn in [Cost Control](#cost-control)).

**[MUST]** If a phase's score distribution drifts by ≥ ±0.5 from the Opus baseline — mean over the prior 5 cycles of the same evaluation type on the same issue tracker — revert that phase to `opus` and update this table in the same commit.

**Pilot rollout order** (safest first): GATE:QUALITY → GATE:PLAN / HYPOTHESIS → DIAGNOSE A/B/3 → REFINE → AUDIT → RED. Measure the score-distribution shift at each step before moving on. AUDIT is rolled out near the end because security findings are sensitive; adopt only after a single pilot cycle confirms no drift.

**Sources**:
- Anthropic model selection guide: https://docs.claude.com/en/docs/about-claude/models/choosing-a-model
- Sonnet 4.6 release notes (SWE-bench Verified 80.2%): https://www.anthropic.com/news/claude-sonnet-4-6
- Opus 4.7 release notes: https://www.anthropic.com/news/claude-opus-4-7
- Long-session degradation user reports: `anthropics/claude-code` issues #54991, #56367, #53459, #34685, #62144

## Context Injection — Role-Scoped Document Routing

**[MUST]** Subagent document injection is role-scoped, not shared context. `docs/INDEX.md` is the orchestrator's **router** for selecting which documents each role receives — it is never injected wholesale as common context to every spawn.

**[MUST]** Role-scoped injection does not break DIAGNOSE context separation: the structure-analysis path (Phase A) and the issue-analysis path (Phase B) receive disjoint document sets. The per-role injection whitelist — which baseline/review/ADR doc is allowed into which DIAGNOSE phase — is the DIAGNOSE playbook's body ([`docs/phases/analysis.md`](docs/phases/analysis.md)). ARCHITECT-onward injection guidance lives in [`docs/autoflow-guide.md`](docs/autoflow-guide.md) and preserves role-minimal injection and [Deliberation Isolation](#deliberation-isolation-delegated-facilitation).

## Communication — Agent Teams

Communication with sub-repo AIs uses **Agent Teams**.

- The Lead (orchestrator) runs `TeamCreate`, then spawns Teammates via `Agent` with `team_name` and `name`.
- Teammates communicate via `SendMessage` (push-based delivery).
- `SendMessage(to: "*")` broadcasts.
- MCP coord is auxiliary, used for asynchronous logging and handoff.

### Cost Control

These rules apply to every cycle to prevent token-cost blow-up. Background: Claude Code's `TeammateIdle` hook cannot cancel orchestrator turns and there is no native `agentTeams.skipIdleTurns` setting (per [agent-teams docs](https://code.claude.com/docs/en/agent-teams.md) and [costs docs](https://code.claude.com/docs/en/costs.md)), so cost control is enforced at the codebase level.

- **Phase-boundary respawn**: ARCHITECT runs as a self-contained `Workflow` that ends when it returns (no persistent facilitator/teammates to shut down — see [Deliberation Isolation](#deliberation-isolation-delegated-facilitation)). At DISPATCH entry the orchestrator spawns fresh agents for RED/GREEN, passing `.autoflow/issue-{N}-*.md` paths only — discussion history is not carried into implementation phases.
- **[MUST] Orchestrator context discipline**: the orchestrator holds only anchors, summaries, verdicts, and decisions — never raw material. It does not read a full artifact (whole design docs, full source files) to judge it, nor run multi-step investigations in its own context; that absorption is **delegated** to a subagent or teammate that writes any body to `.autoflow/*` and returns only an anchor + one-line summary. This applies to (a) the orchestrator's own reads and (b) every direct/ad-hoc `Agent` spawn, scripted-phase or not (e.g. DIAGNOSE Phase A/B/3 write `.autoflow/issue-N-phase-*.md` and return a summary, not the body). Cheap anchor-checks stay in-context — a `git show <SHA>`, a one-line command re-run, a targeted `git show HEAD:<file>` of the specific lines (see Execution Principles > Verify teammate claims). Full body enters orchestrator context only when strictly required (e.g. evaluator scores). Multi-teammate **deliberation** is absorbed the same way — a discussion is delegated to a facilitator sub-context, not run in the orchestrator's turn stream (see [Deliberation Isolation](#deliberation-isolation-delegated-facilitation)).
- **Test-runner output**: run the suite in a quiet/summary mode (e.g. `--silent --reporters=summary`, or your test runner's equivalent). Never paste raw verbose output (per-case lines, full coverage report) into a teammate message or report. See [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Testing Standards.
- **Team size**: keep ≤ 5 teammates per Agent Teams session. Use Agent Teams only when cross-AI coordination is required — single-AI tasks should use a direct `Agent` spawn instead.

### Deliberation Isolation (delegated facilitation)

Multi-teammate deliberation phases (ARCHITECT; the Developer-AI ↔ Test-AI cause-branch exchange in VERIFY) run inside an **isolated facilitation sub-context**, not in the orchestrator's own turn stream. This is a structural rule, not a cost optimization — see [`docs/design-rationale.md`](docs/design-rationale.md) > Decision 8.

**Why** — a teammate→lead `SendMessage` is auto-injected into the recipient's conversation as a turn and persists until compaction. When the orchestrator is the discussion lead, every round of Developer-AI ↔ Test-AI cross-talk lands in its context, and the two teammates' near-duplicate convergence reports (e.g. dev `Full mutual ACCEPT` + test `MUTUAL ACCEPT reached`) load the same information twice. Beyond token cost, this contaminates judgment: retracted claims, wrong oracles, and reversed scopes accumulate in the orchestrator's working context and it oscillates on decisions it had already settled (observed in practice). A cheaper or summarized round (file-pull, checkpoint summary) does not fix this — the orchestrator still receives the round and the duplicate accumulation. Removing the contamination requires removing the orchestrator from the loop, not shrinking each message.

- **[MUST]** The orchestrator delegates a multi-teammate deliberation to a **facilitator** realized as an isolated **`Workflow`** (Claude Code v2.1.154+), **not** as a nested Agent Team — a spawned teammate cannot create its own team and a team's lead is fixed for its lifetime, so a nested-team facilitator is not executable; and a peer-teammate facilitator is not a documented isolation boundary. The workflow runs the Developer-AI and Test-AI sub-agents in-script ("intermediate results stay in script variables instead of landing in Claude's context"), drives convergence under the Discussion Protocol, writes the converged artifacts to `.autoflow/*`, appends settled decisions to the decision ledger, and returns to the orchestrator **only** one structured result (per-phase — see [`docs/teammate-contracts.md`](docs/teammate-contracts.md) > Facilitator > Return Contract): ARCHITECT returns `{ verdict: CONVERGED|ESCALATE, artifact paths, summary }`; VERIFY returns `{ test/impl self-check, next_action: RED|GREEN|SEQUENTIAL_FIX|EVALUATION_AI }`. The orchestrator never receives the round-by-round messages or the duplicate dual reports. Reference scripts: `.claude/workflows/{architect-deliberation,verify-cause-branch}.js`.
- **[MUST] Isolation is for deliberation, not verification.** Delegated facilitation removes the orchestrator's exposure to round-by-round prose — it does **not** remove the orchestrator's verification job. After the result returns, the orchestrator does **not** read the design docs cover-to-cover to judge them (that full read-and-score is GATE:PLAN's fresh Evaluation AI); it **spot-checks targeted excerpts** — pulling the specific `path:line` a returned decision rests on and re-deriving the cited fact (`git show`, command re-run, `git show HEAD:<file>`). The catches that justify the orchestrator's role come from these targeted facts, not from reading deliberation prose; that leverage is preserved.
- **Termination** (per [`docs/design-rationale.md`](docs/design-rationale.md) > Decision 7): the facilitated discussion carries an explicit cap — ARCHITECT max **6 rounds** (a round = one Developer-AI ↔ Test-AI exchange cycle) → `ESCALATE` on no mutual ACCEPT; VERIFY is a **single** self-check round (deterministic `next_action`, no internal loop). A facilitated deliberation never loops without a termination condition.
- **Respawn / lifecycle**: each facilitation is a self-contained workflow run — it ends when it returns its result (no long-lived teammate to shut down). At DISPATCH entry the implementation teammates (RED/GREEN) are spawned fresh, carrying only `.autoflow/*` paths (see *Phase-boundary respawn* above).

#### Decision Ledger

A per-issue append-only record, `.autoflow/issue-{N}-ledger.md`, fixes settled decisions so an enlarged context cannot silently re-open them.

- Each entry records: the decision (one line), its **grounds** (evidence / artifact `path:line`), its **authority** (what settled it — `ARCHITECT mutual ACCEPT`, `GATE:PLAN PASS (avg 8.2)`, `VERIFY Evaluation-AI arbitration`), and the cycle/phase.
- **[MUST]** A recorded decision is not re-litigated without a **new verified fact** — a fact unavailable when the entry was written and deterministically checkable (a commit SHA, a `Tests: N passed` line, a `file:line` content), not a re-reading or re-interpretation of material already on the record. This caps oscillation-driven round explosion and aligns with the GATE-verdict-outranks-rereading rule (a settled gate verdict is not overturned by re-reading the issue body).
- **[MUST]** The ledger is append-only: entries are never edited or deleted. A superseding decision adds a new entry that cites the new fact and references the entry it supersedes.
- The facilitator appends entries during deliberation; the orchestrator appends each gate's verdict after the gate. The ledger lives in the host repo (sub-repo AIs do not write it).

### Discussion Protocol

→ Single source of truth: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Discussion Protocol

The orchestrator and sub-repo AIs follow the same rules. Core: UNDERSTAND → VERIFY → EVALUATE → RESPOND (ACCEPT / COUNTER / PARTIAL / ESCALATE). No groundless agreement, no evaluation without reading the relevant files, devil's advocate required on the first exchange.

## Development Lifecycle — AutoFlow

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
| DIAGNOSE (intake readiness triage) → user | new-issue only: a planning/design/ADR prerequisite is clearly required first → write reason + suggested issue-split draft to `.autoflow/issue-{N}-triage.md`, report anchor + summary, pause (no auto issue creation); ambiguous → PASS to structure analysis → see [`docs/phases/analysis.md`](docs/phases/analysis.md) |
| DIAGNOSE (intake readiness triage) → structure analysis | triage PASS (no clear prerequisite) → Phase A/B fan-out begins |
| DIAGNOSE (structure eval) → close | GATE:HYPOTHESIS structure FAIL → issue auto-closed + AutoFlow terminated |
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

### Phase Playbook Loading Contract

Each phase's procedure body — its numbered steps, scoring rubric, and phase-local `[MUST]`/`[DENY]` constraints — lives in an on-demand **playbook**, not in this core file. This file retains only what every phase needs to *route*: the cross-phase invariants (above), the router (the phase list and Flow Control table above), the regression / escalation caps (above), the Execution Principles (below), and the state schema (below).

**[MUST]** On entering a phase, Read its playbook below **before** acting in that phase. The playbook is the source of truth for that phase's body; this core file does not restate it. Do not execute a phase from memory of a prior cycle — re-read the playbook each cycle (the playbook may have changed, and the gate verdicts depend on its current rubric).

| Phase | Playbook to Read on entry |
|-------|---------------------------|
| PREFLIGHT | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > PREFLIGHT; git procedures: [`docs/git-workflow.md`](docs/git-workflow.md) (Git Clean Check, Post-Merge Cleanup) |
| DIAGNOSE | [`docs/phases/analysis.md`](docs/phases/analysis.md) — intake readiness triage (new-issue), 3-Phase A/B/3 analysis, per-role injection whitelist, issue-type scoring rubric, FAIL disposition, bias prevention |
| GATE:HYPOTHESIS | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GATE:HYPOTHESIS |
| ARCHITECT | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > ARCHITECT; facilitator contract: [`docs/teammate-contracts.md`](docs/teammate-contracts.md) > Facilitator; isolation rationale: this file > Deliberation Isolation |
| GATE:PLAN | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GATE:PLAN |
| DISPATCH | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > DISPATCH |
| RED | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > RED |
| GREEN | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GREEN; change surface: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md) > Change Surface Rules |
| VERIFY | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VERIFY |
| REFINE | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > REFINE |
| VALIDATE | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > VALIDATE; affected docs: [`docs/maintained-docs.md`](docs/maintained-docs.md) |
| AUDIT | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > AUDIT; checklist: [`docs/security-checklist.md`](docs/security-checklist.md) |
| GATE:QUALITY | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > GATE:QUALITY |
| DELIVER | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > DELIVER |
| INTEGRATE | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > INTEGRATE |
| LAND | [`docs/autoflow-guide.md`](docs/autoflow-guide.md) > LAND; git procedures: [`docs/git-workflow.md`](docs/git-workflow.md) |

The gate **PASS thresholds** (each ≥ 7, avg ≥ 7.5, security ≤ 3 → block) and the **regression / retry caps** are fixed invariants: they live in the Flow Control table and the **Regressions** line above and are enforced by the hook (`.claude/hooks/check-autoflow-gate.sh`) — the per-gate playbooks restate each gate's rubric items but not these thresholds. The evaluation contract (fresh-spawn Evaluation AI, the 10-point scale, the output format) lives in [`docs/teammate-contracts.md`](docs/teammate-contracts.md) > Evaluation System and [`docs/evaluation-system.md`](docs/evaluation-system.md).

### Execution Principles

- **Safety first**: accurate flow execution beats fast response. Accuracy over speed.
- **Verify before transition**: re-confirm completion conditions before moving on.
- **Every phase is mandatory**: no skipping based on perceived simplicity.
- **Teammate idle handling**: idle notifications (`{"type":"idle_notification",...}`) signal teammate availability; they do not require a response. Continue work when (a) a teammate sends an actionable report via SendMessage, (b) a Bash result you initiated returns, or (c) the user types a new prompt.
- **Verify teammate claims before dispatch**: every teammate report's Evidence anchor is verified before ACCEPT — `git show <SHA>` for a commit anchor, re-running the cited command for a test-summary anchor, `git show HEAD:<file>` for a file-state anchor. **An anchor-less report is rejected, not interpreted.** Do not dispatch based on a single AI's unverified claim — stale snapshots in working memory or hash confabulation can cause noop redo dispatches.
- **Incomplete output is never ground truth**: a 1-line tool result — a Read-dedup stub (`file unchanged … refer to that earlier tool_result`; the dedup ledger is not reset on compaction, `anthropics/claude-code#46749`) or a `Cancelled: parallel tool call … errored` — is a harness artifact, not data. Never conclude "absent / empty / stub" or escalate a blocker from one; re-read via shell (`sed -n`/`grep`/`wc -l`, which bypasses the dedup ledger) and reproduce the finding before acting. Do not batch parallel `cd`-prefixed Bash — use `git -C <path>` + absolute paths. The `Read` PostToolUse hook (`.claude/hooks/check-read-dedup.sh`) flags the dedup case at runtime.
- **Stop on error**: do not act on errors or omissions until the situation is fully understood.

### AutoFlow State Tracking (Hook integration)

While AutoFlow is in progress, an issue-scoped state file lives under `.autoflow/`. The hook computes pass/fail directly from `scores` to enforce gates.

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

> Consolidated reference (the form the Evaluation AI is pointed at): [`docs/teammate-contracts.md`](docs/teammate-contracts.md) > Evaluation System. The tables below are the orchestrator's inline copy.

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
| Structure evaluation | Type 1: Behavior gap, Code-change necessity (2) — Type 2: Content gap, Consistency impact, Propagation scope (3) | none (PASS/FAIL single verdict; reuse-neutral; gap-low → close, non-code lever → report + pause; no retry) |
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

- **AutoFlow phase guide**: [`docs/autoflow-guide.md`](docs/autoflow-guide.md)
- **Documentation index (role-scoped injection router)**: [`docs/INDEX.md`](docs/INDEX.md)
- **DIAGNOSE analysis playbook**: [`docs/phases/analysis.md`](docs/phases/analysis.md)
- **Evaluation system**: [`docs/evaluation-system.md`](docs/evaluation-system.md)
- **Teammate contracts (role contracts + consolidated scoring)**: [`docs/teammate-contracts.md`](docs/teammate-contracts.md)
- **Design rationale (why every rule exists)**: [`docs/design-rationale.md`](docs/design-rationale.md)
- **Git procedures**: [`docs/git-workflow.md`](docs/git-workflow.md)
- **Repo boundary rules**: [`docs/repo-boundary-rules.md`](docs/repo-boundary-rules.md)
- **Credentials & runtime state**: [`docs/credentials.md`](docs/credentials.md)
- **Sub-repo common rules**: [`docs/submodule-common-rules.md`](docs/submodule-common-rules.md)
- **Maintained docs registry**: [`docs/maintained-docs.md`](docs/maintained-docs.md)
- **Security checklist**: [`docs/security-checklist.md`](docs/security-checklist.md)
