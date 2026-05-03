# Auto-Flow Design Rationale

This document explains the design intent and reasoning behind every major decision in Auto-Flow.
Where CLAUDE.md describes **what to do and how**, this document explains **why** it was designed that way.

**Any new AI reading this repository should read this document first.**
Understanding the design intent takes priority over following the rules.
Without understanding the reasons, an AI may propose something that "looks better" but undermines a core principle.

---

## The Problems This System Solves

Auto-Flow addresses structural problems that arise in AI-driven development environments.

### Problem 1: AI Is Biased Toward Solving the Moment It Receives an Issue

AI is trained to be helpful. The moment it receives an issue, the frame "this is a problem to solve" locks into its context. Even when analyzing code afterward, it tends to overlook parts where the existing structure already handles the concern, or proposes unnecessary code changes.

This is not a defect in AI. It is a byproduct of "be helpful" training. It cannot be fixed through training alone. **It must be blocked structurally.**

### Problem 2: A Single Session Cannot Effectively Challenge Its Own Reasoning

When analysis and evaluation happen in the same conversation, previously generated text influences subsequent generation (self-reinforcement). Evaluation converges toward "my analysis was correct." This is a structural problem inherent to the context window.

### Problem 3: AI Self-Reporting Is Unreliable

Even when an AI declares "PASS," whether that judgment actually meets the defined criteria is a separate question. AI tends to implicitly adjust standards while scoring, or interpret edge cases favorably.

---

## Core Design Decisions and Their Reasoning

### Decision 1: AI-A Does Not Receive the Issue Content (3-Phase Independent Analysis)

**What it does**

- **AI-A**: Analyzes code structure only — without seeing the issue content
- **AI-B**: Analyzes the issue text only — without seeing the code
- **Phase 3**: AI-A evaluates AI-B's proposed resolution from a structural perspective

**Why it works this way**

Information isolation is the key. If AI-A knows the issue, it starts looking for "structure that solves this problem." Without the issue, it sees the structure as it actually is. The information asymmetry between the two AIs creates the validity of cross-verification.

It is normal for AI-B to use zero tools. Its purpose is to analyze the problem from the issue text alone. If it reads code, it shares the same bias as AI-A, making Phase 3 verification purely ceremonial.

Claude is already trained to "give balanced answers." It rarely produces overtly one-sided responses. That is the effect of training. But the bias Auto-Flow prevents is different. When Claude receives an issue, "I need to solve this" is already embedded in the context. When it analyzes code in that state, it reads existing structure that already handles the concern as "insufficient." There is no malice. It is correct, helpful behavior. That is precisely why training cannot catch it. Training blocks "bad answers." Structure blocks "good intentions aimed in the wrong direction." This is why information isolation is necessary.

**Why this design must not be changed**

The suggestion "let's give AI-A the issue for efficiency" destroys the core of this system. Bias prevention can only be achieved through information isolation. Claude's built-in bias mitigation training is effective at balancing response tone, but it cannot prevent context contamination.

---

### Decision 2: Evaluation AI Is Spawned Fresh Every Time

**What it does**

The Evaluation AI at GATE:HYPOTHESIS, GATE:PLAN, SHIP, and GATE:QUALITY is created new for each invocation. It carries no prior conversation history.

**Why it works this way**

To start from a state with no trace of prior reasoning. When the same agent creates a plan and then evaluates it, it struggles to reject its own plan. A freshly spawned agent sees only the deliverable. It has no investment in the process.

**Bias elimination takes priority over cost**

"Reusing the same agent saves tokens" is factually true. But in this system, bias elimination takes priority over cost optimization. The quality of an expert system comes from the independence of its judgments.

---

### Decision 3: The Hook Does Not Trust AI's PASS Judgment

**What it does**

`check-autoflow-gate.sh` does **not** read the `pass` field written by the AI. It calculates the average, minimum, and security score directly from the raw `scores` object.

**Why it works this way**

To bring the trust chain down to the script level. An AI can implicitly decide "this is good enough to pass" while recording scores. The script ignores that judgment and looks only at the numbers. Numbers cannot be manipulated (within the system's constraints).

**What this means**

No matter how eloquently an AI says "the plan is excellent," if the scores don't meet the threshold, it cannot advance to the next phase. The gate operates on numbers, not explanations.

---

### Decision 4: The Pipeline Is Designed to Be Stateless

**What it does**

Each issue is processed independently. Past issue evaluation results do not influence the current issue's analysis.

**Why it works this way**

If a past evaluation was wrong and it influences the next evaluation, bias propagates. As incorrect judgments accumulate, the system hardens in a particular direction. Injecting past data into a pipeline whose principle is bias elimination undermines that principle.

**Improvement loops happen outside the pipeline**

Analysis of pass/fail patterns, modification of evaluation criteria, and identification of cross-issue correlations are performed by humans externally. Changes are reflected through CLAUDE.md and evaluation prompt modifications, with history tracked in Git. If the pipeline modifies its own criteria, it becomes impossible to trace which point in time had the correct judgment.

**However, factual lookups are different**

Injecting past evaluation results (bias injection) and looking up past code change history or issue context (factual lookup) are different things. Querying related issues and commit history at DIAGNOSE is allowed because it serves to accurately understand the current state.

---

### Decision 5: Phase Transitions Are Completion-Condition Based

**What it does**

Each phase transitions to the next only when its stated completion conditions are met. All phases are performed regardless of change size.

**Why it works this way**

AI tends to judge "this change is small enough to skip phases." That judgment itself is a product of bias. The thought "this one is simple" causes verification to be skipped, and problems emerge from the skipped verification. Simplicity can be determined after the process, not before it.

The act of judging "this change is simple" is itself a product of bias. That judgment is made before implementation. Before implementation, there is no way to know whether it is actually simple. The judgment may sometimes be correct, but when it is wrong, problems emerge from the verification that was skipped. Auto-Flow does not permit this judgment at all. Simplicity can be evaluated post-hoc, after all phases are completed. Pre-process judgment is not allowed.

---

### Decision 6: Structure Evaluation FAIL Means Issue Close

**What it does**

When the structure evaluation at PREFLIGHT–DIAGNOSE returns FAIL, Auto-Flow terminates and the issue is closed. It means the existing structure can already handle the concern — no code change needed.

**Why it works this way**

The best code is code that is never written. AI feels pressure to create something when it receives an issue. Structure evaluation is the first gate that blocks that pressure. In practice, this judgment has prevented unnecessary code changes — when existing architecture already solved the problem.

---

### Decision 7: All Loops Must Have Termination Conditions

**What it does**

Every repetition in Auto-Flow (e.g., GREEN↔VERIFY test-fix cycles, REVISION→GATE:QUALITY re-evaluation cycles, LAND revision requests) has an explicit maximum retry count. No loop can run indefinitely.

**Why it works this way**

When a loop fails, the work does not simply stop. The failure cause is classified, and the flow regresses to the appropriate phase. When all retries are exhausted, the work is handed to a human. There is no scenario where a loop never terminates.

For comparison: review gate structures where two models find problems in each other's output (e.g., Codex-style mutual review) lack explicit termination conditions, creating infinite loop risk. Auto-Flow blocks this through three mechanisms: **maximum regression count + cause classification + defined human escalation point.**

**This principle applies to all future additions**

When introducing any new loop structure to this system, it must have an explicit termination condition. A loop without a termination condition is not permitted. This is not a guideline — it is a hard constraint.

---

### Decision 8: Phase Transitions Use a Three-Party Split (Teammate / Orchestrator / Hook)

**What it does**

Phase transitions in Auto-Flow are split across three parties so that no single party owns both the content judgment and the state mutation. Each party performs exactly one mechanical role at a transition.

| Party | Responsibility at a phase transition |
|-------|--------------------------------------|
| Teammate | Produces the artifact required by the current phase and emits a `transition-request` message addressed to the Orchestrator, naming the next phase and citing the evidence path. |
| Orchestrator | Acts as a mechanical pass-through — invokes the `phase-set` helper with the `evidence` field passed verbatim. Does not read, summarize, or judge the evidence content. |
| Hook | Performs mechanical prerequisite verification (required artifacts exist, GATE evaluation PASS where applicable, role marker correct) and either allows or blocks the transition. |

**Why it works this way**

Bias isolation. Phase progression mixes two different concerns: *content correctness* (is the artifact good?) and *state mutation* (advance the phase pointer). If the same party owns both, the party that judges content also chooses whether to advance — and self-reinforcement bias creeps back in. The three-party split ensures the Teammate provides evidence but cannot self-promote, the Orchestrator advances state but cannot interpret content, and the Hook checks mechanical prerequisites without authoring or judging artifacts. Any party doing more than its row would force content judgment back into the loop.

**Rejected alternatives**

- **Model 1: Teammate-autonomous.** The teammate writes its own phase file at completion. Rejected because it produces a phase-file blind spot — neither the Orchestrator nor the Hook owns the update, so a teammate can advance the system into a phase it did not earn, and there is no mechanical record of who authorized the transition.
- **Model 2: Orchestrator-gated.** The Orchestrator reads the evidence and decides whether the transition is justified. Rejected because gating forces the Orchestrator to interpret evidence content, which violates the Orchestrator-does-not-judge-content invariant established by the prompt rules and Decision 1. Once the Orchestrator interprets evidence in one place, the same justification ("just a quick check") leaks into evaluation prompts and DIAGNOSE inputs.

The mechanical entry point invoked by the Orchestrator is the `phase-set` helper. The `phase-set` helper itself is tracked separately as Item 2 (#28) and will be introduced by that issue; this decision specifies the contract it must satisfy (mechanical pass-through, evidence verbatim, no content interpretation).

---

### Decision 9: Orchestrator Holds Five Facilitator Facets

**What it does**

The Orchestrator's mechanical-pass-through stance decomposes into five simultaneous facets. The Orchestrator holds all five at all times during autoflow execution; no facet activates or deactivates based on situation.

| Facet | Behavior |
|-------|----------|
| Space Holder | The Orchestrator reads pending Teammate messages on a pull cadence and waits silently between reads. Reading is the only inbound action. |
| Flow Observer | The Orchestrator records the inbound stream — `transition-request` messages, status reports, questions — without interpreting their content. |
| Signal Responder | The Orchestrator emits outbound messages only when one of the four enumerated signal types fires (see signal-type table below). |
| Time Steward | The Orchestrator tracks the up-front deadline communicated to each Teammate at DISPATCH (`CLAUDE.md:301-323`) and emits exactly one reminder at or after that deadline. After the single reminder, the post-reminder path is the Regression Rules table at `CLAUDE.md:179-185` — never a second reminder. |
| Result Receiver | The Orchestrator verifies that an inbound `transition-request` matches the canonical format. The verification is mechanical: it checks the presence of the `@orchestrator transition-request` header, the `from`, `to`, and `evidence` fields, that the addressee is the Orchestrator (not a sibling Teammate per `CLAUDE.md:116`), and — for evaluator outputs — the `evaluator.role_marker` field per `CLAUDE.md:60`. The verification excludes reading the contents of `evidence`, judging whether the artifact at the cited path is correct, and judging whether the `from`/`to` pair is a valid transition; all three exclusions belong to the Hook or to a fresh Evaluation AI. |

The four signal types — and the only signal types — that authorize an outbound message from the Orchestrator are:

| # | Signal type | Anchored flow event |
|---|-------------|---------------------|
| 1 | transition-request acknowledgment | `CLAUDE.md:109-118` — the Orchestrator invokes `phase-set` after a Teammate emits a `transition-request`. |
| 2 | dispute arbitration trigger | `CLAUDE.md:168` — the Orchestrator spawns a fresh Evaluation AI when VERIFY DEADLOCK occurs. |
| 3 | deadline reminder | Time Steward — exactly one outbound reminder per task, sent at or after the up-front deadline communicated at DISPATCH. |
| 4 | gate evaluator spawn | `CLAUDE.md:92` — the Orchestrator spawns a fresh Evaluation AI when entering GATE:HYPOTHESIS, GATE:PLAN, or GATE:QUALITY. The spawn does not violate the no-interpret-evidence invariant because the Orchestrator hands raw artifacts to the Evaluation AI without reading or summarizing them; the Evaluation AI performs all content judgment. |

Signal 2 and signal 4 are listed separately even though both spawn a fresh Evaluation AI. Signal 2 is reactive to a deadlock; signal 4 is proactive at gate entry. Conflating them would suppress the difference between "evaluator as referee" and "evaluator as gatekeeper."

**Why it works this way**

Negative-form constraints alone leave loopholes — an LLM can rationalize an outbound message as "not a nudge, just a check-in" and satisfy a prohibition while violating its intent (the same failure mode named in the Behavioral Rule Authoring Style section). Naming five positive facets and four enumerated signal types replaces "do not message outside the protocol" with "the Orchestrator emits one of these four signals." The positive enumeration is mechanically observable: any outbound message either matches one of the four signal types or it does not.

The five facets operationalize the existing invariants — "Orchestrator does not implement" (`CLAUDE.md:144`) and "Orchestrator does not interpret evidence content" (`CLAUDE.md:80,117`). They do not introduce new responsibilities. They make the existing stance discoverable in one place rather than scattered across negative-form rules.

**Rejected alternatives**

- **Alternating modes for Flow Observer and Signal Responder.** Treating the inbound and outbound facets as modes the Orchestrator switches between would require the Orchestrator to decide which mode it is in. That decision is itself a content judgment and would re-introduce the Model 2 defect rejected at Decision 8. The two facets are therefore framed as simultaneous facets of one stance.
- **Numeric polling interval for Space Holder.** Prescribing "poll every N minutes" creates a discretionary outbound signal — the Orchestrator could rationalize a poll as a courtesy ping. The Space Holder facet is bounded instead by what each poll does: read inbound messages, do not send.
- **Recurring or fixed-fraction deadline reminders.** "Remind at 80% elapsed" and "remind every hour after the deadline" are both rejected because each creates a class of outbound message that can be rationalized into many outbound messages. The Time Steward facet permits exactly one reminder, at or after the up-front deadline.
- **Result Receiver verifying evidence content.** Extending verification to "is the artifact at the cited path correct?" reintroduces the Model 2 defect rejected at Decision 8. Result Receiver verification therefore terminates at the canonical `transition-request` shape.
- **Human escalation as the fourth signal type.** Rejected because escalation is the result of an exhausted retry loop (`CLAUDE.md:144`), not a routine outbound signal. Folding it into the four-signal-type table would conflate routine flow with terminal handoff.

**What this means**

The five facets are simultaneous facets of one stance, not alternating modes and not a checklist. The Orchestrator does not select which facet is active. The Orchestrator's outbound surface is closed: any message the Orchestrator sends matches one of the four signal types in the table above, or the Orchestrator does not send it. The Result Receiver bound is mechanical: structural checks on the `transition-request` shape only, no reading of `evidence` content, no judgment of artifact correctness — those judgments remain with the Hook and with fresh Evaluation AIs.

---

### Decision 10: State Tree Is Namespaced by Sub-Repo Identifier

**What it does**

`.autoflow-state/` lives in the orchestrator's host repo working tree only. It never appears inside a sub-repo working tree. The state directory is uniformly namespaced as `.autoflow-state/<sub-repo-id>/<issue-number>/`, with `<sub-repo-id>` defaulting to `self` for single-repo deployments. The `current-issue` file holds a single line of the form `<sub-repo-id>/<issue-number>` (legacy bare-integer values are honored as `self/<integer>`). The `phase-set` helper refuses to write when `git -C "$CLAUDE_PROJECT_DIR" rev-parse --show-superproject-working-tree` returns a non-empty path, exiting with code 65; the env override `AUTOFLOW_ALLOW_SUBMODULE_STATE=1` exists for testing/CI only. PREFLIGHT additionally produces an `intake.md` artifact at `${STATE_DIR}/<sub-repo-id>/<issue-number>/intake.md` with three required sections (`## Sub-Repo`, `## Branch`, `## State Location`); the gate hook warns at PREFLIGHT and hard-blocks at DIAGNOSE+ if the artifact is missing.

**Why it works this way**

Without a namespace key the state layout has no separation between *where work happens* (a sub-repo) and *where orchestration is recorded* (the host repo that owns the orchestrator session). Issue #40's reference incident — state for issue #31 written under `services/autoflow-upstream/.autoflow-state/31/` — happened because `phase-set` and `check-autoflow-gate.sh` trusted `CLAUDE_PROJECT_DIR` verbatim and the directory layout had no slot to record which sub-repo the issue belonged to. Anchoring all state to the host repo makes the host the single auditable authority, and prefixing every issue with a sub-repo identifier preserves multi-repo deployments without creating cross-host fragmentation. The submodule-rejection probe at the writer (not the gate) catches the misroute the moment it would happen, and the env override exists so test fixtures can still create state inside a fixture submodule. `intake.md` exists because `requirements.md` is consumed by Test/Developer AI and conflating provenance crowds it; intake records the routing facts (sub-repo identifier, branch, state path) once at PREFLIGHT and is read by the gate hook to confirm the orchestrator declared its anchor before any analysis begins.

**Rejected alternatives**

- **Use `git rev-parse --show-toplevel` basename to compute `<sub-repo-id>` inside `phase-set`.** Rejected because the script then has to know which clone is the host and which is the sub-repo; the orchestrator already has that knowledge and can pass it via `AUTOFLOW_SUBREPO_ID`. Keeping computation outside the script preserves the single-responsibility boundary.
- **Auto-migrate legacy `.autoflow-state/<N>/` directories into `.autoflow-state/self/<N>/`.** Rejected because in-flight phase transitions would silently relocate mid-run; the cost of one manual `mv` is bounded, the cost of a wrong migration is unbounded.
- **JSON `current-issue` carrying explicit `{ "subrepo": ..., "issue": ... }`.** Rejected because every shell consumer would need a parser; the slash-separated text form is parseable by `case "$raw" in */*) ... esac` in two lines and cannot grow extra fields by accident.
- **Remote-URL slug as the sub-repo identifier.** Rejected because remote URLs require network access to canonicalize, change when a fork is renamed, and disagree with the on-disk submodule path that contributors actually navigate.
- **Cross-host aggregation tooling that merges multiple host-repo state trees.** Rejected because it reintroduces the fragmentation the host repo was chosen to eliminate; if multiple hosts coordinate, that coordination belongs at the protocol layer (e.g., GitHub Issues), not in `.autoflow-state/`.
- **Enforce intake schema in `phase-set` rather than the gate hook.** Rejected because it would conflate the writer (sole appender of phase/history) with the validator (sole reader of artifact preconditions); the writer/gate split established by Decision 8 must be preserved.

**What this means**

The host repo is the only writeable home for `.autoflow-state/`. A sub-repo containing an `.autoflow-state/` directory is a misconfiguration that `phase-set` will catch the next time the orchestrator tries to write. New issues land at `.autoflow-state/<sub-repo-id>/<issue-number>/` regardless of whether the project is single-repo (`<sub-repo-id>=self`) or multi-repo (`<sub-repo-id>=<submodule-basename>`); the gate hook treats the namespaced layout as the authoritative shape and reads legacy flat-layout directories only as a transitional accommodation. PREFLIGHT must declare the routing facts in `intake.md` before DIAGNOSE; this declaration is what the gate hook checks, not the orchestrator's own assertions about where it is running.

---

## Evaluation System Design Intent

### Why Scoring Criteria Are Not Fixed

The evaluation categories and weights in CLAUDE.md must be customized per project. They should reflect "what actually matters in this project," not universal standards. As a project matures, patterns emerge showing which items correlate with actual failures. At that point, humans adjust the criteria.

### Why PASS Criteria Are Strict (Average >= 7.5, Individual >= 7)

Lenient criteria create a pattern of "scoring high on easy items to raise the average while passing difficult items." This is why individual minimum thresholds exist. The reason security score <= 3 triggers mandatory rework is the same — some items cannot be diluted by averaging.

### The Role of Issue Analysis Evaluation (GATE:HYPOTHESIS)

The purpose is to ensure only well-analyzed issues proceed to implementation. Entering implementation with insufficient analysis incurs greater costs later. The stricter this gate, the higher the quality of subsequent phases.

---

## What Must NOT Be Done in This System

The following may look like "better approaches" but undermine core principles:

| Do Not | Reason |
|--------|--------|
| Give AI-A the issue content | Context contamination → bias introduced |
| Reuse the Evaluation AI | Self-reinforcement bias → independence lost |
| Trust the Hook's `pass` field | Trusting AI self-report → gate neutralized |
| Inject past evaluation results into current analysis | Bias propagation → system hardens in one direction |
| Allow phase-skipping judgment | "This one is simple" is itself a biased judgment |
| Let the pipeline modify its own criteria | Judgment tracing impossible → trust chain collapse |
| Design loops without termination conditions | No maximum retry → infinite loop risk → system hangs |
| Let a Teammate send a phase-transition request to another Teammate | Bypasses the Orchestrator — no party authorizes peer transitions, breaks the three-party split |
| Send Orchestrator messages outside the four enumerated signal types | Discretionary outbound messaging reintroduces content judgment by the Orchestrator and breaks the closed signal surface defined in Decision 9 |

---

## Known Limitations and Ongoing Discussions

### Limitations

- **No failure learning loop**: Currently accumulated manually via issue comments. Pass/fail pattern analysis is performed by humans externally.
- **No cross-issue correlation detection**: Cannot automatically detect repeated similar-pattern issues. Under internal discussion.
- **No lightweight mode**: Full phase execution even for small changes. Overhead exists.

### Under Discussion

- Including related issue and commit history lookup at DIAGNOSE entry (factual lookup, not bias injection)
- Systematizing issue preparation stages through external cross-issue correlation analysis

---

## Behavioral Rule Authoring Style

Every behavioral rule in this system should have three elements:

1. **The action** — stated in positive form: "the AI does X."
2. **The reason** — why this action is required.
3. **Step instructions** — how to perform it, if non-obvious.

**Why positive form over negative prohibition**

Negative rules ("do not do X") leave loopholes: an LLM can reason "I did not do X, I did Y instead" and satisfy the prohibition while violating the intent. Positive rules anchor the behavior — "cite file paths and line numbers" is harder to route around than "no vague statements."

The classic failure mode: `[DENY] No opinions or leading phrases` — an LLM can silently reframe an opinion as a "neutral observation" and pass the check. The positive form breaks this: `[MUST] State observations as direct facts — cite file paths and line numbers` gives a concrete, verifiable action.

**Example (before/after)**

Before:
```
4. **[DENY]** No opinions, interpretations, or leading phrases ("consider that ~", "note that ~", "this is ~ so")
```

After:
```
4. **[MUST]** State observations as direct facts — cite file paths and line numbers. Prohibited forms: "consider that ~", "note that ~", "this is ~ so".
```

The "Prohibited forms" note is kept as a supplementary anchor. The rule is now anchored on the positive behavior first.

**When the forbidden-form note is still needed**

A forbidden-form note is appropriate when listing specific prohibited patterns (as above). It is NOT a substitute for stating what the AI should do. Rule of thumb: the `[MUST]` positive action comes first; the prohibited forms are the safety net.

---

## Summary: The Design Philosophy of This System

**The pipeline's goal is not to get better with each run, but to perform well without bias every single time.**

Improvement does not happen automatically inside the pipeline. Humans observe patterns, make judgments, modify CLAUDE.md, and those changes take effect from the next issue onward. The pipeline is a tool that executes those criteria without bias.

When adding new features or modifications to this system, ask this question first:

> "Does this change eliminate a bias, or does it introduce one?"
