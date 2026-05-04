#!/usr/bin/env bash
# =============================================================================
# T9 — On exit 68 (archive failed after comment posted), stderr must include:
#   (a) the literal source path of ${STATE_DIR}/<sub-repo-id>/<issue>/
#   (b) the literal target archive path the helper attempted
#   (c) a single `mv` recovery command the human can copy/paste
# (Tightened AC-S9.)
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
trap 'teardown_fixture' EXIT

ID="T9"
setup_fixture

write_eval_json self 5001 FAIL
set_current_issue self 5001

# Sabotage the archive step by making ${STATE_DIR}/archive non-writable.
mkdir -p "${TMP_ROOT}/.autoflow-state/archive"
chmod 0500 "${TMP_ROOT}/.autoflow-state/archive"

# Capture stderr separately so we can grep it.
STDERR_FILE="${TMP_ROOT}/stderr.txt"
"$HELPER" 2>"$STDERR_FILE" >/dev/null
RC=$?

# Restore perms before assertions so cleanup works.
chmod 0700 "${TMP_ROOT}/.autoflow-state/archive" 2>/dev/null || true

if [ "$RC" -ne 68 ]; then
  fail "$ID" "expected exit 68 on archive failure, got $RC; stderr: $(cat "$STDERR_FILE")"
fi

SRC_PATH="${TMP_ROOT}/.autoflow-state/self/5001"
TARGET_PARENT="${TMP_ROOT}/.autoflow-state/archive/self"

if ! grep -qF "$SRC_PATH" "$STDERR_FILE"; then
  fail "$ID" "stderr missing source path '$SRC_PATH'; got: $(cat "$STDERR_FILE")"
fi
if ! grep -qF "$TARGET_PARENT/5001-" "$STDERR_FILE"; then
  fail "$ID" "stderr missing target archive path under '$TARGET_PARENT/5001-...'; got: $(cat "$STDERR_FILE")"
fi
if ! grep -qE '(^|[[:space:]])mv[[:space:]]' "$STDERR_FILE"; then
  fail "$ID" "stderr missing recovery 'mv' command; got: $(cat "$STDERR_FILE")"
fi

pass "$ID" "exit 68 includes source path, target path, and mv recovery hint"
