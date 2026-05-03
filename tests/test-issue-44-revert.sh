#!/usr/bin/env bash
# Test: Revert of Issue #33 / PR #43 (Issue #44)
# Encodes the 22 ACs from .autoflow-state/autoflow-upstream/44/plan.md (lines 78-99).
# Each AC is wired into a function `test_acN_<short_name>`. Aggregates pass/fail counts.
# Exits 0 only when every AC passes. Before the revert, several ACs MUST FAIL (RED).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PASS_COUNT=0
FAIL_COUNT=0
FAILED_ACS=()

pass() {
  echo "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED_ACS+=("$2")
}

# ---------- AC1: Forbidden token zero — TERMINAL:VERIFY-FAILED ----------
test_ac1_forbidden_terminal_token() {
  echo "AC1: 'TERMINAL:VERIFY-FAILED' must not appear anywhere in the working tree"
  if ! grep -rF 'TERMINAL:VERIFY-FAILED' --exclude-dir='.git' --exclude-dir='node_modules' . >/dev/null 2>&1; then
    pass "no occurrences of 'TERMINAL:VERIFY-FAILED'"
  else
    fail "'TERMINAL:VERIFY-FAILED' still appears in the tree" "AC1"
  fi
}

# ---------- AC2: Forbidden token zero — forensic-recorder ----------
test_ac2_forbidden_forensic_recorder() {
  echo "AC2: 'forensic-recorder' must not appear anywhere in the working tree"
  if ! grep -rF 'forensic-recorder' --exclude-dir='.git' --exclude-dir='node_modules' . >/dev/null 2>&1; then
    pass "no occurrences of 'forensic-recorder'"
  else
    fail "'forensic-recorder' still appears in the tree" "AC2"
  fi
}

# ---------- AC3: Forbidden token zero — detailed-failure-analysis ----------
test_ac3_forbidden_detailed_failure_analysis() {
  echo "AC3: 'detailed-failure-analysis' must not appear anywhere in the working tree"
  if ! grep -rF 'detailed-failure-analysis' --exclude-dir='.git' --exclude-dir='node_modules' . >/dev/null 2>&1; then
    pass "no occurrences of 'detailed-failure-analysis'"
  else
    fail "'detailed-failure-analysis' still appears in the tree" "AC3"
  fi
}

# ---------- AC4: Required token — Flow Control row in CLAUDE.md ----------
test_ac4_flow_control_verify_deadlock() {
  echo "AC4: CLAUDE.md must contain 'VERIFY DEADLOCK' Flow Control row"
  if grep -F 'VERIFY DEADLOCK' CLAUDE.md >/dev/null 2>&1; then
    pass "'VERIFY DEADLOCK' present in CLAUDE.md"
  else
    fail "'VERIFY DEADLOCK' missing from CLAUDE.md" "AC4"
  fi
}

# ---------- AC5: Required token — narrative line, CLAUDE.md ----------
test_ac5_claudemd_fresh_eval_narrative() {
  echo "AC5: CLAUDE.md must contain 'fresh Evaluation AI arbitrates' narrative line"
  if grep -F 'fresh Evaluation AI arbitrates' CLAUDE.md >/dev/null 2>&1; then
    pass "'fresh Evaluation AI arbitrates' present in CLAUDE.md"
  else
    fail "'fresh Evaluation AI arbitrates' missing from CLAUDE.md" "AC5"
  fi
}

# ---------- AC6: Required token — narrative line, CLAUDE.md.template ----------
test_ac6_template_fresh_eval_narrative() {
  echo "AC6: CLAUDE.md.template must contain 'fresh Evaluation AI arbitrates' narrative line"
  if grep -F 'fresh Evaluation AI arbitrates' CLAUDE.md.template >/dev/null 2>&1; then
    pass "'fresh Evaluation AI arbitrates' present in CLAUDE.md.template"
  else
    fail "'fresh Evaluation AI arbitrates' missing from CLAUDE.md.template" "AC6"
  fi
}

# ---------- AC7: Required token — narrative line, autoflow-guide.md ----------
test_ac7_guide_fresh_eval_narrative() {
  echo "AC7: docs/autoflow-guide.md must contain 'fresh Evaluation AI arbitrates' narrative line"
  if grep -F 'fresh Evaluation AI arbitrates' docs/autoflow-guide.md >/dev/null 2>&1; then
    pass "'fresh Evaluation AI arbitrates' present in docs/autoflow-guide.md"
  else
    fail "'fresh Evaluation AI arbitrates' missing from docs/autoflow-guide.md" "AC7"
  fi
}

# ---------- AC8: Decision 11 fully removed ----------
test_ac8_decision11_removed() {
  echo "AC8: docs/design-rationale.md must not contain 'Decision 11:'"
  if ! grep -F 'Decision 11:' docs/design-rationale.md >/dev/null 2>&1; then
    pass "'Decision 11:' absent from docs/design-rationale.md"
  else
    fail "'Decision 11:' still present in docs/design-rationale.md" "AC8"
  fi
}

# ---------- AC9: Signal 2 wording restored ----------
test_ac9_signal2_dispute_arbitration() {
  echo "AC9: docs/design-rationale.md must contain exactly one 'dispute arbitration trigger'"
  local count
  count=$(grep -F 'dispute arbitration trigger' docs/design-rationale.md 2>/dev/null | wc -l | tr -d '[:space:]')
  count="${count:-0}"
  if [ "$count" = "1" ]; then
    pass "'dispute arbitration trigger' appears exactly once"
  else
    fail "'dispute arbitration trigger' appears $count time(s) (expected 1)" "AC9"
  fi
}

# ---------- AC10: Test file deletion ----------
test_ac10_issue33_test_deleted() {
  echo "AC10: tests/test-issue-33-verify-terminal.sh must not exist"
  if [ ! -f tests/test-issue-33-verify-terminal.sh ]; then
    pass "tests/test-issue-33-verify-terminal.sh has been deleted"
  else
    fail "tests/test-issue-33-verify-terminal.sh still exists" "AC10"
  fi
}

# ---------- AC11: phase-set VALID_PHASES line lacks TERMINAL ----------
test_ac11_phase_set_valid_phases() {
  echo "AC11: .claude/scripts/phase-set VALID_PHASES line must not contain 'TERMINAL'"
  if grep -E '^readonly VALID_PHASES=' .claude/scripts/phase-set 2>/dev/null | grep -v -F 'TERMINAL' >/dev/null 2>&1; then
    pass "VALID_PHASES line exists and lacks 'TERMINAL'"
  else
    fail "VALID_PHASES line missing or still contains 'TERMINAL'" "AC11"
  fi
}

# ---------- AC12: Regression — phase-set tests ----------
test_ac12_phase_set_tests_pass() {
  echo "AC12: tests/test-phase-set.sh must exit 0 with stdout containing '0 failed'"
  local out exit_code
  out=$(bash tests/test-phase-set.sh 2>&1) || true
  exit_code=$?
  if [ $exit_code -eq 0 ] && echo "$out" | grep -F '0 failed' >/dev/null 2>&1; then
    pass "tests/test-phase-set.sh: exit 0 and '0 failed'"
  else
    fail "tests/test-phase-set.sh: exit=$exit_code; '0 failed' not found in output" "AC12"
  fi
}

# ---------- AC13: Regression — hook role-marker tests ----------
test_ac13_hook_role_marker_tests_pass() {
  echo "AC13: tests/test-hook-role-marker.sh must exit 0 with stdout containing 'FAIL: 0'"
  local out exit_code
  out=$(bash tests/test-hook-role-marker.sh 2>&1) || true
  exit_code=$?
  if [ $exit_code -eq 0 ] && echo "$out" | grep -F 'FAIL: 0' >/dev/null 2>&1; then
    pass "tests/test-hook-role-marker.sh: exit 0 and 'FAIL: 0'"
  else
    fail "tests/test-hook-role-marker.sh: exit=$exit_code; 'FAIL: 0' not found in output" "AC13"
  fi
}

# ---------- AC14: Restoration — TDD cycle restoration tests ----------
test_ac14_tdd_cycle_restoration_pass() {
  echo "AC14: tests/test-tdd-cycle-restoration.sh must exit 0 with '0 FAIL', '0 failed', or 'FAIL: 0'"
  local out exit_code
  out=$(bash tests/test-tdd-cycle-restoration.sh 2>&1)
  exit_code=$?
  if [ $exit_code -eq 0 ] && \
     (echo "$out" | grep -E '0 (FAIL|failed)|FAIL: 0' >/dev/null 2>&1); then
    pass "tests/test-tdd-cycle-restoration.sh: exit 0 and zero-failure summary line found"
  else
    fail "tests/test-tdd-cycle-restoration.sh: exit=$exit_code; zero-failure summary not found" "AC14"
  fi
}

# ---------- AC15: Revert completeness — diff stat (5 zero-#45/#46 files) ----------
test_ac15_revert_diff_stat_empty() {
  echo "AC15: 5 files with zero #45/#46 edits must be byte-identical to fa93b6f"
  local diff_out
  diff_out=$(git diff fa93b6f..HEAD --stat -- \
    .claude/hooks/check-autoflow-gate.sh \
    .claude/scripts/phase-set \
    docs/design-rationale.md \
    docs/evaluation-system.md \
    tests/test-tdd-cycle-restoration.sh 2>/dev/null)
  if [ -z "$diff_out" ]; then
    pass "git diff fa93b6f..HEAD --stat is empty for the 5 zero-delta files"
  else
    fail "git diff fa93b6f..HEAD --stat returned non-empty: $diff_out" "AC15"
  fi
}

# ---------- AC16: Revert completeness — file deletion ----------
test_ac16_issue33_file_absent() {
  echo "AC16: tests/test-issue-33-verify-terminal.sh must be absent (file-existence check)"
  if [ ! -f tests/test-issue-33-verify-terminal.sh ]; then
    pass "file is absent"
  else
    fail "file still present" "AC16"
  fi
}

# ---------- AC17: #45 preservation — CLAUDE.md axis 3 ----------
test_ac17_claudemd_axis3_preserved() {
  echo "AC17: CLAUDE.md must contain 'Structural Change Necessity' (#45 axis 3)"
  if grep -F 'Structural Change Necessity' CLAUDE.md >/dev/null 2>&1; then
    pass "'Structural Change Necessity' preserved in CLAUDE.md"
  else
    fail "'Structural Change Necessity' missing from CLAUDE.md" "AC17"
  fi
}

# ---------- AC18: #45 preservation — CLAUDE.md.template axis 3 ----------
test_ac18_template_axis3_preserved() {
  echo "AC18: CLAUDE.md.template must contain 'Structural Change Necessity' (#45 axis 3)"
  if grep -F 'Structural Change Necessity' CLAUDE.md.template >/dev/null 2>&1; then
    pass "'Structural Change Necessity' preserved in CLAUDE.md.template"
  else
    fail "'Structural Change Necessity' missing from CLAUDE.md.template" "AC18"
  fi
}

# ---------- AC19: #45 preservation — autoflow-guide.md axis 3 ----------
test_ac19_guide_axis3_preserved() {
  echo "AC19: docs/autoflow-guide.md must contain 'Structural Change Necessity' (#45 axis 3)"
  if grep -F 'Structural Change Necessity' docs/autoflow-guide.md >/dev/null 2>&1; then
    pass "'Structural Change Necessity' preserved in docs/autoflow-guide.md"
  else
    fail "'Structural Change Necessity' missing from docs/autoflow-guide.md" "AC19"
  fi
}

# ---------- AC20: Hook arm fully removed ----------
test_ac20_hook_arm_removed() {
  echo "AC20: .claude/hooks/check-autoflow-gate.sh must not contain 'TERMINAL:VERIFY-FAILED)' case-arm"
  if ! grep -F 'TERMINAL:VERIFY-FAILED)' .claude/hooks/check-autoflow-gate.sh >/dev/null 2>&1; then
    pass "case-arm 'TERMINAL:VERIFY-FAILED)' absent from hook"
  else
    fail "case-arm 'TERMINAL:VERIFY-FAILED)' still present in hook" "AC20"
  fi
}

# ---------- AC21: Helper fully removed ----------
test_ac21_check_helper_removed() {
  echo "AC21: .claude/hooks/check-autoflow-gate.sh must not contain 'check_detailed_failure_artifact'"
  if ! grep -F 'check_detailed_failure_artifact' .claude/hooks/check-autoflow-gate.sh >/dev/null 2>&1; then
    pass "helper 'check_detailed_failure_artifact' absent from hook"
  else
    fail "helper 'check_detailed_failure_artifact' still present in hook" "AC21"
  fi
}

# ---------- AC22: Do-not table row removed ----------
test_ac22_do_not_row_removed() {
  echo "AC22: docs/design-rationale.md must not contain 'Auto-reclassify a test artifact during VERIFY'"
  if ! grep -F 'Auto-reclassify a test artifact during VERIFY' docs/design-rationale.md >/dev/null 2>&1; then
    pass "'Auto-reclassify a test artifact during VERIFY' row absent"
  else
    fail "'Auto-reclassify a test artifact during VERIFY' row still present" "AC22"
  fi
}

# ---------- Run all ACs ----------
test_ac1_forbidden_terminal_token
test_ac2_forbidden_forensic_recorder
test_ac3_forbidden_detailed_failure_analysis
test_ac4_flow_control_verify_deadlock
test_ac5_claudemd_fresh_eval_narrative
test_ac6_template_fresh_eval_narrative
test_ac7_guide_fresh_eval_narrative
test_ac8_decision11_removed
test_ac9_signal2_dispute_arbitration
test_ac10_issue33_test_deleted
test_ac11_phase_set_valid_phases
test_ac12_phase_set_tests_pass
test_ac13_hook_role_marker_tests_pass
test_ac14_tdd_cycle_restoration_pass
test_ac15_revert_diff_stat_empty
test_ac16_issue33_file_absent
test_ac17_claudemd_axis3_preserved
test_ac18_template_axis3_preserved
test_ac19_guide_axis3_preserved
test_ac20_hook_arm_removed
test_ac21_check_helper_removed
test_ac22_do_not_row_removed

# ---------- Summary ----------
echo ""
echo "==================================================="
echo "Issue #44 revert ACs — PASS: $PASS_COUNT, FAIL: $FAIL_COUNT"
if [ ${#FAILED_ACS[@]} -gt 0 ]; then
  echo "Failed ACs: ${FAILED_ACS[*]}"
fi
echo "==================================================="

if [ "$FAIL_COUNT" -eq 0 ]; then
  exit 0
else
  exit 1
fi
