#!/usr/bin/env bash
# =============================================================================
# runner.sh — execute every T*.sh in this directory and report aggregate.
# Exit 0 if all PASS, non-zero if any FAIL.
# =============================================================================

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

PASS=0
FAIL=0
FAILED_TESTS=()

for f in T*.sh; do
  [ -f "$f" ] || continue
  if bash "$f"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$f")
  fi
done

echo ""
echo "=== post-hypothesis-fail summary ==="
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"
if [ "${#FAILED_TESTS[@]}" -gt 0 ]; then
  for t in "${FAILED_TESTS[@]}"; do
    echo "  - ${t}"
  done
fi

[ "$FAIL" -eq 0 ]
