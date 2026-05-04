#!/usr/bin/env bash
# =============================================================================
# Test Suite: PREFLIGHT multi sub-repo sync helper (Issue #38, unit tests)
# =============================================================================
# Validates that .claude/scripts/preflight-sync:
#   - Skips silently (exit 0) when no registry exists (TC1)
#   - Rejects malformed YAML registry with EX_DATAERR=65 (TC2)
#   - Iterates over registered sub-repos and reports clean state (TC3)
#   - Detects pre-existing dirty state and aborts with exit 66 (TC4)
#   - Surfaces fetch failures during sync as exit 67 (TC5)
#   - Honours SYNC_FORCE=1 to bypass dirty-state guard (TC6)
#   - Falls back to .gitmodules when .autoflow/sub-repos.yml is absent (TC7)
#   - Prefers .autoflow/sub-repos.yml when both registries exist (TC8)
#
# All test cases set up an isolated mktemp working directory, treat it as the
# parent repo, and clean up via trap. The helper is invoked via `bash` so it
# does not need to be executable on disk to run (matches phase-set test style).
#
# Exit codes the helper is expected to use:
#   0  — sync success or skip (registry empty)
#   65 — registry format error (EX_DATAERR)
#   66 — pre-existing dirty state in a sub-repo
#   67 — sync failure (e.g. git fetch failed)
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFLIGHT_SYNC="${REPO_ROOT}/.claude/scripts/preflight-sync"

PASS=0
FAIL=0
ERRORS=()

# ---------------------------------------------------------------------------
# Test helpers (style mirrors tests/test-phase-set.sh)
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

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------
TEST_DIR=""

setup_test_dir() {
  TEST_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'preflight-sync')
  # macOS mktemp returns /var/folders/... which is fine; record absolute path
  TEST_DIR="$(cd "$TEST_DIR" && pwd)"
}

cleanup_test_dir() {
  if [ -n "${TEST_DIR:-}" ] && [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
  TEST_DIR=""
}

# Always clean up on script exit (covers any unexpected interruption between
# explicit cleanup_test_dir calls).
trap 'cleanup_test_dir' EXIT

# Initialize TEST_DIR as a parent git repo (so 'git submodule foreach' style
# helpers do not blow up on missing .git).
init_parent_repo() {
  ( cd "$TEST_DIR" \
      && git init -q . \
      && git config user.email "test@example.com" \
      && git config user.name "Test User" \
      && git commit --allow-empty -q -m "init" )
}

# Create a mock sub-repo directory at $TEST_DIR/$1 with one commit.
init_sub_repo() {
  local name="$1"
  local sub_path="${TEST_DIR}/${name}"
  mkdir -p "$sub_path"
  ( cd "$sub_path" \
      && git init -q . \
      && git config user.email "sub@example.com" \
      && git config user.name "Sub User" \
      && echo "x" > seed.txt \
      && git add seed.txt \
      && git commit -q -m "seed" )
  # Add a fake "origin" remote pointing at itself so fetch is harmless and
  # exists. Tests that need fetch to fail will overwrite the URL.
  ( cd "$sub_path" \
      && git remote add origin "$sub_path" 2>/dev/null || true )
}

# Run the helper from inside TEST_DIR; capture stdout/stderr/exit code.
run_preflight_sync() {
  local exit_code=0
  ( cd "$TEST_DIR" \
      && bash "$PREFLIGHT_SYNC" "$@" \
        > "${TEST_DIR}/stdout.txt" 2> "${TEST_DIR}/stderr.txt" ) \
    || exit_code=$?
  echo "$exit_code"
}

echo "=== Test Suite: preflight-sync helper (Issue #38 — unit) ==="
echo ""

# ===========================================================================
# TC1: registry empty → exit 0, stdout mentions "skipped"
# ===========================================================================
echo "--- TC1: no registry → skip with exit 0 ---"
setup_test_dir
init_parent_repo
# Deliberately: no .gitmodules, no .autoflow/sub-repos.yml
exit_code=$(run_preflight_sync)
assert_exit_code 0 "$exit_code" \
  "TC1a: empty registry exits 0"
if [ -f "${TEST_DIR}/stdout.txt" ] \
    && grep -qi "skip" "${TEST_DIR}/stdout.txt" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: TC1b: stdout contains 'skip' keyword"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: TC1b: stdout does not contain 'skip' keyword")
  echo "  FAIL: TC1b: stdout does not contain 'skip' keyword"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# TC2: malformed YAML in .autoflow/sub-repos.yml → exit 65 (EX_DATAERR)
# ===========================================================================
echo "--- TC2: malformed registry YAML → exit 65 ---"
setup_test_dir
init_parent_repo
mkdir -p "${TEST_DIR}/.autoflow"
# Garbage that does NOT start with the expected `sub_repos:` root key, with
# stray punctuation that any sane parser must reject.
cat > "${TEST_DIR}/.autoflow/sub-repos.yml" <<'EOF'
this is: [not, valid
  - oops
   ::: broken :::
EOF
exit_code=$(run_preflight_sync)
assert_exit_code 65 "$exit_code" \
  "TC2a: malformed YAML registry exits 65"
# stderr should mention the file or 'format' so the user knows what failed.
if grep -Eqi "sub-repos\.yml|format|invalid|parse" "${TEST_DIR}/stderr.txt" \
      2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: TC2b: stderr explains the registry format error"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: TC2b: stderr lacks a clear format-error message")
  echo "  FAIL: TC2b: stderr lacks a clear format-error message"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# TC3: registered clean sub-repos → exit 0, both sub-repo names referenced
# ===========================================================================
echo "--- TC3: clean sub-repos sync → exit 0, both names visible ---"
setup_test_dir
init_parent_repo
init_sub_repo "subA"
init_sub_repo "subB"
mkdir -p "${TEST_DIR}/.autoflow"
cat > "${TEST_DIR}/.autoflow/sub-repos.yml" <<'EOF'
sub_repos:
  - subA
  - subB
EOF
exit_code=$(run_preflight_sync)
assert_exit_code 0 "$exit_code" \
  "TC3a: clean registered sub-repos exit 0"
# Combined output (stdout+stderr) should reference both sub-repos so the user
# sees what was visited. The helper may use either stream; check both.
combined="${TEST_DIR}/combined.txt"
cat "${TEST_DIR}/stdout.txt" "${TEST_DIR}/stderr.txt" > "$combined" 2>/dev/null
if grep -q "subA" "$combined" 2>/dev/null \
    && grep -q "subB" "$combined" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: TC3b: helper output references both subA and subB"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: TC3b: helper output missing subA and/or subB references")
  echo "  FAIL: TC3b: helper output missing subA and/or subB references"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# TC4: pre-existing dirty in one sub-repo → exit 66, name reported
# ===========================================================================
echo "--- TC4: dirty sub-repo pre-check → exit 66, name reported ---"
setup_test_dir
init_parent_repo
init_sub_repo "subA"
init_sub_repo "subB"
# Make subB dirty by adding an untracked file.
echo "untracked" > "${TEST_DIR}/subB/dirty.txt"
mkdir -p "${TEST_DIR}/.autoflow"
cat > "${TEST_DIR}/.autoflow/sub-repos.yml" <<'EOF'
sub_repos:
  - subA
  - subB
EOF
exit_code=$(run_preflight_sync)
assert_exit_code 66 "$exit_code" \
  "TC4a: pre-existing dirty exits 66"
combined="${TEST_DIR}/combined.txt"
cat "${TEST_DIR}/stdout.txt" "${TEST_DIR}/stderr.txt" > "$combined" 2>/dev/null
if grep -q "subB" "$combined" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: TC4b: dirty sub-repo name (subB) is reported"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: TC4b: dirty sub-repo name (subB) NOT reported in output")
  echo "  FAIL: TC4b: dirty sub-repo name (subB) NOT reported in output"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# TC5: fetch failure during sync → exit 67
# ===========================================================================
echo "--- TC5: fetch failure during sync → exit 67 ---"
setup_test_dir
init_parent_repo
init_sub_repo "subA"
# Break the origin URL so `git fetch` will fail unconditionally.
( cd "${TEST_DIR}/subA" \
    && git remote remove origin 2>/dev/null || true
  cd "${TEST_DIR}/subA" \
    && git remote add origin "/nonexistent/path/that/does/not/exist.git" )
mkdir -p "${TEST_DIR}/.autoflow"
cat > "${TEST_DIR}/.autoflow/sub-repos.yml" <<'EOF'
sub_repos:
  - subA
EOF
exit_code=$(run_preflight_sync)
assert_exit_code 67 "$exit_code" \
  "TC5a: fetch failure exits 67"
combined="${TEST_DIR}/combined.txt"
cat "${TEST_DIR}/stdout.txt" "${TEST_DIR}/stderr.txt" > "$combined" 2>/dev/null
if grep -Eqi "fetch|sync.*fail|failed" "$combined" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: TC5b: helper output mentions the fetch/sync failure"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: TC5b: helper output does not mention the failure")
  echo "  FAIL: TC5b: helper output does not mention the failure"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# TC6: SYNC_FORCE=1 bypasses the dirty-state guard from TC4
# ===========================================================================
echo "--- TC6: SYNC_FORCE=1 bypasses dirty guard → exit 0 ---"
setup_test_dir
init_parent_repo
init_sub_repo "subA"
init_sub_repo "subB"
echo "untracked" > "${TEST_DIR}/subB/dirty.txt"
mkdir -p "${TEST_DIR}/.autoflow"
cat > "${TEST_DIR}/.autoflow/sub-repos.yml" <<'EOF'
sub_repos:
  - subA
  - subB
EOF
exit_code=0
( cd "$TEST_DIR" \
    && SYNC_FORCE=1 bash "$PREFLIGHT_SYNC" \
      > "${TEST_DIR}/stdout.txt" 2> "${TEST_DIR}/stderr.txt" ) \
  || exit_code=$?
assert_exit_code 0 "$exit_code" \
  "TC6: SYNC_FORCE=1 with dirty sub-repo exits 0 (guard bypassed)"
cleanup_test_dir
echo ""

# ===========================================================================
# TC7: .gitmodules fallback (no .autoflow/sub-repos.yml) → exit 0
# ===========================================================================
echo "--- TC7: .gitmodules fallback when yml absent → exit 0 ---"
setup_test_dir
init_parent_repo
init_sub_repo "subA"
# Write a minimal .gitmodules listing subA (we do not actually run
# `git submodule add` because we want a controlled fixture without network).
cat > "${TEST_DIR}/.gitmodules" <<'EOF'
[submodule "subA"]
	path = subA
	url = ./subA
EOF
# Deliberately: NO .autoflow/sub-repos.yml
exit_code=$(run_preflight_sync)
assert_exit_code 0 "$exit_code" \
  "TC7a: .gitmodules-only registry exits 0"
combined="${TEST_DIR}/combined.txt"
cat "${TEST_DIR}/stdout.txt" "${TEST_DIR}/stderr.txt" > "$combined" 2>/dev/null
if grep -q "subA" "$combined" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: TC7b: helper output references subA from .gitmodules"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: TC7b: helper output did not reference subA from .gitmodules")
  echo "  FAIL: TC7b: helper output did not reference subA from .gitmodules"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# TC8: both registries present → .autoflow/sub-repos.yml takes precedence
# .gitmodules lists "subOnlyInGitmodules" but yml lists "subOnlyInYaml" — only
# the yaml-listed sub-repo should be visited.
# ===========================================================================
echo "--- TC8: yml overrides .gitmodules when both exist ---"
setup_test_dir
init_parent_repo
init_sub_repo "subOnlyInYaml"
init_sub_repo "subOnlyInGitmodules"
mkdir -p "${TEST_DIR}/.autoflow"
cat > "${TEST_DIR}/.autoflow/sub-repos.yml" <<'EOF'
sub_repos:
  - subOnlyInYaml
EOF
cat > "${TEST_DIR}/.gitmodules" <<'EOF'
[submodule "subOnlyInGitmodules"]
	path = subOnlyInGitmodules
	url = ./subOnlyInGitmodules
EOF
exit_code=$(run_preflight_sync)
assert_exit_code 0 "$exit_code" \
  "TC8a: dual-registry exits 0"
combined="${TEST_DIR}/combined.txt"
cat "${TEST_DIR}/stdout.txt" "${TEST_DIR}/stderr.txt" > "$combined" 2>/dev/null
yaml_seen=1
gitmod_seen=1
grep -q "subOnlyInYaml" "$combined" 2>/dev/null || yaml_seen=0
grep -q "subOnlyInGitmodules" "$combined" 2>/dev/null || gitmod_seen=0
if [ "$yaml_seen" -eq 1 ]; then
  PASS=$((PASS + 1))
  echo "  PASS: TC8b: helper visited subOnlyInYaml (yml entry honoured)"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: TC8b: helper did NOT visit subOnlyInYaml")
  echo "  FAIL: TC8b: helper did NOT visit subOnlyInYaml"
fi
# TC8c is meaningful ONLY when TC8b passed (yaml entry was actually visited).
# Otherwise "didn't visit gitmodules entry" is trivially true (e.g. helper
# missing → no output at all). Tie the success condition together:
#   yaml_seen=1 AND gitmod_seen=0 → precedence proven.
if [ "$yaml_seen" -eq 1 ] && [ "$gitmod_seen" -eq 0 ]; then
  PASS=$((PASS + 1))
  echo "  PASS: TC8c: yml visited AND gitmodules entry skipped (precedence proven)"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: TC8c: precedence not proven (yaml_seen=$yaml_seen, gitmod_seen=$gitmod_seen)")
  echo "  FAIL: TC8c: precedence not proven (yaml_seen=$yaml_seen, gitmod_seen=$gitmod_seen)"
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
