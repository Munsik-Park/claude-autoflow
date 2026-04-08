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
3. **Security score is NOT <= 3** (auto-fail trigger)

If any condition is not met, the change **fails**.

### Why These Thresholds Are Strict

Lenient criteria create a pattern of "scoring high on easy categories to raise the average while passing weak categories." The individual minimum threshold (>= 7) prevents this gaming. Security <= 3 triggers mandatory rework because security cannot be diluted by averaging — some items are non-negotiable.

### Auto-FAIL Rules

| Condition | Result | Action |
|-----------|--------|--------|
| Security <= 3 | AUTO-FAIL | → STEP 4 (mandatory major rework) |
| Any category < 7 | FAIL | → STEP 7 (revision) |
| Overall < 7.5 | FAIL | → STEP 7 (revision) |

---

## Scoring Categories

| Category | Weight | Description |
|----------|--------|-------------|
| **Correctness** | 30% | Does the implementation fulfill all requirements from the issue? Does it handle edge cases? |
| **Code Quality** | 20% | Is the code clean, readable, and maintainable? Does it follow project conventions? |
| **Test Coverage** | 20% | Are critical paths tested? Are edge cases covered? Do tests actually validate behavior? |
| **Security** | 15% | Are there any new vulnerabilities? Does it pass the security checklist? |
| **Performance** | 15% | Are there any regressions? Is the approach reasonably efficient? |

### Weighted Score Calculation

```
overall = (correctness * 0.30) + (code_quality * 0.20) + (test_coverage * 0.20) 
        + (security * 0.15) + (performance * 0.15)
```

### Example

```
correctness:    8 * 0.30 = 2.40
code_quality:   8 * 0.20 = 1.60
test_coverage:  7 * 0.20 = 1.40
security:       9 * 0.15 = 1.35
performance:    7 * 0.15 = 1.05
                         ------
overall:                   7.80  → PASS (>= 7.5, all categories >= 7)
```

```
correctness:    9 * 0.30 = 2.70
code_quality:   8 * 0.20 = 1.60
test_coverage:  6 * 0.20 = 1.20    ← below 7!
security:       8 * 0.15 = 1.20
performance:    8 * 0.15 = 1.20
                         ------
overall:                   7.90  → FAIL (test_coverage 6 < minimum 7)
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
    "correctness": 8,
    "code_quality": 7,
    "test_coverage": 7,
    "security": 9,
    "performance": 7
  },
  "overall": 7.6,
  "pass": true,
  "category_feedback": {
    "correctness": "All requirements met. Edge case for empty input handled correctly.",
    "code_quality": "Clean implementation. Consider extracting the validation logic into a helper.",
    "test_coverage": "Good coverage of happy path. Add a test for concurrent access.",
    "security": "No issues found. Input validation is thorough.",
    "performance": "Acceptable. The N+1 query in line 45 could be optimized but is not critical."
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
| `scores` | object | Per-category scores (1–10) |
| `overall` | number | Weighted average score |
| `pass` | boolean | Whether criteria are met |
| `category_feedback` | object | Per-category comments |
| `blocking_issues` | array | Issues that must be fixed (empty if pass) |
| `suggestions` | array | Non-blocking improvement ideas |

---

## Evaluation Process

### Input to Evaluation AI

The Evaluation AI receives:
1. **Issue requirements** (`.autoflow-state/<issue>/requirements.md`)
2. **Implementation plan** (`.autoflow-state/<issue>/plan.md`)
3. **Code diff** (`git diff` of the changes)
4. **Test results** (test output from STEP 5c)
5. **Security checklist** (from `docs/security-checklist.md`)

### Evaluation Steps

1. **Read** all inputs thoroughly
2. **Verify correctness** against requirements
3. **Review code quality** against project conventions
4. **Assess test coverage** — are critical paths tested?
5. **Check security** against the security checklist
6. **Evaluate performance** — any regressions or inefficiencies?
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

- The hook **does NOT read the AI-generated `pass` field**
- It extracts individual scores from the `scores` object and calculates the weighted average itself
- It checks: weighted average >= 7.5, all categories >= 7, security > 3
- This design brings the trust chain down to the script level — AI judgment is bypassed

> **Why?** AI tends to implicitly adjust standards while scoring, or interpret edge cases favorably. The hook ignores AI judgment and checks only numbers. See [docs/design-rationale.md](design-rationale.md#decision-3-the-hook-does-not-trust-ais-pass-judgment).

---

## Customizing the Evaluation System

### Adjusting Weights

Modify the category weights in `CLAUDE.md` to match your project priorities:
- **Security-critical project**: Increase security weight to 25%, reduce performance to 5%
- **Performance-critical project**: Increase performance weight to 25%, reduce code quality to 10%

### Adjusting PASS Threshold

The default thresholds are: overall >= 7.5, individual >= 7, security auto-fail <= 3. To change:
1. Update `PASS_THRESHOLD`, `MIN_CATEGORY_SCORE`, and `SECURITY_AUTO_FAIL_THRESHOLD` in `check-autoflow-gate.sh`
2. Update the PASS criteria in `CLAUDE.md`
3. Document the change and rationale

### Adding Categories

You can add project-specific evaluation categories:
- **Accessibility** (for frontend projects)
- **Documentation** (for API projects)
- **Backwards Compatibility** (for library projects)

Update the weights so all categories sum to 100%.
