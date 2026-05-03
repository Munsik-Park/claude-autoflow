#!/usr/bin/env bash
# =============================================================================
# Auto-Flow Gate Hook
# =============================================================================
# Enforces Auto-Flow phase progression by validating state files before
# allowing commits or PR creation.
#
# Phase names (in order):
#   PREFLIGHT → DIAGNOSE → GATE:HYPOTHESIS → ARCHITECT → GATE:PLAN →
#   DISPATCH → RED → GREEN → VERIFY → REFINE → GATE:SECURITY →
#   GATE:QUALITY → SHIP → LAND
#
# Usage:
#   This script is called by Claude Code hooks. It checks .autoflow-state/
#   files to ensure the current phase's exit criteria are met.
#
# Environment:
#   CLAUDE_PROJECT_DIR — Root directory of the project (set by Claude Code)
#   AUTO_FAIL_KEY      — Category key for auto-fail (default: consistency)
#
# Exit codes:
#   0 — Gate passed, proceed
#   1 — Gate blocked, requirements not met
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Early branch: PreToolUse gate on direct writes to phase file
# ---------------------------------------------------------------------------
# When invoked as a Claude Code PreToolUse hook, the script receives a JSON
# payload on stdin describing the tool call. We block direct Write/Edit/
# MultiEdit attempts on .autoflow-state/<issue>/phase unless the env sentinel
# AUTOFLOW_PHASE_SET=1 is set (which only the .claude/scripts/phase-set
# helper sets). Per Claude Code hook semantics, exit code 2 = blocking error
# (model sees stderr + execution prevented). All non-matching cases exit 0
# so the early branch never blocks unrelated operations. If stdin is a TTY
# (CLI invocation) or empty, fall through to the existing main "$@" path.
# ---------------------------------------------------------------------------
if [ ! -t 0 ]; then
  _autoflow_payload="$(cat || true)"
  if [ -n "$_autoflow_payload" ]; then
    # Single awk pass extracts hook_event_name, tool_name, file_path.
    # Values are wrapped in single quotes via awk so eval is safe even if the
    # JSON-extracted strings contain shell metacharacters.
    eval "$(printf '%s' "$_autoflow_payload" | awk -F'"' '
{
  for (i=1; i<=NF; i++) {
    if ($i=="hook_event_name" && ev=="") ev=$(i+2)
    else if ($i=="tool_name" && tn=="") tn=$(i+2)
    else if ($i=="file_path" && fp=="") fp=$(i+2)
  }
}
END {
  printf "_autoflow_event='\''%s'\''\n_autoflow_tool='\''%s'\''\n_autoflow_target='\''%s'\''\n", ev, tn, fp
}')"
    if [ "$_autoflow_event" = "PreToolUse" ]; then
      case "$_autoflow_tool" in
        Write|Edit|MultiEdit)
          # Issue #40 / Decision 6: dual-pattern glob matches both the legacy
          # flat layout (`.autoflow-state/<N>/phase`) and the new namespaced
          # layout (`.autoflow-state/<sub-repo-id>/<N>/phase`). POSIX `*`
          # does not cross `/`, so the two patterns are non-overlapping.
          case "$_autoflow_target" in
            *.autoflow-state/*/*/phase|*.autoflow-state/*/phase)
              if [ -z "${AUTOFLOW_PHASE_SET:-}" ]; then
                echo "[AutoFlow Gate] Direct write to phase file blocked: ${_autoflow_target}" >&2
                echo "[AutoFlow Gate] Use the helper: .claude/scripts/phase-set <PHASE> [--note '<text>']" >&2
                exit 2
              fi
              ;;
            *.autoflow-state/*/*/evaluation.json|*.autoflow-state/*/evaluation.json|*.autoflow-state/*/*/evaluation/*.json|*.autoflow-state/*/evaluation/*.json)
              if [ "$_autoflow_tool" = "Write" ]; then
                # Payload embeds file content as escaped JSON string — \"role_marker\" confirms evaluator object.
                _autoflow_role_marker_found="$(awk \
                  '/\\"role_marker\\"[[:space:]]*:[[:space:]]*\\"[^\\"\\\\]/ { print "found"; exit }' \
                  <<< "$_autoflow_payload")"
                if [ -z "$_autoflow_role_marker_found" ]; then
                  echo "[AutoFlow Gate] evaluation.json blocked: evaluator.role_marker is missing. Evaluation AI must emit the standard schema." >&2
                  exit 2
                fi
              fi
              ;;
          esac
          ;;
      esac
      # PreToolUse event handled (allow / non-matching) — do not run main gate.
      exit 0
    fi
    # Non-PreToolUse JSON payload: fall through to main (preserves existing
    # commit/PR-time behavior when invoked with a payload that lacks event).
  fi
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.autoflow-state"
PASS_THRESHOLD="7.5"
MIN_CATEGORY_SCORE=7
AUTO_FAIL_KEY="${AUTO_FAIL_KEY:-consistency}"
AUTO_FAIL_THRESHOLD=3

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log_info()  { echo "[AutoFlow Gate] ℹ  $*"; }
log_pass()  { echo "[AutoFlow Gate] ✅ $*"; }
log_fail()  { echo "[AutoFlow Gate] ❌ $*"; }
log_warn()  { echo "[AutoFlow Gate] ⚠️  $*"; }

# ---------------------------------------------------------------------------
# Resolve current issue (Issue #40, Decision 2 / plan §3.2):
# Returns a qualified `<sub-repo-id>/<issue-number>` string. The slash form is
# returned as-is; a bare integer (legacy) is normalized to `self/<N>`. Legacy
# flat-layout state directories (`.autoflow-state/<N>/`) without a matching
# namespaced directory are honored for back-compat reads — see plan §4.
# ---------------------------------------------------------------------------
get_current_issue() {
  local issue_file="${STATE_DIR}/current-issue"
  if [ ! -f "$issue_file" ]; then
    log_warn "No current-issue file found at ${issue_file}"
    log_info "Skipping gate check (no active Auto-Flow session)"
    exit 0
  fi
  local raw subrepo
  raw=$(cat "$issue_file" | tr -d '[:space:]')
  case "$raw" in
    */*)
      printf '%s' "$raw"
      ;;
    *)
      subrepo="${AUTOFLOW_SUBREPO_ID:-self}"
      if [ -d "${STATE_DIR}/${raw}" ] && [ ! -d "${STATE_DIR}/${subrepo}/${raw}" ]; then
        # Legacy flat-layout state directory still in use — return bare form
        # so downstream `${STATE_DIR}/${qualified_issue}/...` resolves to the
        # existing directory.
        printf '%s' "$raw"
      else
        printf '%s/%s' "$subrepo" "$raw"
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Read phase status for an issue
# ---------------------------------------------------------------------------
get_current_phase() {
  local issue="$1"
  local phase_file="${STATE_DIR}/${issue}/phase"
  if [ ! -f "$phase_file" ]; then
    log_fail "No phase file found for issue #${issue}"
    log_info "Expected: ${phase_file}"
    exit 1
  fi
  cat "$phase_file" | tr -d '[:space:]'
}

# ---------------------------------------------------------------------------
# Extract a score value from evaluation JSON
# ---------------------------------------------------------------------------
# Handles both flat format ("key": 8) and structured format ("key": {"score": 8, "reason": "..."})
# Uses POSIX grep/sed/awk only — no jq dependency
extract_score() {
  local file="$1"
  local key="$2"

  # Find the line containing "key": and extract the numeric score.
  # Handles both flat ("key": 8) and structured ("key": {"score": 8, "reason": "..."}).
  # Uses POSIX grep/sed/awk only — no jq.
  local score
  score=$(awk -v key="\"${key}\"" '
    BEGIN { found = 0 }
    $0 ~ key {
      # Check if this line has "score": (structured, same line)
      if (match($0, /"score"[[:space:]]*:[[:space:]]*[0-9][0-9.]*/)) {
        s = substr($0, RSTART, RLENGTH)
        # Extract number after the colon
        match(s, /[0-9][0-9.]*$/)
        print substr(s, RSTART, RLENGTH)
        exit
      }
      # Check if this line has { (structured, score on next line)
      if ($0 ~ /{/) {
        found = 1
        next
      }
      # Flat format: "key": N (no { on the line)
      match($0, /:[[:space:]]*[0-9][0-9.]*/)
      if (RSTART > 0) {
        s = substr($0, RSTART, RLENGTH)
        match(s, /[0-9][0-9.]*/)
        print substr(s, RSTART, RLENGTH)
        exit
      }
    }
    found && /\"score\"/ {
      match($0, /[0-9][0-9.]*/)
      if (RSTART > 0) {
        print substr($0, RSTART, RLENGTH)
      }
      exit
    }
    found && /}/ { found = 0 }
  ' "$file")

  if [ -n "$score" ]; then
    echo "$score"
  else
    echo "0"
  fi
}

# ---------------------------------------------------------------------------
# Get all score keys from the evaluation JSON dynamically
# ---------------------------------------------------------------------------
get_score_keys() {
  local file="$1"
  # Extract all top-level keys from the "scores" JSON object.
  # Uses only POSIX awk — no GNU extensions.
  # Strategy: find the "scores" line, count brace depth to track nested objects,
  # and extract key names that are direct children of "scores".
  awk '
    BEGIN { in_scores = 0; depth = 0 }
    /"scores"[[:space:]]*:/ {
      in_scores = 1
      # Count braces on this line to set initial depth
      depth = 0
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") depth++
        if (c == "}") depth--
      }
      next
    }
    in_scores {
      # Count opening/closing braces to track when we leave the scores object
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") depth++
        if (c == "}") depth--
      }
      # Extract key names (but skip nested keys like "score", "reason")
      if (match($0, /"[a-zA-Z_][a-zA-Z0-9_]*"[[:space:]]*:/)) {
        s = substr($0, RSTART + 1, RLENGTH - 3)
        gsub(/[[:space:]]*$/, "", s)
        gsub(/"/, "", s)
        if (s != "score" && s != "reason" && s != "scores") {
          print s
        }
      }
      if (depth <= 0) { in_scores = 0 }
    }
  ' "$file"
}

# ---------------------------------------------------------------------------
# Get weight for a category from weights.json or equal weight fallback
# ---------------------------------------------------------------------------
get_weight() {
  local issue="$1"
  local category="$2"
  local num_categories="$3"
  local weights_file="${STATE_DIR}/${issue}/weights.json"

  if [ -f "$weights_file" ]; then
    local w
    w=$(grep "\"${category}\"" "$weights_file" | grep -o '[0-9][0-9.]*' | head -1)
    if [ -n "$w" ]; then
      echo "$w"
      return
    fi
  fi

  # Equal weight fallback: 1/N
  awk "BEGIN { printf \"%.6f\", 1.0 / $num_categories }"
}

# ---------------------------------------------------------------------------
# Check: Is evaluation passing?
# ---------------------------------------------------------------------------
# IMPORTANT: This function does NOT read the AI-generated "pass" field.
# It calculates pass/fail independently from the raw scores.
check_evaluation_pass() {
  local issue="$1"
  local eval_file="${STATE_DIR}/${issue}/evaluation.json"

  if [ ! -f "$eval_file" ]; then
    log_fail "No evaluation file found: ${eval_file}"
    return 1
  fi

  # Dynamically discover all score categories
  local score_keys
  score_keys=$(get_score_keys "$eval_file")
  local num_categories
  num_categories=$(echo "$score_keys" | wc -l | tr -d '[:space:]')

  if [ "$num_categories" -eq 0 ]; then
    log_fail "No score categories found in ${eval_file}"
    return 1
  fi

  # Build score list and display
  local scores_display=""
  local all_scores=""
  local key score
  for key in $score_keys; do
    score=$(extract_score "$eval_file" "$key")
    scores_display="${scores_display} ${key}:${score}"
    all_scores="${all_scores} ${key}=${score}"
  done

  log_info "Scores —${scores_display}"

  # Check 1: Auto-fail key
  local auto_fail_score
  auto_fail_score=$(extract_score "$eval_file" "$AUTO_FAIL_KEY")
  if [ "$auto_fail_score" != "0" ]; then
    local is_auto_fail
    is_auto_fail=$(awk "BEGIN { print ($auto_fail_score <= $AUTO_FAIL_THRESHOLD) ? 1 : 0 }")
    if [ "$is_auto_fail" -eq 1 ]; then
      log_fail "${AUTO_FAIL_KEY} score: ${auto_fail_score} (<= ${AUTO_FAIL_THRESHOLD}) — AUTO-FAIL (mandatory rework)"
      return 1
    fi
  fi

  # Check 2: Individual category minimums
  local has_min_fail=0
  local failing_categories=""
  for key in $score_keys; do
    score=$(extract_score "$eval_file" "$key")
    local below_min
    below_min=$(awk "BEGIN { print ($score < $MIN_CATEGORY_SCORE) ? 1 : 0 }")
    if [ "$below_min" -eq 1 ]; then
      has_min_fail=1
      failing_categories="${failing_categories} ${key}(${score})"
    fi
  done

  if [ "$has_min_fail" -eq 1 ]; then
    log_fail "Categories below minimum (${MIN_CATEGORY_SCORE}):${failing_categories} — FAIL"
    return 1
  fi

  # Check 3: Weighted average
  local weighted_sum="0"
  local weight_sum="0"
  for key in $score_keys; do
    score=$(extract_score "$eval_file" "$key")
    local w
    w=$(get_weight "$issue" "$key" "$num_categories")
    weighted_sum=$(awk "BEGIN { printf \"%.6f\", $weighted_sum + ($score * $w) }")
    weight_sum=$(awk "BEGIN { printf \"%.6f\", $weight_sum + $w }")
  done

  # Normalize by total weight (in case weights don't sum to 1)
  local calculated_overall
  calculated_overall=$(awk "BEGIN { printf \"%.2f\", $weighted_sum / $weight_sum }")

  log_info "Calculated overall: ${calculated_overall} (threshold: ${PASS_THRESHOLD})"

  local overall_pass
  overall_pass=$(awk "BEGIN { print ($calculated_overall >= $PASS_THRESHOLD) ? 1 : 0 }")
  if [ "$overall_pass" -eq 1 ]; then
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
  if [ ! -f "$delegation_file" ]; then
    log_fail "delegation.md not found: ${delegation_file}"
    log_info "DISPATCH must produce delegation.md before proceeding"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Check: Does intake.md exist (Issue #40, Decision 5 / plan §3.4)?
# Mirrors check_delegation_exists. Verifies file presence AND the three
# required section tokens (`## Sub-Repo`, `## Branch`, `## State Location`)
# so a placeholder file does not silently satisfy the gate.
# ---------------------------------------------------------------------------
check_intake_exists() {
  local issue="$1"
  local intake_file="${STATE_DIR}/${issue}/intake.md"
  if [ ! -f "$intake_file" ]; then
    log_fail "intake.md not found: ${intake_file}"
    log_info "PREFLIGHT must produce intake.md before DIAGNOSE"
    return 1
  fi
  local token
  for token in '## Sub-Repo' '## Branch' '## State Location'; do
    if ! grep -F -q "$token" "$intake_file" 2>/dev/null; then
      log_fail "intake.md missing required section: ${token}"
      return 1
    fi
  done
  return 0
}

# ---------------------------------------------------------------------------
# Main gate logic
# ---------------------------------------------------------------------------
main() {
  log_info "Running Auto-Flow gate check..."

  local issue
  issue=$(get_current_issue)

  if [ -z "$issue" ]; then
    log_info "No active issue — skipping gate"
    exit 0
  fi

  log_info "Active issue: #${issue}"

  local phase
  phase=$(get_current_phase "$issue")
  log_info "Current phase: ${phase}"

  # Issue #40: intake gate applies only when the orchestrator is using the new
  # namespaced layout (qualified `<sub-repo-id>/<issue-number>`). Legacy bare-
  # integer state remains exempt to keep pre-#40 fixtures and in-flight issues
  # unblocked. PREFLIGHT warns; DIAGNOSE+ hard-blocks. See plan §3.5.
  case "$issue" in
    */*) _namespaced=1 ;;
    *)   _namespaced=0 ;;
  esac

  case "$phase" in
    # PREFLIGHT: intake.md is the artifact this very phase produces, so a
    # missing file warns rather than blocks (avoids chicken-and-egg with the
    # first phase-set PREFLIGHT call).
    PREFLIGHT)
      if [ "$_namespaced" -eq 1 ] \
          && ! check_intake_exists "$issue" >/dev/null 2>&1; then
        log_warn "intake.md not yet present at ${STATE_DIR}/${issue}/intake.md — PREFLIGHT must produce it before DIAGNOSE"
      fi
      log_pass "${phase} — no gate restrictions"
      ;;

    # DIAGNOSE+: intake.md is required (hard-block) under namespaced layout.
    DIAGNOSE|GATE:HYPOTHESIS|ARCHITECT|GATE:PLAN|DISPATCH)
      if [ "$_namespaced" -eq 1 ]; then
        check_intake_exists "$issue" || exit 1
      fi
      log_pass "${phase} — no gate restrictions"
      ;;

    # TDD phases: delegation must exist (intake also required when namespaced)
    RED|GREEN|VERIFY|REFINE)
      if [ "$_namespaced" -eq 1 ]; then
        check_intake_exists "$issue" || exit 1
      fi
      check_delegation_exists "$issue" || exit 1
      log_pass "${phase} — delegation.md found, TDD in progress"
      ;;

    # Evaluation gates: check scores
    GATE:SECURITY|GATE:QUALITY)
      check_delegation_exists "$issue" || exit 1
      log_info "${phase} — checking evaluation result..."
      check_evaluation_pass "$issue"
      ;;

    # SHIP: evaluation must have passed
    SHIP)
      log_info "${phase} — verifying evaluation before PR..."
      check_evaluation_pass "$issue"
      ;;

    # LAND: human action required
    LAND)
      log_warn "${phase} — waiting for human merge approval"
      ;;

    *)
      log_warn "Unknown phase: ${phase} — allowing by default"
      ;;
  esac

  log_pass "Gate check complete"
  exit 0
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
main "$@"
