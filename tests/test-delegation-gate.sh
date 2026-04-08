#!/usr/bin/env bash
# Test Suite: Delegation Gate for STEP 4 (Issue #16)
# Validates that delegation.md is enforced as a mandatory artifact
# before STEP 5a can begin, across documentation and hook logic.

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

assert_contains() {
  local file="$1" pattern="$2" desc="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc (pattern '$pattern' not found in $file)")
    echo "  FAIL: $desc"
  fi
}

assert_not_contains() {
  local file="$1" pattern="$2" desc="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc (pattern '$pattern' found in $file)")
    echo "  FAIL: $desc"
  else
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  fi
}

TEMPLATE="CLAUDE.md.template"
CLAUDE_MD="CLAUDE.md"
GUIDE="docs/autoflow-guide.md"
HOOK=".claude/hooks/check-autoflow-gate.sh"

echo "=== Test Suite: Delegation Gate for STEP 4 (Issue #16) ==="
echo ""

# ==========================================================================
# AC1: CLAUDE.md.template STEP 4 section mentions delegation.md as mandatory
# ==========================================================================
echo "--- AC1: STEP 4 mentions delegation.md as mandatory ---"

assert_contains "$TEMPLATE" "delegation\.md" \
  "T1: CLAUDE.md.template STEP 4 section references delegation.md"

assert_contains "$TEMPLATE" "delegation\.md.*mandatory\|[MUST].*delegation\.md\|\[MUST\].*delegation" \
  "T2: CLAUDE.md.template marks delegation.md as mandatory in STEP 4"

echo ""

# ==========================================================================
# AC2: CLAUDE.md.template STEP 5a mentions delegation.md as entry precondition
# ==========================================================================
echo "--- AC2: STEP 5a mentions delegation.md as precondition ---"

assert_contains "$TEMPLATE" "delegation\.md.*precondition\|delegation\.md.*before\|delegation\.md.*exists\|delegation\.md.*entry" \
  "T3: CLAUDE.md.template STEP 5a references delegation.md as entry requirement"

echo ""

# ==========================================================================
# AC3: delegation.md format is defined with required sections
# ==========================================================================
echo "--- AC3: delegation.md format definition ---"

# The template should define the expected structure of delegation.md
assert_contains "$TEMPLATE" "Team\|team" \
  "T4: delegation.md format includes Team section (already present — baseline)"

# These are the specific sections that delegation.md must contain
assert_contains "$TEMPLATE" "Test AI Instructions\|test-ai.*instructions\|Test AI.*task" \
  "T5: delegation.md format includes Test AI Instructions section"

assert_contains "$TEMPLATE" "Developer AI Instructions\|dev-ai.*instructions\|Developer AI.*task" \
  "T6: delegation.md format includes Developer AI Instructions section"

echo ""

# ==========================================================================
# AC4: Flow Control Table includes delegation.md in STEP 4 condition
# ==========================================================================
echo "--- AC4: Flow Control Table updated ---"

assert_contains "$TEMPLATE" "STEP 4.*delegation\.md\|delegation\.md.*STEP 4" \
  "T7: Flow Control table mentions delegation.md for STEP 4"

echo ""

# ==========================================================================
# AC5: docs/autoflow-guide.md is consistent with template updates
# ==========================================================================
echo "--- AC5: autoflow-guide.md consistency ---"

assert_contains "$GUIDE" "delegation\.md" \
  "T8: autoflow-guide.md references delegation.md"

assert_contains "$GUIDE" "delegation\.md.*mandatory\|[MUST].*delegation\|\[MUST\].*delegation" \
  "T9: autoflow-guide.md marks delegation.md as mandatory"

echo ""

# ==========================================================================
# AC6: State File Structure includes delegation.md
# ==========================================================================
echo "--- AC6: State File Structure includes delegation.md ---"

assert_contains "$GUIDE" "delegation\.md.*#\|├── delegation\.md\|└── delegation\.md" \
  "T10: autoflow-guide.md state file structure lists delegation.md"

assert_contains "$CLAUDE_MD" "delegation\.md.*#\|├── delegation\.md\|└── delegation\.md" \
  "T11: CLAUDE.md state file structure lists delegation.md"

echo ""

# ==========================================================================
# AC7-9: Hook behavior tests (check-autoflow-gate.sh)
# ==========================================================================
echo "--- AC7-9: Hook behavior tests ---"

# Create a temporary directory for hook testing
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Set up mock autoflow-state directory
setup_mock_state() {
  local step="$1"
  local issue="99"
  mkdir -p "${TEST_DIR}/.autoflow-state/${issue}"
  echo "$issue" > "${TEST_DIR}/.autoflow-state/current-issue"
  echo "$step" > "${TEST_DIR}/.autoflow-state/${issue}/step"
}

# AC7: Hook validates delegation.md existence at STEP >= 5
echo ""
echo "  --- AC7: Hook checks delegation.md at STEP >= 5 ---"

setup_mock_state 5
CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > "${TEST_DIR}/output-step5.txt" 2>&1 || true
if grep -qi "delegation" "${TEST_DIR}/output-step5.txt" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: T12: Hook mentions delegation.md when checking STEP 5"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T12: Hook does not mention delegation.md at STEP 5")
  echo "  FAIL: T12: Hook mentions delegation.md when checking STEP 5"
fi

# AC8: Hook exits 1 with clear error when delegation.md missing at STEP >= 5
echo ""
echo "  --- AC8: Hook exits 1 when delegation.md missing ---"

setup_mock_state 5
# Ensure no delegation.md exists
rm -f "${TEST_DIR}/.autoflow-state/99/delegation.md"
hook_exit=0
CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > "${TEST_DIR}/output-missing.txt" 2>&1 || hook_exit=$?
if [ "$hook_exit" -eq 1 ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T13: Hook exits 1 when delegation.md is missing at STEP 5"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T13: Hook exits 0 (should exit 1) when delegation.md is missing at STEP 5 (got exit $hook_exit)")
  echo "  FAIL: T13: Hook exits 1 when delegation.md is missing at STEP 5"
fi

# Also test STEP 6 (should also require delegation.md)
setup_mock_state 6
rm -f "${TEST_DIR}/.autoflow-state/99/delegation.md"
# Create a passing evaluation.json so the eval gate doesn't mask the delegation check
mkdir -p "${TEST_DIR}/.autoflow-state/99"
cat > "${TEST_DIR}/.autoflow-state/99/evaluation.json" <<'EJSON'
{
  "scores": {
    "correctness": { "score": 9 },
    "code_quality": { "score": 9 },
    "test_coverage": { "score": 9 },
    "security": { "score": 9 },
    "performance": { "score": 9 }
  }
}
EJSON
hook_exit_6=0
CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > "${TEST_DIR}/output-step6-nodelegation.txt" 2>&1 || hook_exit_6=$?
if grep -qi "delegation" "${TEST_DIR}/output-step6-nodelegation.txt" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: T14: Hook checks delegation.md at STEP 6"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T14: Hook does not check delegation.md at STEP 6")
  echo "  FAIL: T14: Hook checks delegation.md at STEP 6"
fi

# AC9: STEP 0-4 commits still work without delegation.md (no regression)
echo ""
echo "  --- AC9: No regression for STEP 0-4 ---"

for s in 0 1 2 3 4; do
  setup_mock_state "$s"
  rm -f "${TEST_DIR}/.autoflow-state/99/delegation.md"
  step_exit=0
  CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > "${TEST_DIR}/output-step${s}.txt" 2>&1 || step_exit=$?
  if [ "$step_exit" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  PASS: T15-${s}: Hook passes at STEP ${s} without delegation.md"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: T15-${s}: Hook fails at STEP ${s} without delegation.md (exit $step_exit)")
    echo "  FAIL: T15-${s}: Hook passes at STEP ${s} without delegation.md"
  fi
done

# Bonus: Hook passes at STEP 5 when delegation.md EXISTS
echo ""
echo "  --- Bonus: Hook passes when delegation.md is present ---"

setup_mock_state 5
cat > "${TEST_DIR}/.autoflow-state/99/delegation.md" <<'DELEG'
## Team
issue-16-team

## Test AI Instructions
Write tests for acceptance criteria.

## Developer AI Instructions
Implement minimum code to pass tests.
DELEG
hook_exit_with=0
CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" > "${TEST_DIR}/output-step5-with.txt" 2>&1 || hook_exit_with=$?
if [ "$hook_exit_with" -eq 0 ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T16: Hook passes at STEP 5 when delegation.md exists"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T16: Hook passes at STEP 5 when delegation.md exists (got exit $hook_exit_with)")
  echo "  FAIL: T16: Hook passes at STEP 5 when delegation.md exists"
fi

echo ""

# ==========================================================================
# AC10: CLAUDE.md is synced with template changes
# ==========================================================================
echo "--- AC10: CLAUDE.md synced with template ---"

assert_contains "$CLAUDE_MD" "delegation\.md" \
  "T17: CLAUDE.md references delegation.md"

# CLAUDE.md STEP 4 should mention delegation.md
assert_contains "$CLAUDE_MD" "STEP 4.*delegation\|delegation.*STEP 4\|## STEP 4" \
  "T18: CLAUDE.md STEP 4 section exists (baseline)"

# Check that CLAUDE.md Flow Control also reflects delegation.md
assert_contains "$CLAUDE_MD" "delegation\.md.*STEP 4\|STEP 4.*delegation" \
  "T19: CLAUDE.md Flow Control references delegation.md for STEP 4"

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
