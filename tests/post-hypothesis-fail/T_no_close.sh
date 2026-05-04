#!/usr/bin/env bash
# =============================================================================
# T_no_close — AC-S8: helper must NEVER call `gh issue close`.
#   `grep -F 'gh issue close' .claude/scripts/post-hypothesis-fail`
#   must return zero matches.
# =============================================================================

set -u
ID="T_no_close"
HELPER="$(cd "$(dirname "$0")/../.." && pwd)/.claude/scripts/post-hypothesis-fail"

if [ ! -f "$HELPER" ]; then
  echo "FAIL: ${ID} — helper not present (cannot grep)"
  exit 1
fi

if grep -F 'gh issue close' "$HELPER" >/dev/null 2>&1; then
  echo "FAIL: ${ID} — helper contains 'gh issue close'"
  exit 1
fi

echo "PASS: ${ID}"
exit 0
