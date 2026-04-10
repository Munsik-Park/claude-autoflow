#!/usr/bin/env bash
# Test: TDD Cycle Restoration (Issue #4)
# Verifies RED/GREEN/VERIFY/REFINE sub-steps are present in template files.
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

# ---------- AC 1: Lifecycle table GATE:PLAN = "Plan Evaluation" ----------
test_ac1_step3_plan_evaluation() {
  echo "AC1: CLAUDE.md.template lifecycle table shows GATE:PLAN as Plan Evaluation"
  # Look for a table row with GATE:PLAN and "Plan Evaluation" (not "Implementation")
  if grep -E '^\| *GATE:PLAN .*Plan Evaluation' "$TEMPLATE" >/dev/null 2>&1; then
    pass "GATE:PLAN is Plan Evaluation"
  else
    fail "GATE:PLAN is not Plan Evaluation in lifecycle table"
  fi
}

# ---------- AC 2: Lifecycle table DISPATCH = "Task Assignment" ----------
test_ac2_step4_task_assignment() {
  echo "AC2: CLAUDE.md.template lifecycle table shows DISPATCH as Task Assignment"
  if grep -E '^\| *DISPATCH .*Task Assignment' "$TEMPLATE" >/dev/null 2>&1; then
    pass "DISPATCH is Task Assignment"
  else
    fail "DISPATCH is not Task Assignment in lifecycle table"
  fi
}

# ---------- AC 3: Template contains RED, GREEN, VERIFY, REFINE references ----------
test_ac3_step5_substeps() {
  echo "AC3: CLAUDE.md.template contains RED, GREEN, VERIFY, REFINE references"
  local all_found=true
  for phase in RED GREEN VERIFY REFINE; do
    if ! grep -q "$phase" "$TEMPLATE" 2>/dev/null; then
      all_found=false
      break
    fi
  done
  if $all_found; then
    pass "All RED/GREEN/VERIFY/REFINE references found"
  else
    fail "Missing one or more RED/GREEN/VERIFY/REFINE references"
  fi
}

# ---------- AC 4: Flow Control Table includes RED->GREEN->VERIFY->REFINE transitions ----------
test_ac4_flow_control_transitions() {
  echo "AC4: Flow Control Table in CLAUDE.md.template includes RED->GREEN->VERIFY->REFINE transitions"
  # Check for flow control rows mentioning RED, GREEN, VERIFY, REFINE
  local count
  count=$(grep -cE '^\|.*(RED|GREEN|VERIFY|REFINE)' "$TEMPLATE" 2>/dev/null || true)
  count=${count:-0}
  # Ensure count is a single number
  count=$(echo "$count" | tail -1)
  if [ "$count" -ge 4 ]; then
    pass "Flow control table has RED/GREEN/VERIFY/REFINE transitions"
  else
    fail "Flow control table missing RED/GREEN/VERIFY/REFINE transitions (found $count rows)"
  fi
}

# ---------- AC 5: RED phase requires Red confirmation ----------
test_ac5_red_confirmation() {
  echo "AC5: RED section requires Red confirmation (tests must FAIL)"
  if grep -qi 'red.*confirm\|must.*fail\|all.*fail' "$TEMPLATE" 2>/dev/null &&
     grep -q 'RED' "$TEMPLATE" 2>/dev/null; then
    # More specific: check that Red confirmation appears in context of RED
    # Extract section around RED and check for Red/FAIL
    if sed -n '/^###* RED/,/^###* GREEN/p' "$TEMPLATE" 2>/dev/null | grep -qiE 'red|must.*fail|all.*fail'; then
      pass "RED phase requires Red confirmation"
    else
      fail "RED phase does not mention Red confirmation"
    fi
  else
    fail "RED section with Red confirmation not found"
  fi
}

# ---------- AC 6: GREEN phase states minimum implementation principle ----------
test_ac6_minimum_implementation() {
  echo "AC6: GREEN section states minimum implementation principle"
  if sed -n '/^###* GREEN/,/^###* VERIFY/p' "$TEMPLATE" 2>/dev/null | grep -qiE 'minimum.*code|minimum.*implementation|not.*implement.*beyond.*test|do not implement.*not covered'; then
    pass "GREEN phase states minimum implementation principle"
  else
    fail "GREEN phase minimum implementation principle not found"
  fi
}

# ---------- AC 7: VERIFY phase includes 4 failure paths ----------
test_ac7_four_failure_paths() {
  echo "AC7: VERIFY section includes 4 failure paths (test issue, impl issue, both, deadlock)"
  local section
  section=$(sed -n '/^###* VERIFY/,/^###* REFINE/p' "$TEMPLATE" 2>/dev/null)
  if [ -z "$section" ]; then
    fail "VERIFY section not found"
    return
  fi
  local paths_found=0
  echo "$section" | grep -qiE 'test issue|test incorrect' && paths_found=$((paths_found + 1))
  echo "$section" | grep -qiE 'impl.* issue|implementation.* issue|implementation incorrect' && paths_found=$((paths_found + 1))
  echo "$section" | grep -qiE 'both' && paths_found=$((paths_found + 1))
  echo "$section" | grep -qiE 'deadlock' && paths_found=$((paths_found + 1))
  if [ "$paths_found" -ge 4 ]; then
    pass "All 4 failure paths found in VERIFY phase"
  else
    fail "Only $paths_found of 4 failure paths found in VERIFY phase"
  fi
}

# ---------- AC 8: Deadlock path mentions fresh Evaluation AI ----------
test_ac8_deadlock_fresh_eval() {
  echo "AC8: Deadlock path mentions fresh Evaluation AI"
  local section
  section=$(sed -n '/^###* VERIFY/,/^###* REFINE/p' "$TEMPLATE" 2>/dev/null)
  if [ -z "$section" ]; then
    fail "VERIFY section not found for deadlock check"
    return
  fi
  if echo "$section" | grep -qiE 'deadlock.*evaluation.*ai|evaluation.*ai.*arbitrat'; then
    pass "Deadlock path mentions fresh Evaluation AI"
  else
    fail "Deadlock path does not mention fresh Evaluation AI"
  fi
}

# ---------- AC 9: GREEN<->VERIFY round-trip limit: max 3 cycles ----------
test_ac9_roundtrip_limit() {
  echo "AC9: GREEN<->VERIFY round-trip limit: max 3 cycles documented"
  if grep -qE 'GREEN.*VERIFY.*3|VERIFY.*GREEN.*3|max.*3.*cycle|3.*round.?trip' "$TEMPLATE" 2>/dev/null; then
    pass "GREEN<->VERIFY max 3 cycle limit documented"
  else
    fail "GREEN<->VERIFY max 3 cycle limit not found"
  fi
}

# ---------- AC 10: REFINE phase includes refactor + Green re-confirmation + max 2 ----------
test_ac10_refactor_green() {
  echo "AC10: REFINE section includes refactor with Green re-confirmation, max 2 attempts"
  local section
  section=$(sed -n '/^###* REFINE/,/^###* GATE:QUALITY\|^###* REVISION\|^###* SHIP\|^###* LAND\|^## /p' "$TEMPLATE" 2>/dev/null)
  if [ -z "$section" ]; then
    fail "REFINE section not found"
    return
  fi
  local checks=0
  echo "$section" | grep -qiE 'refactor' && checks=$((checks + 1))
  echo "$section" | grep -qiE 'green|tests.*pass|re-run.*test' && checks=$((checks + 1))
  echo "$section" | grep -qiE 'max.*2|2.*attempt' && checks=$((checks + 1))
  if [ "$checks" -ge 3 ]; then
    pass "REFINE phase has refactor, Green re-confirmation, max 2 attempts"
  else
    fail "REFINE phase missing elements ($checks of 3 found)"
  fi
}

# ---------- AC 11: autoflow-guide.md contains RED/GREEN/VERIFY/REFINE subsections ----------
test_ac11_guide_substeps() {
  echo "AC11: autoflow-guide.md contains RED/GREEN/VERIFY/REFINE subsections"
  local all_found=true
  for phase in RED GREEN VERIFY REFINE; do
    if ! grep -qE '#+.*'"$phase" "$GUIDE" 2>/dev/null; then
      all_found=false
      break
    fi
  done
  if $all_found; then
    pass "autoflow-guide.md has RED/GREEN/VERIFY/REFINE subsections"
  else
    fail "autoflow-guide.md missing RED/GREEN/VERIFY/REFINE subsections"
  fi
}

# ---------- AC 12: autoflow-guide.md regression rules include GREEN<->VERIFY cycle limits ----------
test_ac12_guide_regression() {
  echo "AC12: autoflow-guide.md regression rules include GREEN<->VERIFY cycle limits"
  if grep -qE 'GREEN.*VERIFY|VERIFY.*GREEN' "$GUIDE" 2>/dev/null; then
    pass "autoflow-guide.md regression rules include GREEN<->VERIFY cycle limits"
  else
    fail "autoflow-guide.md missing GREEN<->VERIFY cycle limits in regression rules"
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

# ---------- AC 15: evaluation-system.md references "VERIFY" ----------
test_ac15_eval_step5c() {
  echo "AC15: evaluation-system.md references VERIFY (not generic TDD cycle)"
  if grep -q 'VERIFY' "$EVAL_SYSTEM" 2>/dev/null; then
    pass "evaluation-system.md references VERIFY"
  else
    fail "evaluation-system.md does not reference VERIFY"
  fi
}

# ---------- AC 16: README.md lifecycle table shows updated GATE:PLAN/DISPATCH/RED names ----------
test_ac16_readme_lifecycle() {
  echo "AC16: README.md lifecycle table shows updated GATE:PLAN/DISPATCH/RED names"
  local checks=0
  grep -qE 'GATE:PLAN.*Plan Evaluation' "$README" 2>/dev/null && checks=$((checks + 1))
  grep -qE 'DISPATCH.*Task Assignment' "$README" 2>/dev/null && checks=$((checks + 1))
  grep -qE '\bRED\b' "$README" 2>/dev/null && checks=$((checks + 1))
  if [ "$checks" -ge 3 ]; then
    pass "README.md lifecycle table updated for GATE:PLAN/DISPATCH/RED"
  else
    fail "README.md lifecycle table not updated ($checks of 3 checks passed)"
  fi
}

# ---------- AC 17: Pure documentation changes bypass guidance ----------
test_ac17_pure_docs_bypass() {
  echo "AC17: Pure documentation changes bypass guidance exists in CLAUDE.md.template"
  if grep -qiE 'pure.*doc.*change|pure.*prose.*change|skip.*tdd|skip.*red\b|bypass.*test' "$TEMPLATE" 2>/dev/null; then
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
