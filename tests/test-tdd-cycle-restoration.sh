#!/usr/bin/env bash
# Test: TDD Cycle Restoration (Issue #4)
# Verifies STEP 5a/5b/5c/5d sub-steps are present in template files.
# All tests should FAIL (Red) before implementation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TEMPLATE="$REPO_ROOT/CLAUDE.md.template"
GUIDE="$REPO_ROOT/docs/autoflow-guide.md"
EVAL_SYSTEM="$REPO_ROOT/docs/evaluation-system.md"
README="$REPO_ROOT/README.md"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# ---------- AC 1: Lifecycle table STEP 3 = "Plan Evaluation" ----------
test_ac1_step3_plan_evaluation() {
  echo "AC1: CLAUDE.md.template lifecycle table shows STEP 3 as Plan Evaluation"
  # Look for a table row with STEP 3 and "Plan Evaluation" (not "Implementation")
  if grep -E '^\| *3 .*Plan Evaluation' "$TEMPLATE" >/dev/null 2>&1; then
    pass "STEP 3 is Plan Evaluation"
  else
    fail "STEP 3 is not Plan Evaluation in lifecycle table"
  fi
}

# ---------- AC 2: Lifecycle table STEP 4 = "Task Assignment" ----------
test_ac2_step4_task_assignment() {
  echo "AC2: CLAUDE.md.template lifecycle table shows STEP 4 as Task Assignment"
  if grep -E '^\| *4 .*Task Assignment' "$TEMPLATE" >/dev/null 2>&1; then
    pass "STEP 4 is Task Assignment"
  else
    fail "STEP 4 is not Task Assignment in lifecycle table"
  fi
}

# ---------- AC 3: Template contains STEP 5a, 5b, 5c, 5d references ----------
test_ac3_step5_substeps() {
  echo "AC3: CLAUDE.md.template contains STEP 5a, 5b, 5c, 5d references"
  local all_found=true
  for sub in 5a 5b 5c 5d; do
    if ! grep -q "STEP $sub" "$TEMPLATE" 2>/dev/null; then
      all_found=false
      break
    fi
  done
  if $all_found; then
    pass "All STEP 5a/5b/5c/5d references found"
  else
    fail "Missing one or more STEP 5a/5b/5c/5d references"
  fi
}

# ---------- AC 4: Flow Control Table includes 5a->5b->5c->5d transitions ----------
test_ac4_flow_control_transitions() {
  echo "AC4: Flow Control Table in CLAUDE.md.template includes 5a->5b->5c->5d transitions"
  # Check for flow control rows mentioning 5a, 5b, 5c, 5d
  local count
  count=$(grep -cE '^\|.*STEP 5[abcd]' "$TEMPLATE" 2>/dev/null || true)
  count=${count:-0}
  # Ensure count is a single number
  count=$(echo "$count" | tail -1)
  if [ "$count" -ge 4 ]; then
    pass "Flow control table has 5a/5b/5c/5d transitions"
  else
    fail "Flow control table missing 5a/5b/5c/5d transitions (found $count rows)"
  fi
}

# ---------- AC 5: STEP 5a requires Red confirmation ----------
test_ac5_red_confirmation() {
  echo "AC5: STEP 5a section requires Red confirmation (tests must FAIL)"
  if grep -qi 'red.*confirm\|must.*fail\|all.*fail' "$TEMPLATE" 2>/dev/null &&
     grep -q '5a' "$TEMPLATE" 2>/dev/null; then
    # More specific: check that Red confirmation appears in context of 5a
    # Extract section around 5a and check for Red/FAIL
    if sed -n '/STEP 5a/,/STEP 5[bcd]/p' "$TEMPLATE" 2>/dev/null | grep -qiE 'red|must.*fail|all.*fail'; then
      pass "STEP 5a requires Red confirmation"
    else
      fail "STEP 5a does not mention Red confirmation"
    fi
  else
    fail "STEP 5a section with Red confirmation not found"
  fi
}

# ---------- AC 6: STEP 5b states minimum implementation principle ----------
test_ac6_minimum_implementation() {
  echo "AC6: STEP 5b states minimum implementation principle"
  if sed -n '/STEP 5b/,/STEP 5[cd]/p' "$TEMPLATE" 2>/dev/null | grep -qiE 'minimum.*code|minimum.*implementation|not.*implement.*beyond.*test|do not implement.*not covered'; then
    pass "STEP 5b states minimum implementation principle"
  else
    fail "STEP 5b minimum implementation principle not found"
  fi
}

# ---------- AC 7: STEP 5c includes 4 failure paths ----------
test_ac7_four_failure_paths() {
  echo "AC7: STEP 5c includes 4 failure paths (test issue, impl issue, both, deadlock)"
  local section
  section=$(sed -n '/STEP 5c/,/STEP 5d/p' "$TEMPLATE" 2>/dev/null)
  if [ -z "$section" ]; then
    fail "STEP 5c section not found"
    return
  fi
  local paths_found=0
  echo "$section" | grep -qiE 'test issue|test incorrect' && paths_found=$((paths_found + 1))
  echo "$section" | grep -qiE 'impl.* issue|implementation.* issue|implementation incorrect' && paths_found=$((paths_found + 1))
  echo "$section" | grep -qiE 'both' && paths_found=$((paths_found + 1))
  echo "$section" | grep -qiE 'deadlock' && paths_found=$((paths_found + 1))
  if [ "$paths_found" -ge 4 ]; then
    pass "All 4 failure paths found in STEP 5c"
  else
    fail "Only $paths_found of 4 failure paths found in STEP 5c"
  fi
}

# ---------- AC 8: Deadlock path mentions fresh Evaluation AI ----------
test_ac8_deadlock_fresh_eval() {
  echo "AC8: Deadlock path mentions fresh Evaluation AI"
  local section
  section=$(sed -n '/STEP 5c/,/STEP 5d/p' "$TEMPLATE" 2>/dev/null)
  if [ -z "$section" ]; then
    fail "STEP 5c section not found for deadlock check"
    return
  fi
  if echo "$section" | grep -qiE 'deadlock.*evaluation.*ai|evaluation.*ai.*arbitrat'; then
    pass "Deadlock path mentions fresh Evaluation AI"
  else
    fail "Deadlock path does not mention fresh Evaluation AI"
  fi
}

# ---------- AC 9: 5b<->5c round-trip limit: max 3 cycles ----------
test_ac9_roundtrip_limit() {
  echo "AC9: 5b<->5c round-trip limit: max 3 cycles documented"
  if grep -qE '5b.*5c.*3|max.*3.*cycle|3.*round.?trip' "$TEMPLATE" 2>/dev/null; then
    pass "5b<->5c max 3 cycle limit documented"
  else
    fail "5b<->5c max 3 cycle limit not found"
  fi
}

# ---------- AC 10: STEP 5d includes refactor + Green re-confirmation + max 2 ----------
test_ac10_refactor_green() {
  echo "AC10: STEP 5d includes refactor with Green re-confirmation, max 2 attempts"
  local section
  section=$(sed -n '/STEP 5d/,/STEP [67]/p' "$TEMPLATE" 2>/dev/null)
  if [ -z "$section" ]; then
    fail "STEP 5d section not found"
    return
  fi
  local checks=0
  echo "$section" | grep -qiE 'refactor' && checks=$((checks + 1))
  echo "$section" | grep -qiE 'green|tests.*pass|re-run.*test' && checks=$((checks + 1))
  echo "$section" | grep -qiE 'max.*2|2.*attempt' && checks=$((checks + 1))
  if [ "$checks" -ge 3 ]; then
    pass "STEP 5d has refactor, Green re-confirmation, max 2 attempts"
  else
    fail "STEP 5d missing elements ($checks of 3 found)"
  fi
}

# ---------- AC 11: autoflow-guide.md contains STEP 5a/5b/5c/5d subsections ----------
test_ac11_guide_substeps() {
  echo "AC11: autoflow-guide.md contains STEP 5a/5b/5c/5d subsections"
  local all_found=true
  for sub in 5a 5b 5c 5d; do
    if ! grep -qE '#+.*STEP '$sub'|#+.*5'${sub: -1} "$GUIDE" 2>/dev/null; then
      all_found=false
      break
    fi
  done
  if $all_found; then
    pass "autoflow-guide.md has STEP 5a/5b/5c/5d subsections"
  else
    fail "autoflow-guide.md missing STEP 5a/5b/5c/5d subsections"
  fi
}

# ---------- AC 12: autoflow-guide.md regression rules include 5b<->5c cycle limits ----------
test_ac12_guide_regression() {
  echo "AC12: autoflow-guide.md regression rules include 5b<->5c cycle limits"
  if grep -qE '5b.*5c|5c.*5b' "$GUIDE" 2>/dev/null; then
    pass "autoflow-guide.md regression rules include 5b<->5c cycle limits"
  else
    fail "autoflow-guide.md missing 5b<->5c cycle limits in regression rules"
  fi
}

# ---------- AC 13: autoflow-guide.md uses "phase-3.md" (not "phase-c.md") ----------
test_ac13_phase3_filename() {
  echo "AC13: autoflow-guide.md uses phase-3.md (not phase-c.md) in state file structure"
  if grep -q 'phase-3\.md' "$GUIDE" 2>/dev/null; then
    pass "autoflow-guide.md uses phase-3.md"
  else
    fail "autoflow-guide.md does not use phase-3.md (may use phase-c.md instead)"
  fi
}

# ---------- AC 14: evaluation-system.md does NOT contain "5.7" reference ----------
test_ac14_no_5_7() {
  echo "AC14: evaluation-system.md does NOT contain 5.7 reference"
  if grep -q '5\.7' "$EVAL_SYSTEM" 2>/dev/null; then
    fail "evaluation-system.md still contains 5.7 reference"
  else
    pass "evaluation-system.md does not contain 5.7 reference"
  fi
}

# ---------- AC 15: evaluation-system.md references "STEP 5c" ----------
test_ac15_eval_step5c() {
  echo "AC15: evaluation-system.md references STEP 5c (not flat STEP 5)"
  if grep -q 'STEP 5c' "$EVAL_SYSTEM" 2>/dev/null; then
    pass "evaluation-system.md references STEP 5c"
  else
    fail "evaluation-system.md does not reference STEP 5c"
  fi
}

# ---------- AC 16: README.md lifecycle table shows updated STEP 3/4/5 names ----------
test_ac16_readme_lifecycle() {
  echo "AC16: README.md lifecycle table shows updated STEP 3/4/5 names"
  local checks=0
  grep -qE 'STEP 3.*Plan Evaluation' "$README" 2>/dev/null && checks=$((checks + 1))
  grep -qE 'STEP 4.*Task Assignment' "$README" 2>/dev/null && checks=$((checks + 1))
  grep -qE 'STEP 5a' "$README" 2>/dev/null && checks=$((checks + 1))
  if [ "$checks" -ge 3 ]; then
    pass "README.md lifecycle table updated for STEP 3/4/5"
  else
    fail "README.md lifecycle table not updated ($checks of 3 checks passed)"
  fi
}

# ---------- AC 17: Pure documentation changes bypass guidance ----------
test_ac17_pure_docs_bypass() {
  echo "AC17: Pure documentation changes bypass guidance exists in CLAUDE.md.template"
  if grep -qiE 'pure.*doc.*change|pure.*prose.*change|skip.*tdd|skip.*step.*5|bypass.*test' "$TEMPLATE" 2>/dev/null; then
    pass "Pure documentation changes bypass guidance found"
  else
    fail "Pure documentation changes bypass guidance not found"
  fi
}

# ========== Run all tests ==========
echo "============================================"
echo "Test Suite: TDD Cycle Restoration (Issue #4)"
echo "============================================"
echo ""

test_ac1_step3_plan_evaluation
test_ac2_step4_task_assignment
test_ac3_step5_substeps
test_ac4_flow_control_transitions
test_ac5_red_confirmation
test_ac6_minimum_implementation
test_ac7_four_failure_paths
test_ac8_deadlock_fresh_eval
test_ac9_roundtrip_limit
test_ac10_refactor_green
test_ac11_guide_substeps
test_ac12_guide_regression
test_ac13_phase3_filename
test_ac14_no_5_7
test_ac15_eval_step5c
test_ac16_readme_lifecycle
test_ac17_pure_docs_bypass

echo ""
echo "============================================"
echo "Results: $PASS_COUNT PASS / $FAIL_COUNT FAIL (total $((PASS_COUNT + FAIL_COUNT)))"
echo "============================================"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
else
  exit 0
fi
