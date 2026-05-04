#!/usr/bin/env bash
# =============================================================================
# T8 — Submodule guard (AC-S7): when CLAUDE_PROJECT_DIR is inside a submodule,
#       the helper refuses to write unless AUTOFLOW_ALLOW_SUBMODULE_STATE=1.
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
trap 'teardown_fixture' EXIT

ID="T8"
setup_fixture

# Build a host repo that contains a submodule, then point CLAUDE_PROJECT_DIR
# at the submodule's working tree.
HOST="${TMP_ROOT}/host"
SUB_SRC="${TMP_ROOT}/sub-src"
mkdir -p "$HOST" "$SUB_SRC"

( cd "$SUB_SRC" && git init -q && git config user.email "t@e.com" \
    && git config user.name "t" \
    && git commit -q --allow-empty -m "sub init" ) >/dev/null 2>&1

( cd "$HOST" && git init -q && git config user.email "t@e.com" \
    && git config user.name "t" \
    && git commit -q --allow-empty -m "host init" \
    && git -c protocol.file.allow=always submodule add -q "$SUB_SRC" sub \
        >/dev/null 2>&1 ) >/dev/null 2>&1

SUB_WT="${HOST}/sub"
if [ ! -d "$SUB_WT" ]; then
  fail "$ID" "could not create submodule fixture (skipping)"
fi

# Point CLAUDE_PROJECT_DIR at the submodule and seed minimal state inside it
# so resolve_issue would otherwise succeed.
export CLAUDE_PROJECT_DIR="$SUB_WT"
mkdir -p "${SUB_WT}/.autoflow-state/self/4001/analysis"
write_eval_json_in() {
  local dir="$1"
  cat > "${dir}/evaluation-hypothesis.json" <<'EOF'
{
  "phase": "GATE:HYPOTHESIS",
  "issue": "#4001",
  "evaluator": { "role_marker": "[role:eval-hypothesis]", "session_id": "x" },
  "scores": {
    "structural_overlap": { "score": 8, "reason": "x" },
    "code_change_necessity": { "score": 5, "reason": "x" },
    "structural_change_necessity": { "score": 5, "reason": "x" }
  },
  "verdict": "FAIL",
  "rationale": "x"
}
EOF
}
write_eval_json_in "${SUB_WT}/.autoflow-state/self/4001"
echo "self/4001" > "${SUB_WT}/.autoflow-state/current-issue"

# Without escape hatch → must refuse.
unset AUTOFLOW_ALLOW_SUBMODULE_STATE
OUT=$(run_helper 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
  fail "$ID" "helper succeeded inside submodule without escape hatch (output: $OUT)"
fi
if [ ! -d "${SUB_WT}/.autoflow-state/self/4001" ]; then
  fail "$ID" "issue dir was archived despite submodule guard"
fi

# With escape hatch → should be allowed (or at least not exit on submodule check).
export AUTOFLOW_ALLOW_SUBMODULE_STATE=1
OUT2=$(run_helper 2>&1); RC2=$?
if [ "$RC2" -ne 0 ]; then
  fail "$ID" "helper failed inside submodule with escape hatch (rc=$RC2, output: $OUT2)"
fi

pass "$ID" "submodule guard refuses without escape hatch and allows with it"
