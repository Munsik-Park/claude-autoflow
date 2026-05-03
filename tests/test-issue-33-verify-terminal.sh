#!/usr/bin/env bash
# =============================================================================
# Test Suite: Issue #33 — VERIFY-DEADLOCK → unified fail-closed handler
# =============================================================================
# Encodes the 14 [automated] acceptance criteria from
#   .autoflow-state/autoflow-upstream/33/plan.md §"Acceptance criteria"
#
# AC numbering matches plan.md exactly.
#
# Style follows tests/test-issue-40-doc-sync.sh and tests/test-phase-set.sh:
#   - set -euo pipefail
#   - mktemp -d for isolated state fixtures
#   - POSIX grep/awk only; no GNU extensions; no `sed -i` without backup
#   - One test function per AC; PASS/FAIL printed inline; aggregate at the end
#
# Manual ACs (13, 14 — worked-example markdown blocks in
# docs/autoflow-guide.md) are listed in the "Manual verification checklist"
# comment block at the end of this file.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
CLAUDE_TEMPLATE="${REPO_ROOT}/CLAUDE.md.template"
AUTOFLOW_GUIDE="${REPO_ROOT}/docs/autoflow-guide.md"
DESIGN_RATIONALE="${REPO_ROOT}/docs/design-rationale.md"
EVAL_SYSTEM="${REPO_ROOT}/docs/evaluation-system.md"
PHASE_SET="${REPO_ROOT}/.claude/scripts/phase-set"
HOOK="${REPO_ROOT}/.claude/hooks/check-autoflow-gate.sh"
TEST_PHASE_SET="${REPO_ROOT}/tests/test-phase-set.sh"
TEST_HOOK_ROLE_MARKER="${REPO_ROOT}/tests/test-hook-role-marker.sh"

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

# ---------------------------------------------------------------------------
# Fixture helpers (mirror tests/test-phase-set.sh conventions)
# ---------------------------------------------------------------------------
TEST_DIR=""

setup_test_dir() {
  TEST_DIR=$(mktemp -d)
}

cleanup_test_dir() {
  if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
  TEST_DIR=""
}

# Write a valid detailed-failure-analysis.md under a given dir. The four
# required headers from plan.md §"New artifacts introduced" are present.
write_valid_failure_artifact() {
  local target="$1"
  cat > "$target" <<'ARTIFACT'
# Detailed Failure Analysis

## Pattern Classification
self-reinterpretation
sub-classification: SKIP attempt

## Triggering Message
sender: test-ai
body: this AC should be SKIPped because the test is misclassified

## Failing Test Output
test_id: T1
stdout/stderr:
  AssertionError: expected exit 0 got 1

## RED Decision Basis
delegation.md AC 1 stated the script must exit 0; the test follows that contract.
ARTIFACT
}

echo "=== Test Suite: Issue #33 — VERIFY terminal failure path ==="
echo ""

# ===========================================================================
# AC 1: grep -c "VERIFY DEADLOCK" services/autoflow-upstream/CLAUDE.md → 0
# ===========================================================================
echo "--- AC 1: CLAUDE.md must not contain 'VERIFY DEADLOCK' ---"
if [ ! -f "$CLAUDE_MD" ]; then
  fail "AC1: CLAUDE.md not found"
else
  count=$(grep -c "VERIFY DEADLOCK" "$CLAUDE_MD" || true)
  if [ "$count" = "0" ]; then
    pass "AC1: CLAUDE.md contains 0 occurrences of 'VERIFY DEADLOCK'"
  else
    fail "AC1: CLAUDE.md contains $count occurrence(s) of 'VERIFY DEADLOCK' (expected 0)"
  fi
fi
echo ""

# ===========================================================================
# AC 2: grep -c "VERIFY DEADLOCK" services/autoflow-upstream/CLAUDE.md.template → 0
# ===========================================================================
echo "--- AC 2: CLAUDE.md.template must not contain 'VERIFY DEADLOCK' ---"
if [ ! -f "$CLAUDE_TEMPLATE" ]; then
  fail "AC2: CLAUDE.md.template not found"
else
  count=$(grep -c "VERIFY DEADLOCK" "$CLAUDE_TEMPLATE" || true)
  if [ "$count" = "0" ]; then
    pass "AC2: CLAUDE.md.template contains 0 occurrences of 'VERIFY DEADLOCK'"
  else
    fail "AC2: CLAUDE.md.template contains $count occurrence(s) of 'VERIFY DEADLOCK' (expected 0)"
  fi
fi
echo ""

# ===========================================================================
# AC 3: 'Evaluation AI arbitrates' must be absent from CLAUDE.md,
# CLAUDE.md.template, and docs/autoflow-guide.md.
# ===========================================================================
echo "--- AC 3: 'Evaluation AI arbitrates' must be absent from three files ---"
for f in "$CLAUDE_MD" "$CLAUDE_TEMPLATE" "$AUTOFLOW_GUIDE"; do
  if [ ! -f "$f" ]; then
    fail "AC3: file not found: $f"
    continue
  fi
  count=$(grep -c "Evaluation AI arbitrates" "$f" || true)
  if [ "$count" = "0" ]; then
    pass "AC3: $(basename "$f") contains 0 occurrences of 'Evaluation AI arbitrates'"
  else
    fail "AC3: $(basename "$f") contains $count occurrence(s) of 'Evaluation AI arbitrates' (expected 0)"
  fi
done
echo ""

# ===========================================================================
# AC 4: phase-set must list TERMINAL:VERIFY-FAILED inside VALID_PHASES.
# Approach: extract the VALID_PHASES line (begins with VALID_PHASES= or
# `readonly VALID_PHASES=`), then grep for the new phase token inside it.
# ===========================================================================
echo "--- AC 4: phase-set VALID_PHASES must contain 'TERMINAL:VERIFY-FAILED' ---"
if [ ! -f "$PHASE_SET" ]; then
  fail "AC4: phase-set script not found"
else
  valid_phases_line=$(awk '
    /VALID_PHASES[[:space:]]*=/ { print; exit }
  ' "$PHASE_SET")
  if [ -z "$valid_phases_line" ]; then
    fail "AC4: VALID_PHASES assignment line not found in phase-set"
  else
    if printf '%s' "$valid_phases_line" | grep -F -q "TERMINAL:VERIFY-FAILED"; then
      pass "AC4: VALID_PHASES line contains 'TERMINAL:VERIFY-FAILED'"
    else
      fail "AC4: VALID_PHASES line does not contain 'TERMINAL:VERIFY-FAILED' (line: $valid_phases_line)"
    fi
  fi
fi
echo ""

# ===========================================================================
# AC 5: phase-set TERMINAL:VERIFY-FAILED with phase=VERIFY and a valid
# detailed-failure-analysis.md exits 0 and writes the new phase.
# Fixture uses self/33 namespace.
# ===========================================================================
echo "--- AC 5: phase-set TERMINAL:VERIFY-FAILED happy path → exit 0 + phase written ---"
setup_test_dir
mkdir -p "${TEST_DIR}/.autoflow-state/self/33"
echo "self/33" > "${TEST_DIR}/.autoflow-state/current-issue"
echo "VERIFY" > "${TEST_DIR}/.autoflow-state/self/33/phase"
write_valid_failure_artifact \
  "${TEST_DIR}/.autoflow-state/self/33/detailed-failure-analysis.md"

exit_code=0
CLAUDE_PROJECT_DIR="$TEST_DIR" \
  bash "$PHASE_SET" TERMINAL:VERIFY-FAILED \
    > "${TEST_DIR}/stdout.txt" 2> "${TEST_DIR}/stderr.txt" \
  || exit_code=$?

if [ "$exit_code" -eq 0 ]; then
  pass "AC5a: phase-set TERMINAL:VERIFY-FAILED exits 0 on valid fixture"
else
  fail "AC5a: phase-set TERMINAL:VERIFY-FAILED exited $exit_code (expected 0); stderr: $(cat "${TEST_DIR}/stderr.txt" 2>/dev/null || true)"
fi

PHASE_FILE="${TEST_DIR}/.autoflow-state/self/33/phase"
if [ -f "$PHASE_FILE" ] && [ "$(cat "$PHASE_FILE")" = "TERMINAL:VERIFY-FAILED" ]; then
  pass "AC5b: phase file equals 'TERMINAL:VERIFY-FAILED'"
else
  actual=$(cat "$PHASE_FILE" 2>/dev/null || echo "<missing>")
  fail "AC5b: phase file content is '$actual' (expected 'TERMINAL:VERIFY-FAILED')"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# AC 6: Hook (PreToolUse Write) targeting the phase file with phase=VERIFY
# but missing detailed-failure-analysis.md must exit 2 with stderr mentioning
# 'detailed-failure-analysis'. We invoke the hook directly with a JSON
# payload simulating the phase-set write attempt; the AUTOFLOW_PHASE_SET=1
# sentinel is set so the existing direct-write block does NOT swallow the
# event — the new TERMINAL:VERIFY-FAILED guard must take over.
# ===========================================================================
echo "--- AC 6: hook blocks TERMINAL:VERIFY-FAILED transition without artifact ---"
setup_test_dir
mkdir -p "${TEST_DIR}/.autoflow-state/self/33"
echo "self/33" > "${TEST_DIR}/.autoflow-state/current-issue"
echo "VERIFY" > "${TEST_DIR}/.autoflow-state/self/33/phase"
# Deliberately do NOT write detailed-failure-analysis.md.

PAYLOAD_AC6=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/.autoflow-state/self/33/phase","content":"TERMINAL:VERIFY-FAILED\n"}}' "$TEST_DIR")

exit_code=0
printf '%s' "$PAYLOAD_AC6" \
  | AUTOFLOW_PHASE_SET=1 CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
  || exit_code=$?

if [ "$exit_code" -eq 2 ]; then
  pass "AC6a: hook exits 2 when TERMINAL:VERIFY-FAILED requested without artifact"
else
  fail "AC6a: hook exited $exit_code (expected 2); stderr: $(cat "${TEST_DIR}/hook.err" 2>/dev/null || true)"
fi

if grep -q "detailed-failure-analysis" "${TEST_DIR}/hook.err" 2>/dev/null \
    || grep -q "detailed-failure-analysis" "${TEST_DIR}/hook.out" 2>/dev/null; then
  pass "AC6b: hook output mentions 'detailed-failure-analysis'"
else
  fail "AC6b: hook output does not mention 'detailed-failure-analysis'"
fi
cleanup_test_dir
echo ""

# ===========================================================================
# AC 7: '[role:forensic-recorder]' must appear in BOTH
# docs/design-rationale.md AND docs/evaluation-system.md.
# Use grep -F (literal) so the brackets are not regex-interpreted.
# ===========================================================================
echo "--- AC 7: '[role:forensic-recorder]' must appear in design-rationale + evaluation-system ---"
for f in "$DESIGN_RATIONALE" "$EVAL_SYSTEM"; do
  if [ ! -f "$f" ]; then
    fail "AC7: file not found: $f"
    continue
  fi
  if grep -F -q "[role:forensic-recorder]" "$f"; then
    pass "AC7: $(basename "$f") contains '[role:forensic-recorder]'"
  else
    fail "AC7: $(basename "$f") missing '[role:forensic-recorder]'"
  fi
done
echo ""

# ===========================================================================
# AC 8: design-rationale.md has '### Decision 11' header AND the section
# between '### Decision 11' and the next '### ' contains the literal phrase
# 'Auto-Flow cannot solve everything' (case-sensitive).
# ===========================================================================
echo "--- AC 8: design-rationale.md '### Decision 11' section contains the rationale phrase ---"
if [ ! -f "$DESIGN_RATIONALE" ]; then
  fail "AC8: design-rationale.md not found"
else
  if grep -Eq "^### Decision 11" "$DESIGN_RATIONALE"; then
    pass "AC8a: '### Decision 11' header found"
  else
    fail "AC8a: '### Decision 11' header missing"
  fi

  decision_11_body=$(awk '
    /^### Decision 11/ { in_section = 1; print; next }
    in_section && /^### / { in_section = 0 }
    in_section { print }
  ' "$DESIGN_RATIONALE")

  if printf '%s' "$decision_11_body" | grep -F -q "Auto-Flow cannot solve everything"; then
    pass "AC8b: Decision 11 section contains 'Auto-Flow cannot solve everything'"
  else
    fail "AC8b: Decision 11 section missing 'Auto-Flow cannot solve everything'"
  fi
fi
echo ""

# ===========================================================================
# AC 9: design-rationale.md must NO LONGER contain
#   'dispute arbitration trigger' (Signal 2 row replaced)
#   'evaluator as referee' (Decision 9 narrative updated)
# ===========================================================================
echo "--- AC 9: design-rationale.md must remove deprecated phrases ---"
if [ ! -f "$DESIGN_RATIONALE" ]; then
  fail "AC9: design-rationale.md not found"
else
  for phrase in "dispute arbitration trigger" "evaluator as referee"; do
    if grep -F -q "$phrase" "$DESIGN_RATIONALE"; then
      fail "AC9: design-rationale.md still contains '$phrase'"
    else
      pass "AC9: design-rationale.md no longer contains '$phrase'"
    fi
  done
fi
echo ""

# ===========================================================================
# AC 10: pre-existing tests/test-phase-set.sh exits 0 with the new
# VALID_PHASES list. We run it via bash from REPO_ROOT.
# ===========================================================================
echo "--- AC 10: tests/test-phase-set.sh still exits 0 ---"
if [ ! -f "$TEST_PHASE_SET" ]; then
  fail "AC10: tests/test-phase-set.sh not found"
else
  exit_code=0
  ( cd "$REPO_ROOT" && bash "$TEST_PHASE_SET" ) \
    > /tmp/test-issue-33-phase-set.out 2>&1 \
    || exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    pass "AC10: tests/test-phase-set.sh exits 0 (no regression)"
  else
    fail "AC10: tests/test-phase-set.sh exited $exit_code (output saved to /tmp/test-issue-33-phase-set.out)"
  fi
fi
echo ""

# ===========================================================================
# AC 11: pre-existing tests/test-hook-role-marker.sh exits 0 (existing
# evaluator.role_marker enforcement on evaluation.json paths is unchanged).
# ===========================================================================
echo "--- AC 11: tests/test-hook-role-marker.sh still exits 0 ---"
if [ ! -f "$TEST_HOOK_ROLE_MARKER" ]; then
  fail "AC11: tests/test-hook-role-marker.sh not found"
else
  exit_code=0
  ( cd "$REPO_ROOT" && bash "$TEST_HOOK_ROLE_MARKER" ) \
    > /tmp/test-issue-33-role-marker.out 2>&1 \
    || exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    pass "AC11: tests/test-hook-role-marker.sh exits 0 (no regression)"
  else
    fail "AC11: tests/test-hook-role-marker.sh exited $exit_code (output saved to /tmp/test-issue-33-role-marker.out)"
  fi
fi
echo ""

# ===========================================================================
# AC 12: PreToolUse Write payload targeting
# .autoflow-state/<sub>/<n>/detailed-failure-analysis.md is allowed by the
# hook (exit 0) WITHOUT requiring an evaluator.role_marker field. The
# payload body deliberately omits role_marker; the hook MUST treat the
# artifact class as exempt (markdown, not evaluation JSON).
#
# Two-part assertion:
#  AC12a: behavior — the hook exits 0 on the Write payload.
#  AC12b: source-level evidence — check_detailed_failure_artifact helper
#         (added by plan §"Files changed") exists in the hook AND its
#         comment-block (per delegation.md "GATE:PLAN evaluator addenda"
#         item 3) explicitly states why role_marker enforcement is
#         intentionally skipped for this artifact. AC12b is the new-content
#         specific assertion that fails against the current repo.
# ===========================================================================
echo "--- AC 12: hook allows Write to detailed-failure-analysis.md without role_marker ---"
setup_test_dir
PAYLOAD_AC12=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/tmp/x/.autoflow-state/self/33/detailed-failure-analysis.md","content":"## Pattern Classification\\nself-reinterpretation\\n"}}')
exit_code=0
printf '%s' "$PAYLOAD_AC12" \
  | env -u AUTOFLOW_PHASE_SET CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK" \
    > "${TEST_DIR}/hook.out" 2> "${TEST_DIR}/hook.err" \
  || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  pass "AC12a: hook exits 0 for Write to detailed-failure-analysis.md (no role_marker needed)"
else
  fail "AC12a: hook exited $exit_code for Write to detailed-failure-analysis.md (expected 0); stderr: $(cat "${TEST_DIR}/hook.err" 2>/dev/null || true)"
fi
cleanup_test_dir

# AC12b: source-level evidence. The hook MUST contain a helper called
# `check_detailed_failure_artifact` AND a comment near it explaining that
# role_marker enforcement is intentionally skipped for this artifact.
if [ ! -f "$HOOK" ]; then
  fail "AC12b: check-autoflow-gate.sh not found"
else
  if grep -F -q "check_detailed_failure_artifact" "$HOOK"; then
    helper_block=$(awk '
      /check_detailed_failure_artifact/ { in_block = 1 }
      in_block { print; lines++ }
      in_block && lines > 80 { exit }
    ' "$HOOK")
    if printf '%s' "$helper_block" | grep -F -q "role_marker"; then
      pass "AC12b: check_detailed_failure_artifact helper documents role_marker exclusion"
    else
      fail "AC12b: check_detailed_failure_artifact helper missing role_marker exclusion comment"
    fi
  else
    fail "AC12b: check_detailed_failure_artifact helper not present in check-autoflow-gate.sh"
  fi
fi
echo ""

# ===========================================================================
# AC 15: design-rationale.md must contain the literal phrase
# 'no new verdict enumeration' (Decision 11 explicitly states the
# out-of-scope items).
# ===========================================================================
echo "--- AC 15: design-rationale.md must contain 'no new verdict enumeration' ---"
if [ ! -f "$DESIGN_RATIONALE" ]; then
  fail "AC15: design-rationale.md not found"
else
  if grep -F -q "no new verdict enumeration" "$DESIGN_RATIONALE"; then
    pass "AC15: design-rationale.md contains 'no new verdict enumeration'"
  else
    fail "AC15: design-rationale.md missing 'no new verdict enumeration'"
  fi
fi
echo ""

# ===========================================================================
# AC 16: 'TERMINAL:VERIFY-FAILED' must appear in check-autoflow-gate.sh
# inside the `case "$phase"` switch (not just in a comment elsewhere).
# Approach: extract the lines starting at the `case "$phase"` opener up to
# the matching `esac`, then grep for the token in that slice.
# ===========================================================================
echo "--- AC 16: check-autoflow-gate.sh case \"\$phase\" switch contains 'TERMINAL:VERIFY-FAILED' ---"
if [ ! -f "$HOOK" ]; then
  fail "AC16: check-autoflow-gate.sh not found"
else
  # Extract the block from the line containing `case "$phase"` to the next
  # standalone `esac`. POSIX awk; no GNU extensions.
  case_phase_block=$(awk '
    /case[[:space:]]*"\$phase"/ { in_block = 1; print; next }
    in_block { print }
    in_block && /^[[:space:]]*esac[[:space:]]*$/ { in_block = 0; exit }
  ' "$HOOK")

  if [ -z "$case_phase_block" ]; then
    fail "AC16: could not locate 'case \"\$phase\"' block in check-autoflow-gate.sh"
  else
    if printf '%s' "$case_phase_block" | grep -F -q "TERMINAL:VERIFY-FAILED"; then
      pass "AC16: 'TERMINAL:VERIFY-FAILED' appears inside the case \"\$phase\" switch"
    else
      fail "AC16: 'TERMINAL:VERIFY-FAILED' not found inside the case \"\$phase\" switch"
    fi
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

# =============================================================================
# Manual verification checklist (NOT automated — covers plan.md ACs 13, 14)
# =============================================================================
# Per delegation.md "GATE:PLAN evaluator addenda" item 2, each worked example
# in docs/autoflow-guide.md MUST follow this exact heading layout so the
# manual check is mechanical:
#
#   ### Worked Example — Pattern <A|B>: <one-line title>
#   #### Setup
#   #### Trigger event
#   #### Forensic artifact (excerpt of detailed-failure-analysis.md)
#   #### Out-of-band resolution
#
# Manual checks:
#
#   [ ] AC 13: docs/autoflow-guide.md, inside the new TERMINAL:VERIFY-FAILED
#       section, contains a `### Worked Example — Pattern A: <title>` block
#       that follows the four-#### sub-heading layout above. The
#       "Forensic artifact" sub-section excerpt must show all four required
#       artifact section headers (## Pattern Classification, ## Triggering
#       Message, ## Failing Test Output, ## RED Decision Basis).
#
#   [ ] AC 14: docs/autoflow-guide.md, in the same section, contains a
#       `### Worked Example — Pattern B: <title>` block following the same
#       four-#### sub-heading layout. The scenario shows BOTH teammates
#       emitting "no problem on my side" after round-trip 1, and the
#       forensic-recorder path executing (NOT the removed Evaluator
#       arbitration).
# =============================================================================
