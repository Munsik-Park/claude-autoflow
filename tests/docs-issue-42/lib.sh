#!/usr/bin/env bash
# =============================================================================
# lib.sh — shared helpers for docs-issue-42 grep tests.
# =============================================================================

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
CLAUDE_TEMPLATE="${REPO_ROOT}/CLAUDE.md.template"
GUIDE="${REPO_ROOT}/docs/autoflow-guide.md"
RATIONALE="${REPO_ROOT}/docs/design-rationale.md"
COMMENT_TEMPLATE="${REPO_ROOT}/docs/gate-hypothesis-fail-comment.md"
EVAL_SYS="${REPO_ROOT}/docs/evaluation-system.md"

pass() { echo "PASS: $1"; exit 0; }
fail() { echo "FAIL: $1 — $2"; exit 1; }

# extract_section <file> <header_regex_anchor_start> <header_regex_anchor_end>
# Prints lines starting at the line matching the start anchor up to (but not
# including) the line matching the end anchor.
extract_section() {
  local file="$1" start="$2" end="$3"
  awk -v start="$start" -v end="$end" '
    $0 ~ start { in_sec=1 }
    in_sec && $0 ~ end && NR > 1 {
      # Only end if the end-anchor line is *after* the start (skip if same line).
      if (matched_start) { exit }
    }
    in_sec { print; matched_start=1 }
  ' "$file"
}
