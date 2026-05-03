#!/usr/bin/env bash
# Test script for issue #45: Type 1 (Code) rubric axis-3 redefined to
# "Structural Change Necessity" — direction-symmetric across additive and
# subtractive proposals. Asserts AC1, AC2, AC3, AC4, AC6 from plan.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
CLAUDE_TEMPLATE="$REPO_ROOT/CLAUDE.md.template"
AUTOFLOW_GUIDE="$REPO_ROOT/docs/autoflow-guide.md"

FAILURES=0
TOTAL=0

pass() {
  TOTAL=$((TOTAL + 1))
  echo "PASS: $1"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAILURES=$((FAILURES + 1))
  echo "FAIL: $1"
}

check() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" >/dev/null 2>&1; then
    echo "PASS: $1"
  else
    FAILURES=$((FAILURES + 1))
    echo "FAIL: $1"
  fi
}

echo "========================================="
echo "Issue #45: Rubric Direction-Symmetric Axis Tests"
echo "========================================="
echo ""

# ============================================================
# AC1: CLAUDE.md axis-3 wording updated
# ============================================================
echo "--- AC1: CLAUDE.md axis-3 renamed ---"

check "AC1a. CLAUDE.md contains 'Structural Change Necessity'" \
  "grep -F 'Structural Change Necessity' '$CLAUDE_MD'"

check "AC1b. CLAUDE.md does NOT contain 'New Mechanism Necessity'" \
  "! grep -F 'New Mechanism Necessity' '$CLAUDE_MD'"

echo ""

# ============================================================
# AC2: CLAUDE.md.template axis-3 wording updated
# ============================================================
echo "--- AC2: CLAUDE.md.template axis-3 renamed ---"

check "AC2a. CLAUDE.md.template contains 'Structural Change Necessity'" \
  "grep -F 'Structural Change Necessity' '$CLAUDE_TEMPLATE'"

check "AC2b. CLAUDE.md.template does NOT contain 'New Mechanism Necessity'" \
  "! grep -F 'New Mechanism Necessity' '$CLAUDE_TEMPLATE'"

echo ""

# ============================================================
# AC3: docs/autoflow-guide.md axis-3 wording updated
# ============================================================
echo "--- AC3: autoflow-guide.md axis-3 renamed ---"

check "AC3a. autoflow-guide.md contains 'Structural Change Necessity'" \
  "grep -F 'Structural Change Necessity' '$AUTOFLOW_GUIDE'"

check "AC3b. autoflow-guide.md does NOT contain 'New Mechanism Necessity'" \
  "! grep -F 'New Mechanism Necessity' '$AUTOFLOW_GUIDE'"

echo ""

# ============================================================
# AC4: Type 1 (Code) rubric still has exactly 3 axes,
#      and the axis-name set is exactly
#      {Structural Overlap, Code Change Necessity, Structural Change Necessity}
# ============================================================
echo "--- AC4: Type 1 axis count and name set ---"

# Extract the Type 1 (Code) Scoring block from a file.
# Block starts at the line containing "**Type 1 (Code) Scoring:**" and ends
# at the line containing "**Type 2" (next section header).
# Then keep only data rows that look like "| <Capitalized name> | ..." and
# exclude the header row "| Category | Measures |" and the separator "|---".
extract_type1_axes() {
  local file="$1"
  awk '
    /\*\*Type 1 \(Code\) Scoring:\*\*/ { in_block = 1; next }
    in_block && /\*\*Type 2/           { in_block = 0 }
    in_block { print }
  ' "$file" |
  awk -F'|' '
    /^\| *Category *\| *Measures *\|/ { next }
    /^\|[ -]*-+/                      { next }
    /^\| *[A-Z]/ {
      name = $2
      sub(/^ +/, "", name)
      sub(/ +$/, "", name)
      print name
    }
  '
}

check_axis_set() {
  local label="$1"
  local file="$2"
  local axes
  axes="$(extract_type1_axes "$file")"
  local count
  count=$(printf '%s\n' "$axes" | grep -c .)
  if [ "$count" -ne 3 ]; then
    fail "$label: expected 3 Type 1 axes, found $count"
    echo "    axes: $(printf '%s\n' "$axes" | tr '\n' ',' )"
    return
  fi
  local sorted_actual sorted_expected
  sorted_actual=$(printf '%s\n' "$axes" | LC_ALL=C sort)
  sorted_expected=$(printf '%s\n' "Code Change Necessity" "Structural Change Necessity" "Structural Overlap" | LC_ALL=C sort)
  if [ "$sorted_actual" = "$sorted_expected" ]; then
    pass "$label: axis name set matches {Structural Overlap, Code Change Necessity, Structural Change Necessity}"
  else
    fail "$label: axis name set mismatch"
    echo "    expected:"
    printf '%s\n' "$sorted_expected" | sed 's/^/      /'
    echo "    actual:"
    printf '%s\n' "$sorted_actual" | sed 's/^/      /'
  fi
}

check_axis_set "AC4a. CLAUDE.md"           "$CLAUDE_MD"
check_axis_set "AC4b. CLAUDE.md.template"  "$CLAUDE_TEMPLATE"
check_axis_set "AC4c. autoflow-guide.md"   "$AUTOFLOW_GUIDE"

echo ""

# ============================================================
# AC6: Worked example — rubric is direction-symmetric.
#   Scenario A (subtractive proposal): (9, 9, 8) → PASS
#   Scenario B (fully handled by existing structure): (3, 4, 2) → FAIL
#
# Deterministic integer-tenths rounding policy:
#   sum_x10        = (s1 + s2 + s3) * 10
#   avg_tenths     = sum_x10 / 3        (integer floor division)
#   min            = smallest of s1, s2, s3
#   PASS iff avg_tenths >= 75 AND min >= 7
# ============================================================
echo "--- AC6: compute_verdict direction-symmetry ---"

compute_verdict() {
  local s1="$1" s2="$2" s3="$3"
  local sum_x10 avg_tenths min
  sum_x10=$(( (s1 + s2 + s3) * 10 ))
  avg_tenths=$(( sum_x10 / 3 ))
  min="$s1"
  [ "$s2" -lt "$min" ] && min="$s2"
  [ "$s3" -lt "$min" ] && min="$s3"
  if [ "$avg_tenths" -ge 75 ] && [ "$min" -ge 7 ]; then
    echo "PASS"
  else
    echo "FAIL"
  fi
}

verdict_a="$(compute_verdict 9 9 8)"
if [ "$verdict_a" = "PASS" ]; then
  pass "AC6a. Scenario A (9,9,8) → PASS (subtractive proposal not auto-FAILed)"
else
  fail "AC6a. Scenario A (9,9,8) expected PASS, got $verdict_a"
fi

verdict_b="$(compute_verdict 3 4 2)"
if [ "$verdict_b" = "FAIL" ]; then
  pass "AC6b. Scenario B (3,4,2) → FAIL (existing-structure case still rejected)"
else
  fail "AC6b. Scenario B (3,4,2) expected FAIL, got $verdict_b"
fi

echo ""
echo "========================================="
echo "Results: $((TOTAL - FAILURES))/$TOTAL passed, $FAILURES failed"
echo "========================================="

if [ "$FAILURES" -gt 0 ]; then
  exit 1
else
  exit 0
fi
