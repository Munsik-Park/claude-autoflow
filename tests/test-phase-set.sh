#!/usr/bin/env bash
# =============================================================================
# Test Suite: phase-set helper script + PreToolUse hook block (Sub-issue #28)
# =============================================================================
# Validates that:
#   - .claude/scripts/phase-set is the sole writer of .autoflow-state/<issue>/phase
#     and the sole appender to .autoflow-state/<issue>/history.log
#   - .claude/hooks/check-autoflow-gate.sh blocks direct PreToolUse Write/Edit
#     to phase files unless the AUTOFLOW_PHASE_SET env sentinel is set
#   - .claude/settings.json registers the hook with the correct nested shape
#
# Acceptance criteria encoded: T1-T15 from delegation.md
# (T15 covers AC 16 — settings.json validity, with grep-based fallback when
# python3/node are unavailable.)
#
# Exit codes used by the helper:
#   0  — success or --help
#   64 — usage error
#   65 — invalid phase or missing current-issue
#   73 — I/O error
#
# Exit code expected from the hook BLOCK path (per plan ERRATA E2): 2
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHASE_SET="${REPO_ROOT}/.claude/scripts/phase-set"
HOOK="${REPO_ROOT}/.claude/hooks/check-autoflow-gate.sh"
SETTINGS="${REPO_ROOT}/.claude/settings.json"
SIBLING_TEST="${REPO_ROOT}/tests/test-check-autoflow-gate.sh"

PASS=0
FAIL=0
ERRORS=()

# ---------------------------------------------------------------------------
# Test helpers (style mirrors tests/test-check-autoflow-gate.sh)
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
  local file="$1" pattern="$2" desc="$3"
  if [ -f "$file" ] && grep -q -- "$pattern" "$file" 2>/dev/null; then
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

assert_equals() {
  local expected="$1" actual="$2" desc="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc (expected '$expected', got '$actual')")
    echo "  FAIL: $desc (expected '$expected', got '$actual')"
  fi
}

assert_true() {
  local cond="$1" desc="$2"
  if [ "$cond" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $desc")
    echo "  FAIL: $desc"
  fi
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------
TEST_DIR=""

setup_test_dir() {
  TEST_DIR=$(mktemp -d)
}

cleanup_test_dir() {
  if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}

# Create a minimal .autoflow-state/ skeleton with current-issue=99
setup_state_dir() {
  local issue="${1:-99}"
  mkdir -p "${TEST_DIR}/.autoflow-state/${issue}"
  echo "$issue" > "${TEST_DIR}/.autoflow-state/current-issue"
}

# Run phase-set from inside an isolated CLAUDE_PROJECT_DIR fixture
run_phase_set() {
  local exit_code=0
  CLAUDE_PROJECT_DIR="$TEST_DIR" \
    bash "$PHASE_SET" "$@" \
      > "${TEST_DIR}/stdout.txt" 2> "${TEST_DIR}/stderr.txt" \
      || exit_code=$?
  echo "$exit_code"
}

echo "=== Test Suite: phase-set helper + hook block (Sub-issue #28) ==="
echo ""

# ===========================================================================
# T1: phase-set --help exits 0, prints "Usage:" to stdout
# ===========================================================================
echo "--- T1: --help exits 0, Usage on stdout ---"
setup_test_dir
exit_code=$(run_phase_set --help)
assert_exit_code 0 "$exit_code" "T1a: --help exits 0"
if [ -f "${TEST_DIR}/stdout.txt" ] && grep -q "Usage:" "${TEST_DIR}/stdout.txt" 2>/dev/null; then
  PASS=$((PASS + 1)); echo "  PASS: T1b: --help prints 'Usage:' to stdout"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T1b: --help did not print 'Usage:' to stdout")
  echo "  FAIL: T1b: --help did not print 'Usage:' to stdout"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# T2: no-arg invocation exits 64, stderr contains 'Usage'
# ===========================================================================
echo "--- T2: no-arg exits 64, stderr Usage ---"
setup_test_dir
exit_code=$(run_phase_set)
assert_exit_code 64 "$exit_code" "T2a: no-arg invocation exits 64"
assert_file_contains "${TEST_DIR}/stderr.txt" "Usage" "T2b: stderr contains 'Usage'"
cleanup_test_dir
echo ""

# ===========================================================================
# T3: unknown phase exits 65, file unchanged byte-for-byte, stderr names BOGUS
# ===========================================================================
echo "--- T3: unknown phase exits 65, file unchanged, stderr names token ---"
setup_test_dir
setup_state_dir 99
# Pre-existing phase content we want to verify is preserved.
printf 'DIAGNOSE\n' > "${TEST_DIR}/.autoflow-state/99/phase"
before_hash=$(cksum < "${TEST_DIR}/.autoflow-state/99/phase")
exit_code=$(run_phase_set BOGUS)
assert_exit_code 65 "$exit_code" "T3a: BOGUS phase exits 65"
after_hash=$(cksum < "${TEST_DIR}/.autoflow-state/99/phase")
assert_equals "$before_hash" "$after_hash" \
  "T3b: phase file unchanged byte-for-byte after rejection"
assert_file_contains "${TEST_DIR}/stderr.txt" "BOGUS" \
  "T3c: stderr message names rejected token 'BOGUS'"
cleanup_test_dir
echo ""

# ===========================================================================
# T4: phase-set DIAGNOSE exits 0, file content equals "DIAGNOSE\n"
# ===========================================================================
echo "--- T4: valid phase write succeeds with exact content ---"
setup_test_dir
setup_state_dir 99
exit_code=$(run_phase_set DIAGNOSE)
assert_exit_code 0 "$exit_code" "T4a: DIAGNOSE write exits 0"
if [ -f "${TEST_DIR}/.autoflow-state/99/phase" ]; then
  actual_content=$(cat "${TEST_DIR}/.autoflow-state/99/phase")
  # cat strips trailing newline only if absent; we want exactly "DIAGNOSE\n"
  # so compare via printf.
  expected=$(printf 'DIAGNOSE\n')
  # Read raw bytes to compare including newline
  actual_raw=$(od -c < "${TEST_DIR}/.autoflow-state/99/phase" | head -1)
  if [ "$actual_content" = "DIAGNOSE" ] \
      && [ "$(wc -c < "${TEST_DIR}/.autoflow-state/99/phase")" -eq 9 ]; then
    PASS=$((PASS + 1))
    echo "  PASS: T4b: phase file equals 'DIAGNOSE\\n' (9 bytes)"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: T4b: phase file content not 'DIAGNOSE\\n' (got: $actual_raw)")
    echo "  FAIL: T4b: phase file content not 'DIAGNOSE\\n'"
  fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T4b: phase file was not created")
  echo "  FAIL: T4b: phase file was not created"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# T5: missing .autoflow-state/current-issue → exits 65 with stderr message
# ===========================================================================
echo "--- T5: missing current-issue exits 65 ---"
setup_test_dir
mkdir -p "${TEST_DIR}/.autoflow-state"
# Deliberately do NOT create current-issue
exit_code=$(run_phase_set DIAGNOSE)
assert_exit_code 65 "$exit_code" "T5a: missing current-issue exits 65"
# Stderr must mention current-issue or no active issue
if grep -Eq "current-issue|no active issue" "${TEST_DIR}/stderr.txt" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: T5b: stderr explains missing current-issue"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T5b: stderr lacks clear 'current-issue' message")
  echo "  FAIL: T5b: stderr lacks clear 'current-issue' message"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# T6: --note "minimum impl" reproduced verbatim in history.log final line
#     with ISO-8601 UTC timestamp prefix
# ===========================================================================
echo "--- T6: --note reproduced in history.log with ISO-8601 timestamp ---"
setup_test_dir
setup_state_dir 99
exit_code=$(run_phase_set GREEN --note "minimum impl")
assert_exit_code 0 "$exit_code" "T6a: GREEN with --note exits 0"
HIST="${TEST_DIR}/.autoflow-state/99/history.log"
# Regex per delegation.md T6: ^[0-9-]+T[0-9:]+Z \| TRANSITION \| .*->GREEN \| minimum impl$
assert_file_matches_regex "$HIST" \
  '^[0-9-]+T[0-9:]+Z \| TRANSITION \| .*->GREEN \| minimum impl$' \
  "T6b: history.log final line matches timestamp+TRANSITION+->GREEN+note format"
cleanup_test_dir
echo ""

# ===========================================================================
# T7: first call with no history.log → file created, line begins with INIT->
# ===========================================================================
echo "--- T7: first call creates history.log with INIT-> sentinel ---"
setup_test_dir
setup_state_dir 99
# Ensure no history.log exists
[ -f "${TEST_DIR}/.autoflow-state/99/history.log" ] \
  && rm -f "${TEST_DIR}/.autoflow-state/99/history.log"
exit_code=$(run_phase_set PREFLIGHT)
assert_exit_code 0 "$exit_code" "T7a: first PREFLIGHT call exits 0"
HIST="${TEST_DIR}/.autoflow-state/99/history.log"
if [ -f "$HIST" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T7b: history.log was created"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T7b: history.log was not created")
  echo "  FAIL: T7b: history.log was not created"
fi
# Line must contain "INIT->" sentinel as the from-phase marker
assert_file_contains "$HIST" "INIT->" \
  "T7c: history.log first line contains 'INIT->' sentinel"
cleanup_test_dir
echo ""

# ===========================================================================
# T8: static check — atomic write idiom present (mv .*\.tmp)
# ===========================================================================
echo "--- T8: atomic write idiom (mv ... .tmp) present in script ---"
if [ -f "$PHASE_SET" ] && grep -q 'mv .*\.tmp' "$PHASE_SET" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: T8: phase-set contains 'mv .*\\.tmp' atomic-write idiom"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T8: phase-set missing 'mv .*\\.tmp' atomic-write idiom")
  echo "  FAIL: T8: phase-set missing 'mv .*\\.tmp' atomic-write idiom"
fi
echo ""

# ===========================================================================
# T9: concurrency — fork two background invocations with different phases,
# wait, assert phase ∈ {A, B} and history.log has exactly 2 lines
# ===========================================================================
echo "--- T9: concurrent invocations terminate cleanly, 2 history lines ---"
setup_test_dir
setup_state_dir 99
# Fork two phase-set processes in parallel
( CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$PHASE_SET" GREEN \
    >/dev/null 2>&1 ) &
PID_A=$!
( CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$PHASE_SET" REFINE \
    >/dev/null 2>&1 ) &
PID_B=$!
wait "$PID_A" 2>/dev/null || true
wait "$PID_B" 2>/dev/null || true

HIST="${TEST_DIR}/.autoflow-state/99/history.log"
PHASE_FILE="${TEST_DIR}/.autoflow-state/99/phase"

if [ -f "$PHASE_FILE" ]; then
  final_phase=$(tr -d '[:space:]' < "$PHASE_FILE")
  if [ "$final_phase" = "GREEN" ] || [ "$final_phase" = "REFINE" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: T9a: final phase ∈ {GREEN, REFINE} (got '$final_phase')"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: T9a: final phase '$final_phase' not in {GREEN, REFINE}")
    echo "  FAIL: T9a: final phase '$final_phase' not in {GREEN, REFINE}"
  fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T9a: phase file missing after concurrent writes")
  echo "  FAIL: T9a: phase file missing after concurrent writes"
fi

if [ -f "$HIST" ]; then
  line_count=$(wc -l < "$HIST" | tr -d '[:space:]')
  if [ "$line_count" = "2" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: T9b: history.log has exactly 2 lines"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: T9b: history.log has $line_count lines, expected 2")
    echo "  FAIL: T9b: history.log has $line_count lines, expected 2"
  fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T9b: history.log missing after concurrent writes")
  echo "  FAIL: T9b: history.log missing after concurrent writes"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# T10: hook block — PreToolUse + Write on phase-file path, no AUTOFLOW_PHASE_SET
# Per plan ERRATA E2: expected exit code is 2 (not 1).
# ===========================================================================
echo "--- T10: hook blocks direct PreToolUse Write to phase file (exit 2) ---"
setup_test_dir
# Hook does not need state-dir setup for the early-branch check, but
# CLAUDE_PROJECT_DIR is set so the hook resolves paths consistently.
PAYLOAD_T10='{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/tmp/x/.autoflow-state/99/phase"}}'
# Make sure AUTOFLOW_PHASE_SET is NOT inherited from this test runner's env
exit_code=0
printf '%s' "$PAYLOAD_T10" \
  | env -u AUTOFLOW_PHASE_SET CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
    || exit_code=$?
assert_exit_code 2 "$exit_code" \
  "T10a: hook exits 2 when PreToolUse Write targets phase file without sentinel"
# Stderr should mention phase-set helper (plan section 7 E1)
if grep -q "phase-set" "${TEST_DIR}/hook.err" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: T10b: hook stderr names the phase-set helper"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T10b: hook stderr does not name phase-set helper")
  echo "  FAIL: T10b: hook stderr does not name phase-set helper"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# T11: hook permits — same JSON as T10, but AUTOFLOW_PHASE_SET=1 in env
# ===========================================================================
echo "--- T11: hook permits when AUTOFLOW_PHASE_SET=1 (exit 0) ---"
setup_test_dir
PAYLOAD_T11="$PAYLOAD_T10"
exit_code=0
printf '%s' "$PAYLOAD_T11" \
  | AUTOFLOW_PHASE_SET=1 CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
    || exit_code=$?
assert_exit_code 0 "$exit_code" \
  "T11: hook exits 0 when AUTOFLOW_PHASE_SET=1 is set"
cleanup_test_dir
echo ""

# ===========================================================================
# T11b: hook ignores non-Write tool — tool_name "Read" → exit 0
# Per plan ERRATA: when tool_name is NOT in {Write, Edit, MultiEdit}, hook
# does not block (still exit 0).
# ===========================================================================
echo "--- T11b: hook does not block non-Write tools (Read) ---"
setup_test_dir
PAYLOAD_T11B='{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/x/.autoflow-state/99/phase"}}'
exit_code=0
printf '%s' "$PAYLOAD_T11B" \
  | env -u AUTOFLOW_PHASE_SET CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
    || exit_code=$?
assert_exit_code 0 "$exit_code" \
  "T11b: hook exits 0 when tool_name is 'Read' (not in Write/Edit/MultiEdit)"
cleanup_test_dir
echo ""

# ===========================================================================
# T12: regression — existing tests/test-check-autoflow-gate.sh still exits 0
# ===========================================================================
echo "--- T12: regression — sibling test suite still exits 0 ---"
exit_code=0
( cd "$REPO_ROOT" && bash "$SIBLING_TEST" ) \
  > /tmp/test-phase-set-sibling.out 2>&1 \
  || exit_code=$?
assert_exit_code 0 "$exit_code" \
  "T12: tests/test-check-autoflow-gate.sh exits 0 (no regression)"
echo ""

# ===========================================================================
# T13: forward-reference path — file at exact path .claude/scripts/phase-set
# ===========================================================================
echo "--- T13: helper exists at exact path .claude/scripts/phase-set ---"
if [ -f "$PHASE_SET" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T13a: file exists at .claude/scripts/phase-set"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T13a: file missing at .claude/scripts/phase-set")
  echo "  FAIL: T13a: file missing at .claude/scripts/phase-set"
fi
if [ -x "$PHASE_SET" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T13b: file is executable"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T13b: file is not executable")
  echo "  FAIL: T13b: file is not executable"
fi
echo ""

# ===========================================================================
# T14: BSD/GNU portability — static greps assert absence of GNU-only idioms
# Allow `sed -i ''` (BSD/portable form with empty backup arg) — that pattern
# starts with `sed -i ''` so we forbid only `sed -i ` (with a trailing space
# *and* no quote after it would be the GNU flag). We use a strict "sed -i"
# followed by a space, then a non-quote character.
# ===========================================================================
echo "--- T14: BSD/GNU portability static checks ---"
PORT_FAIL=0
PORT_DESC=""
if [ -f "$PHASE_SET" ]; then
  # Forbid: `sed -i ` followed by something other than a quote (GNU in-place)
  if grep -Eq "sed -i [^'\"]" "$PHASE_SET" 2>/dev/null; then
    PORT_FAIL=1; PORT_DESC="${PORT_DESC} GNU 'sed -i' usage;"
  fi
  # Forbid: `date -I` (GNU-only ISO date flag)
  if grep -q "date -I" "$PHASE_SET" 2>/dev/null; then
    PORT_FAIL=1; PORT_DESC="${PORT_DESC} GNU 'date -I' usage;"
  fi
  # Forbid: `readlink -f` (GNU-only canonicalize)
  if grep -q "readlink -f" "$PHASE_SET" 2>/dev/null; then
    PORT_FAIL=1; PORT_DESC="${PORT_DESC} GNU 'readlink -f' usage;"
  fi
  if [ "$PORT_FAIL" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  PASS: T14: phase-set contains no GNU-only idioms (sed -i / date -I / readlink -f)"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: T14: phase-set contains GNU-only idioms:${PORT_DESC}")
    echo "  FAIL: T14: phase-set contains GNU-only idioms:${PORT_DESC}"
  fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T14: phase-set missing — cannot run portability check")
  echo "  FAIL: T14: phase-set missing — cannot run portability check"
fi
echo ""

# ===========================================================================
# T15: settings.json validity (covers AC 16)
# Trade-off: do NOT require python3 (may not be installed in CI). Use:
#   - grep-based structural checks (always available)
#   - `node -e 'JSON.parse(...)'` if node is available, else grep-only
# ===========================================================================
echo "--- T15: .claude/settings.json exists, valid, and has nested structure ---"
if [ -f "$SETTINGS" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T15a: .claude/settings.json exists"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T15a: .claude/settings.json missing")
  echo "  FAIL: T15a: .claude/settings.json missing"
fi

# Structural grep checks — required by delegation.md
for token in '"PreToolUse"' '"matcher"' '"hooks"' '"command"'; do
  if [ -f "$SETTINGS" ] && grep -q "$token" "$SETTINGS" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo "  PASS: T15: settings.json contains $token"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: T15: settings.json missing token $token")
    echo "  FAIL: T15: settings.json missing token $token"
  fi
done

# JSON-syntax validity check via node if available; otherwise grep-only.
# Trade-off documented above: python3 is not assumed to be installed.
if [ -f "$SETTINGS" ]; then
  if command -v node >/dev/null 2>&1; then
    if node -e "JSON.parse(require('fs').readFileSync('$SETTINGS','utf8'))" \
        >/dev/null 2>&1; then
      PASS=$((PASS + 1))
      echo "  PASS: T15: settings.json parses as valid JSON (via node)"
    else
      FAIL=$((FAIL + 1))
      ERRORS+=("FAIL: T15: settings.json is not valid JSON (node parse failed)")
      echo "  FAIL: T15: settings.json is not valid JSON (node parse failed)"
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json,sys; json.load(open('$SETTINGS'))" \
        >/dev/null 2>&1; then
      PASS=$((PASS + 1))
      echo "  PASS: T15: settings.json parses as valid JSON (via python3)"
    else
      FAIL=$((FAIL + 1))
      ERRORS+=("FAIL: T15: settings.json is not valid JSON (python3 parse failed)")
      echo "  FAIL: T15: settings.json is not valid JSON (python3 parse failed)"
    fi
  else
    # Neither node nor python3 available — record SKIP as a PASS so portability
    # of the test itself isn't penalized. The structural grep checks above
    # still cover the "looks right" case.
    PASS=$((PASS + 1))
    echo "  PASS: T15: JSON parser unavailable (node/python3) — grep-only structural validation"
  fi
fi
echo ""

# ===========================================================================
# T16: phase-set rejects writes inside a submodule working tree (Issue #40 AC 1)
# Decision 4: trigger = `git rev-parse --show-superproject-working-tree` returns
# non-empty AND `AUTOFLOW_ALLOW_SUBMODULE_STATE` is unset → exit 65 (EX_DATAERR).
# Stderr message MUST mention both `submodule` and `AUTOFLOW_ALLOW_SUBMODULE_STATE`
# so the user knows what went wrong and how to override (testing/CI only).
# ===========================================================================
echo "--- T16: phase-set refuses to write inside a submodule (exit 65) ---"
setup_test_dir
setup_state_dir 99
# Build a tiny shim directory that intercepts `git` calls. The shim
# unconditionally returns a non-empty path for
# `rev-parse --show-superproject-working-tree`, simulating "we are inside a
# submodule whose superproject lives at /fake/superproject". All other `git`
# subcommands delegate to the real git found in $REAL_PATH so behavior in
# phase-set's other code paths remains intact.
SHIM_DIR_T16="${TEST_DIR}/bin"
mkdir -p "$SHIM_DIR_T16"
cat > "${SHIM_DIR_T16}/git" <<'GITSHIM'
#!/usr/bin/env bash
# Stub: only the superproject probe is intercepted; everything else delegates.
for arg in "$@"; do
  if [ "$arg" = "--show-superproject-working-tree" ]; then
    echo "/fake/superproject"
    exit 0
  fi
done
exec /usr/bin/env -i PATH="$REAL_PATH" git "$@"
GITSHIM
chmod +x "${SHIM_DIR_T16}/git"
REAL_PATH="$PATH"
export REAL_PATH
exit_code=0
PATH="${SHIM_DIR_T16}:${PATH}" \
  CLAUDE_PROJECT_DIR="$TEST_DIR" \
  bash "$PHASE_SET" DIAGNOSE \
    > "${TEST_DIR}/stdout.txt" 2> "${TEST_DIR}/stderr.txt" \
    || exit_code=$?
assert_exit_code 65 "$exit_code" \
  "T16a: phase-set DIAGNOSE inside submodule exits 65"
assert_file_contains "${TEST_DIR}/stderr.txt" "submodule" \
  "T16b: stderr mentions 'submodule' (Decision 4)"
assert_file_contains "${TEST_DIR}/stderr.txt" "AUTOFLOW_ALLOW_SUBMODULE_STATE" \
  "T16c: stderr names AUTOFLOW_ALLOW_SUBMODULE_STATE escape hatch (Decision 4)"
# Phase file MUST NOT have been created — rejection precedes any write.
if [ ! -f "${TEST_DIR}/.autoflow-state/99/phase" ] \
    && [ ! -f "${TEST_DIR}/.autoflow-state/self/99/phase" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T16d: no phase file created on rejection"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T16d: phase file was created despite rejection")
  echo "  FAIL: T16d: phase file was created despite rejection"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# T17: AUTOFLOW_ALLOW_SUBMODULE_STATE=1 escape hatch (Issue #40 AC 2)
# Same fixture as T16 (git-shim pretends we're in a submodule), but with
# the env override set the rejection block is bypassed; phase write succeeds
# and lands under the namespaced layout `<state>/self/<N>/`.
# ===========================================================================
echo "--- T17: AUTOFLOW_ALLOW_SUBMODULE_STATE=1 bypasses submodule rejection ---"
setup_test_dir
setup_state_dir 99
SHIM_DIR_T17="${TEST_DIR}/bin"
mkdir -p "$SHIM_DIR_T17"
cat > "${SHIM_DIR_T17}/git" <<'GITSHIM'
#!/usr/bin/env bash
for arg in "$@"; do
  if [ "$arg" = "--show-superproject-working-tree" ]; then
    echo "/fake/superproject"
    exit 0
  fi
done
exec /usr/bin/env -i PATH="$REAL_PATH" git "$@"
GITSHIM
chmod +x "${SHIM_DIR_T17}/git"
REAL_PATH="$PATH"
export REAL_PATH
exit_code=0
PATH="${SHIM_DIR_T17}:${PATH}" \
  AUTOFLOW_ALLOW_SUBMODULE_STATE=1 \
  CLAUDE_PROJECT_DIR="$TEST_DIR" \
  bash "$PHASE_SET" DIAGNOSE \
    > "${TEST_DIR}/stdout.txt" 2> "${TEST_DIR}/stderr.txt" \
    || exit_code=$?
assert_exit_code 0 "$exit_code" \
  "T17a: phase-set with AUTOFLOW_ALLOW_SUBMODULE_STATE=1 exits 0"
T17_PHASE="${TEST_DIR}/.autoflow-state/self/99/phase"
if [ -f "$T17_PHASE" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T17b: phase file created at .autoflow-state/self/99/phase"
  # Content must equal exactly "DIAGNOSE\n" (9 bytes).
  if [ "$(cat "$T17_PHASE")" = "DIAGNOSE" ] \
      && [ "$(wc -c < "$T17_PHASE")" -eq 9 ]; then
    PASS=$((PASS + 1))
    echo "  PASS: T17c: phase file equals 'DIAGNOSE\\n' (9 bytes)"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: T17c: phase file content not 'DIAGNOSE\\n'")
    echo "  FAIL: T17c: phase file content not 'DIAGNOSE\\n'"
  fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T17b: phase file not created at .autoflow-state/self/99/phase")
  echo "  FAIL: T17b: phase file not created at .autoflow-state/self/99/phase"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# T18: namespaced write — current-issue=mysubrepo/77 (Issue #40 AC 3)
# Decision 2: `current-issue` of the form `<sub-repo-id>/<issue-number>` writes
# state to `${STATE_DIR}/<sub-repo-id>/<issue-number>/`.
# ===========================================================================
echo "--- T18: namespaced current-issue=mysubrepo/77 → two-segment path ---"
setup_test_dir
mkdir -p "${TEST_DIR}/.autoflow-state"
echo "mysubrepo/77" > "${TEST_DIR}/.autoflow-state/current-issue"
exit_code=$(run_phase_set DIAGNOSE)
assert_exit_code 0 "$exit_code" \
  "T18a: phase-set with namespaced current-issue exits 0"
T18_PHASE="${TEST_DIR}/.autoflow-state/mysubrepo/77/phase"
T18_HIST="${TEST_DIR}/.autoflow-state/mysubrepo/77/history.log"
if [ -f "$T18_PHASE" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T18b: phase file at .autoflow-state/mysubrepo/77/phase exists"
  if [ "$(cat "$T18_PHASE")" = "DIAGNOSE" ] \
      && [ "$(wc -c < "$T18_PHASE")" -eq 9 ]; then
    PASS=$((PASS + 1))
    echo "  PASS: T18c: phase file equals 'DIAGNOSE\\n' (9 bytes)"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: T18c: phase file content not 'DIAGNOSE\\n'")
    echo "  FAIL: T18c: phase file content not 'DIAGNOSE\\n'"
  fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T18b: phase file missing at .autoflow-state/mysubrepo/77/phase")
  echo "  FAIL: T18b: phase file missing at .autoflow-state/mysubrepo/77/phase"
fi
if [ -f "$T18_HIST" ]; then
  T18_LINES=$(wc -l < "$T18_HIST" | tr -d '[:space:]')
  if [ "$T18_LINES" = "1" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: T18d: history.log has exactly 1 transition line"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: T18d: history.log has $T18_LINES lines, expected 1")
    echo "  FAIL: T18d: history.log has $T18_LINES lines, expected 1"
  fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T18d: history.log missing at .autoflow-state/mysubrepo/77/history.log")
  echo "  FAIL: T18d: history.log missing"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# T19: legacy bare-integer fallback (Issue #40 AC 4)
# Decision 3: a `current-issue` containing a bare integer (no slash) is parsed
# as `self/<integer>` so all writes land under the namespaced layout.
# Note: this expects the NEW layout `.autoflow-state/self/99/`, NOT the old
# `.autoflow-state/99/`.
# ===========================================================================
echo "--- T19: legacy bare-integer current-issue=99 → self/99/ ---"
setup_test_dir
mkdir -p "${TEST_DIR}/.autoflow-state"
echo "99" > "${TEST_DIR}/.autoflow-state/current-issue"
exit_code=$(run_phase_set DIAGNOSE)
assert_exit_code 0 "$exit_code" \
  "T19a: phase-set with bare-integer current-issue exits 0"
T19_NEW="${TEST_DIR}/.autoflow-state/self/99/phase"
T19_OLD="${TEST_DIR}/.autoflow-state/99/phase"
if [ -f "$T19_NEW" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T19b: phase file at .autoflow-state/self/99/phase (new layout)"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T19b: phase file missing at .autoflow-state/self/99/phase")
  echo "  FAIL: T19b: phase file missing at .autoflow-state/self/99/phase"
fi
# The legacy flat path MUST NOT be created — Decision 3 mandates uniform
# layout, no flat fallback writes.
if [ ! -f "$T19_OLD" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: T19c: legacy flat path .autoflow-state/99/phase NOT created"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T19c: legacy flat path .autoflow-state/99/phase was created")
  echo "  FAIL: T19c: legacy flat path .autoflow-state/99/phase was created"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# T10c: PreToolUse blocks new-depth namespaced phase path (Issue #40 AC 5)
# Decision 6: dual-pattern glob in the hook's PreToolUse case must catch both
# legacy (.autoflow-state/<N>/phase) and new (.autoflow-state/<sub>/<N>/phase)
# write attempts. T10 already covers legacy depth; T10c covers the new depth.
# ===========================================================================
echo "--- T10c: hook blocks PreToolUse Write to new-depth phase path (exit 2) ---"
setup_test_dir
PAYLOAD_T10C='{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/tmp/x/.autoflow-state/sub/99/phase"}}'
exit_code=0
printf '%s' "$PAYLOAD_T10C" \
  | env -u AUTOFLOW_PHASE_SET CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
    || exit_code=$?
assert_exit_code 2 "$exit_code" \
  "T10c: hook exits 2 for new-depth .autoflow-state/<sub>/<N>/phase write"
cleanup_test_dir
echo ""

# ===========================================================================
# T20: PREFLIGHT warn-only intake gate (Issue #40 GATE:PLAN suggestion #2)
# Decision 5 / plan §3.5: missing intake.md at PREFLIGHT WARNS but does not
# block (avoids chicken-and-egg with the very first phase-set PREFLIGHT
# call). DIAGNOSE+ would hard-block (covered by T-intake-missing in the
# sibling test file). This test pins down the warn-only behavior at PREFLIGHT.
# ===========================================================================
echo "--- T20: hook warns (exit 0) on missing intake.md at PREFLIGHT ---"
setup_test_dir
mkdir -p "${TEST_DIR}/.autoflow-state/self/50"
echo "self/50" > "${TEST_DIR}/.autoflow-state/current-issue"
echo "PREFLIGHT" > "${TEST_DIR}/.autoflow-state/self/50/phase"
# Deliberately NO intake.md
exit_code=0
CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
  > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
  || exit_code=$?
assert_exit_code 0 "$exit_code" \
  "T20a: PREFLIGHT without intake.md exits 0 (warn-only, not block)"
# Stderr (or stdout — log_warn writes to stdout in current hook, but plan §3.5
# says "warning"; the warning text must mention intake.md regardless of stream).
if grep -q "intake.md" "${TEST_DIR}/hook.err" 2>/dev/null \
    || grep -q "intake.md" "${TEST_DIR}/hook.out" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: T20b: hook output names 'intake.md' as warning subject"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: T20b: hook output does not mention 'intake.md' at PREFLIGHT")
  echo "  FAIL: T20b: hook output does not mention 'intake.md' at PREFLIGHT"
fi
cleanup_test_dir
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
