#!/usr/bin/env bash
# Test script for issue #18: CLAUDE.md → CLAUDE.md.template / docs sync
# Tests all 11 acceptance criteria. All tests MUST FAIL (Red) before implementation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_TEMPLATE="$REPO_ROOT/CLAUDE.md.template"
AUTOFLOW_GUIDE="$REPO_ROOT/docs/autoflow-guide.md"
EVAL_SYSTEM="$REPO_ROOT/docs/evaluation-system.md"

FAILURES=0
TOTAL=0

check() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" >/dev/null 2>&1; then
    echo "PASS: $1"
  else
    FAILURES=$((FAILURES + 1))
    echo "FAIL: $1"
  fi
}

echo "===== Issue #18 Sync Tests ====="
echo ""

# --------------------------------------------------------------------------
# AC1: CLAUDE.md.template STEP 5d has [MUST] marker for 5d-2 mandatory re-run
#      AND "DO NOT SKIP" text
# --------------------------------------------------------------------------
check "AC1: template STEP 5d has [MUST] marker for mandatory re-run" \
  "grep -q '\[MUST\]' '$CLAUDE_TEMPLATE' && grep -A5 '5d-2' '$CLAUDE_TEMPLATE' | grep -q '\[MUST\]'"

check "AC1b: template STEP 5d has DO NOT SKIP text" \
  "grep -q 'DO NOT SKIP' '$CLAUDE_TEMPLATE'"

# --------------------------------------------------------------------------
# AC2: CLAUDE.md.template STEP 5d has no-refactoring path
#      (e.g., "No -> document reason" or "no refactoring needed")
# --------------------------------------------------------------------------
check "AC2: template STEP 5d has no-refactoring path" \
  "grep -i -q 'no.*document reason\|no refactoring needed\|No.*→.*document\|Refactoring needed' '$CLAUDE_TEMPLATE'"

# --------------------------------------------------------------------------
# AC3: CLAUDE.md.template has Orchestrator Boundaries subsection with
#      file-level boundary list AND "No exceptions" text
# --------------------------------------------------------------------------
check "AC3a: template has Orchestrator Boundaries subsection" \
  "grep -q 'Orchestrator Boundaries' '$CLAUDE_TEMPLATE'"

check "AC3b: template has No exceptions text" \
  "grep -qi 'No exceptions' '$CLAUDE_TEMPLATE'"

# --------------------------------------------------------------------------
# AC4: CLAUDE.md.template has Evaluation AI Prompt Rules subsection
#      with at least 3 [MUST] rules and 1 [DENY] rule
# --------------------------------------------------------------------------
check "AC4a: template has Evaluation AI Prompt Rules subsection" \
  "grep -q 'Evaluation AI Prompt Rules' '$CLAUDE_TEMPLATE'"

# Count [MUST] rules in the Evaluation AI Prompt Rules section
# We need at least 3 [MUST] lines after the Evaluation AI Prompt Rules heading
check "AC4b: template Eval AI Prompt Rules has >= 3 MUST rules" \
  "grep -A10 'Evaluation AI Prompt Rules' '$CLAUDE_TEMPLATE' | grep -c '\[MUST\]' | awk '\$1 >= 3'"

check "AC4c: template Eval AI Prompt Rules has >= 1 DENY rule" \
  "grep -A10 'Evaluation AI Prompt Rules' '$CLAUDE_TEMPLATE' | grep -q '\[DENY\]'"

# --------------------------------------------------------------------------
# AC5: CLAUDE.md.template Flow Control AUTO-FAIL line routes to STEP 4
# --------------------------------------------------------------------------
check "AC5: template AUTO-FAIL routes to STEP 4 (not STEP 3)" \
  "grep -i 'auto-fail\|AUTO-FAIL' '$CLAUDE_TEMPLATE' | grep -q 'STEP 4'"

# --------------------------------------------------------------------------
# AC6: docs/autoflow-guide.md STEP 5d has [MUST] marker for mandatory re-run
#      AND "no refactoring" path language
# --------------------------------------------------------------------------
check "AC6a: autoflow-guide STEP 5d has [MUST] marker" \
  "awk '/^## STEP 5d/,/^---$/{print}' '$AUTOFLOW_GUIDE' | grep -q '\[MUST\]'"

check "AC6b: autoflow-guide STEP 5d has no-refactoring path" \
  "awk '/^## STEP 5d/,/^---$/{print}' '$AUTOFLOW_GUIDE' | grep -qi 'no.*refactor\|Refactoring needed'"

# --------------------------------------------------------------------------
# AC7: docs/autoflow-guide.md has orchestrator boundaries section
# --------------------------------------------------------------------------
check "AC7: autoflow-guide has Orchestrator Boundaries section" \
  "grep -q 'Orchestrator Boundaries' '$AUTOFLOW_GUIDE'"

# --------------------------------------------------------------------------
# AC8: docs/autoflow-guide.md AUTO-FAIL routes to STEP 4 in STEP 6 section
#      AND in Regression Rules table
# --------------------------------------------------------------------------
check "AC8a: autoflow-guide STEP 6 AUTO-FAIL routes to STEP 4" \
  "awk '/## STEP 6/,/## STEP 7/{print}' '$AUTOFLOW_GUIDE' | grep -i 'auto-fail\|security.*<=.*3' | grep -q 'STEP 4'"

check "AC8b: autoflow-guide Regression Rules AUTO-FAIL routes to STEP 4" \
  "awk '/^## Regression Rules/,/^---$/{print}' '$AUTOFLOW_GUIDE' | grep -i 'security.*<=.*3' | grep -q 'STEP 4'"

# --------------------------------------------------------------------------
# AC9: docs/autoflow-guide.md has Evaluation AI Prompt Rules
# --------------------------------------------------------------------------
check "AC9: autoflow-guide has Evaluation AI Prompt Rules" \
  "grep -q 'Evaluation AI Prompt Rules' '$AUTOFLOW_GUIDE'"

# --------------------------------------------------------------------------
# AC10: Both files keep "Security" category name (NOT "Consistency")
#       This verifies they use "Security" in the evaluation categories,
#       not "Consistency" which is the CLAUDE.md-specific name.
# --------------------------------------------------------------------------
check "AC10a: template evaluation categories use Security (not Consistency)" \
  "grep -A10 'Evaluation Categories' '$CLAUDE_TEMPLATE' | grep -q 'Security'"

check "AC10b: autoflow-guide evaluation categories use Security (not Consistency)" \
  "awk '/Scoring Categories/,/### PASS/{print}' '$AUTOFLOW_GUIDE' | grep -q 'Security'"

# --------------------------------------------------------------------------
# AC11: docs/evaluation-system.md AUTO-FAIL routes to STEP 4
# --------------------------------------------------------------------------
check "AC11: evaluation-system.md AUTO-FAIL routes to STEP 4 (not STEP 3)" \
  "grep -i 'auto-fail\|Security.*<=.*3' '$EVAL_SYSTEM' | grep -q 'STEP 4'"

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "===== Results: $((TOTAL - FAILURES))/$TOTAL passed, $FAILURES failed ====="

if [ "$FAILURES" -gt 0 ]; then
  echo "OVERALL: FAIL (Red)"
  exit 1
else
  echo "OVERALL: PASS (Green)"
  exit 0
fi
