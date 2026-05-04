#!/usr/bin/env bash
# =============================================================================
# T4 — gh stub returns non-zero on `issue comment` → exit 67, state preserved
# (AC-S3 part 3)
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
trap 'teardown_fixture' EXIT

ID="T4"
setup_fixture

write_eval_json self 1003 FAIL
set_current_issue self 1003

# auth status must succeed (default), but issue comment must fail.
export GH_STUB_EXIT=1
export GH_STUB_AUTH_EXIT=0

OUT=$(run_helper 2>&1); RC=$?

if [ "$RC" -ne 67 ]; then
  fail "$ID" "expected exit 67 on gh comment failure, got $RC; output: $OUT"
fi

# Active issue dir must remain.
if [ ! -d "${TMP_ROOT}/.autoflow-state/self/1003" ]; then
  fail "$ID" "active issue dir was destroyed despite gh comment failure"
fi

# Archive must NOT exist for this issue.
if [ -d "${TMP_ROOT}/.autoflow-state/archive/self/" ] \
    && ls "${TMP_ROOT}/.autoflow-state/archive/self/" 2>/dev/null | grep -q '^1003-'; then
  fail "$ID" "archive was created despite comment-post failure"
fi

# current-issue must remain populated.
if [ ! -s "${TMP_ROOT}/.autoflow-state/current-issue" ]; then
  fail "$ID" "current-issue was truncated despite comment-post failure"
fi

pass "$ID" "gh comment failure → exit 67 with state preserved"
