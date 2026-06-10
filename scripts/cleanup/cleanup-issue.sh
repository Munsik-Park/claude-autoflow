#!/usr/bin/env bash
# scripts/cleanup/cleanup-issue.sh
#
# AutoFlow Post-Merge Cleanup helper — removes a resolved issue's
# `.autoflow/issue-<N>.*` + `.autoflow/issue-<N>-*` management files (state
# JSON, decision ledger, design docs, phase/eval reports). Run at PREFLIGHT
# prior-cycle resolution once the issue's PR is observed merged or closed (see
# docs/git-workflow.md > Post-Merge Cleanup).
#
# WHY A SCRIPT (not a bare `rm`): the cleanup is invoked by PATH
# (`scripts/cleanup/cleanup-issue.sh <N>`), so the Bash command carries no `rm`
# token. Claude Code permission precedence is deny > allow, so an `rm`
# allow-exception (e.g. `Bash(rm -f .autoflow/issue-*)`) CANNOT override a broad
# `rm` deny (e.g. `Bash(rm:*)`) — the deny always wins. A non-`rm` wrapper is
# never matched by an rm deny, so this lets a broad rm deny coexist with
# AutoFlow cleanup. Internally it uses `find -delete` (no `rm` at all), scoped
# to `.autoflow/` (maxdepth 1).
#
# NUMBER-BOUNDARY MATCH: the issue's files are `issue-<N>.json` (state) and
# `issue-<N>-*` (companions) — i.e. the char after <N> is always `.` or `-`,
# never a digit. Matching `\( -name "issue-${N}.*" -o -name "issue-${N}-*" \)`
# (NOT a bare `issue-${N}*` glob) deletes only issue <N> and never a
# prefix-collision sibling — `12` must not match `123`/`120` (review finding).
# The digits-only guard on N additionally blocks globs / path traversal / slashes.
#
# Allow-list (so it never prompts even when rm is denied):
#   "Bash(./scripts/cleanup/cleanup-issue.sh:*)"   (or the no-`./` form you invoke)
#
# Usage: scripts/cleanup/cleanup-issue.sh <issue-number> [<issue-number> ...]
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <issue-number> [<issue-number> ...]" >&2
  exit 64
fi

ROOT="$(git rev-parse --show-toplevel)"
AUTOFLOW_DIR="$ROOT/.autoflow"

if [ ! -d "$AUTOFLOW_DIR" ]; then
  echo "no .autoflow/ directory at $ROOT — nothing to clean"
  exit 0
fi

status=0
for N in "$@"; do
  # Guard: issue number must be digits only — blocks globs, path traversal, slashes.
  case "$N" in
    '' | *[!0-9]*)
      echo "refuse: issue number must be digits only, got '$N'" >&2
      status=64
      continue
      ;;
  esac

  # Number-boundary match: `issue-<N>.*` (state json) OR `issue-<N>-*` (companions).
  # A bare `issue-<N>*` would also match `issue-<N>3` etc. — see review finding.
  matches="$(find "$AUTOFLOW_DIR" -maxdepth 1 -type f \( -name "issue-${N}.*" -o -name "issue-${N}-*" \) 2>/dev/null || true)"
  if [ -z "$matches" ]; then
    echo "issue #${N}: no .autoflow/issue-${N}.* or issue-${N}-* files — already clean"
    continue
  fi
  count="$(printf '%s\n' "$matches" | grep -c .)"
  # Scoped, number-boundary deletion within .autoflow/ only (find -delete, no rm).
  find "$AUTOFLOW_DIR" -maxdepth 1 -type f \( -name "issue-${N}.*" -o -name "issue-${N}-*" \) -delete
  echo "issue #${N}: removed ${count} .autoflow/issue-${N}.*/-* file(s)"
done

exit "$status"
