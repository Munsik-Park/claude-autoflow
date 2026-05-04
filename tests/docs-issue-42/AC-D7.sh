#!/usr/bin/env bash
# =============================================================================
# AC-D7 — docs/gate-hypothesis-fail-comment.md exists, is non-empty, contains
#   placeholder tokens for issue number, scores, rationale, and links, and
#   includes a worked example block.
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
ID="AC-D7"

if [ ! -f "$COMMENT_TEMPLATE" ]; then
  fail "$ID" "$COMMENT_TEMPLATE does not exist"
fi
if [ ! -s "$COMMENT_TEMPLATE" ]; then
  fail "$ID" "$COMMENT_TEMPLATE is empty"
fi

# Placeholder tokens — at least one form per concept must appear. The
# canonical convention is `{{...}}` (mustache-style) per CLAUDE.md.template.
need_placeholder() {
  local concept="$1"; shift
  for p in "$@"; do
    if grep -qF -- "$p" "$COMMENT_TEMPLATE"; then
      return 0
    fi
  done
  fail "$ID" "no placeholder for ${concept} (looked for: $*)"
}

need_placeholder 'issue number'  '{{ISSUE_NUMBER}}'  '{{issue_number}}'  '{{ISSUE}}'
need_placeholder 'scores'        '{{SCORES}}'        '{{scores}}'        '{{SCORES_TABLE}}'
need_placeholder 'rationale'     '{{RATIONALE}}'     '{{rationale}}'
need_placeholder 'analysis link' '{{ANALYSIS_LINK}}' '{{analysis_link}}' 'analysis/phase-3.md'

# Worked example block: convention is a heading line (## / ### or bold) that
# contains the word "example" (case-insensitive).
if ! grep -qiE '^(#{1,4} .*example|\*\*.*example.*\*\*)' "$COMMENT_TEMPLATE"; then
  fail "$ID" "no worked example heading found"
fi

pass "$ID"
