#!/usr/bin/env bash
# =============================================================================
# T7 — Missing current-issue → exit 65 (AC-S6)
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
trap 'teardown_fixture' EXIT

ID="T7"
setup_fixture

# No current-issue file at all.
rm -f "${TMP_ROOT}/.autoflow-state/current-issue"

OUT=$(run_helper 2>&1); RC=$?

if [ "$RC" -ne 65 ]; then
  fail "$ID" "expected exit 65 for missing current-issue, got $RC; output: $OUT"
fi

if [ -s "${GH_STUB_BODY_FILE}" ]; then
  fail "$ID" "gh stub captured a body despite missing current-issue"
fi

pass "$ID" "missing current-issue → exit 65"
