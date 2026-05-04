#!/usr/bin/env bash
# =============================================================================
# T1 — Happy path (AC-S2):
#   Given a FAIL evaluation JSON with role_marker [role:eval-hypothesis] and a
#   gh stub returning 0, the helper:
#     - posts a comment via `gh issue comment`
#     - moves state to `.autoflow-state/archive/<subrepo>/<issue>-<ts>/`
#     - clears `current-issue`
#     - exits 0
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
trap 'teardown_fixture' EXIT

ID="T1"
setup_fixture

write_eval_json self 999 FAIL
set_current_issue self 999

OUT=$(run_helper 2>&1); RC=$?

if [ "$RC" -ne 0 ]; then
  fail "$ID" "expected exit 0, got $RC; output: $OUT"
fi

# 1. comment was posted via the stub
if [ ! -s "${GH_STUB_BODY_FILE}" ]; then
  fail "$ID" "gh stub did not capture a non-empty --body-file"
fi

# 2. active issue dir is gone
if [ -d "${TMP_ROOT}/.autoflow-state/self/999" ]; then
  fail "$ID" "active issue dir was not moved out of the state tree"
fi

# 3. archive dir exists with a 999-<ts> child
if ! ls "${TMP_ROOT}/.autoflow-state/archive/self/" 2>/dev/null | grep -q '^999-'; then
  fail "$ID" "no archive dir matching 999-<ts> under archive/self/"
fi

# 4. current-issue file is empty (truncated) or missing
if [ -s "${TMP_ROOT}/.autoflow-state/current-issue" ]; then
  fail "$ID" "current-issue was not truncated"
fi

pass "$ID" "happy path posts comment, archives state, clears current-issue"
