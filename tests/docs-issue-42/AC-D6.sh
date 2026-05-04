#!/usr/bin/env bash
# =============================================================================
# AC-D6 (tightened) — docs/design-rationale.md Decision 6 body must contain
#   ALL THREE literal tokens, in any order:
#     - "evaluation observation"
#     - "disposition decision"
#     - "state action"
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
ID="AC-D6"

if [ ! -f "$RATIONALE" ]; then
  fail "$ID" "$RATIONALE not found"
fi

# Extract Decision 6 body: from a heading line containing "Decision 6"
# up to the next heading line containing "Decision 7" or end of file.
section=$(awk '
  /^#{1,4} .*Decision 6/{flag=1; print; next}
  /^#{1,4} .*Decision 7/{flag=0}
  flag' "$RATIONALE")

if [ -z "$section" ]; then
  fail "$ID" "Decision 6 section not found in $RATIONALE"
fi

for tok in 'evaluation observation' 'disposition decision' 'state action'; do
  if ! printf '%s' "$section" | grep -qF -- "$tok"; then
    fail "$ID" "Decision 6 missing literal token: '$tok'"
  fi
done

pass "$ID"
