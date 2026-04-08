#!/usr/bin/env bash
# Test Suite: Discussion Protocol Update (Issue #7)
# Validates that CLAUDE.md.template Discussion Protocol matches CLAUDE.md's
# evidence-oriented version with UNDERSTAND/VERIFY/EVALUATE/RESPOND cycle.

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

echo "=== Test Suite: Discussion Protocol Update (Issue #7) ==="
echo ""

# --- AC1: 4-step UNDERSTAND/VERIFY/EVALUATE/RESPOND cycle ---
echo "--- AC1: 4-step cycle in CLAUDE.md.template ---"

assert_contains "$TEMPLATE" "UNDERSTAND" \
  "T1: Template contains UNDERSTAND step"

assert_contains "$TEMPLATE" "VERIFY" \
  "T2: Template contains VERIFY step"

assert_contains "$TEMPLATE" "EVALUATE" \
  "T3: Template contains EVALUATE step"

assert_contains "$TEMPLATE" "RESPOND" \
  "T4: Template contains RESPOND step"

assert_contains "$TEMPLATE" "UNDERSTAND.*VERIFY\|1\..*UNDERSTAND" \
  "T5: Template has numbered UNDERSTAND/VERIFY/EVALUATE/RESPOND process"

echo ""

# --- AC2: Three enforcement rules ---
echo "--- AC2: Three enforcement rules ---"

assert_contains "$TEMPLATE" "No agreement without evidence" \
  "T6: Template contains 'No agreement without evidence' rule"

assert_contains "$TEMPLATE" "First exchange devil's advocate\|first exchange devil" \
  "T7: Template contains 'First exchange devil's advocate' rule"

assert_contains "$TEMPLATE" "Cannot evaluate without reading\|cannot evaluate without reading" \
  "T8: Template contains 'Cannot evaluate without reading' rule"

echo ""

# --- AC3: Structured response types ---
echo "--- AC3: Structured response types (ACCEPT/COUNTER/PARTIAL/ESCALATE) ---"

assert_contains "$TEMPLATE" "ACCEPT" \
  "T9: Template contains ACCEPT response type"

assert_contains "$TEMPLATE" "COUNTER" \
  "T10: Template contains COUNTER response type"

assert_contains "$TEMPLATE" "PARTIAL" \
  "T11: Template contains PARTIAL response type"

assert_contains "$TEMPLATE" "ESCALATE" \
  "T12: Template contains ESCALATE response type"

assert_contains "$TEMPLATE" "with specific evidence\|no groundless agreement" \
  "T13: ACCEPT response includes evidence requirement"

echo ""

# --- AC4: Old protocol fully removed ---
echo "--- AC4: Old 5-step protocol removed ---"

assert_not_contains "$TEMPLATE" "1\. \*\*Raise\*\*" \
  "T14: Old 'Raise' step removed"

assert_not_contains "$TEMPLATE" "2\. \*\*Context\*\*: Include what was attempted" \
  "T15: Old 'Context' step removed"

assert_not_contains "$TEMPLATE" "3\. \*\*Options\*\*: Present at least 2" \
  "T16: Old 'Options' step removed"

assert_not_contains "$TEMPLATE" "4\. \*\*Recommend\*\*: State a recommendation" \
  "T17: Old 'Recommend' step removed"

assert_not_contains "$TEMPLATE" "5\. \*\*Escalate\*\*: If agents disagree" \
  "T18: Old 'Escalate' step removed"

assert_not_contains "$TEMPLATE" "Raised by.*Agent Role" \
  "T19: Old discussion format template removed"

assert_not_contains "$TEMPLATE" "Option A.*Description.*Trade-off" \
  "T20: Old options format removed"

echo ""

# --- AC5: Structure matches CLAUDE.md ---
echo "--- AC5: Structure matches CLAUDE.md Discussion Protocol ---"

assert_contains "$TEMPLATE" "### Process" \
  "T21: Template has '### Process' subsection (matching CLAUDE.md)"

assert_contains "$TEMPLATE" "### Rules" \
  "T22: Template has '### Rules' subsection (matching CLAUDE.md)"

assert_contains "$TEMPLATE" "When ambiguity or disagreement arises" \
  "T23: Template has matching intro text"

assert_contains "$TEMPLATE" "Check against actual files/data" \
  "T24: Template VERIFY step matches CLAUDE.md wording"

assert_contains "$TEMPLATE" "Form judgment with evidence" \
  "T25: Template EVALUATE step matches CLAUDE.md wording"

echo ""

# --- AC6: No other files modified ---
echo "--- AC6: Only CLAUDE.md.template should be modified ---"
echo "  (This is a git diff check — verified at PR time, not in this test)"
echo "  SKIP: AC6 verified via git diff during review"

echo ""

# --- Summary ---
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
