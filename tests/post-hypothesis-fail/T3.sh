#!/usr/bin/env bash
# =============================================================================
# T3 — role_marker missing/wrong → exit 65, no side effects (AC-S3 part 2)
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
trap 'teardown_fixture' EXIT

ID="T3"
setup_fixture

write_eval_json self 1002 FAIL "[role:eval-quality]"
set_current_issue self 1002

OUT=$(run_helper 2>&1); RC=$?

if [ "$RC" -ne 65 ]; then
  fail "$ID" "expected exit 65 for wrong role_marker, got $RC; output: $OUT"
fi

if [ -s "${GH_STUB_BODY_FILE}" ]; then
  fail "$ID" "gh stub captured a body but role_marker was wrong"
fi

if [ ! -d "${TMP_ROOT}/.autoflow-state/self/1002" ]; then
  fail "$ID" "active issue dir was destroyed despite exit 65"
fi

pass "$ID" "wrong role_marker → exit 65 with no state mutation"
