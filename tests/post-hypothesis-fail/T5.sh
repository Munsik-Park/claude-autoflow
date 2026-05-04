#!/usr/bin/env bash
# =============================================================================
# T5 — Two FAIL runs in rapid succession produce two distinct archive dirs
#       (AC-S4 + AC-S5 tightening: nanosecond / fallback uniqueness)
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
trap 'teardown_fixture' EXIT

ID="T5"
setup_fixture

# --- run 1 ---
write_eval_json self 2001 FAIL
set_current_issue self 2001
OUT1=$(run_helper 2>&1); RC1=$?
if [ "$RC1" -ne 0 ]; then
  fail "$ID" "first run exited $RC1; output: $OUT1"
fi

# --- run 2: re-create the same issue dir + current-issue, run again immediately ---
write_eval_json self 2001 FAIL
set_current_issue self 2001
OUT2=$(run_helper 2>&1); RC2=$?
if [ "$RC2" -ne 0 ]; then
  fail "$ID" "second run exited $RC2; output: $OUT2"
fi

# Two distinct archive directories with prefix 2001- must exist.
ARCHIVES=$(ls "${TMP_ROOT}/.autoflow-state/archive/self/" 2>/dev/null | grep -c '^2001-' || true)
if [ "${ARCHIVES:-0}" -lt 2 ]; then
  ls -la "${TMP_ROOT}/.autoflow-state/archive/self/" >&2 || true
  fail "$ID" "expected 2+ archive dirs prefixed 2001-, got ${ARCHIVES:-0}"
fi

pass "$ID" "two FAIL runs in same second produce distinct archive dirs"
