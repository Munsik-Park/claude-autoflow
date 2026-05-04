#!/usr/bin/env bash
# =============================================================================
# AC-D1 — CLAUDE.md Flow Control row for GATE:HYPOTHESIS FAIL must contain
#         "Comment posted + Auto-Flow terminated locally" and must NOT contain
#         "Issue closed" as the next state.
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
ID="AC-D1"

if [ ! -f "$CLAUDE_MD" ]; then
  fail "$ID" "$CLAUDE_MD not found"
fi

# The Flow Control table starts at "## Flow Control" and ends before the
# "### Regression Rules" header.
section=$(awk '/^## Flow Control[[:space:]]*$/{flag=1;next} /^### Regression Rules/{flag=0} flag' "$CLAUDE_MD")

# Locate the row whose first column contains "GATE:HYPOTHESIS FAIL".
row=$(printf '%s\n' "$section" | grep -F 'GATE:HYPOTHESIS FAIL' || true)
if [ -z "$row" ]; then
  fail "$ID" "no row matching 'GATE:HYPOTHESIS FAIL' in Flow Control"
fi

if ! printf '%s' "$row" | grep -qF 'Comment posted + Auto-Flow terminated locally'; then
  fail "$ID" "row missing literal 'Comment posted + Auto-Flow terminated locally'; row: $row"
fi

# Must not contain "Issue closed" as the third column entry.
if printf '%s' "$row" | grep -qF 'Issue closed'; then
  fail "$ID" "row still contains 'Issue closed'; row: $row"
fi

pass "$ID"
