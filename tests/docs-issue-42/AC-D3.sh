#!/usr/bin/env bash
# =============================================================================
# AC-D3 — CLAUDE.md DIAGNOSE > Phase 3 FAIL clause:
#   - contains "post evaluation comment"
#   - contains a forbidding statement about `gh issue close` (literal "forbidden")
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
ID="AC-D3"

if [ ! -f "$CLAUDE_MD" ]; then
  fail "$ID" "$CLAUDE_MD not found"
fi

section=$(awk '/^### Phase 3: Cross-Verification/{flag=1;next} /^## /{if(flag){flag=0}} flag' "$CLAUDE_MD")

fail_clause=$(printf '%s\n' "$section" | grep -F '**FAIL**' || true)
if [ -z "$fail_clause" ]; then
  fail "$ID" "no FAIL clause found in Phase 3 section"
fi

# Accept either the literal 'post evaluation comment' (plan wording) or the
# orchestrator's expanded 'posts ... evaluation comment' phrasing — both
# encode the same prescription. Match: post(s|ing)? <up to 30 chars> evaluation comment.
if ! printf '%s' "$fail_clause" | grep -Eq 'post(s|ing)?[^.]{0,30}evaluation comment'; then
  fail "$ID" "FAIL clause missing 'post(s)...evaluation comment' phrasing; clause: $fail_clause"
fi

if ! printf '%s' "$fail_clause" | grep -qiF 'forbidden'; then
  fail "$ID" "FAIL clause missing forbidding statement (literal 'forbidden'); clause: $fail_clause"
fi

pass "$ID"
