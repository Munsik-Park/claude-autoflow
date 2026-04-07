# Evaluation System

> The Auto-Flow evaluation system provides quantified quality assessment at STEP 6, ensuring consistent standards across all changes.

---

## Overview

The Evaluation AI is an **independent agent** that scores completed work before it reaches human review. This separation ensures objectivity — the agent that wrote the code never evaluates it.

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

A change **passes** evaluation when:

1. **Overall weighted score >= 7**
2. **No individual category scores below 5**

If either condition is not met, the change **fails** and must be revised (STEP 7).

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
code_quality:   7 * 0.20 = 1.40
test_coverage:  7 * 0.20 = 1.40
security:       9 * 0.15 = 1.35
performance:    7 * 0.15 = 1.05
                         ------
overall:                   7.60  → PASS
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
4. **Test results** (test output from STEP 5)
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

1. The Evaluation AI receives the **updated** diff and test results
2. It also receives the **previous evaluation** for context
3. It re-evaluates from scratch (not incrementally)
4. The new evaluation replaces the old one in the state file

### Maximum Revision Cycles

- **3 revision cycles maximum** before human escalation
- Each cycle: STEP 7 (revision) → STEP 6 (re-evaluation)
- If still failing after 3 cycles, the Orchestrator escalates to a human with all evaluation reports

---

## Hook Integration

The `check-autoflow-gate.sh` hook reads the evaluation JSON to enforce the gate:

- At **STEP 6**: Checks if `evaluation.json` exists and `pass === true`
- At **STEP 8**: Re-verifies that the evaluation still passes before allowing PR creation
- The hook uses the `overall` score and `PASS_THRESHOLD` (default: 7)

---

## Customizing the Evaluation System

### Adjusting Weights

Modify the category weights in `CLAUDE.md` to match your project priorities:
- **Security-critical project**: Increase security weight to 25%, reduce performance to 5%
- **Performance-critical project**: Increase performance weight to 25%, reduce code quality to 10%

### Adjusting PASS Threshold

The default threshold is 7. To change:
1. Update `PASS_THRESHOLD` in `check-autoflow-gate.sh`
2. Update the PASS criteria in `CLAUDE.md`
3. Document the change and rationale

### Adding Categories

You can add project-specific evaluation categories:
- **Accessibility** (for frontend projects)
- **Documentation** (for API projects)
- **Backwards Compatibility** (for library projects)

Update the weights so all categories sum to 100%.
