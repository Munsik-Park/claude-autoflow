#!/usr/bin/env bash
# =============================================================================
# Test Suite: Issue #38 — multi sub-repo sync integration
# =============================================================================
# Validates the document/state integration of PREFLIGHT 0-2b:
#   TC9  — When preflight-sync exits 67 during PREFLIGHT, phase-set must NOT
#          allow transition to DIAGNOSE (PREFLIGHT abort propagates).
#   TC10 — CLAUDE.md and CLAUDE.md.template both define the `0-2b` sub-step.
#   TC11 — docs/autoflow-guide.md PREFLIGHT section table contains a `0-2b` row.
#   TC12 — docs/design-rationale.md contains a `[CONDITIONAL]` marker AND
#          relates the new Decision to "Never skip phases".
#
# These tests must FAIL until the Developer AI lands the implementation —
# they assert the end-state contract.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFLIGHT_SYNC="${REPO_ROOT}/.claude/scripts/preflight-sync"
PHASE_SET="${REPO_ROOT}/.claude/scripts/phase-set"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
CLAUDE_TEMPLATE="${REPO_ROOT}/CLAUDE.md.template"
GUIDE="${REPO_ROOT}/docs/autoflow-guide.md"
RATIONALE="${REPO_ROOT}/docs/design-rationale.md"

PASS=0
FAIL=0
ERRORS=()

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
assert_exit_code() {
  local expected="$1" actual="$2" desc="$3"
  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc (expected exit $expected, got $actual)")
    echo "  FAIL: $desc (expected exit $expected, got $actual)"
  fi
}

assert_file_contains() {
  # Uses grep -F so that bracketed/regex-special patterns like '[CONDITIONAL]'
  # are matched as literal strings (not character classes).
  local file="$1" pattern="$2" desc="$3"
  if [ -f "$file" ] && grep -qF -- "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc (pattern '$pattern' not found in $file)")
    echo "  FAIL: $desc"
  fi
}

assert_file_matches_regex() {
  local file="$1" regex="$2" desc="$3"
  if [ -f "$file" ] && grep -Eq -- "$regex" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc (regex '$regex' did not match in $file)")
    echo "  FAIL: $desc"
  fi
}

# ---------------------------------------------------------------------------
# Fixture helpers (TC9)
# ---------------------------------------------------------------------------
TEST_DIR=""

setup_test_dir() {
  TEST_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'issue-38-int')
  TEST_DIR="$(cd "$TEST_DIR" && pwd)"
}

cleanup_test_dir() {
  if [ -n "${TEST_DIR:-}" ] && [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
  TEST_DIR=""
}

trap 'cleanup_test_dir' EXIT

echo "=== Test Suite: Issue #38 multi sub-repo sync (integration) ==="
echo ""

# ===========================================================================
# TC9: PREFLIGHT abort integration —
# When `.autoflow-state/<issue>/phase` is PREFLIGHT and preflight-sync would
# fail (exit 67), phase-set must not silently advance to DIAGNOSE.
#
# Strategy: invoke preflight-sync on a fixture rigged to exit 67 (broken
# origin URL). Whatever exit code we observe, then attempt the DIAGNOSE
# transition only if sync exited 0 (orchestrator contract). The test passes
# ONLY when both:
#   (a) sync exited exactly 67, AND
#   (b) phase file remained at PREFLIGHT.
# Both halves must hold; we do NOT credit "phase unchanged" when sync itself
# couldn't even run (e.g. helper missing → exit 127), because that would
# trivially pass without proving the abort contract.
# ===========================================================================
echo "--- TC9: PREFLIGHT abort blocks DIAGNOSE transition ---"
setup_test_dir
# Build a mock parent + sub-repo with broken origin so sync fails.
( cd "$TEST_DIR" \
    && git init -q . \
    && git config user.email "test@example.com" \
    && git config user.name "Test User" \
    && git commit --allow-empty -q -m "init" )
mkdir -p "${TEST_DIR}/subA"
( cd "${TEST_DIR}/subA" \
    && git init -q . \
    && git config user.email "sub@example.com" \
    && git config user.name "Sub User" \
    && echo "x" > seed.txt \
    && git add seed.txt \
    && git commit -q -m "seed" \
    && git remote add origin "/nonexistent/broken/path.git" )
mkdir -p "${TEST_DIR}/.autoflow"
cat > "${TEST_DIR}/.autoflow/sub-repos.yml" <<'EOF'
sub_repos:
  - subA
EOF
# State setup: current-issue=38, phase=PREFLIGHT (the gate).
mkdir -p "${TEST_DIR}/.autoflow-state/38"
echo "38" > "${TEST_DIR}/.autoflow-state/current-issue"
echo "PREFLIGHT" > "${TEST_DIR}/.autoflow-state/38/phase"

# Run preflight-sync; capture its exit code.
sync_exit=0
( cd "$TEST_DIR" \
    && bash "$PREFLIGHT_SYNC" \
      > "${TEST_DIR}/sync.out" 2> "${TEST_DIR}/sync.err" ) \
  || sync_exit=$?
assert_exit_code 67 "$sync_exit" \
  "TC9a: preflight-sync against broken sub-repo exits 67"

# Orchestrator contract: only invoke phase-set when sync_exit == 0. We model
# this by SKIPPING the phase-set call when sync_exit is non-zero. Then the
# end-state assertion is "phase file is still PREFLIGHT".
if [ "$sync_exit" -eq 0 ]; then
  # In this test sync MUST have failed; if it succeeds we let phase-set try
  # so the test surfaces the broken contract.
  CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$PHASE_SET" DIAGNOSE \
    > "${TEST_DIR}/ps.out" 2> "${TEST_DIR}/ps.err" || true
fi

actual_phase=""
if [ -f "${TEST_DIR}/.autoflow-state/38/phase" ]; then
  actual_phase=$(tr -d '[:space:]' < "${TEST_DIR}/.autoflow-state/38/phase")
fi
# TC9b passes ONLY if sync_exit was exactly 67 AND phase is still PREFLIGHT.
# Either condition alone (e.g. helper missing → 127, or wrong exit code) is
# a contract violation and must FAIL — this prevents TC9b from passing
# trivially when the implementation is absent.
if [ "$sync_exit" -eq 67 ] && [ "$actual_phase" = "PREFLIGHT" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: TC9b: sync exit 67 AND phase remained PREFLIGHT (abort contract)"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: TC9b: abort contract not satisfied (sync_exit=$sync_exit, phase='$actual_phase')")
  echo "  FAIL: TC9b: abort contract not satisfied (sync_exit=$sync_exit, phase='$actual_phase')"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# TC10: CLAUDE.md and CLAUDE.md.template both reference 0-2b
# ===========================================================================
echo "--- TC10: CLAUDE.md / CLAUDE.md.template both define 0-2b ---"
assert_file_matches_regex "$CLAUDE_MD" "0-2b" \
  "TC10a: CLAUDE.md references the 0-2b sub-step"
assert_file_matches_regex "$CLAUDE_TEMPLATE" "0-2b" \
  "TC10b: CLAUDE.md.template references the 0-2b sub-step"
echo ""

# ===========================================================================
# TC11: docs/autoflow-guide.md has a 0-2b row in the PREFLIGHT section table.
# We require the row to appear AFTER the PREFLIGHT section heading. Use awk
# to slice the file from "## PREFLIGHT" to the next "## " heading and grep
# inside that slice. If no slice is produced or no match is found, FAIL.
# ===========================================================================
echo "--- TC11: autoflow-guide.md PREFLIGHT table contains 0-2b row ---"
if [ -f "$GUIDE" ]; then
  preflight_slice=$(awk '
    /^## .*PREFLIGHT/ { in_section=1; print; next }
    /^## / && in_section { in_section=0 }
    in_section { print }
  ' "$GUIDE")
  if printf '%s\n' "$preflight_slice" | grep -Eq "0-2b"; then
    PASS=$((PASS + 1))
    echo "  PASS: TC11: autoflow-guide.md PREFLIGHT section contains 0-2b"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: TC11: autoflow-guide.md PREFLIGHT section missing 0-2b row")
    echo "  FAIL: TC11: autoflow-guide.md PREFLIGHT section missing 0-2b row"
  fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: TC11: docs/autoflow-guide.md does not exist")
  echo "  FAIL: TC11: docs/autoflow-guide.md does not exist"
fi
echo ""

# ===========================================================================
# TC12: design-rationale.md contains the [CONDITIONAL] marker AND relates the
# new Decision to "Never skip phases".
# Uses grep -F so the literal [CONDITIONAL] token is matched (not parsed as
# a character class).
# ===========================================================================
echo "--- TC12: design-rationale.md has [CONDITIONAL] marker + 'Never skip phases' tie ---"
assert_file_contains "$RATIONALE" "[CONDITIONAL]" \
  "TC12a: design-rationale.md contains literal '[CONDITIONAL]' marker"
assert_file_contains "$RATIONALE" "Never skip phases" \
  "TC12b: design-rationale.md references 'Never skip phases'"
echo ""

# ===========================================================================
# Summary
# ===========================================================================
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
