#!/usr/bin/env bash
# Test Suite: Phase-Transition Responsibility Model (Issue #27)
# Encodes the 8 acceptance criteria from .autoflow-state/27/plan.md section 4.
# All grep/diff checks MUST FAIL (Red) against the unmodified docs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
CLAUDE_TEMPLATE="$REPO_ROOT/CLAUDE.md.template"
DESIGN_RATIONALE="$REPO_ROOT/docs/design-rationale.md"

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

echo "============================================================"
echo "Issue #27: Phase-Transition Responsibility Model Tests"
echo "============================================================"
echo ""

# ============================================================
# AC1: Three-party split documented in design-rationale.md
# ============================================================
echo "--- AC1: design-rationale.md documents three-party split ---"

check "1a. design-rationale.md mentions Teammate/Orchestrator/Hook split or 'three-party'" \
  "grep -E 'Teammate.*Orchestrator.*Hook|three-party' '$DESIGN_RATIONALE'"

echo ""

# ============================================================
# AC2: Rejected alternatives named with reasons
# ============================================================
echo "--- AC2: Rejected alternatives named with stated reasons ---"

check "2a. design-rationale.md names 'Teammate-autonomous' model" \
  "grep -E 'Teammate-autonomous' '$DESIGN_RATIONALE'"

check "2b. design-rationale.md names 'Orchestrator-gated' model" \
  "grep -E 'Orchestrator-gated' '$DESIGN_RATIONALE'"

# Each named model must have a stated reason within 10 lines after the name
# (looking for 'blind spot' near Teammate-autonomous, 'interpret' near Orchestrator-gated).
check "2c. 'Teammate-autonomous' has rejection reason ('blind spot' within 10 lines)" \
  "grep -A10 'Teammate-autonomous' '$DESIGN_RATIONALE' | grep -qiE 'blind spot|blind-spot'"

check "2d. 'Orchestrator-gated' has rejection reason ('interpret' within 10 lines)" \
  "grep -A10 'Orchestrator-gated' '$DESIGN_RATIONALE' | grep -qi 'interpret'"

echo ""

# ============================================================
# AC3: Canonical transition-request format in CLAUDE.md and template
# Token sequence: @orchestrator transition-request, then from:, to:, evidence:
# Verifiable with grep -A4 -- the captured 5 lines must contain the
# fields in order.
# ============================================================
echo "--- AC3: Canonical transition-request format present in both files ---"

check_transition_block() {
  local label="$1" file="$2"
  local block from_line to_line ev_line
  TOTAL=$((TOTAL + 1))

  if ! grep -q "@orchestrator transition-request" "$file" 2>/dev/null; then
    FAILURES=$((FAILURES + 1))
    echo "FAIL: $label (no '@orchestrator transition-request' header)"
    return
  fi

  # Capture header line + next 4 lines (5 lines total)
  block=$(grep -A4 "@orchestrator transition-request" "$file" | head -n 5)

  # Find which line numbers (1..5 in the captured block) contain each field.
  from_line=$(echo "$block" | grep -n '^.*from:' | head -n 1 | cut -d: -f1 || true)
  to_line=$(echo "$block" | grep -n '^.*to:' | head -n 1 | cut -d: -f1 || true)
  ev_line=$(echo "$block" | grep -n '^.*evidence:' | head -n 1 | cut -d: -f1 || true)

  if [ -z "$from_line" ] || [ -z "$to_line" ] || [ -z "$ev_line" ]; then
    FAILURES=$((FAILURES + 1))
    echo "FAIL: $label (missing one of from:/to:/evidence: in 5-line block)"
    return
  fi

  if [ "$from_line" -lt "$to_line" ] && [ "$to_line" -lt "$ev_line" ]; then
    echo "PASS: $label"
  else
    FAILURES=$((FAILURES + 1))
    echo "FAIL: $label (fields not in from:->to:->evidence: order; got lines $from_line/$to_line/$ev_line)"
  fi
}

check_transition_block "3a. CLAUDE.md has 5-line transition-request block (from->to->evidence)" "$CLAUDE_MD"
check_transition_block "3b. CLAUDE.md.template has 5-line transition-request block (from->to->evidence)" "$CLAUDE_TEMPLATE"

echo ""

# ============================================================
# AC4: 'does not interpret evidence' phrase in CLAUDE.md
# ============================================================
echo "--- AC4: Orchestrator non-interpretation rule in CLAUDE.md ---"

check "4a. CLAUDE.md contains 'does not interpret evidence'" \
  "grep -q 'does not interpret evidence' '$CLAUDE_MD'"

echo ""

# ============================================================
# AC5: Sibling-prohibition / address-the-Orchestrator rule
# ============================================================
echo "--- AC5: Sibling-to-sibling transitions explicitly prohibited ---"

check "5a. CLAUDE.md has sibling-prohibition or 'must address the Orchestrator' wording" \
  "grep -iE 'sibling.*forbidden|sibling-to-sibling.*prohibit|must address the Orchestrator' '$CLAUDE_MD'"

echo ""

# ============================================================
# AC6: Canonical format block byte-identical between CLAUDE.md and template
# ============================================================
echo "--- AC6: Canonical format block byte-identical across CLAUDE.md and template ---"

TOTAL=$((TOTAL + 1))
if grep -q "@orchestrator transition-request" "$CLAUDE_MD" 2>/dev/null \
   && grep -q "@orchestrator transition-request" "$CLAUDE_TEMPLATE" 2>/dev/null; then
  CLAUDE_BLOCK=$(grep -A4 "@orchestrator transition-request" "$CLAUDE_MD" | head -n 5)
  TEMPLATE_BLOCK=$(grep -A4 "@orchestrator transition-request" "$CLAUDE_TEMPLATE" | head -n 5)
  DIFF_OUTPUT=$(diff <(printf '%s\n' "$CLAUDE_BLOCK") <(printf '%s\n' "$TEMPLATE_BLOCK") || true)
  if [ -z "$DIFF_OUTPUT" ]; then
    echo "PASS: 6a. Canonical 5-line transition-request block is byte-identical in both files"
  else
    FAILURES=$((FAILURES + 1))
    echo "FAIL: 6a. Canonical transition-request block differs between CLAUDE.md and CLAUDE.md.template"
  fi
else
  FAILURES=$((FAILURES + 1))
  echo "FAIL: 6a. Canonical transition-request block missing from one or both files"
fi

echo ""

# ============================================================
# AC7: phase-set helper forward-reference in CLAUDE.md AND design-rationale.md
# ============================================================
echo "--- AC7: phase-set helper forward-reference in both files ---"

check "7a. CLAUDE.md mentions phase-set with forward-ref (#28 / Item 2 / will be introduced)" \
  "grep -E 'phase-set.*(#28|Item 2|will be introduced)' '$CLAUDE_MD'"

check "7b. design-rationale.md mentions phase-set with forward-ref (#28 / Item 2 / will be introduced)" \
  "grep -E 'phase-set.*(#28|Item 2|will be introduced)' '$DESIGN_RATIONALE'"

echo ""

# ============================================================
# AC8: git diff --name-only main..HEAD restricted to allowed paths
# Lenient: only fail if a forbidden path is present (subset is fine).
# Allowed prefixes/files:
#   - CLAUDE.md
#   - CLAUDE.md.template
#   - docs/design-rationale.md
#   - tests/test-issue-27-phase-transition-protocol.sh
#   - .autoflow-state/27/...
# ============================================================
echo "--- AC8: Only allowed files modified vs main ---"

TOTAL=$((TOTAL + 1))
DIFF_FILES=$(git -C "$REPO_ROOT" diff --name-only main..HEAD 2>/dev/null || true)
FORBIDDEN_FILES=""
if [ -n "$DIFF_FILES" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      CLAUDE.md) ;;
      CLAUDE.md.template) ;;
      docs/design-rationale.md) ;;
      tests/test-issue-27-phase-transition-protocol.sh) ;;
      .autoflow-state/27/*) ;;
      .autoflow-state/27) ;;
      *) FORBIDDEN_FILES="$FORBIDDEN_FILES$f"$'\n' ;;
    esac
  done <<EOF
$DIFF_FILES
EOF
fi

if [ -z "$FORBIDDEN_FILES" ]; then
  echo "PASS: 8a. git diff main..HEAD contains no forbidden paths"
else
  FAILURES=$((FAILURES + 1))
  echo "FAIL: 8a. git diff main..HEAD contains forbidden paths:"
  printf '%s' "$FORBIDDEN_FILES" | sed 's/^/      /'
fi

echo ""

# ============================================================
# Manual checklist (criterion 6 semantic non-contradiction
# and criterion 1 "exactly one responsibility row per party")
# ============================================================
echo "--- Manual checklist (human verification at GATE:QUALITY) ---"
echo "  [ ] M1. design-rationale.md three-party section has exactly one"
echo "         responsibility row per party (Teammate, Orchestrator, Hook)."
echo "  [ ] M2. The three-party split, canonical format, and"
echo "         non-interpretation rule do not semantically contradict each"
echo "         other across CLAUDE.md, CLAUDE.md.template, and"
echo "         docs/design-rationale.md."
echo ""

# ============================================================
# Summary
# ============================================================
echo "============================================================"
echo "RESULT: $FAILURES failures of $TOTAL checks"
echo "============================================================"

if [ "$FAILURES" -gt 0 ]; then
  exit 1
else
  exit 0
fi
