#!/usr/bin/env bash
# Test script for issue #19: Phase 3 evaluation criteria differentiation
# Tests all 7 acceptance criteria. All tests MUST FAIL (Red) before implementation.

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

# ============================================================
# Capture Phase A/B baseline content BEFORE any checks
# This is used by criterion 7 to verify no modifications
# ============================================================

# Helper: portable "all lines except last" (works on both BSD and GNU)
drop_last() { sed '$ d'; }

# CLAUDE.md Phase A baseline (lines 180-188)
CLAUDE_PHASE_A_BASELINE=$(sed -n '/^### Phase A: Structure Analysis.*DOES NOT SEE THE ISSUE/,/^### Phase B:/p' "$CLAUDE_MD" | drop_last)
# CLAUDE.md Phase B baseline (lines 190-197)
CLAUDE_PHASE_B_BASELINE=$(sed -n '/^### Phase B: Issue Analysis.*DOES NOT SEE THE CODE/,/^### Phase 3:/p' "$CLAUDE_MD" | drop_last)

# CLAUDE.md.template Phase A baseline
TEMPLATE_PHASE_A_BASELINE=$(sed -n '/^### Phase A: Structure Analysis.*DOES NOT SEE THE ISSUE/,/^### Phase B:/p' "$CLAUDE_TEMPLATE" | drop_last)
# CLAUDE.md.template Phase B baseline
TEMPLATE_PHASE_B_BASELINE=$(sed -n '/^### Phase B: Issue Analysis.*DOES NOT SEE THE CODE/,/^### Phase 3:/p' "$CLAUDE_TEMPLATE" | drop_last)

# docs/autoflow-guide.md Phase A baseline
GUIDE_PHASE_A_BASELINE=$(sed -n '/^### Phase A: Structure Analysis/,/^### Phase B:/p' "$AUTOFLOW_GUIDE" | drop_last)
# docs/autoflow-guide.md Phase B baseline
GUIDE_PHASE_B_BASELINE=$(sed -n '/^### Phase B: Issue Analysis/,/^### Phase 3:/p' "$AUTOFLOW_GUIDE" | drop_last)

echo "========================================="
echo "Issue #19: Phase 3 Evaluation Criteria Tests"
echo "========================================="
echo ""

# ============================================================
# Test 1: CLAUDE.md Phase 3 has issue type classification
# ============================================================
echo "--- Test 1: CLAUDE.md Phase 3 issue type classification ---"

# Extract Phase 3 section from CLAUDE.md
CLAUDE_PHASE3=$(sed -n '/^### Phase 3: Cross-Verification/,/^---$/p' "$CLAUDE_MD")

check "1a. CLAUDE.md Phase 3 mentions Type 1" \
  "echo \"\$CLAUDE_PHASE3\" | grep -q 'Type 1'"

check "1b. CLAUDE.md Phase 3 mentions Type 2" \
  "echo \"\$CLAUDE_PHASE3\" | grep -q 'Type 2'"

check "1c. CLAUDE.md Phase 3 mentions Code type" \
  "echo \"\$CLAUDE_PHASE3\" | grep -qi 'Type 1.*Code\|Code.*Type 1'"

check "1d. CLAUDE.md Phase 3 mentions Documentation/Consistency type" \
  "echo \"\$CLAUDE_PHASE3\" | grep -qi 'Type 2.*Documentation\|Documentation.*Type 2'"

echo ""

# ============================================================
# Test 2: CLAUDE.md Phase 3 has Type 1 AND Type 2 scoring tables
# ============================================================
echo "--- Test 2: CLAUDE.md Phase 3 scoring category tables ---"

# Type 1 categories
check "2a. CLAUDE.md Phase 3 has Structural Overlap category" \
  "echo \"\$CLAUDE_PHASE3\" | grep -q 'Structural Overlap'"

check "2b. CLAUDE.md Phase 3 has Code Change Necessity category" \
  "echo \"\$CLAUDE_PHASE3\" | grep -q 'Code Change Necessity'"

check "2c. CLAUDE.md Phase 3 has New Mechanism Necessity category" \
  "echo \"\$CLAUDE_PHASE3\" | grep -q 'New Mechanism Necessity'"

# Type 2 categories
check "2d. CLAUDE.md Phase 3 has Content Gap category" \
  "echo \"\$CLAUDE_PHASE3\" | grep -q 'Content Gap'"

check "2e. CLAUDE.md Phase 3 has Consistency Impact category" \
  "echo \"\$CLAUDE_PHASE3\" | grep -q 'Consistency Impact'"

check "2f. CLAUDE.md Phase 3 has Propagation Scope category" \
  "echo \"\$CLAUDE_PHASE3\" | grep -q 'Propagation Scope'"

echo ""

# ============================================================
# Test 3: CLAUDE.md.template Phase 3 has type classification + scoring
# ============================================================
echo "--- Test 3: CLAUDE.md.template Phase 3 type classification + scoring ---"

TEMPLATE_PHASE3=$(sed -n '/^### Phase 3: Cross-Verification/,/^---\|^### Synthesis\|^## /p' "$CLAUDE_TEMPLATE")

check "3a. Template Phase 3 mentions Type 1" \
  "echo \"\$TEMPLATE_PHASE3\" | grep -q 'Type 1'"

check "3b. Template Phase 3 mentions Type 2" \
  "echo \"\$TEMPLATE_PHASE3\" | grep -q 'Type 2'"

check "3c. Template Phase 3 has Structural Overlap" \
  "echo \"\$TEMPLATE_PHASE3\" | grep -q 'Structural Overlap'"

check "3d. Template Phase 3 has Content Gap" \
  "echo \"\$TEMPLATE_PHASE3\" | grep -q 'Content Gap'"

check "3e. Template Phase 3 has Consistency Impact" \
  "echo \"\$TEMPLATE_PHASE3\" | grep -q 'Consistency Impact'"

check "3f. Template Phase 3 has Propagation Scope" \
  "echo \"\$TEMPLATE_PHASE3\" | grep -q 'Propagation Scope'"

echo ""

# ============================================================
# Test 4: docs/autoflow-guide.md Phase 3 has type classification + scoring
# ============================================================
echo "--- Test 4: autoflow-guide.md Phase 3 type classification + scoring ---"

GUIDE_PHASE3=$(sed -n '/^### Phase 3: Cross-Verification/,/^---\|^### Exit\|^## /p' "$AUTOFLOW_GUIDE")

check "4a. Guide Phase 3 mentions Type 1" \
  "echo \"\$GUIDE_PHASE3\" | grep -q 'Type 1'"

check "4b. Guide Phase 3 mentions Type 2" \
  "echo \"\$GUIDE_PHASE3\" | grep -q 'Type 2'"

check "4c. Guide Phase 3 has Structural Overlap" \
  "echo \"\$GUIDE_PHASE3\" | grep -q 'Structural Overlap'"

check "4d. Guide Phase 3 has Content Gap" \
  "echo \"\$GUIDE_PHASE3\" | grep -q 'Content Gap'"

check "4e. Guide Phase 3 has Consistency Impact" \
  "echo \"\$GUIDE_PHASE3\" | grep -q 'Consistency Impact'"

check "4f. Guide Phase 3 has Propagation Scope" \
  "echo \"\$GUIDE_PHASE3\" | grep -q 'Propagation Scope'"

echo ""

# ============================================================
# Test 5: All 3 files have identical PASS/FAIL criteria
# ============================================================
echo "--- Test 5: Consistent PASS/FAIL criteria across files ---"

# Check each file's Phase 3 section for the threshold values
check "5a. CLAUDE.md Phase 3 has avg >= 7.5 threshold" \
  "echo \"\$CLAUDE_PHASE3\" | grep -q 'avg >= 7.5'"

check "5b. CLAUDE.md Phase 3 has all >= 7 threshold" \
  "echo \"\$CLAUDE_PHASE3\" | grep -q 'all >= 7'"

check "5c. Template Phase 3 has avg >= 7.5 threshold" \
  "echo \"\$TEMPLATE_PHASE3\" | grep -q 'avg >= 7.5'"

check "5d. Template Phase 3 has all >= 7 threshold" \
  "echo \"\$TEMPLATE_PHASE3\" | grep -q 'all >= 7'"

check "5e. Guide Phase 3 has avg >= 7.5 threshold" \
  "echo \"\$GUIDE_PHASE3\" | grep -q 'avg >= 7.5'"

check "5f. Guide Phase 3 has all >= 7 threshold" \
  "echo \"\$GUIDE_PHASE3\" | grep -q 'all >= 7'"

echo ""

# ============================================================
# Test 6: Hybrid issue default is Type 1 (Code)
# ============================================================
echo "--- Test 6: Hybrid issue defaults to Type 1 ---"

check "6a. CLAUDE.md Phase 3 mentions hybrid default to Type 1" \
  "echo \"\$CLAUDE_PHASE3\" | grep -qi 'hybrid.*Type 1\|default.*Type 1'"

check "6b. Template Phase 3 mentions hybrid default to Type 1" \
  "echo \"\$TEMPLATE_PHASE3\" | grep -qi 'hybrid.*Type 1\|default.*Type 1'"

check "6c. Guide Phase 3 mentions hybrid default to Type 1" \
  "echo \"\$GUIDE_PHASE3\" | grep -qi 'hybrid.*Type 1\|default.*Type 1'"

echo ""

# ============================================================
# Test 7: Phase A and Phase B sections are NOT modified
# ============================================================
echo "--- Test 7: Phase A/B sections unchanged ---"

# Re-extract Phase A/B after implementation and compare
CLAUDE_PHASE_A_CURRENT=$(sed -n '/^### Phase A: Structure Analysis.*DOES NOT SEE THE ISSUE/,/^### Phase B:/p' "$CLAUDE_MD" | drop_last)
CLAUDE_PHASE_B_CURRENT=$(sed -n '/^### Phase B: Issue Analysis.*DOES NOT SEE THE CODE/,/^### Phase 3:/p' "$CLAUDE_MD" | drop_last)

TEMPLATE_PHASE_A_CURRENT=$(sed -n '/^### Phase A: Structure Analysis.*DOES NOT SEE THE ISSUE/,/^### Phase B:/p' "$CLAUDE_TEMPLATE" | drop_last)
TEMPLATE_PHASE_B_CURRENT=$(sed -n '/^### Phase B: Issue Analysis.*DOES NOT SEE THE CODE/,/^### Phase 3:/p' "$CLAUDE_TEMPLATE" | drop_last)

GUIDE_PHASE_A_CURRENT=$(sed -n '/^### Phase A: Structure Analysis/,/^### Phase B:/p' "$AUTOFLOW_GUIDE" | drop_last)
GUIDE_PHASE_B_CURRENT=$(sed -n '/^### Phase B: Issue Analysis/,/^### Phase 3:/p' "$AUTOFLOW_GUIDE" | drop_last)

# Compare baseline vs current — they should be identical
if [ "$CLAUDE_PHASE_A_BASELINE" = "$CLAUDE_PHASE_A_CURRENT" ]; then
  pass "7a. CLAUDE.md Phase A unchanged"
else
  fail "7a. CLAUDE.md Phase A was modified"
fi

if [ "$CLAUDE_PHASE_B_BASELINE" = "$CLAUDE_PHASE_B_CURRENT" ]; then
  pass "7b. CLAUDE.md Phase B unchanged"
else
  fail "7b. CLAUDE.md Phase B was modified"
fi

if [ "$TEMPLATE_PHASE_A_BASELINE" = "$TEMPLATE_PHASE_A_CURRENT" ]; then
  pass "7c. CLAUDE.md.template Phase A unchanged"
else
  fail "7c. CLAUDE.md.template Phase A was modified"
fi

if [ "$TEMPLATE_PHASE_B_BASELINE" = "$TEMPLATE_PHASE_B_CURRENT" ]; then
  pass "7d. CLAUDE.md.template Phase B unchanged"
else
  fail "7d. CLAUDE.md.template Phase B was modified"
fi

if [ "$GUIDE_PHASE_A_BASELINE" = "$GUIDE_PHASE_A_CURRENT" ]; then
  pass "7e. autoflow-guide.md Phase A unchanged"
else
  fail "7e. autoflow-guide.md Phase A was modified"
fi

if [ "$GUIDE_PHASE_B_BASELINE" = "$GUIDE_PHASE_B_CURRENT" ]; then
  pass "7f. autoflow-guide.md Phase B unchanged"
else
  fail "7f. autoflow-guide.md Phase B was modified"
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
