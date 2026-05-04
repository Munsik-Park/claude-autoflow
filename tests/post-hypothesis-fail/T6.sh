#!/usr/bin/env bash
# =============================================================================
# T6 — --dry-run produces output but performs no filesystem mutation
#       Note: AC-S5 in the original plan (dry-run) is the DRY-RUN test;
#             the AC-S5 tightening renamed AC-S5 to the archive-uniqueness AC.
#             Per delegation §AC tightenings, the archive-uniqueness check is
#             still labeled AC-S5; the dry-run AC stays in the suite under T6.
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
trap 'teardown_fixture' EXIT

ID="T6"
setup_fixture

write_eval_json self 3001 FAIL
set_current_issue self 3001

OUT=$(run_helper --dry-run 2>&1); RC=$?

if [ "$RC" -ne 0 ]; then
  fail "$ID" "expected exit 0 from --dry-run, got $RC; output: $OUT"
fi

# No gh body file should have been written.
if [ -s "${GH_STUB_BODY_FILE}" ]; then
  fail "$ID" "gh stub captured a body during --dry-run"
fi

# State must be unchanged.
if [ ! -d "${TMP_ROOT}/.autoflow-state/self/3001" ]; then
  fail "$ID" "active issue dir was moved despite --dry-run"
fi
if [ -d "${TMP_ROOT}/.autoflow-state/archive/self/" ] \
    && ls "${TMP_ROOT}/.autoflow-state/archive/self/" 2>/dev/null | grep -q '^3001-'; then
  fail "$ID" "archive dir was created despite --dry-run"
fi
if [ ! -s "${TMP_ROOT}/.autoflow-state/current-issue" ]; then
  fail "$ID" "current-issue was truncated despite --dry-run"
fi

# Output should mention the rendered comment text or target archive path.
if ! printf '%s' "$OUT" | grep -qE 'archive|comment|dry'; then
  fail "$ID" "--dry-run output did not mention archive/comment/dry; got: $OUT"
fi

pass "$ID" "--dry-run produces output without filesystem mutation"
