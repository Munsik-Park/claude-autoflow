#!/usr/bin/env bash
# =============================================================================
# T10 — Preflight `gh auth status`. If gh is missing/unauthenticated, helper
#        exits 66 with stderr `post-hypothesis-fail: gh CLI missing or
#        unauthenticated`. (Tightened AC-S10.)
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
trap 'teardown_fixture' EXIT

ID="T10"
setup_fixture

write_eval_json self 6001 FAIL
set_current_issue self 6001

# --- Case 1: gh is missing entirely (PATH stripped of stub). ---
SAVED_PATH="$PATH"
export PATH="/usr/bin:/bin"
STDERR_FILE_1="${TMP_ROOT}/stderr1.txt"
"$HELPER" 2>"$STDERR_FILE_1" >/dev/null
RC1=$?
export PATH="$SAVED_PATH"

if [ "$RC1" -ne 66 ]; then
  fail "$ID" "Case1: expected exit 66 when gh missing, got $RC1; stderr: $(cat "$STDERR_FILE_1")"
fi
if ! grep -qF 'post-hypothesis-fail: gh CLI missing or unauthenticated' "$STDERR_FILE_1"; then
  fail "$ID" "Case1: stderr missing canonical message; got: $(cat "$STDERR_FILE_1")"
fi

# --- Case 2: gh present but `gh auth status` exits non-zero. ---
export GH_STUB_AUTH_EXIT=1
STDERR_FILE_2="${TMP_ROOT}/stderr2.txt"
"$HELPER" 2>"$STDERR_FILE_2" >/dev/null
RC2=$?

if [ "$RC2" -ne 66 ]; then
  fail "$ID" "Case2: expected exit 66 when gh auth fails, got $RC2; stderr: $(cat "$STDERR_FILE_2")"
fi
if ! grep -qF 'post-hypothesis-fail: gh CLI missing or unauthenticated' "$STDERR_FILE_2"; then
  fail "$ID" "Case2: stderr missing canonical message; got: $(cat "$STDERR_FILE_2")"
fi

pass "$ID" "missing gh OR unauth → exit 66 with canonical message"
