#!/usr/bin/env bash
# =============================================================================
# AC-D5 — docs/autoflow-guide.md GATE:HYPOTHESIS section body:
#   - no longer contains the imperative "Close the issue."
#   - contains "post evaluation comment"
#   - contains "archive local state"
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
ID="AC-D5"

if [ ! -f "$GUIDE" ]; then
  fail "$ID" "$GUIDE not found"
fi

# Extract from "## GATE:HYPOTHESIS" header up to the next "## " header.
section=$(awk '/^## GATE:HYPOTHESIS/{flag=1;next} /^## /{if(flag){flag=0}} flag' "$GUIDE")
if [ -z "$section" ]; then
  fail "$ID" "GATE:HYPOTHESIS section not found in $GUIDE"
fi

if printf '%s' "$section" | grep -qF 'Close the issue.'; then
  fail "$ID" "GATE:HYPOTHESIS section still contains imperative 'Close the issue.'"
fi

if ! printf '%s' "$section" | grep -qF 'post evaluation comment'; then
  fail "$ID" "GATE:HYPOTHESIS section missing 'post evaluation comment'"
fi

if ! printf '%s' "$section" | grep -qF 'archive local state'; then
  fail "$ID" "GATE:HYPOTHESIS section missing 'archive local state'"
fi

pass "$ID"
