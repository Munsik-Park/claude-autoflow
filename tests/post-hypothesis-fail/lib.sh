#!/usr/bin/env bash
# =============================================================================
# lib.sh — shared fixture helpers for post-hypothesis-fail tests (T1..T10).
# =============================================================================
# Each test sources this file, calls `setup_fixture`, runs the helper, asserts,
# and traps EXIT to call `teardown_fixture`.
# =============================================================================

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="${REPO_ROOT}/.claude/scripts/post-hypothesis-fail"
STUB_DIR="${REPO_ROOT}/tests/post-hypothesis-fail/stubs"

TMP_ROOT=""
ORIG_PATH=""
ORIG_CWD=""

setup_fixture() {
  TMP_ROOT=$(mktemp -d 2>/dev/null || mktemp -d -t 'phf-test')
  TMP_ROOT="$(cd "$TMP_ROOT" && pwd)"
  ORIG_CWD="$(pwd)"

  # Build a clean PATH that prefers the gh stub.
  ORIG_PATH="$PATH"
  export PATH="${STUB_DIR}:${PATH}"

  export GH_STUB_ARGV_FILE="${TMP_ROOT}/gh-argv.log"
  export GH_STUB_BODY_FILE="${TMP_ROOT}/gh-body.txt"
  export GH_STUB_EXIT=0
  export GH_STUB_AUTH_EXIT=0
  export GH_STUB_AUTH_STATUS="Logged in to github.com as testuser"

  # Treat TMP_ROOT as the project root so the helper resolves
  # ${CLAUDE_PROJECT_DIR}/.autoflow-state.
  export CLAUDE_PROJECT_DIR="$TMP_ROOT"
  mkdir -p "${TMP_ROOT}/.autoflow-state"

  # Initialize a non-submodule git repo so the submodule guard does not trip.
  ( cd "$TMP_ROOT" && git init -q && git config user.email "t@example.com" \
      && git config user.name "tester" \
      && git commit -q --allow-empty -m "init" ) >/dev/null 2>&1 || true
}

# Write a minimal evaluation-hypothesis.json into the active issue dir.
# Args: <sub-repo-id> <issue> <verdict> [role_marker]
write_eval_json() {
  local subrepo="$1" issue="$2" verdict="$3" role="${4:-[role:eval-hypothesis]}"
  local dir="${TMP_ROOT}/.autoflow-state/${subrepo}/${issue}"
  mkdir -p "${dir}/analysis"
  cat > "${dir}/evaluation-hypothesis.json" <<EOF
{
  "phase": "GATE:HYPOTHESIS",
  "issue": "#${issue}",
  "evaluator": {
    "role_marker": "${role}",
    "session_id": "test-session"
  },
  "scores": {
    "structural_overlap": { "score": 8, "reason": "existing dispatcher already handles" },
    "code_change_necessity": { "score": 5, "reason": "minor data tweak only" },
    "structural_change_necessity": { "score": 5, "reason": "no new mechanism needed" }
  },
  "average": 6.0,
  "verdict": "${verdict}",
  "blocking_issues": [],
  "suggestions": ["consider closing as superseded"],
  "rationale": "Existing dispatcher already covers this case."
}
EOF
  cat > "${dir}/analysis/phase-3.md" <<EOF
# Phase 3 Cross-Verification — Issue #${issue}

Existing structure handles the proposed resolution.
EOF
}

set_current_issue() {
  local subrepo="$1" issue="$2"
  printf '%s/%s\n' "$subrepo" "$issue" > "${TMP_ROOT}/.autoflow-state/current-issue"
}

run_helper() {
  "$HELPER" "$@"
}

teardown_fixture() {
  if [ -n "${ORIG_PATH:-}" ]; then
    export PATH="$ORIG_PATH"
    ORIG_PATH=""
  fi
  if [ -n "${ORIG_CWD:-}" ] && [ -d "$ORIG_CWD" ]; then
    cd "$ORIG_CWD" 2>/dev/null || true
    ORIG_CWD=""
  fi
  if [ -n "${TMP_ROOT:-}" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf "$TMP_ROOT"
  fi
  TMP_ROOT=""
}

# Test outcome reporters (single-test files).
pass() {
  local id="$1" msg="${2:-}"
  if [ -n "$msg" ]; then
    echo "PASS: ${id} — ${msg}"
  else
    echo "PASS: ${id}"
  fi
  teardown_fixture
  exit 0
}

fail() {
  local id="$1" msg="${2:-no detail}"
  echo "FAIL: ${id} — ${msg}"
  teardown_fixture
  exit 1
}
