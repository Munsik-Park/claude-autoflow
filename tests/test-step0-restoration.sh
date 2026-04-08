#!/usr/bin/env bash
# Test Suite: STEP 0 Pre-Work Restoration (Issue #5)
# Validates that STEP 0 is "Pre-Work" (Git Clean Check) across all docs

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
GUIDE="docs/autoflow-guide.md"
README="README.md"
EVAL_SYSTEM="docs/evaluation-system.md"

echo "=== Test Suite: STEP 0 Pre-Work Restoration ==="
echo ""

# --- CLAUDE.md.template tests ---
echo "--- CLAUDE.md.template ---"

assert_contains "$TEMPLATE" "Pre-Work" \
  "T1: CLAUDE.md.template STEP 0 contains 'Pre-Work'"

assert_contains "$TEMPLATE" "git status" \
  "T2: CLAUDE.md.template STEP 0 includes git status check"

assert_contains "$TEMPLATE" "git fetch" \
  "T3: CLAUDE.md.template STEP 0 includes git fetch"

assert_not_contains "$TEMPLATE" "| 0 | \*\*Issue Analysis\*\*" \
  "T4: CLAUDE.md.template STEP 0 is NOT 'Issue Analysis'"

assert_contains "$TEMPLATE" "Git clean.*branch created\|branch created.*Git clean" \
  "T5: CLAUDE.md.template Flow Control shows STEP 0 exit as git clean + branch"

# --- docs/autoflow-guide.md tests ---
echo ""
echo "--- docs/autoflow-guide.md ---"

assert_contains "$GUIDE" "Pre-Work" \
  "T6: autoflow-guide.md STEP 0 contains 'Pre-Work'"

assert_contains "$GUIDE" "git status" \
  "T7: autoflow-guide.md STEP 0 includes git status check"

assert_contains "$GUIDE" "git fetch" \
  "T8: autoflow-guide.md STEP 0 includes git fetch"

assert_not_contains "$GUIDE" "## STEP 0: Issue Analysis" \
  "T9: autoflow-guide.md STEP 0 is NOT titled 'Issue Analysis'"

# --- README.md tests ---
echo ""
echo "--- README.md ---"

assert_contains "$README" "STEP 0.*Pre-Work\|STEP 0.*Git Clean" \
  "T10: README.md STEP 0 shows Pre-Work or Git Clean Check"

assert_not_contains "$README" "STEP 0.*Issue Analysis" \
  "T11: README.md STEP 0 is NOT 'Issue Analysis'"

# --- Cross-file consistency ---
echo ""
echo "--- Cross-file consistency ---"

assert_not_contains "$TEMPLATE" "| STEP 0 | Issue analyzed" \
  "T12: Flow Control table does not reference 'Issue analyzed' for STEP 0"

# --- Evaluation system unchanged ---
echo ""
echo "--- Evaluation system ---"

# evaluation-system.md should not define STEP 0 content at all
assert_not_contains "$EVAL_SYSTEM" "STEP 0" \
  "T13: evaluation-system.md does not reference STEP 0"

# --- STEP 1 absorbs issue understanding ---
echo ""
echo "--- STEP 1 absorption ---"

assert_contains "$GUIDE" "## STEP 1" \
  "T14: autoflow-guide.md has STEP 1 section"

# State file structure: requirements.md annotation should reference Pre-Work or STEP 0-1
assert_not_contains "$GUIDE" "requirements.md.*# STEP 0 output" \
  "T15: State file annotation does not label requirements.md as 'STEP 0 output' specifically"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failures:"
  for err in "${ERRORS[@]}"; do
    echo "  $err"
  done
  exit 1
fi

exit 0
