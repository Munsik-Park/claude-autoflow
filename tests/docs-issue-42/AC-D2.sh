#!/usr/bin/env bash
# =============================================================================
# AC-D2 — CLAUDE.md Regression Rules row for GATE:HYPOTHESIS FAIL has
#         Max Retries 0, Escalation does NOT contain "Issue closed (by design)".
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
ID="AC-D2"

if [ ! -f "$CLAUDE_MD" ]; then
  fail "$ID" "$CLAUDE_MD not found"
fi

section=$(awk '/^### Regression Rules[[:space:]]*$/{flag=1;next} /^## /{if(flag){flag=0}} flag' "$CLAUDE_MD")

row=$(printf '%s\n' "$section" | grep -F 'GATE:HYPOTHESIS FAIL' || true)
if [ -z "$row" ]; then
  fail "$ID" "no row matching 'GATE:HYPOTHESIS FAIL' in Regression Rules"
fi

# Pipe-split the row, Max Retries is column 3.
retries=$(printf '%s' "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
if [ "$retries" != "0" ]; then
  fail "$ID" "Max Retries column is '$retries', expected '0'; row: $row"
fi

if printf '%s' "$row" | grep -qF 'Issue closed (by design)'; then
  fail "$ID" "Escalation still contains 'Issue closed (by design)'; row: $row"
fi

pass "$ID"
