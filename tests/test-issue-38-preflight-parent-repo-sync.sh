#!/usr/bin/env bash
# =============================================================================
# Test Suite: Issue #38 — PREFLIGHT parent-repo sync sub-step (0-2b)
# =============================================================================
# Encodes AC1–AC7 from
#   .autoflow-state/autoflow-upstream/38/plan.md §6
#
# AC1 — PREFLIGHT in CLAUDE.md contains the 0-2b parent-repo sync line,
#       positioned strictly between 0-2 and 0-3.
# AC2 — The 0-2b step line is character-identical between CLAUDE.md and
#       CLAUDE.md.template (mirroring contract from plan §4.1, §4.3).
# AC3 — CLAUDE.local.md.example has a "### Parent-Repo Sync Procedure"
#       section that back-references "PREFLIGHT step `0-2b`".
# AC4 — Optional carrier split:
#       (a) CLAUDE.md.template wraps the new step in
#           "<!-- BEGIN/END: OPTIONAL PARENT-REPO SYNC -->" HTML comments.
#       (b) CLAUDE.md uses prose conditional ("If this repo tracks an
#           upstream sub-repo via patch-apply" + "Skip if the project is
#           single-repo.").
#       (c) CLAUDE.md MUST NOT contain the HTML carrier markers.
# AC5 — docs/autoflow-guide.md PREFLIGHT Activities list contains a bullet
#       paraphrasing the 0-2b step ("(Optional, parent-repo / sub-repo
#       layout only)" + "tracks an upstream sub-repo via patch-apply").
# AC6 — Regression: every existing test script under
#       services/autoflow-upstream/tests/ continues to exit 0.
# AC7 — Negative: the new 0-2b instruction MUST NOT mention
#       ".autoflow-state" anywhere across the four edited files.
#
# Run from inside services/autoflow-upstream/ OR from the host repo root —
# the script normalizes its working directory via `git rev-parse`.
# =============================================================================

set -uo pipefail
# NOTE: not using `set -e` so a single FAIL does not short-circuit the suite.

# ---------------------------------------------------------------------------
# Resolve REPO_ROOT = services/autoflow-upstream/ regardless of caller cwd.
# `dirname $0`/.. lands us at the sub-repo root because this script lives at
# tests/. We then anchor every path under REPO_ROOT.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
CLAUDE_TEMPLATE="${REPO_ROOT}/CLAUDE.md.template"
AUTOFLOW_GUIDE="${REPO_ROOT}/docs/autoflow-guide.md"
LOCAL_EXAMPLE="${REPO_ROOT}/CLAUDE.local.md.example"
TESTS_DIR="${REPO_ROOT}/tests"
SELF_NAME="$(basename "$0")"

PASS=0
FAIL=0
ERRORS=()

pass() {
  PASS=$((PASS + 1))
  echo "  PASS: $1"
}

fail() {
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL: $1")
  echo "  FAIL: $1"
}

echo "=== Test Suite: Issue #38 PREFLIGHT parent-repo sync (0-2b) ==="
echo "REPO_ROOT: $REPO_ROOT"
echo ""

# ---------------------------------------------------------------------------
# AC1 — CLAUDE.md PREFLIGHT contains 0-2b in correct position
# Plan §2.3.1, §6 AC1.
# ---------------------------------------------------------------------------
echo "--- AC1: CLAUDE.md PREFLIGHT contains 0-2b parent-repo sync step ---"

if [ ! -f "$CLAUDE_MD" ]; then
  fail "AC1-file: CLAUDE.md not found"
else
  # AC1a — exactly one 0-2b line within the PREFLIGHT block matches the prose.
  ac1a_count=$(awk '/^## PREFLIGHT: Pre-Work/,/^---$/' "$CLAUDE_MD" \
    | grep -E '^0-2b\. If this repo tracks an upstream sub-repo via patch-apply' \
    | wc -l | tr -d '[:space:]')
  if [ "$ac1a_count" = "1" ]; then
    pass "AC1a: exactly one 0-2b prose line in PREFLIGHT block"
  else
    fail "AC1a: expected 1 '0-2b. If this repo tracks an upstream sub-repo via patch-apply' line, got $ac1a_count"
  fi

  # AC1b — order check: 0-2, 0-2b, 0-3 line numbers must be strictly increasing
  # within the PREFLIGHT block.
  ordering=$(awk '/^## PREFLIGHT: Pre-Work/,/^---$/' "$CLAUDE_MD" \
    | grep -nE '^(0-2|0-2b|0-3)\.' \
    || true)
  # Extract just the labels in order of appearance.
  labels_in_order=$(printf '%s\n' "$ordering" | sed -E 's/^[0-9]+:([^.]+)\..*/\1/' | tr '\n' ' ' | sed 's/ $//')
  if [ "$labels_in_order" = "0-2 0-2b 0-3" ]; then
    pass "AC1b: PREFLIGHT step order is 0-2 → 0-2b → 0-3"
  else
    fail "AC1b: PREFLIGHT step order expected '0-2 0-2b 0-3', got '$labels_in_order'"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# AC2 — 0-2b step line is character-identical between CLAUDE.md and
# CLAUDE.md.template. Plan §4.1, §4.3, §6 AC2.
# ---------------------------------------------------------------------------
echo "--- AC2: 0-2b step line is character-identical in CLAUDE.md and CLAUDE.md.template ---"

if [ ! -f "$CLAUDE_MD" ] || [ ! -f "$CLAUDE_TEMPLATE" ]; then
  fail "AC2-files: one or both of CLAUDE.md / CLAUDE.md.template not found"
else
  diff_out=$(diff \
    <(grep -F '0-2b. If this repo tracks an upstream sub-repo' "$CLAUDE_MD") \
    <(grep -F '0-2b. If this repo tracks an upstream sub-repo' "$CLAUDE_TEMPLATE") \
    2>&1 || true)
  if [ -z "$diff_out" ]; then
    # Empty diff — but only meaningful if both sides actually contain the line.
    md_has=$(grep -c -F '0-2b. If this repo tracks an upstream sub-repo' "$CLAUDE_MD" || true)
    tpl_has=$(grep -c -F '0-2b. If this repo tracks an upstream sub-repo' "$CLAUDE_TEMPLATE" || true)
    if [ "$md_has" -ge 1 ] && [ "$tpl_has" -ge 1 ]; then
      pass "AC2: 0-2b line matches byte-for-byte between CLAUDE.md and CLAUDE.md.template"
    else
      fail "AC2: 0-2b line absent from one or both files (CLAUDE.md=$md_has, template=$tpl_has)"
    fi
  else
    fail "AC2: 0-2b line diverges between CLAUDE.md and CLAUDE.md.template (diff non-empty)"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# AC3 — CLAUDE.local.md.example has Parent-Repo Sync section back-referencing
# PREFLIGHT step `0-2b`. Plan §2.4, §6 AC3.
# ---------------------------------------------------------------------------
echo "--- AC3: CLAUDE.local.md.example has Parent-Repo Sync section ---"

if [ ! -f "$LOCAL_EXAMPLE" ]; then
  fail "AC3-file: CLAUDE.local.md.example not found"
else
  # AC3a — section header exists exactly once.
  ac3a_count=$(grep -c '^### Parent-Repo Sync Procedure' "$LOCAL_EXAMPLE" || true)
  if [ "$ac3a_count" = "1" ]; then
    pass "AC3a: '### Parent-Repo Sync Procedure' header present (exactly 1)"
  else
    fail "AC3a: expected 1 '### Parent-Repo Sync Procedure' header, got $ac3a_count"
  fi

  # AC3b — the literal back-reference string appears at least once.
  ac3b_count=$(grep -c -F 'PREFLIGHT step `0-2b`' "$LOCAL_EXAMPLE" || true)
  if [ "$ac3b_count" -ge 1 ]; then
    pass "AC3b: 'PREFLIGHT step \`0-2b\`' back-reference present"
  else
    fail "AC3b: 'PREFLIGHT step \`0-2b\`' back-reference missing"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# AC4 — Carrier split: HTML for template, prose for CLAUDE.md, and CLAUDE.md
# MUST NOT contain the HTML carrier markers. Plan §2.2, §2.3.1, §2.3.2, §6 AC4.
# ---------------------------------------------------------------------------
echo "--- AC4: optional-carrier split (HTML in template, prose in CLAUDE.md) ---"

# AC4a — template has BEGIN marker exactly once.
if [ ! -f "$CLAUDE_TEMPLATE" ]; then
  fail "AC4a-file: CLAUDE.md.template not found"
else
  begin_count=$(grep -c 'BEGIN: OPTIONAL PARENT-REPO SYNC' "$CLAUDE_TEMPLATE" || true)
  if [ "$begin_count" = "1" ]; then
    pass "AC4a: CLAUDE.md.template contains 'BEGIN: OPTIONAL PARENT-REPO SYNC' (1 occurrence)"
  else
    fail "AC4a: expected 1 'BEGIN: OPTIONAL PARENT-REPO SYNC' in template, got $begin_count"
  fi

  end_count=$(grep -c 'END: OPTIONAL PARENT-REPO SYNC' "$CLAUDE_TEMPLATE" || true)
  if [ "$end_count" = "1" ]; then
    pass "AC4b: CLAUDE.md.template contains 'END: OPTIONAL PARENT-REPO SYNC' (1 occurrence)"
  else
    fail "AC4b: expected 1 'END: OPTIONAL PARENT-REPO SYNC' in template, got $end_count"
  fi
fi

# AC4c — CLAUDE.md uses prose conditional (antecedent + skip clause).
if [ ! -f "$CLAUDE_MD" ]; then
  fail "AC4c-file: CLAUDE.md not found"
else
  prose_count=$(grep -F 'If this repo tracks an upstream sub-repo via patch-apply' "$CLAUDE_MD" \
    | grep -F 'Skip if the project is single-repo.' \
    | wc -l | tr -d '[:space:]')
  if [ "$prose_count" = "1" ]; then
    pass "AC4c: CLAUDE.md prose conditional (antecedent + 'Skip if the project is single-repo.') present"
  else
    fail "AC4c: expected 1 prose conditional line in CLAUDE.md, got $prose_count"
  fi

  # AC4d — CLAUDE.md MUST NOT contain the HTML BEGIN marker.
  md_html_count=$(grep -c 'BEGIN: OPTIONAL PARENT-REPO SYNC' "$CLAUDE_MD" || true)
  if [ "$md_html_count" = "0" ]; then
    pass "AC4d: CLAUDE.md does NOT contain 'BEGIN: OPTIONAL PARENT-REPO SYNC' (carrier is template-only)"
  else
    fail "AC4d: CLAUDE.md unexpectedly contains 'BEGIN: OPTIONAL PARENT-REPO SYNC' ($md_html_count occurrences)"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# AC5 — docs/autoflow-guide.md PREFLIGHT description has the parent-repo
# bullet (prose form). Plan §2.3.3, §6 AC5.
# ---------------------------------------------------------------------------
echo "--- AC5: docs/autoflow-guide.md PREFLIGHT contains parent-repo bullet ---"

if [ ! -f "$AUTOFLOW_GUIDE" ]; then
  fail "AC5-file: docs/autoflow-guide.md not found"
else
  # Extract PREFLIGHT block (between "## PREFLIGHT: Pre-Work" and "### Exit Criteria").
  preflight_block=$(awk '
    /^## PREFLIGHT: Pre-Work/ { in_section = 1; print; next }
    in_section && /^### Exit Criteria/ { in_section = 0 }
    in_section { print }
  ' "$AUTOFLOW_GUIDE")

  # AC5a — exactly one bullet with the optionality marker.
  ac5a_count=$(printf '%s\n' "$preflight_block" \
    | grep -F '(Optional, parent-repo / sub-repo layout only)' \
    | wc -l | tr -d '[:space:]')
  if [ "$ac5a_count" = "1" ]; then
    pass "AC5a: PREFLIGHT block has 1 '(Optional, parent-repo / sub-repo layout only)' bullet"
  else
    fail "AC5a: expected 1 '(Optional, parent-repo / sub-repo layout only)' bullet, got $ac5a_count"
  fi

  # AC5b — bullet content mentions patch-apply.
  ac5b_count=$(printf '%s\n' "$preflight_block" \
    | grep -F 'tracks an upstream sub-repo via patch-apply' \
    | wc -l | tr -d '[:space:]')
  if [ "$ac5b_count" = "1" ]; then
    pass "AC5b: PREFLIGHT block mentions 'tracks an upstream sub-repo via patch-apply'"
  else
    fail "AC5b: expected 1 'tracks an upstream sub-repo via patch-apply' line, got $ac5b_count"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# AC6 — Regression: every existing test script under tests/ exits 0.
# Plan §5 Risk 5, §6 AC6.
# ---------------------------------------------------------------------------
echo "--- AC6: regression — existing tests/ scripts still exit 0 ---"

# Discover sibling scripts. Exclude this very script to avoid recursion.
regression_failures=0
regression_total=0
for script in "$TESTS_DIR"/*.sh; do
  [ -f "$script" ] || continue
  script_name="$(basename "$script")"
  if [ "$script_name" = "$SELF_NAME" ]; then
    continue
  fi
  regression_total=$((regression_total + 1))
  rc=0
  ( cd "$REPO_ROOT" && bash "$script" ) > "/tmp/issue-38-regression-${script_name}.log" 2>&1 || rc=$?
  if [ "$rc" = "0" ]; then
    pass "AC6: $script_name exits 0"
  else
    fail "AC6: $script_name exited $rc (see /tmp/issue-38-regression-${script_name}.log)"
    regression_failures=$((regression_failures + 1))
  fi
done

if [ "$regression_total" = "0" ]; then
  fail "AC6: no sibling test scripts found under tests/ — discovery is broken"
fi
echo ""

# ---------------------------------------------------------------------------
# AC7 — Negative: new 0-2b instruction MUST NOT mention .autoflow-state
# anywhere across the four edited files. Plan §6 AC7, §1 (git-only sub-step),
# §2.5; phase-a §7.3 (state-tree isolation).
# ---------------------------------------------------------------------------
echo "--- AC7: no .autoflow-state writes in the new 0-2b sub-step ---"

# AC7a — automated grep: any line containing `0-2b` across the four files
# must NOT also contain `.autoflow-state`.
ac7_violations=$(grep -F '0-2b' \
  "$CLAUDE_MD" \
  "$CLAUDE_TEMPLATE" \
  "$AUTOFLOW_GUIDE" \
  "$LOCAL_EXAMPLE" \
  2>/dev/null \
  | grep -F '.autoflow-state' \
  | wc -l | tr -d '[:space:]')

if [ "$ac7_violations" = "0" ]; then
  pass "AC7a: no .autoflow-state references on any 0-2b line across the 4 edited files"
else
  fail "AC7a: $ac7_violations lines mention both '0-2b' and '.autoflow-state' (violation)"
fi

# AC7b — manual review checklist (per delegation.md instruction: encode as
# documented printf, do NOT automate beyond the grep above).
printf 'MANUAL: AC7 positive scope — reviewer must confirm the 0-2b step text is git-only (mentions only git or working-tree concepts; no .autoflow-state, no new tooling).\n'
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "Failures:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
fi

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
