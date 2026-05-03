#!/usr/bin/env bash
# =============================================================================
# Test Suite: Dynamic Score Categories for check-autoflow-gate.sh (Issue #8)
# =============================================================================
# Validates that the gate hook dynamically enumerates score categories,
# supports dual formats (flat/structured), handles weight configuration,
# and allows configurable auto-fail keys.
#
# All tests create temporary directories with mock .autoflow-state/ fixtures
# and invoke the hook script, checking exit codes and output.
# =============================================================================

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

HOOK=".claude/hooks/check-autoflow-gate.sh"

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
    echo "  FAIL: $desc"
  fi
}

assert_output_contains() {
  local output_file="$1" pattern="$2" desc="$3"
  if grep -qi "$pattern" "$output_file" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc (pattern '$pattern' not found in output)")
    echo "  FAIL: $desc"
  fi
}

assert_output_not_contains() {
  local output_file="$1" pattern="$2" desc="$3"
  if grep -qi "$pattern" "$output_file" 2>/dev/null; then
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc (pattern '$pattern' unexpectedly found in output)")
    echo "  FAIL: $desc"
  else
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
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

# Set up mock autoflow-state with a given phase and evaluation JSON
setup_eval_fixture() {
  local phase="$1"
  local eval_json="$2"
  local issue="99"
  mkdir -p "${TEST_DIR}/.autoflow-state/${issue}"
  echo "$issue" > "${TEST_DIR}/.autoflow-state/current-issue"
  echo "$phase" > "${TEST_DIR}/.autoflow-state/${issue}/phase"
  # Create delegation.md so delegation gate doesn't block
  cat > "${TEST_DIR}/.autoflow-state/${issue}/delegation.md" <<'EOF'
## Team
test-team
## Test AI Instructions
test
## Developer AI Instructions
test
EOF
  echo "$eval_json" > "${TEST_DIR}/.autoflow-state/${issue}/evaluation.json"
}

# Run hook and capture exit code + output
run_hook() {
  local exit_code=0
  CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > "${TEST_DIR}/output.txt" 2>&1 || exit_code=$?
  echo "$exit_code"
}

# Run hook with custom env vars
run_hook_with_env() {
  local env_vars="$1"
  local exit_code=0
  eval "$env_vars CLAUDE_PROJECT_DIR=\"$TEST_DIR\" bash \"$HOOK\"" > "${TEST_DIR}/output.txt" 2>&1 || exit_code=$?
  echo "$exit_code"
}

echo "=== Test Suite: Dynamic Score Categories (Issue #8) ==="
echo ""

# ==========================================================================
# GROUP 1: Dynamic Enumeration — Standard Categories
# ==========================================================================
echo "--- GROUP 1: Dynamic enumeration with standard CLAUDE.md categories ---"

setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "phase": "GATE:QUALITY",
  "issue": "#99",
  "scores": {
    "correctness": { "score": 9, "reason": "Meets all requirements" },
    "quality": { "score": 8, "reason": "Clean code" },
    "test_coverage": { "score": 8, "reason": "Good coverage" },
    "consistency": { "score": 9, "reason": "Aligned with design" },
    "documentation": { "score": 8, "reason": "Docs updated" }
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T01: Standard CLAUDE.md categories (all passing) → PASS"
assert_output_contains "${TEST_DIR}/output.txt" "PASS" \
  "T02: Output indicates PASS for standard categories"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 2: Dynamic Enumeration — Custom/Arbitrary Categories
# ==========================================================================
echo "--- GROUP 2: Dynamic enumeration with custom categories ---"

setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "phase": "GATE:QUALITY",
  "issue": "#99",
  "scores": {
    "accessibility": { "score": 9, "reason": "WCAG compliant" },
    "reliability": { "score": 8, "reason": "Error handling solid" },
    "maintainability": { "score": 8, "reason": "Well structured" }
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T03: Custom categories (accessibility, reliability, maintainability) → PASS"
assert_output_contains "${TEST_DIR}/output.txt" "accessibility\|reliability\|maintainability" \
  "T04: Output mentions custom category names"
cleanup_test_dir

echo ""

# Test with a single category
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "overall_quality": { "score": 9, "reason": "Excellent" }
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T05: Single custom category with high score → PASS"
cleanup_test_dir

echo ""

# Test with many categories
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "cat_a": 8,
    "cat_b": 8,
    "cat_c": 8,
    "cat_d": 8,
    "cat_e": 8,
    "cat_f": 8,
    "cat_g": 8
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T06: Seven flat-format custom categories all passing → PASS"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 3: Dual Format Support — Flat
# ==========================================================================
echo "--- GROUP 3: Dual format — flat ---"

setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 9,
    "quality": 8,
    "test_coverage": 8,
    "consistency": 9,
    "documentation": 8
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T07: Flat format scores (all passing) → PASS"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 4: Dual Format Support — Structured
# ==========================================================================
echo "--- GROUP 4: Dual format — structured ---"

setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": { "score": 9, "reason": "All requirements met" },
    "quality": { "score": 8, "reason": "Clean" },
    "test_coverage": { "score": 8, "reason": "Covered" },
    "consistency": { "score": 9, "reason": "Consistent" },
    "documentation": { "score": 8, "reason": "Updated" }
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T08: Structured format scores (all passing) → PASS"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 5: Dual Format Support — Mixed
# ==========================================================================
echo "--- GROUP 5: Dual format — mixed ---"

setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 9,
    "quality": { "score": 8, "reason": "Clean code" },
    "test_coverage": 8,
    "consistency": { "score": 9, "reason": "Aligned" },
    "documentation": 8
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T09: Mixed format (flat + structured) all passing → PASS"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 6: Weight Configuration — With weights.json
# ==========================================================================
echo "--- GROUP 6: Weight configuration with weights.json ---"

# With weights.json: weighted average should use configured weights
# correctness=10 (weight 0.5), quality=6 (weight 0.5) → avg = 8.0 → PASS
# BUT quality=6 < 7 → FAIL due to individual minimum
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 10,
    "quality": 6
  }
}'
cat > "${TEST_DIR}/.autoflow-state/99/weights.json" <<'WJSON'
{
  "correctness": 0.5,
  "quality": 0.5
}
WJSON
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T10: With weights.json, quality=6 below min → FAIL"
cleanup_test_dir

echo ""

# With weights.json: heavy weight on high-scoring category pulls average up
# correctness=10 (weight 0.9), quality=7 (weight 0.1) → weighted avg = 9.7 → PASS
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 10,
    "quality": 7
  }
}'
cat > "${TEST_DIR}/.autoflow-state/99/weights.json" <<'WJSON'
{
  "correctness": 0.9,
  "quality": 0.1
}
WJSON
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T11: With weights.json, weighted avg=9.7, all>=7 → PASS"
cleanup_test_dir

echo ""

# Verify weights actually matter: same scores, different weights, different result
# correctness=7 (weight 0.1), quality=10 (weight 0.9) → weighted avg = 9.7 → PASS
# correctness=7 (weight 0.9), quality=10 (weight 0.1) → weighted avg = 7.3 → FAIL (<7.5)
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 7,
    "quality": 10
  }
}'
cat > "${TEST_DIR}/.autoflow-state/99/weights.json" <<'WJSON'
{
  "correctness": 0.9,
  "quality": 0.1
}
WJSON
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T12: With weights.json, heavy weight on low score → weighted avg<7.5 → FAIL"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 7: Weight Configuration — Without weights.json (equal weights)
# ==========================================================================
echo "--- GROUP 7: Without weights.json → equal weights ---"

# 3 categories at 8 each → avg = 8.0 → PASS
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "cat_x": 8,
    "cat_y": 8,
    "cat_z": 8
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T13: No weights.json, 3 categories at 8 → equal avg=8.0 → PASS"
cleanup_test_dir

echo ""

# 2 categories: one at 10, one at 7 → equal avg = 8.5 → PASS (both >= 7)
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "alpha": 10,
    "beta": 7
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T14: No weights.json, avg=8.5, all>=7 → PASS"
cleanup_test_dir

echo ""

# 2 categories: one at 10, one at 5 → equal avg = 7.5 → but 5 < 7 → FAIL
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "alpha": 10,
    "beta": 5
  }
}'
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T15: No weights.json, avg=7.5 but beta=5<7 → FAIL"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 8: Auto-Fail — Default Key (consistency)
# ==========================================================================
echo "--- GROUP 8: Auto-fail with default key (consistency) ---"

# consistency <= 3 → AUTO-FAIL regardless of other scores
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 10,
    "quality": 10,
    "test_coverage": 10,
    "consistency": 3,
    "documentation": 10
  }
}'
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T16: consistency=3 (<=3) → AUTO-FAIL"
assert_output_contains "${TEST_DIR}/output.txt" "AUTO.FAIL\|auto.fail" \
  "T17: Output mentions AUTO-FAIL for consistency<=3"
cleanup_test_dir

echo ""

# consistency = 2 → AUTO-FAIL
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 10,
    "quality": 10,
    "test_coverage": 10,
    "consistency": 2,
    "documentation": 10
  }
}'
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T18: consistency=2 → AUTO-FAIL"
cleanup_test_dir

echo ""

# consistency = 4 → NOT auto-fail (but still below 7, so FAIL for min check)
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 10,
    "quality": 10,
    "test_coverage": 10,
    "consistency": 4,
    "documentation": 10
  }
}'
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T19: consistency=4 → not auto-fail, but <7 → FAIL (min check)"
assert_output_not_contains "${TEST_DIR}/output.txt" "AUTO.FAIL\|auto.fail" \
  "T20: consistency=4 does NOT trigger AUTO-FAIL message"
cleanup_test_dir

echo ""

# consistency = 8 → no auto-fail, passes fine
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 8,
    "quality": 8,
    "test_coverage": 8,
    "consistency": 8,
    "documentation": 8
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T21: consistency=8 → no auto-fail, all pass → PASS"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 9: Auto-Fail — Custom AUTO_FAIL_KEY env var
# ==========================================================================
echo "--- GROUP 9: Custom AUTO_FAIL_KEY ---"

# Custom auto-fail key: "reliability" at <=3 → AUTO-FAIL
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 10,
    "reliability": 3,
    "quality": 10
  }
}'
exit_code=$(run_hook_with_env "AUTO_FAIL_KEY=reliability")
assert_exit_code 1 "$exit_code" \
  "T22: AUTO_FAIL_KEY=reliability, reliability=3 → AUTO-FAIL"
assert_output_contains "${TEST_DIR}/output.txt" "AUTO.FAIL\|auto.fail" \
  "T23: Output mentions AUTO-FAIL for custom key"
cleanup_test_dir

echo ""

# Custom auto-fail key: consistency is no longer the auto-fail key
# So consistency=2 does NOT trigger auto-fail (but still fails min check)
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 10,
    "consistency": 2,
    "quality": 10
  }
}'
exit_code=$(run_hook_with_env "AUTO_FAIL_KEY=reliability")
assert_exit_code 1 "$exit_code" \
  "T24: AUTO_FAIL_KEY=reliability, consistency=2 → no auto-fail (fails min check)"
assert_output_not_contains "${TEST_DIR}/output.txt" "AUTO.FAIL\|auto.fail" \
  "T25: No AUTO-FAIL message when key doesn't match"
cleanup_test_dir

echo ""

# Non-existent auto-fail key → no auto-fail triggered at all
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 8,
    "quality": 8,
    "test_coverage": 8
  }
}'
exit_code=$(run_hook_with_env "AUTO_FAIL_KEY=nonexistent_key")
assert_exit_code 0 "$exit_code" \
  "T26: AUTO_FAIL_KEY=nonexistent_key → no auto-fail, scores pass → PASS"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 10: Pass/Fail Calculation — Edge Cases
# ==========================================================================
echo "--- GROUP 10: Pass/fail edge cases ---"

# All scores exactly 7.5 → avg=7.5, all>=7 → PASS
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "cat_a": 7.5,
    "cat_b": 7.5,
    "cat_c": 7.5
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T27: All categories at 7.5 → avg=7.5, all>=7 → PASS"
cleanup_test_dir

echo ""

# One category at exactly 7, rest at 8 → avg=7.75, all>=7 → PASS
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "cat_a": 8,
    "cat_b": 7,
    "cat_c": 8,
    "cat_d": 8
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T28: One category at 7, rest at 8 → avg=7.75, all>=7 → PASS"
cleanup_test_dir

echo ""

# One category at 6.9 → below individual minimum → FAIL
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "cat_a": 9,
    "cat_b": 6.9,
    "cat_c": 9
  }
}'
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T29: One category at 6.9 (<7) → FAIL"
cleanup_test_dir

echo ""

# Average exactly 7.49 → below threshold → FAIL
# 3 categories: 7, 7, 7.47 → avg ≈ 7.157 → FAIL
# Better: 2 categories: 7, 7.98 → avg = 7.49 → FAIL
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "cat_a": 7,
    "cat_b": 7.98
  }
}'
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T30: Average=7.49 (below 7.5 threshold) → FAIL"
cleanup_test_dir

echo ""

# All perfect 10s → PASS
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 10,
    "quality": 10,
    "test_coverage": 10,
    "consistency": 10,
    "documentation": 10
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T31: All perfect 10s → PASS"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 11: Backward Compatibility — Old Format
# ==========================================================================
echo "--- GROUP 11: Backward compatibility with old flat format ---"

# The old hardcoded categories in flat format should still work
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 9,
    "code_quality": 8,
    "test_coverage": 8,
    "security": 9,
    "performance": 8
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T32: Old flat format with original category names → PASS"
cleanup_test_dir

echo ""

# Old format with failing security → should be AUTO-FAIL if consistency is default
# NOTE: In the NEW system, auto-fail key defaults to "consistency", not "security"
# So old-style "security" at 2 should NOT trigger auto-fail (but fails min check)
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": 9,
    "code_quality": 8,
    "test_coverage": 8,
    "security": 2,
    "performance": 8
  }
}'
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T33: Old format, security=2 → FAIL (min check, not auto-fail since key is consistency)"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 12: No jq Dependency
# ==========================================================================
echo "--- GROUP 12: No jq dependency ---"

# Verify the script doesn't invoke jq as a command (comments don't count)
# Strip comments, then check for jq usage
if sed 's/#.*//' "$HOOK" | grep -q '\bjq\b' 2>/dev/null; then
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T34: Script contains jq dependency in executable code")
  echo "  FAIL: T34: Script does not use jq in executable code"
else
  PASS=$((PASS + 1))
  echo "  PASS: T34: Script does not use jq in executable code"
fi

echo ""

# ==========================================================================
# GROUP 13: Dynamic Key Enumeration Function Exists
# ==========================================================================
echo "--- GROUP 13: Dynamic key enumeration ---"

# The script should have a function or mechanism for dynamic key discovery
# (not hardcoded category variable names)
if grep -q 'get_score_keys\|score_keys\|for.*key.*in.*scores\|for.*category' "$HOOK" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: T35: Script has dynamic key enumeration mechanism"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T35: Script lacks dynamic key enumeration (still hardcoded)")
  echo "  FAIL: T35: Script has dynamic key enumeration mechanism"
fi

echo ""

# The script should NOT have hardcoded category assignments like the current version
# (correctness=, code_quality=, test_coverage=, security=, performance=)
if grep -q 'correctness=.*extract_score.*correctness' "$HOOK" 2>/dev/null; then
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T36: Script still has hardcoded category extraction")
  echo "  FAIL: T36: Script does NOT have hardcoded category extraction"
else
  PASS=$((PASS + 1))
  echo "  PASS: T36: Script does NOT have hardcoded category extraction"
fi

echo ""

# ==========================================================================
# GROUP 14: Weight Function Exists
# ==========================================================================
echo "--- GROUP 14: Weight configuration function ---"

# Script should have weight configuration logic (reading weights.json, get_weight function)
# Checking for actual function/file-reading logic, not just "weight" in comments
if grep -q 'weights\.json\|get_weight' "$HOOK" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: T37: Script has weight configuration support (weights.json or get_weight)"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T37: Script lacks weight configuration support (no weights.json or get_weight)")
  echo "  FAIL: T37: Script has weight configuration support (weights.json or get_weight)"
fi

echo ""

# ==========================================================================
# GROUP 15: Auto-Fail Key Configuration
# ==========================================================================
echo "--- GROUP 15: Auto-fail key is configurable ---"

# Script should reference AUTO_FAIL_KEY or similar configurable mechanism
if grep -q 'AUTO_FAIL_KEY\|auto_fail_key' "$HOOK" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: T38: Script has configurable auto-fail key"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T38: Script lacks configurable auto-fail key (hardcoded to security)")
  echo "  FAIL: T38: Script has configurable auto-fail key"
fi

echo ""

# Script should default auto-fail key to "consistency" (not "security")
if grep -q 'consistency' "$HOOK" 2>/dev/null && grep -q 'AUTO_FAIL_KEY\|auto_fail_key' "$HOOK" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: T39: Auto-fail key defaults to consistency"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T39: Auto-fail key does not default to consistency")
  echo "  FAIL: T39: Auto-fail key defaults to consistency"
fi

echo ""

# ==========================================================================
# GROUP 16: SHIP also uses dynamic evaluation
# ==========================================================================
echo "--- GROUP 16: SHIP uses same dynamic evaluation ---"

setup_test_dir
setup_eval_fixture "SHIP" '{
  "scores": {
    "custom_a": { "score": 9, "reason": "Good" },
    "custom_b": { "score": 8, "reason": "Fine" }
  }
}'
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T40: SHIP with custom categories → PASS"
cleanup_test_dir

echo ""

setup_test_dir
setup_eval_fixture "SHIP" '{
  "scores": {
    "custom_a": { "score": 9, "reason": "Good" },
    "custom_b": { "score": 5, "reason": "Poor" }
  }
}'
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T41: SHIP with one low custom category → FAIL"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 17: Structured format score extraction
# ==========================================================================
echo "--- GROUP 17: extract_score handles structured format ---"

# Structured format with "score" key nested inside an object
setup_test_dir
setup_eval_fixture "GATE:QUALITY" '{
  "scores": {
    "correctness": { "score": 5, "reason": "Incomplete implementation" },
    "quality": { "score": 5, "reason": "Messy" },
    "test_coverage": { "score": 5, "reason": "Sparse" },
    "consistency": { "score": 5, "reason": "Misaligned" },
    "documentation": { "score": 5, "reason": "Missing" }
  }
}'
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T42: All structured scores at 5 → FAIL (below min)"
cleanup_test_dir

echo ""

# ==========================================================================
# GROUP 18: Intake gate (Issue #40 — host-vs-sub-repo state separation)
# ==========================================================================
# Plan §3.4–3.5 / Decision 5: `intake.md` must exist under
# `${STATE_DIR}/<sub-repo-id>/<issue-number>/` once the orchestrator passes
# PREFLIGHT. PREFLIGHT itself warns (covered in test-phase-set.sh T20);
# DIAGNOSE+ hard-blocks. Required tokens inside intake.md are
# `## Sub-Repo`, `## Branch`, `## State Location` (mirrors delegation.md
# token-presence pattern in check_delegation_exists at lines 353–362).
echo "--- GROUP 18: Intake gate (Issue #40) ---"

# T-intake-missing: namespaced layout, phase=DIAGNOSE, no intake.md → exit 1
setup_test_dir
mkdir -p "${TEST_DIR}/.autoflow-state/self/50"
echo "self/50" > "${TEST_DIR}/.autoflow-state/current-issue"
echo "DIAGNOSE" > "${TEST_DIR}/.autoflow-state/self/50/phase"
# Deliberately do NOT create intake.md
exit_code=$(run_hook)
assert_exit_code 1 "$exit_code" \
  "T-intake-missing: DIAGNOSE without intake.md → exit 1"
assert_output_contains "${TEST_DIR}/output.txt" "intake.md" \
  "T-intake-missing-msg: stderr/output mentions 'intake.md'"
cleanup_test_dir

echo ""

# T-intake-present: same fixture + valid intake.md → exit 0
setup_test_dir
mkdir -p "${TEST_DIR}/.autoflow-state/self/50"
echo "self/50" > "${TEST_DIR}/.autoflow-state/current-issue"
echo "DIAGNOSE" > "${TEST_DIR}/.autoflow-state/self/50/phase"
cat > "${TEST_DIR}/.autoflow-state/self/50/intake.md" <<'INTAKE'
# Intake — Issue #50

## Sub-Repo
self

## Branch
fix/50-test

## State Location
.autoflow-state/self/50/

## Source Issue URL
https://example.invalid/issues/50
INTAKE
exit_code=$(run_hook)
assert_exit_code 0 "$exit_code" \
  "T-intake-present: DIAGNOSE with valid intake.md → exit 0"
cleanup_test_dir

echo ""

# ==========================================================================
# Summary
# ==========================================================================
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "Failures:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
fi

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
