#!/usr/bin/env bash
# =============================================================================
# T2 — verdict != FAIL  → exit 65, no side effects (AC-S3 part 1)
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
trap 'teardown_fixture' EXIT

ID="T2"
setup_fixture

write_eval_json self 1001 PASS
set_current_issue self 1001

OUT=$(run_helper 2>&1); RC=$?

if [ "$RC" -ne 65 ]; then
  fail "$ID" "expected exit 65, got $RC; output: $OUT"
fi

# No comment should have been posted.
if [ -s "${GH_STUB_BODY_FILE}" ]; then
  fail "$ID" "gh stub captured a body but verdict was PASS"
fi

# Active issue dir must remain untouched.
if [ ! -d "${TMP_ROOT}/.autoflow-state/self/1001" ]; then
  fail "$ID" "active issue dir was destroyed despite exit 65"
fi

# Archive dir must NOT exist.
if [ -d "${TMP_ROOT}/.autoflow-state/archive/self/" ] \
    && ls "${TMP_ROOT}/.autoflow-state/archive/self/" 2>/dev/null | grep -q '^1001-'; then
  fail "$ID" "archive dir was created despite exit 65"
fi

# current-issue must remain populated.
if [ ! -s "${TMP_ROOT}/.autoflow-state/current-issue" ]; then
  fail "$ID" "current-issue was truncated despite exit 65"
fi

pass "$ID" "verdict != FAIL → exit 65 with no state mutation"
