#!/usr/bin/env bash
# =============================================================================
# Test: sed_inplace function from setup/init.sh
# =============================================================================
# Tests acceptance criteria for Issue #9:
#   1. sed_inplace correctly substitutes placeholders
#   2. No sed -i direct calls remain in init.sh
#   3. No unintended backup files are created
#   4. Placeholder substitution produces correct results
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
TESTS=0

assert_eq() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  TESTS=$((TESTS + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_true() {
  local desc="$1"
  local condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Setup: extract sed_inplace function for isolated testing
# ---------------------------------------------------------------------------
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Source only the sed_inplace function
eval "$(sed -n '/^sed_inplace()/,/^}/p' "$PROJECT_ROOT/setup/init.sh")"

# ---------------------------------------------------------------------------
# Test 1: sed_inplace substitutes a placeholder correctly
# ---------------------------------------------------------------------------
echo "Test 1: Basic placeholder substitution"
echo "Hello {{PROJECT_NAME}} world" > "$TMPDIR_TEST/test1.txt"
sed_inplace "s|{{PROJECT_NAME}}|MyProject|g" "$TMPDIR_TEST/test1.txt"
assert_eq "placeholder replaced" "Hello MyProject world" "$(cat "$TMPDIR_TEST/test1.txt")"

# ---------------------------------------------------------------------------
# Test 2: sed_inplace does not leave backup files
# ---------------------------------------------------------------------------
echo "Test 2: No backup files created"
echo "{{FOO}}" > "$TMPDIR_TEST/test2.txt"
sed_inplace "s|{{FOO}}|bar|g" "$TMPDIR_TEST/test2.txt"
BACKUP_COUNT=$(find "$TMPDIR_TEST" -name "test2.txt*" | wc -l | tr -d ' ')
assert_eq "only original file exists (no .bak, -e, etc.)" "1" "$BACKUP_COUNT"

# ---------------------------------------------------------------------------
# Test 3: sed_inplace does not leave .tmp files
# ---------------------------------------------------------------------------
echo "Test 3: No .tmp files remain"
echo "{{BAR}}" > "$TMPDIR_TEST/test3.txt"
sed_inplace "s|{{BAR}}|baz|g" "$TMPDIR_TEST/test3.txt"
assert_true "no .tmp files remain" "[[ ! -f '$TMPDIR_TEST/test3.txt.tmp' ]]"

# ---------------------------------------------------------------------------
# Test 4: Multiple substitutions in same file
# ---------------------------------------------------------------------------
echo "Test 4: Multiple substitutions"
cat > "$TMPDIR_TEST/test4.txt" << 'EOF'
name: {{PROJECT_NAME}}
org: {{GITHUB_ORG}}
branch: {{DEFAULT_BRANCH}}
EOF
sed_inplace "s|{{PROJECT_NAME}}|MyProject|g" "$TMPDIR_TEST/test4.txt"
sed_inplace "s|{{GITHUB_ORG}}|my-org|g" "$TMPDIR_TEST/test4.txt"
sed_inplace "s|{{DEFAULT_BRANCH}}|main|g" "$TMPDIR_TEST/test4.txt"
EXPECTED="name: MyProject
org: my-org
branch: main"
assert_eq "all three placeholders replaced" "$EXPECTED" "$(cat "$TMPDIR_TEST/test4.txt")"

# ---------------------------------------------------------------------------
# Test 5: No sed -i direct calls remain in init.sh
# ---------------------------------------------------------------------------
echo "Test 5: No sed -i calls in init.sh"
SED_I_COUNT=$(grep -c 'sed -i ' "$PROJECT_ROOT/setup/init.sh" || true)
assert_eq "zero sed -i direct calls" "0" "$SED_I_COUNT"

# ---------------------------------------------------------------------------
# Test 6: sed_inplace function exists in init.sh
# ---------------------------------------------------------------------------
echo "Test 6: sed_inplace function defined"
assert_true "sed_inplace function exists in init.sh" \
  "grep -q '^sed_inplace()' '$PROJECT_ROOT/setup/init.sh'"

# ---------------------------------------------------------------------------
# Test 7: File with no matching pattern is unchanged
# ---------------------------------------------------------------------------
echo "Test 7: No-match leaves file unchanged"
echo "no placeholders here" > "$TMPDIR_TEST/test7.txt"
sed_inplace "s|{{NOTHING}}|replaced|g" "$TMPDIR_TEST/test7.txt"
assert_eq "file unchanged when no match" "no placeholders here" "$(cat "$TMPDIR_TEST/test7.txt")"

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
