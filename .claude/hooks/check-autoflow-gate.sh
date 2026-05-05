#!/bin/bash
# Auto-Flow Gate Check
# The hook computes pass/fail directly from the raw `scores` object so that the
# trust chain stops at the script level — the AI's own `pass`/`avg`/`min` fields
# are ignored.
#
# PASS criteria (defined in CLAUDE.md):
#   - average ≥ 7.5
#   - each item ≥ 7
#   - security ≤ 3 → automatic block
#
# Gate points:
#   - Agent (planning spawn)        → GATE:HYPOTHESIS pass required (bug issue)
#                                     verdict containing "skip" → bypass (feat)
#   - Agent (implementation spawn)  → GATE:PLAN pass required
#   - Bash(git push)                → AUDIT + GATE:QUALITY pass required
#   - Bash(gh pr create)            → AUDIT + GATE:QUALITY pass required

set -e

AUTOFLOW_DIR="${CLAUDE_PROJECT_DIR:-.}/.autoflow"
INPUT=$(cat)

# Locate the active issue state file.
STATE_FILE=""
if [ -d "$AUTOFLOW_DIR" ]; then
  STATE_FILE=$(grep -rl '"active": true' "$AUTOFLOW_DIR"/*.json 2>/dev/null | head -1)
fi

# No state file means Auto-Flow has not started — let the call through (pre-PREFLIGHT).
if [ -z "$STATE_FILE" ]; then
  exit 0
fi

ACTIVE=$(jq -r '.active // false' "$STATE_FILE" 2>/dev/null)
if [ "$ACTIVE" != "true" ]; then
  exit 0
fi

# ── Compute PASS verdict from raw scores ──
# Output: JSON { "pass": bool, "avg": float, "min": int, "security": int|null, "reason": string }
check_scores() {
  local phase_key=$1
  jq --arg phase "$phase_key" '
    .phases[$phase].scores // {} |
    if length == 0 then
      { pass: false, avg: 0, min: 0, security: null, reason: "evaluation not run" }
    else
      (to_entries | map(.value | if type == "object" then .score else . end | tonumber)) as $vals |
      ($vals | add / length * 10 | round / 10) as $avg |
      ($vals | min) as $min |
      (.["security"] // .["보안"] // null | if type == "object" then .score else . end) as $sec |
      if $sec != null and $sec <= 3 then
        { pass: false, avg: $avg, min: $min, security: $sec,
          reason: ("security score " + ($sec | tostring) + " — automatic rework") }
      elif $min < 7 then
        { pass: false, avg: $avg, min: $min, security: $sec,
          reason: ("lowest score " + ($min | tostring) + " — each item must be ≥ 7") }
      elif $avg < 7.5 then
        { pass: false, avg: $avg, min: $min, security: $sec,
          reason: ("average " + ($avg | tostring) + " — must be ≥ 7.5") }
      else
        { pass: true, avg: $avg, min: $min, security: $sec, reason: "PASS" }
      end
    end
  ' "$STATE_FILE"
}

# Block if the gate's check_scores result is not pass.
block_with_scores() {
  local gate_name=$1
  local phase_key=$2
  local result
  result=$(check_scores "$phase_key")
  local pass
  pass=$(echo "$result" | jq -r '.pass')

  if [ "$pass" != "true" ]; then
    local reason avg min_val
    reason=$(echo "$result" | jq -r '.reason')
    avg=$(echo "$result" | jq -r '.avg')
    min_val=$(echo "$result" | jq -r '.min')
    echo "BLOCKED: ${gate_name}" >&2
    echo "Reason: ${reason}" >&2
    echo "Current scores — average: ${avg}, lowest: ${min_val}" >&2
    echo "PASS criteria — average ≥ 7.5, each ≥ 7, security > 3" >&2
    echo "State file: $STATE_FILE" >&2
    exit 2
  fi
}

# ── Hook target detection ──
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# ── Gate: Agent spawn ──
if [ "$TOOL_NAME" = "Agent" ]; then
  PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null)
  SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)

  # Research/explore agents pass through.
  if [ "$SUBAGENT_TYPE" = "Explore" ] || [ "$SUBAGENT_TYPE" = "Plan" ] || [ "$SUBAGENT_TYPE" = "claude-code-guide" ]; then
    exit 0
  fi

  # Evaluation agents pass through (prompt contains evaluation keywords).
  if echo "$PROMPT" | grep -qiE "(evaluation|evaluator|평가|evaluate|scoring|채점|review score|assess)"; then
    exit 0
  fi

  # Gate 1: planning agent → GATE:HYPOTHESIS pass required (bug issues only).
  # If gate_hypothesis_cause.verdict does not contain "skip", treat as bug issue.
  VERDICT=$(jq -r '.phases.gate_hypothesis_cause.verdict // empty' "$STATE_FILE" 2>/dev/null)
  if [ -n "$VERDICT" ] && ! echo "$VERDICT" | grep -qi "skip"; then
    if echo "$PROMPT" | grep -qiE "(plan|계획|논의|discuss|design|설계|approach)"; then
      block_with_scores "planning agent spawn requires GATE:HYPOTHESIS pass" "gate_hypothesis_cause"
    fi
  fi

  # Gate 2: implementation agent → GATE:PLAN pass required.
  if echo "$PROMPT" | grep -qiE "(implement|fix|feat|build|create|write code|commit|push|구현|수정|개발)"; then
    block_with_scores "implementation agent spawn requires GATE:PLAN pass" "gate_plan"
  fi
fi

# ── Gate 3: git push → AUDIT + GATE:QUALITY pass required ──
if [ "$TOOL_NAME" = "Bash" ] && echo "$COMMAND" | grep -qE "^git push"; then
  block_with_scores "git push requires AUDIT pass" "audit"
  block_with_scores "git push requires GATE:QUALITY pass" "gate_quality"
fi

# ── Gate 4: gh pr create → AUDIT + GATE:QUALITY pass required ──
if [ "$TOOL_NAME" = "Bash" ] && echo "$COMMAND" | grep -qE "^gh pr create"; then
  block_with_scores "gh pr create requires AUDIT pass" "audit"
  block_with_scores "gh pr create requires GATE:QUALITY pass" "gate_quality"
fi

# Pass.
exit 0
