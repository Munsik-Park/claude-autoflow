#!/usr/bin/env bash
# =============================================================================
# Auto-Flow Gate Hook
# =============================================================================
# Enforces Auto-Flow STEP progression by validating state files before
# allowing commits or PR creation.
#
# Usage:
#   This script is called by Claude Code hooks. It checks .autoflow-state/
#   files to ensure the current STEP's exit criteria are met.
#
# Environment:
#   CLAUDE_PROJECT_DIR — Root directory of the project (set by Claude Code)
#
# Exit codes:
#   0 — Gate passed, proceed
#   1 — Gate blocked, requirements not met
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.autoflow-state"
PASS_THRESHOLD="7.5"
MIN_CATEGORY_SCORE=7
SECURITY_AUTO_FAIL_THRESHOLD=3

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log_info()  { echo "[AutoFlow Gate] ℹ  $*"; }
log_pass()  { echo "[AutoFlow Gate] ✅ $*"; }
log_fail()  { echo "[AutoFlow Gate] ❌ $*"; }
log_warn()  { echo "[AutoFlow Gate] ⚠️  $*"; }

# ---------------------------------------------------------------------------
# Resolve current issue
# ---------------------------------------------------------------------------
# Expects a file: .autoflow-state/current-issue
# Contents: issue number (e.g., "123")
get_current_issue() {
  local issue_file="${STATE_DIR}/current-issue"
  if [[ ! -f "$issue_file" ]]; then
    log_warn "No current-issue file found at ${issue_file}"
    log_info "Skipping gate check (no active Auto-Flow session)"
    exit 0
  fi
  cat "$issue_file" | tr -d '[:space:]'
}

# ---------------------------------------------------------------------------
# Read STEP status for an issue
# ---------------------------------------------------------------------------
# Expects a file: .autoflow-state/<issue>/step
# Contents: step number (e.g., "6")
get_current_step() {
  local issue="$1"
  local step_file="${STATE_DIR}/${issue}/step"
  if [[ ! -f "$step_file" ]]; then
    log_fail "No step file found for issue #${issue}"
    log_info "Expected: ${step_file}"
    exit 1
  fi
  cat "$step_file" | tr -d '[:space:]'
}

# ---------------------------------------------------------------------------
# Extract a score value from evaluation JSON
# ---------------------------------------------------------------------------
# Uses basic grep/sed — no jq dependency required
extract_score() {
  local file="$1"
  local key="$2"
  grep -o "\"${key}\"[[:space:]]*:[[:space:]]*[0-9.]*" "$file" \
    | head -1 \
    | grep -o '[0-9.]*$' || echo "0"
}

# ---------------------------------------------------------------------------
# Check: Is evaluation passing?
# ---------------------------------------------------------------------------
# IMPORTANT: This function does NOT read the AI-generated "pass" field.
# It calculates pass/fail independently from the raw scores.
# Reason: AI self-reporting is unreliable — it may implicitly adjust
# standards while scoring. The gate operates on numbers, not AI judgment.
# See: docs/design-rationale.md (Decision 3)
check_evaluation_pass() {
  local issue="$1"
  local eval_file="${STATE_DIR}/${issue}/evaluation.json"

  if [[ ! -f "$eval_file" ]]; then
    log_fail "No evaluation file found: ${eval_file}"
    return 1
  fi

  # Extract individual category scores from the raw "scores" object
  local correctness code_quality test_coverage security performance
  correctness=$(extract_score "$eval_file" "correctness")
  code_quality=$(extract_score "$eval_file" "code_quality")
  test_coverage=$(extract_score "$eval_file" "test_coverage")
  security=$(extract_score "$eval_file" "security")
  performance=$(extract_score "$eval_file" "performance")

  log_info "Scores — correctness:${correctness} code_quality:${code_quality} test_coverage:${test_coverage} security:${security} performance:${performance}"

  # Calculate weighted average from raw scores (NOT using AI's "overall" field)
  local calculated_overall
  calculated_overall=$(awk "BEGIN { printf \"%.2f\", ($correctness * 0.30) + ($code_quality * 0.20) + ($test_coverage * 0.20) + ($security * 0.15) + ($performance * 0.15) }")

  log_info "Calculated overall: ${calculated_overall} (threshold: ${PASS_THRESHOLD})"

  # Check 1: Security auto-fail
  local security_fail
  security_fail=$(awk "BEGIN { print ($security <= $SECURITY_AUTO_FAIL_THRESHOLD) ? 1 : 0 }")
  if [[ "$security_fail" -eq 1 ]]; then
    log_fail "Security score: ${security} (<= ${SECURITY_AUTO_FAIL_THRESHOLD}) — AUTO-FAIL (mandatory rework)"
    return 1
  fi

  # Check 2: Individual category minimums
  local min_fail
  min_fail=$(awk "BEGIN {
    min = $correctness
    if ($code_quality < min) min = $code_quality
    if ($test_coverage < min) min = $test_coverage
    if ($security < min) min = $security
    if ($performance < min) min = $performance
    print (min < $MIN_CATEGORY_SCORE) ? 1 : 0
  }")
  if [[ "$min_fail" -eq 1 ]]; then
    log_fail "One or more categories below minimum (${MIN_CATEGORY_SCORE}) — FAIL"
    return 1
  fi

  # Check 3: Overall weighted average
  local overall_pass
  overall_pass=$(awk "BEGIN { print ($calculated_overall >= $PASS_THRESHOLD) ? 1 : 0 }")
  if [[ "$overall_pass" -eq 1 ]]; then
    log_pass "Evaluation: ${calculated_overall} (>= ${PASS_THRESHOLD}), all categories >= ${MIN_CATEGORY_SCORE} — PASS"
    return 0
  else
    log_fail "Overall score: ${calculated_overall} (< ${PASS_THRESHOLD}) — FAIL"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Check: Does delegation.md exist?
# ---------------------------------------------------------------------------
check_delegation_exists() {
  local issue="$1"
  local delegation_file="${STATE_DIR}/${issue}/delegation.md"
  if [[ ! -f "$delegation_file" ]]; then
    log_fail "delegation.md not found: ${delegation_file}"
    log_info "STEP 4 must produce delegation.md before proceeding"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Main gate logic
# ---------------------------------------------------------------------------
main() {
  log_info "Running Auto-Flow gate check..."

  local issue
  issue=$(get_current_issue)

  if [[ -z "$issue" ]]; then
    log_info "No active issue — skipping gate"
    exit 0
  fi

  log_info "Active issue: #${issue}"

  local step
  step=$(get_current_step "$issue")
  log_info "Current STEP: ${step}"

  case "$step" in
    # Steps 0-4: No gate block — these are pre-evaluation steps
    [0-4])
      log_pass "STEP ${step} — no gate restrictions"
      ;;

    # Step 5: Delegation gate — delegation.md must exist
    5)
      check_delegation_exists "$issue" || exit 1
      log_pass "STEP ${step} — delegation.md found"
      ;;

    # Step 6: Evaluation in progress — block commits until evaluation completes
    6)
      check_delegation_exists "$issue" || exit 1
      log_info "STEP 6 — checking evaluation result..."
      check_evaluation_pass "$issue"
      ;;

    # Step 7: Revision — allow commits (working on fixes)
    7)
      log_pass "STEP 7 (revision) — commits allowed"
      ;;

    # Step 8: PR phase — evaluation must have passed
    8)
      log_info "STEP 8 — verifying evaluation before PR..."
      check_evaluation_pass "$issue"
      ;;

    # Step 9: Merge phase — human action required
    9)
      log_warn "STEP 9 — waiting for human merge approval"
      ;;

    *)
      log_warn "Unknown STEP: ${step} — allowing by default"
      ;;
  esac

  log_pass "Gate check complete"
  exit 0
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
main "$@"
