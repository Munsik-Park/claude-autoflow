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
PASS_THRESHOLD=7

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
# Read evaluation score
# ---------------------------------------------------------------------------
# Expects a file: .autoflow-state/<issue>/evaluation.json
# Must contain "overall" field with numeric score
get_evaluation_score() {
  local issue="$1"
  local eval_file="${STATE_DIR}/${issue}/evaluation.json"
  if [[ ! -f "$eval_file" ]]; then
    echo "0"
    return
  fi

  # Extract "overall" score — works with basic JSON
  local score
  score=$(grep -o '"overall"[[:space:]]*:[[:space:]]*[0-9.]*' "$eval_file" \
          | head -1 \
          | grep -o '[0-9.]*$' || echo "0")
  echo "$score"
}

# ---------------------------------------------------------------------------
# Check: Is evaluation passing?
# ---------------------------------------------------------------------------
check_evaluation_pass() {
  local issue="$1"
  local score
  score=$(get_evaluation_score "$issue")

  # Compare using awk for float comparison
  local passed
  passed=$(awk "BEGIN { print ($score >= $PASS_THRESHOLD) ? 1 : 0 }")

  if [[ "$passed" -eq 1 ]]; then
    log_pass "Evaluation score: ${score} (>= ${PASS_THRESHOLD}) — PASS"
    return 0
  else
    log_fail "Evaluation score: ${score} (< ${PASS_THRESHOLD}) — FAIL"
    log_info "Return to STEP 3 and address evaluation feedback before proceeding."
    return 1
  fi
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
    # Steps 0-5: No gate block — these are pre-evaluation steps
    [0-5])
      log_pass "STEP ${step} — no gate restrictions"
      ;;

    # Step 6: Evaluation in progress — block commits until evaluation completes
    6)
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
