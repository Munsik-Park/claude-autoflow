#!/usr/bin/env bash
# scripts/test/check-cleanup-issue-boundary.sh
#
# Regression test for the issue-number boundary in scripts/cleanup/cleanup-issue.sh.
# Guards the review finding: `cleanup-issue.sh 12` must delete only issue-12's
# files and MUST NOT touch a prefix-collision sibling (issue-123 / issue-120).
#
# Uses high, unlikely-to-collide test ids and tears them down via `find -delete`
# (no `rm`, so it is unaffected by a broad `rm` permission deny — same rationale
# as cleanup-issue.sh itself).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
AF="$ROOT/.autoflow"
CLEAN="$ROOT/scripts/cleanup/cleanup-issue.sh"

A=9990012      # target
B=99900123     # prefix-collision sibling (must survive)
C=99900120     # prefix-collision sibling (must survive)

teardown() {
  find "$AF" -maxdepth 1 -type f \
    \( -name "issue-${A}*" -o -name "issue-${B}*" -o -name "issue-${C}*" \) \
    -delete 2>/dev/null || true
}
trap teardown EXIT

mkdir -p "$AF"
: > "$AF/issue-${A}.json"
: > "$AF/issue-${A}-ledger.md"
: > "$AF/issue-${B}.json"
: > "$AF/issue-${B}-ledger.md"
: > "$AF/issue-${C}.json"

"$CLEAN" "$A" >/dev/null

fail=0
{ [ ! -e "$AF/issue-${A}.json" ] && [ ! -e "$AF/issue-${A}-ledger.md" ]; } \
  || { echo "FAIL: target issue-${A} files were not deleted" >&2; fail=1; }
{ [ -e "$AF/issue-${B}.json" ] && [ -e "$AF/issue-${B}-ledger.md" ] && [ -e "$AF/issue-${C}.json" ]; } \
  || { echo "FAIL: prefix-collision sibling (issue-${B} / issue-${C}) was wrongly deleted" >&2; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "PASS: number-boundary match — cleanup ${A} kept issue-${B} / issue-${C}"
else
  exit 1
fi
