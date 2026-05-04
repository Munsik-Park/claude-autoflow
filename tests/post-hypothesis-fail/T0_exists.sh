#!/usr/bin/env bash
# =============================================================================
# T0_exists — AC-S1: helper script exists and is executable.
# =============================================================================

set -u
ID="T0_exists"
HELPER="$(cd "$(dirname "$0")/../.." && pwd)/.claude/scripts/post-hypothesis-fail"

if [ ! -f "$HELPER" ]; then
  echo "FAIL: ${ID} — helper script not found at ${HELPER}"
  exit 1
fi
if [ ! -x "$HELPER" ]; then
  echo "FAIL: ${ID} — helper script not executable: ${HELPER}"
  exit 1
fi

echo "PASS: ${ID}"
exit 0
