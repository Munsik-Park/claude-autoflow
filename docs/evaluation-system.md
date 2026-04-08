# Evaluation System

> The Auto-Flow evaluation system provides quantified quality assessment at STEPs 1.5 and 6, ensuring consistent standards across all changes.

---

## Overview

The Evaluation AI is an **independent agent** that scores completed work before it reaches human review. This separation ensures objectivity — the agent that wrote the code never evaluates it.

### Critical Rule: Fresh Spawn Every Time

**The Evaluation AI must be spawned fresh for every evaluation** — at STEPs 1.5, 3, and 6. It carries no prior conversation history. This is mandatory, not optional.

**Why**: When the same agent creates a plan and evaluates it, it struggles to reject its own work. A freshly spawned agent sees only the deliverable — it has no investment in the process. Bias elimination takes priority over token cost savings. See [docs/design-rationale.md](design-rationale.md#decision-2-evaluation-ai-is-spawned-fresh-every-time).

---

## 10-Point Scale

| Score | Label | Meaning |
|-------|-------|---------|
| 10 | Outstanding | Exceptional quality, innovative approach |
| 9 | Excellent | Exceeds requirements, very clean |
| 8 | Very Good | Solid implementation, minor polish possible |
| 7 | Good | Meets all requirements — **minimum PASS** |
| 6 | Acceptable | Works but has notable issues |
| 5 | Marginal | Functional but needs improvement |
| 4 | Below Average | Significant problems |
| 3 | Poor | Major issues, partially functional |
| 2 | Very Poor | Barely functional |
| 1 | Failing | Does not meet requirements |

---

## PASS Criteria

A change **passes** evaluation when ALL of the following are true:

1. **Overall weighted score >= 7.5**
2. **No individual category score below 7**
3. **Consistency score is NOT <= 3** (auto-fail trigger)

If any condition is not met, the change **fails**.

### Why These Thresholds Are Strict

Lenient criteria create a pattern of "scoring high on easy categories to raise the average while passing weak categories." The individual minimum threshold (>= 7) prevents this gaming. Consistency <= 3 triggers mandatory rework because violating core design principles cannot be diluted by averaging — some items are non-negotiable.

### Auto-FAIL Rules

| Condition | Result | Action |
|-----------|--------|--------|
| Consistency <= 3 | AUTO-FAIL | → STEP 4 (mandatory major rework) |
| Any category < 7 | FAIL | → STEP 7 (revision) |
| Overall < 7.5 | FAIL | → STEP 7 (revision) |

---

## Scoring Categories

| Category | Weight | Description |
|----------|--------|-------------|
| **Correctness** | 25% | Does the implementation fulfill all requirements from the issue? Does it handle edge cases? |
| **Quality** | 20% | Is the code clean, readable, and maintainable? Does it follow project conventions? |
| **Test Coverage** | 20% | Are critical paths tested? Are edge cases covered? Do tests actually validate behavior? |
| **Consistency** | 20% | Does the change align with design-rationale.md principles? Does it follow established patterns? |
| **Documentation** | 15% | Are docs updated, links valid, examples accurate? |

### Why "Consistency" Replaces "Security"

This is a template project. The critical risk is not security vulnerabilities but **violating core design principles** (e.g., giving AI-A the issue content "for efficiency"). Consistency scoring catches this. Consistency <= 3 triggers AUTO-FAIL because undermining a core principle from design-rationale.md requires mandatory rework regardless of other scores.

### Weighted Score Calculation

The gate hook dynamically reads all categories from the `scores` object and calculates the weighted average. If a `weights.json` file exists for the issue, those weights are used. Otherwise, equal weights (1/N) are applied across all categories.

```
Example with default CLAUDE.md weights (via weights.json):

overall = (correctness * 0.25) + (quality * 0.20) + (test_coverage * 0.20) 
        + (consistency * 0.20) + (documentation * 0.15)
```

### Example

```
correctness:    8 * 0.25 = 2.00
quality:        8 * 0.20 = 1.60
test_coverage:  7 * 0.20 = 1.40
consistency:    9 * 0.20 = 1.80
documentation:  8 * 0.15 = 1.20
                         ------
overall:                   8.00  → PASS (>= 7.5, all categories >= 7)
```

```
correctness:    9 * 0.25 = 2.25
quality:        8 * 0.20 = 1.60
test_coverage:  6 * 0.20 = 1.20    ← below 7!
consistency:    8 * 0.20 = 1.60
documentation:  8 * 0.15 = 1.20
                         ------
overall:                   7.85  → FAIL (test_coverage 6 < minimum 7)
```

---

## Evaluation Output Format

The Evaluation AI produces a JSON report saved to `.autoflow-state/<issue>/evaluation.json`:

```json
{
  "step": 6,
  "issue": "#123",
  "evaluator": "evaluation-ai",
  "timestamp": "2025-01-15T10:30:00Z",
  "scores": {
    "correctness": { "score": 8, "reason": "All requirements met. Edge case for empty input handled correctly." },
    "quality": { "score": 7, "reason": "Clean implementation. Consider extracting the validation logic into a helper." },
    "test_coverage": { "score": 7, "reason": "Good coverage of happy path. Add a test for concurrent access." },
    "consistency": { "score": 9, "reason": "Aligned with design-rationale.md principles throughout." },
    "documentation": { "score": 7, "reason": "Docs updated. Internal links valid." }
  },
  "blocking_issues": [],
  "suggestions": [
    "Consider adding a test for the concurrent access scenario",
    "The validation helper extraction would improve readability"
  ]
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `step` | number | Always `6` for evaluation |
| `issue` | string | Issue reference (e.g., "#123") |
| `evaluator` | string | Agent identifier |
| `timestamp` | string | ISO 8601 timestamp |
| `scores` | object | Per-category scores — structured format with `score` and `reason` |
| `blocking_issues` | array | Issues that must be fixed (empty if pass) |
| `suggestions` | array | Non-blocking improvement ideas |

> **Note**: The hook does NOT read any AI-generated `pass` or `overall` fields. It calculates pass/fail independently from the raw `scores` values. Flat format (`"key": N`) is also supported for backward compatibility.

---

## Evaluation Process

### Input to Evaluation AI

The Evaluation AI receives:
1. **Issue requirements** (`.autoflow-state/<issue>/requirements.md`)
2. **Implementation plan** (`.autoflow-state/<issue>/plan.md`)
3. **Code diff** (`git diff` of the changes)
4. **Test results** (test output from STEP 5c)

### Evaluation Steps

1. **Read** all inputs thoroughly
2. **Verify correctness** against requirements
3. **Review code quality** against project conventions
4. **Assess test coverage** — are critical paths tested?
5. **Check consistency** against design-rationale.md principles
6. **Evaluate documentation** — are docs updated, links valid?
7. **Score** each category
8. **Calculate** weighted overall score
9. **Determine** PASS/FAIL
10. **Write** evaluation report to state file

---

## Re-Evaluation (After STEP 7)

When a change fails and goes through STEP 7 (revision):

1. A **freshly spawned** Evaluation AI receives the **updated** diff and test results
2. It also receives the **previous evaluation** for context
3. It re-evaluates from scratch (not incrementally)
4. The new evaluation replaces the old one in the state file

> The re-evaluation AI is also spawned fresh — never reused from the previous evaluation cycle.

### Maximum Revision Cycles

- **3 revision cycles maximum** before human escalation
- Each cycle: STEP 7 (revision) → STEP 6 (re-evaluation)
- If still failing after 3 cycles, the Orchestrator escalates to a human with all evaluation reports

---

## Hook Integration

The `check-autoflow-gate.sh` hook enforces the gate by **calculating pass/fail independently from raw scores**:

- The hook **does NOT read the AI-generated `pass` or `overall` fields**
- It dynamically discovers all keys in the `scores` object (no hardcoded category names)
- It extracts individual scores, handling both flat (`"key": N`) and structured (`"key": {"score": N, "reason": "..."}`) formats
- It reads weights from `.autoflow-state/<issue>/weights.json` if available, otherwise uses equal weights (1/N)
- It checks: weighted average >= 7.5, all categories >= 7, auto-fail key > 3
- This design brings the trust chain down to the script level — AI judgment is bypassed

> **Why?** AI tends to implicitly adjust standards while scoring, or interpret edge cases favorably. The hook ignores AI judgment and checks only numbers. See [docs/design-rationale.md](design-rationale.md#decision-3-the-hook-does-not-trust-ais-pass-judgment).

---

## Customizing the Evaluation System

### Dynamic Category Support

The gate hook dynamically enumerates all keys in the `scores` object. You are not limited to the default five categories — any category names work, as long as they appear in the evaluation JSON.

### Configuring Weights

Create a `weights.json` file in `.autoflow-state/<issue>/` to configure per-category weights:

```json
{
  "correctness": 0.25,
  "quality": 0.20,
  "test_coverage": 0.20,
  "consistency": 0.20,
  "documentation": 0.15
}
```

Without `weights.json`, all categories receive equal weight (1/N where N is the number of categories).

### Adjusting PASS Threshold

The default thresholds are: overall >= 7.5, individual >= 7, auto-fail key <= 3. To change:
1. Update `PASS_THRESHOLD`, `MIN_CATEGORY_SCORE`, and `AUTO_FAIL_THRESHOLD` in `check-autoflow-gate.sh`
2. Update the PASS criteria in `CLAUDE.md`
3. Document the change and rationale

### Configuring the Auto-Fail Key

The auto-fail key defaults to `consistency`. To change it, set the `AUTO_FAIL_KEY` environment variable:

```bash
AUTO_FAIL_KEY=security bash .claude/hooks/check-autoflow-gate.sh
```

If the configured auto-fail key does not exist in the evaluation scores, no auto-fail check is performed.

### Adding Custom Categories

Add any category to the evaluation JSON — the hook discovers them automatically. For example, a frontend project might use:

```json
{
  "scores": {
    "correctness": { "score": 8, "reason": "Requirements met" },
    "accessibility": { "score": 9, "reason": "WCAG AA compliant" },
    "performance": { "score": 7, "reason": "Lighthouse score acceptable" }
  }
}
```

Update `weights.json` to assign appropriate weights to your custom categories. If weights are omitted, all categories are weighted equally.
