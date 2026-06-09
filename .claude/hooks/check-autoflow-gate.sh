#!/bin/bash
# AutoFlow Gate Check
# The hook computes pass/fail directly from the raw `scores` object so that the
# trust chain stops at the script level — the AI's own `pass`/`avg`/`min` fields
# are ignored.
#
# Command matching and check ordering follow docs/gate-matching-standard.md:
#   - P1: gates match with the shared CMD_BOUNDARY prefix + word boundary,
#         never a bare `^` (which `cd x && git push` would bypass).
#   - P2: unconditional denies (gh pr merge / default-branch push /
#         blocked-by-review label removal) run in Section 1, BEFORE the
#         activity check, so an inactive/absent state file cannot nullify them.
#
# PASS criteria (defined in CLAUDE.md):
#   - average ≥ 7.5
#   - each item ≥ 7
#   - security ≤ 3 → automatic block
#
# Gate points:
#   - Bash(gh pr merge)             → DENIED unconditionally (AutoFlow never merges)
#   - Bash(git push <default br>)   → DENIED unconditionally (push dev branch + PR only)
#   - Bash(remove blocked-by-review label) → DENIED unconditionally; matches the
#                                     label name across gh pr edit / gh issue edit
#                                     --remove-label and gh api DELETE .../labels/…
#                                     (gate-label clearing is the reviewer's job)
#   - Agent (planning spawn)        → GATE:HYPOTHESIS pass required (bug issue)
#                                     verdict containing "skip" → bypass (feat)
#   - Agent (implementation spawn)  → GATE:PLAN pass required
#   - Bash(git push)                → AUDIT + GATE:QUALITY pass required
#   - Bash(gh pr create)            → AUDIT + GATE:QUALITY pass required

set -e

AUTOFLOW_DIR="${CLAUDE_PROJECT_DIR:-.}/.autoflow"
INPUT=$(cat)

# ── Hook target detection ──
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Shared command-boundary prefix (docs/gate-matching-standard.md > P1).
# Matches command start or the position after ; & | && || — so a gate is
# not bypassed by `cd x && git push` / `a && gh pr create`. Backtick / (
# are intentionally NOT boundary chars: command-substitution evasion is out
# of scope, and including them caused heredoc/body false-positives.
CMD_BOUNDARY='(^|[;&|]|&&|\|\|)[[:space:]]*'

# Scan target: the command with body text removed so a quoted/heredoc body
# that merely mentions a prohibited token does not false-positive, while a
# real chained command outside quotes is preserved (gate-matching-standard
# > Known Limitation refinement):
#   1. drop everything from the first heredoc introducer (`<<`) onward;
#   2. delete single- and double-quoted substrings (inline --body "...").
SCAN=$(printf '%s' "${COMMAND%%<<*}" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

# ── Section 1: Unconditional blocks (state-independent — P2) ──
# AutoFlow never merges and never pushes to the default branch through the
# agent's tools. Enforced regardless of any .autoflow state so that a
# terminal phase setting active:false (or a removed state file) cannot
# disable the prohibition. Merging is performed by external review.
if [ "$TOOL_NAME" = "Bash" ]; then
  if printf '%s' "$SCAN" | grep -qE "${CMD_BOUNDARY}gh[[:space:]]+pr[[:space:]]+merge\b"; then
    echo "BLOCKED: AutoFlow does not merge — 'gh pr merge' is denied (CLAUDE.md > HANDOFF)." >&2
    echo "Merging, issue close, and deployment are owned by an external review process." >&2
    exit 2
  fi

  # The orchestrator must never clear the `blocked-by-review` gate label — that
  # would let the producer self-open its own review gate. Clearing the label is
  # the independent Codex reviewer's step, run inside the isolated `codex exec`
  # session (a subprocess this hook does not intercept). Match the LABEL NAME in
  # a removal context so the deny (a) covers every natural surface that drops the
  # label — `gh pr edit` / `gh issue edit --remove-label blocked-by-review` (a
  # PR's labels are issue labels) and the `gh api … -X DELETE …/labels/
  # blocked-by-review` REST form — while (b) NOT firing on unrelated label edits
  # such as HANDOFF step 7's `gh issue edit … --remove-label status:in-progress`,
  # and (c) leaving other labels removable. Residual (accepted; shared by every
  # Section-1 deny): a quoted label value or a `sh -c "…"`/backtick wrapper is
  # stripped by SCAN and slips — the threat model is the naive self-clear, and
  # the bare form is what callers write.
  if printf '%s' "$SCAN" | grep -qE "[[:space:]]--remove-label[[:space:]=]+blocked-by-review\b" \
     || { printf '%s' "$SCAN" | grep -qE "/labels/blocked-by-review\b" \
          && printf '%s' "$SCAN" | grep -qE "(-X[[:space:]]*|--method[[:space:]=]+)DELETE\b"; }; then
    echo "BLOCKED: AutoFlow does not clear the 'blocked-by-review' gate label." >&2
    echo "Gate-label clearing is the independent Codex reviewer's step, per .codex/review.md." >&2
    exit 2
  fi

  DEFAULT_BRANCH=$(git -C "${CLAUDE_PROJECT_DIR:-.}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
  if printf '%s' "$SCAN" | grep -qE "${CMD_BOUNDARY}git[[:space:]]+push\b" \
     && printf '%s' "$SCAN" | grep -qE "(\borigin[[:space:]]+(HEAD:)?${DEFAULT_BRANCH}\b|:[[:space:]]*${DEFAULT_BRANCH}\b)"; then
    echo "BLOCKED: AutoFlow does not push to ${DEFAULT_BRANCH} — push the dev branch and open a PR (CLAUDE.md > HANDOFF)." >&2
    exit 2
  fi
fi

# ── Section 2: Activity check — locate the active issue state file ──
# No state file means AutoFlow has not started — let the call through
# (pre-PREFLIGHT). The Section 1 denies above already ran unconditionally.
#
# Discovery is JSON-semantic (jq), not a textual grep: a state file is "active"
# iff `.active == true` as JSON, regardless of serialization whitespace. A prior
# `grep -rl '"active": true'` matched only the exact one-space form, so a valid
# but compact (`{"active":true}`) or reformatted (`"active" : true`) state file
# was silently not found — leaving STATE_FILE empty and bypassing every score
# gate (issue #241). jq decides by value; the loop keeps the first active file
# (one issue runs at a time).
#
# Parse-validity and `.active` are decided in a SINGLE jq read per file, not two:
# a `jq -e '.active == true'` returns non-zero for both a parse error AND
# `.active == false`, and reading the file twice (validate, then re-read for
# active) leaves a TOCTOU window where a mid-write between the two reads validates
# on the first and parse-errors on the second — slipping past both branches into a
# silent fail-open (PR #242 review). One `jq -er 'if .active == true ...'` snapshot
# distinguishes the three outcomes atomically: jq exits non-zero on a parse error
# (→ corrupt, recorded in MALFORMED_STATE and made to FAIL CLOSED for the
# score-gated commands below, never silently skipped); otherwise it prints
# "active" / "inactive". The assignment sits in the `if` condition so a jq failure
# does not trip `set -e`.
STATE_FILE=""
STATE_JSON=""
MALFORMED_STATE=""
if [ -d "$AUTOFLOW_DIR" ]; then
  for _sf in "$AUTOFLOW_DIR"/*.json; do
    [ -e "$_sf" ] || continue   # glob had no match → literal path → skip
    # Read the file ONCE into memory and decide parse-validity + active on that
    # single snapshot. Every downstream consumer (ACTIVE, VERDICT, check_scores)
    # reads STATE_JSON, never the file again — so a partial write occurring after
    # discovery cannot turn a later re-read into a jq parse error that exits 5,
    # which PreToolUse treats as a NON-blocking error (only exit 2 blocks). The
    # cat+jq pair sits in the `if` condition so neither failure trips `set -e`.
    # `jq -s` slurps the file: a valid state is EXACTLY ONE top-level JSON object.
    # jq is a stream parser, so two concatenated objects would otherwise parse to
    # "active\nactive" and slip past both the active and the malformed branches
    # (PR #242 review). Zero/multiple top-level values, a non-object top-level, or
    # a parse error all take the malformed path → fail closed.
    # AUTOFLOW-SCHEMA-VALIDATION (issue #245): the filter is CLOSED-WORLD — it accepts ONLY
    # the declared shape (top-level keys in the allowlist or fix_regression_cycle_N; each
    # field's type; verdict in {"",pending,evaluated,skipped (feat issue)}; scores
    # number|{score:number} in [0,10]; phases only at root + fix_regression* cycles) and
    # routes EVERY other shape to error() -> the MALFORMED path -> exit 2. "Reject all not
    # explicitly allowed" (vs the prior open-world "reject known-bad shapes") structurally
    # closes the corrupt-but-valid-JSON fail-open class (issue #245 cycle 2; verdict-value #5,
    # unknown-key/field-type #6). Single source of the vocabulary: tests/fixtures/gate-schema.json
    # (verdict_enum, top_level_keys, cycle_key_grammar, score_range), drift-checked by
    # test-issue-245-schema-validation.sh CLASS A (A9). check_scores below is UNTOUCHED — a
    # validator-passing doc has phases only at grammar-legal cycles, so its walk is uncontaminated.
    if _content=$(cat "$_sf" 2>/dev/null) \
       && _verdict=$(printf '%s' "$_content" | jq -s -er 'def in_range: type == "number" and . >= 0 and . <= 10; def is_score: in_range or (type == "object" and (.score | in_range)); def scores_ok: (type == "object") and ((to_entries | map(.value | is_score)) | all); def verdict_ok: (type == "string") and (. == "" or . == "pending" or . == "evaluated" or . == "skipped (feat issue)"); def phase_ok($p): (.phases[$p] == null) or ((.phases[$p] | type == "object") and ((.phases[$p].verdict == null) or (.phases[$p].verdict | verdict_ok)) and ((.phases[$p].scores == null) or (.phases[$p].scores | scores_ok))); def topkeys_ok: (keys_unsorted - ["active","issue","title","date","cycle","mode","phase","phases","fix_regression"]) | map(select(test("^fix_regression_cycle_[0-9]+$") | not)) | length == 0; def topvalues_ok: ((has("issue")|not) or (.issue|type=="string")) and ((has("title")|not) or (.title|type=="string")) and ((has("date")|not) or (.date|type=="string")) and ((has("cycle")|not) or (.cycle|type=="number")) and ((has("mode")|not) or (.mode|type=="string")) and ((has("phase")|not) or (.phase|type=="string")) and ((has("phases")|not) or (.phases|type=="object")); if (length != 1) or (.[0] | type != "object") then error("state file must be exactly one JSON object") else .[0] | if (has("active") | not) or (.active | type != "boolean") then error("active must be a boolean") elif .active != true then "inactive" elif (topkeys_ok | not) then error("unknown top-level key") elif (topvalues_ok | not) then error("top-level field has wrong type") else ( [.. | objects | select(has("phases"))] as $cycles | ([., (to_entries[] | select(.key == "fix_regression" or (.key | test("^fix_regression_cycle_[0-9]+$"))) | .value)] | map(select(type == "object" and has("phases")))) as $allowed | if (($cycles | length) != ($allowed | length)) then error("phases in a disallowed location") elif ($cycles | map(.phases | type == "object") | all | not) then error("phases must be an object") elif ($cycles | map(. as $c | ["gate_hypothesis_cause","gate_plan","audit","gate_quality"] | map(. as $p | $c | phase_ok($p)) | all) | all | not) then error("gated phase has invalid shape") else "active" end ) end end' 2>/dev/null); then
      if [ "$_verdict" = "active" ]; then
        STATE_FILE="$_sf"
        STATE_JSON="$_content"
        break
      fi
    else
      MALFORMED_STATE="$_sf"    # parse error / unreadable → corrupt; cannot trust its active flag
    fi
  done
fi

# Fail closed on corrupt state: no readable active file, but a malformed state
# file exists whose active flag we cannot determine. The state file gates BOTH
# git push / gh pr create AND score-gated Agent spawns (docs/evaluation-system.md),
# so refuse all of those on corrupt state — while leaving read-only commands and
# the writes needed to repair the file unblocked (no recovery deadlock). Research
# (Explore / Plan / claude-code-guide) and evaluation agents never gate, so they
# stay allowed even on corrupt state. The unconditional Section 1 denies already ran.
if [ -z "$STATE_FILE" ] && [ -n "$MALFORMED_STATE" ]; then
  _gated_corrupt="no"
  if [ "$TOOL_NAME" = "Bash" ] && printf '%s' "$SCAN" | grep -qE "${CMD_BOUNDARY}(git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+create)\b"; then
    _gated_corrupt="yes"
  elif [ "$TOOL_NAME" = "Agent" ]; then
    _atype=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
    _aprompt=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null)
    if [ "$_atype" != "Explore" ] && [ "$_atype" != "Plan" ] && [ "$_atype" != "claude-code-guide" ] \
       && ! echo "$_aprompt" | grep -qiE "(evaluation|evaluator|평가|evaluate|scoring|채점|review score|assess)"; then
      _gated_corrupt="yes"
    fi
  fi
  if [ "$_gated_corrupt" = "yes" ]; then
    echo "BLOCKED: malformed AutoFlow state file: $MALFORMED_STATE" >&2
    echo "A .autoflow/*.json state file is malformed (invalid JSON or schema) — refusing score-gated work on corrupt state. Fix or remove it." >&2
    exit 2
  fi
fi

if [ -z "$STATE_FILE" ]; then
  exit 0
fi

ACTIVE=$(printf '%s' "$STATE_JSON" | jq -r '.active // false' 2>/dev/null)
if [ "$ACTIVE" != "true" ]; then
  exit 0
fi

# ── Compute PASS verdict from raw scores ──
# Output: JSON { "pass": bool, "avg": float, "min": int, "security": int|null, "reason": string }
#
# State files can nest cycles (`fix_regression`, `fix_regression_cycle_2`, …)
# alongside the top-level `phases.*`. A previous cycle's gate scores are
# preserved at the top level, so a naive top-level lookup silently passes the
# stale verdict instead of the current cycle's. Walk every object holding a
# `phases.<phase>.scores` and take the LAST one — JSON authoring order
# corresponds to cycle order (base → fix_regression → fix_regression_cycle_N),
# so `last` is the most recent cycle's evaluation. If no cycle has scored the
# phase yet, the result is the original "evaluation not run" branch.
check_scores() {
  local phase_key=$1
  printf '%s' "$STATE_JSON" | jq --arg phase "$phase_key" '
    [.. | objects | select(has("phases")) | .phases[$phase].scores // empty]
    | map(select((. | type) == "object" and (. | length) > 0))
    | (last // {}) |
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
  '
}

# Block if the gate's check_scores result is not pass.
block_with_scores() {
  local gate_name=$1
  local phase_key=$2
  local result pass
  # A security gate must never let an error in score evaluation become a
  # non-blocking exit. If check_scores fails — e.g. a raw score is non-numeric so
  # jq's `tonumber` errors and exits 5, which PreToolUse does NOT treat as
  # blocking (only exit 2 blocks) — fail closed with an explicit exit 2 (PR #242
  # review). The assignment sits in the `if` condition so the failure does not
  # trip `set -e` before it is handled. All four score gates route through here,
  # so this single guard closes the whole "jq error → exit 5 → fail-open" class.
  if ! result=$(check_scores "$phase_key" 2>/dev/null); then
    echo "BLOCKED: ${gate_name}" >&2
    echo "Reason: state scores are not evaluable (corrupt or non-numeric) — failing closed." >&2
    echo "State file: $STATE_FILE" >&2
    exit 2
  fi
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
  # Fail closed if the verdict cannot be read — a JSON-valid but schema-corrupt
  # state (e.g. `.phases` is not an object) makes this jq error and would
  # otherwise exit 5, a NON-blocking PreToolUse code, for this gated spawn (PR
  # #242 review). The assignment sits in the `if` condition so set -e does not
  # fire first; only non-bypass (planning/implementation) agents reach here.
  if ! VERDICT=$(printf '%s' "$STATE_JSON" | jq -r '.phases.gate_hypothesis_cause.verdict // empty' 2>/dev/null); then
    echo "BLOCKED: AutoFlow state schema is corrupt (.phases is not an object) — failing closed for the Agent spawn." >&2
    echo "State file: $STATE_FILE" >&2
    exit 2
  fi
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
if [ "$TOOL_NAME" = "Bash" ] && printf '%s' "$SCAN" | grep -qE "${CMD_BOUNDARY}git[[:space:]]+push\b"; then
  block_with_scores "git push requires AUDIT pass" "audit"
  block_with_scores "git push requires GATE:QUALITY pass" "gate_quality"
fi

# ── Gate 4: gh pr create → AUDIT + GATE:QUALITY pass required ──
if [ "$TOOL_NAME" = "Bash" ] && printf '%s' "$SCAN" | grep -qE "${CMD_BOUNDARY}gh[[:space:]]+pr[[:space:]]+create\b"; then
  block_with_scores "gh pr create requires AUDIT pass" "audit"
  block_with_scores "gh pr create requires GATE:QUALITY pass" "gate_quality"
fi

# Pass.
exit 0
