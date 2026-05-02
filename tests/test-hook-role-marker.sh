#!/usr/bin/env bash
# =============================================================================
# Test Suite: evaluator.role_marker PreToolUse validation (Issue #29)
# =============================================================================
# Validates that check-autoflow-gate.sh blocks Write to evaluation JSON files
# when the content lacks evaluator.role_marker, and allows the write when
# role_marker is present.
#
# Acceptance criteria tested:
#   AC1: Hook blocks Write to *.autoflow-state/*/evaluation.json
#        when evaluator.role_marker is absent → exit code 2
#   AC2: Hook blocks Write to *.autoflow-state/*/evaluation/*.json
#        when evaluator.role_marker is absent → exit code 2
#   AC3: Hook allows Write to evaluation JSON when
#        evaluator.role_marker is present and non-empty → exit code 0
#   AC4: Hook allows Edit to evaluation JSON regardless of content → exit code 0
#   AC5: Hook allows MultiEdit to evaluation JSON regardless of content → exit code 0
#   AC6: Hook allows Write to non-evaluation JSON (e.g., plan.json)
#        regardless of content → exit code 0
#
# All tests MUST FAIL (RED) until the hook feature is implemented.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="${REPO_ROOT}/.claude/hooks/check-autoflow-gate.sh"

PASS=0
FAIL=0
ERRORS=()

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
assert_exit_code() {
  local expected="$1" actual="$2" desc="$3"
  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc (expected exit $expected, got $actual)")
    echo "  FAIL: $desc (expected exit $expected, got $actual)"
  fi
}

assert_stderr_contains() {
  local stderr_file="$1" pattern="$2" desc="$3"
  if grep -q "$pattern" "$stderr_file" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc (pattern '$pattern' not found in stderr)")
    echo "  FAIL: $desc"
  fi
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------
TEST_DIR=""

setup_test_dir() {
  TEST_DIR=$(mktemp -d)
}

cleanup_test_dir() {
  if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}

# Build a PreToolUse Write payload for an evaluation JSON path with given content
make_write_payload() {
  local file_path="$1"
  local content="$2"
  # Escape double quotes in content for embedding in JSON string
  local escaped_content
  escaped_content=$(printf '%s' "$content" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
  printf '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' \
    "$file_path" "$escaped_content"
}

# Build a PreToolUse Edit payload for an evaluation JSON path
make_edit_payload() {
  local file_path="$1"
  printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"old","new_string":"new"}}' \
    "$file_path"
}

# Build a PreToolUse MultiEdit payload for an evaluation JSON path
make_multiedit_payload() {
  local file_path="$1"
  printf '{"hook_event_name":"PreToolUse","tool_name":"MultiEdit","tool_input":{"file_path":"%s","edits":[]}}' \
    "$file_path"
}

# Evaluation JSON content WITHOUT evaluator.role_marker
EVAL_NO_ROLE_MARKER='{
  "phase": "GATE:QUALITY",
  "issue": "#29",
  "evaluator": "evaluation-ai",
  "scores": {
    "correctness": { "score": 8, "reason": "meets requirements" },
    "quality": { "score": 7, "reason": "clean code" },
    "test_coverage": { "score": 8, "reason": "good coverage" },
    "consistency": { "score": 9, "reason": "aligned with principles" },
    "documentation": { "score": 7, "reason": "docs updated" }
  }
}'

# Evaluation JSON content WITH evaluator.role_marker present
EVAL_WITH_ROLE_MARKER='{
  "phase": "GATE:QUALITY",
  "issue": "#29",
  "evaluator": {
    "role_marker": "evaluation-ai",
    "session_id": "sess-abc123"
  },
  "scores": {
    "correctness": { "score": 8, "reason": "meets requirements" },
    "quality": { "score": 7, "reason": "clean code" },
    "test_coverage": { "score": 8, "reason": "good coverage" },
    "consistency": { "score": 9, "reason": "aligned with principles" },
    "documentation": { "score": 7, "reason": "docs updated" }
  },
  "average": 7.8,
  "verdict": "PASS"
}'

echo "=== Test Suite: evaluator.role_marker PreToolUse validation (Issue #29) ==="
echo ""

# ===========================================================================
# AC1: Hook blocks Write to *.autoflow-state/*/evaluation.json
#      when evaluator.role_marker is absent → exit code 2
# ===========================================================================
echo "--- AC1: Write to evaluation.json without role_marker → blocked (exit 2) ---"
setup_test_dir
PAYLOAD=$(make_write_payload "/tmp/repo/.autoflow-state/29/evaluation.json" "$EVAL_NO_ROLE_MARKER")
exit_code=0
printf '%s' "$PAYLOAD" \
  | CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
  || exit_code=$?
assert_exit_code 2 "$exit_code" \
  "AC1a: hook exits 2 when Write to evaluation.json lacks role_marker"
assert_stderr_contains "${TEST_DIR}/hook.err" "role_marker" \
  "AC1b: stderr mentions role_marker"
cleanup_test_dir
echo ""

# ===========================================================================
# AC2: Hook blocks Write to *.autoflow-state/*/evaluation/*.json
#      when evaluator.role_marker is absent → exit code 2
# ===========================================================================
echo "--- AC2: Write to evaluation/<name>.json without role_marker → blocked (exit 2) ---"
setup_test_dir
PAYLOAD=$(make_write_payload "/tmp/repo/.autoflow-state/29/evaluation/quality.json" "$EVAL_NO_ROLE_MARKER")
exit_code=0
printf '%s' "$PAYLOAD" \
  | CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
  || exit_code=$?
assert_exit_code 2 "$exit_code" \
  "AC2a: hook exits 2 when Write to evaluation/quality.json lacks role_marker"
assert_stderr_contains "${TEST_DIR}/hook.err" "role_marker" \
  "AC2b: stderr mentions role_marker"
cleanup_test_dir
echo ""

# ===========================================================================
# AC3: Hook allows Write to evaluation JSON when
#      evaluator.role_marker is present and non-empty → exit code 0
# ===========================================================================
echo "--- AC3: Write to evaluation.json WITH role_marker → allowed (exit 0) ---"
setup_test_dir
PAYLOAD=$(make_write_payload "/tmp/repo/.autoflow-state/29/evaluation.json" "$EVAL_WITH_ROLE_MARKER")
exit_code=0
printf '%s' "$PAYLOAD" \
  | CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
  || exit_code=$?
assert_exit_code 0 "$exit_code" \
  "AC3: hook exits 0 when Write to evaluation.json includes role_marker"
cleanup_test_dir
echo ""

# ===========================================================================
# AC4: Hook allows Edit to evaluation JSON regardless of content → exit code 0
# (Edit does not carry the full file content, so role_marker check is skipped)
# ===========================================================================
echo "--- AC4: Edit to evaluation.json (no role_marker check) → allowed (exit 0) ---"
setup_test_dir
PAYLOAD=$(make_edit_payload "/tmp/repo/.autoflow-state/29/evaluation.json")
exit_code=0
printf '%s' "$PAYLOAD" \
  | CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
  || exit_code=$?
assert_exit_code 0 "$exit_code" \
  "AC4: hook exits 0 for Edit to evaluation.json (no role_marker check)"
cleanup_test_dir
echo ""

# ===========================================================================
# AC5: Hook allows MultiEdit to evaluation JSON regardless of content → exit code 0
# ===========================================================================
echo "--- AC5: MultiEdit to evaluation.json (no role_marker check) → allowed (exit 0) ---"
setup_test_dir
PAYLOAD=$(make_multiedit_payload "/tmp/repo/.autoflow-state/29/evaluation.json")
exit_code=0
printf '%s' "$PAYLOAD" \
  | CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
  || exit_code=$?
assert_exit_code 0 "$exit_code" \
  "AC5: hook exits 0 for MultiEdit to evaluation.json (no role_marker check)"
cleanup_test_dir
echo ""

# ===========================================================================
# AC6: Hook allows Write to non-evaluation JSON files regardless of content
# (e.g., plan.json — same .autoflow-state/ path but not evaluation.json)
# ===========================================================================
echo "--- AC6: Write to non-evaluation JSON (plan.json) → allowed (exit 0) ---"
setup_test_dir
PAYLOAD=$(make_write_payload "/tmp/repo/.autoflow-state/29/plan.json" "$EVAL_NO_ROLE_MARKER")
exit_code=0
printf '%s' "$PAYLOAD" \
  | CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
  || exit_code=$?
assert_exit_code 0 "$exit_code" \
  "AC6: hook exits 0 for Write to plan.json (not an evaluation path)"
cleanup_test_dir
echo ""

# ===========================================================================
# Summary
# ===========================================================================
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo ""
  echo "Failures:"
  for e in "${ERRORS[@]}"; do
    echo "  $e"
  done
fi
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
