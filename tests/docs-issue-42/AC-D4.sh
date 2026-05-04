#!/usr/bin/env bash
# =============================================================================
# AC-D4 — CLAUDE.md.template mirrors CLAUDE.md on the same changed regions.
#   Verifiable by grep -F on the new key phrases in BOTH files.
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
ID="AC-D4"

if [ ! -f "$CLAUDE_TEMPLATE" ]; then
  fail "$ID" "$CLAUDE_TEMPLATE not found"
fi

# Phrases that must appear in BOTH files. These mirror the new wording the
# orchestrator put into CLAUDE.md; the template must match.
PHRASES=(
  'Comment posted + Auto-Flow terminated locally'
  'Comment posted + local termination + human disposition'
  'evaluation observation, not disposition'
)

for p in "${PHRASES[@]}"; do
  if ! grep -qF -- "$p" "$CLAUDE_TEMPLATE"; then
    fail "$ID" "CLAUDE.md.template missing key phrase: '$p'"
  fi
  if ! grep -qF -- "$p" "$CLAUDE_MD"; then
    fail "$ID" "CLAUDE.md missing key phrase '$p' (host file regression)"
  fi
done

# Phrases that must be GONE from the template's GATE:HYPOTHESIS-related rows.
# Approximate by ensuring the legacy "Issue closed (by design)" line is absent.
if grep -qF 'Issue closed (by design)' "$CLAUDE_TEMPLATE"; then
  fail "$ID" "CLAUDE.md.template still contains legacy 'Issue closed (by design)' Escalation"
fi

pass "$ID"
