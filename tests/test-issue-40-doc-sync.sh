#!/usr/bin/env bash
# =============================================================================
# Test Suite: Issue #40 documentation sync
# =============================================================================
# Validates the documentation acceptance criteria (ACs 9–12) for the
# host-vs-sub-repo state separation work in plan.md:
#
#   AC 9  — docs/design-rationale.md has a "### Decision 10: " header and that
#           section mentions "host repo" (case-insensitive).
#   AC 10 — CLAUDE.md and CLAUDE.md.template both contain the literal string
#           "<sub-repo-id>/<issue-number>" inside the namespaced state-tree
#           description.
#   AC 11 — docs/autoflow-guide.md PREFLIGHT exit-criteria block contains
#           "intake.md".
#   AC 12 — docs/submodule-common-rules.md declares Auto-Flow state ownership
#           (sub-repos must NOT contain .autoflow-state/).
#
# These tests use only POSIX grep/awk/sed and run from the submodule root
# (services/autoflow-upstream/) — they do not depend on CLAUDE_PROJECT_DIR
# or .autoflow-state/ fixtures.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
FAIL=0
ERRORS=()

pass() {
  PASS=$((PASS + 1))
  echo "  PASS: $1"
}

fail() {
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: $1")
  echo "  FAIL: $1"
}

DESIGN_RATIONALE="${REPO_ROOT}/docs/design-rationale.md"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
CLAUDE_TEMPLATE="${REPO_ROOT}/CLAUDE.md.template"
AUTOFLOW_GUIDE="${REPO_ROOT}/docs/autoflow-guide.md"
SUBMODULE_RULES="${REPO_ROOT}/docs/submodule-common-rules.md"

echo "=== Test Suite: Issue #40 documentation sync ==="
echo ""

# ---------------------------------------------------------------------------
# T-design-rationale-decision-10 (AC 9)
# ---------------------------------------------------------------------------
# Two assertions:
#   (a) `grep -E "^### Decision 10: "` succeeds.
#   (b) The section between "^### Decision 10" and the next "^### " contains
#       "host repo" (case-insensitive).
echo "--- T-design-rationale-decision-10 (AC 9) ---"

if [ ! -f "$DESIGN_RATIONALE" ]; then
  fail "T-decision-10-file: docs/design-rationale.md not found"
else
  if grep -Eq "^### Decision 10: " "$DESIGN_RATIONALE"; then
    pass "T-decision-10-header: '### Decision 10: ' header found"
  else
    fail "T-decision-10-header: '### Decision 10: ' header missing"
  fi

  # Extract the Decision 10 section (between the "### Decision 10" line and
  # the next "### " heading). awk-only, no GNU extensions.
  decision_10_body=$(awk '
    /^### Decision 10/ { in_section = 1; print; next }
    in_section && /^### / { in_section = 0 }
    in_section { print }
  ' "$DESIGN_RATIONALE")

  if printf '%s' "$decision_10_body" | grep -qi "host repo"; then
    pass "T-decision-10-host-repo: section contains 'host repo' (case-insensitive)"
  else
    fail "T-decision-10-host-repo: section missing 'host repo'"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# T-claude-md-namespaced-tree (AC 10)
# ---------------------------------------------------------------------------
# Both CLAUDE.md and CLAUDE.md.template must contain the literal string
# "<sub-repo-id>/<issue-number>" — the namespaced layout marker.
echo "--- T-claude-md-namespaced-tree (AC 10) ---"

if [ ! -f "$CLAUDE_MD" ]; then
  fail "T-namespaced-claude-md-file: CLAUDE.md not found"
else
  if grep -F -q "<sub-repo-id>/<issue-number>" "$CLAUDE_MD"; then
    pass "T-namespaced-claude-md: CLAUDE.md contains '<sub-repo-id>/<issue-number>'"
  else
    fail "T-namespaced-claude-md: CLAUDE.md missing '<sub-repo-id>/<issue-number>'"
  fi
fi

if [ ! -f "$CLAUDE_TEMPLATE" ]; then
  fail "T-namespaced-template-file: CLAUDE.md.template not found"
else
  if grep -F -q "<sub-repo-id>/<issue-number>" "$CLAUDE_TEMPLATE"; then
    pass "T-namespaced-template: CLAUDE.md.template contains '<sub-repo-id>/<issue-number>'"
  else
    fail "T-namespaced-template: CLAUDE.md.template missing '<sub-repo-id>/<issue-number>'"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# T-autoflow-guide-intake (AC 11)
# ---------------------------------------------------------------------------
# The PREFLIGHT section of docs/autoflow-guide.md must mention "intake.md".
# Extract the section between "^## PREFLIGHT" and the next "^## " heading.
echo "--- T-autoflow-guide-intake (AC 11) ---"

if [ ! -f "$AUTOFLOW_GUIDE" ]; then
  fail "T-guide-intake-file: docs/autoflow-guide.md not found"
else
  preflight_block=$(awk '
    /^## PREFLIGHT/ { in_section = 1; print; next }
    in_section && /^## / { in_section = 0 }
    in_section { print }
  ' "$AUTOFLOW_GUIDE")

  if printf '%s' "$preflight_block" | grep -F -q "intake.md"; then
    pass "T-guide-intake: PREFLIGHT section in autoflow-guide.md mentions 'intake.md'"
  else
    fail "T-guide-intake: PREFLIGHT section in autoflow-guide.md missing 'intake.md'"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# T-submodule-common-rules-state-ownership (AC 12)
# ---------------------------------------------------------------------------
# docs/submodule-common-rules.md must contain a heading or paragraph about
# state ownership. The plan §1.5 specifies a subsection titled
# "Auto-Flow State Ownership"; we accept any of the patterns:
#   - "state ownership" (case-insensitive)
#   - ".autoflow-state...sub-repo" (or the reverse) describing the ownership
#     constraint.
echo "--- T-submodule-common-rules-state-ownership (AC 12) ---"

if [ ! -f "$SUBMODULE_RULES" ]; then
  fail "T-state-ownership-file: docs/submodule-common-rules.md not found"
else
  if grep -i -E -q '(state ownership|\.autoflow-state.*sub-repo|sub-repo.*\.autoflow-state)' "$SUBMODULE_RULES"; then
    pass "T-state-ownership: submodule-common-rules.md mentions Auto-Flow state ownership"
  else
    fail "T-state-ownership: submodule-common-rules.md missing state-ownership statement"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
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
