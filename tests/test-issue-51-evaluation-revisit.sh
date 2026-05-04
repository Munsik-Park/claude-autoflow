#!/usr/bin/env bash
# Test: Evaluation System Revisit (Issue #51)
# Encodes AC-1..AC-9 from .autoflow-state/self/51/plan.md plus the AC-7
# tightening per delegation.md item 1 and AC-10 from delegation.md item 3.
# Each AC is wired into a function `test_acN_<short_name>`. Aggregates
# pass/fail counts. Exits 0 only when every AC passes. Before the
# implementation lands, ACs 1, 2, 3, 4, 5, 7, 8 MUST FAIL (RED). AC-6
# (subrepo template unchanged) and AC-9 (hook unchanged) are already
# satisfied today; AC-10 depends on the current state of
# docs/autoflow-guide.md (which today contains no Security/Performance
# evaluation-category references and already lists the canonical 5
# categories — so AC-10 may report PASS at RED).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

DESIGN_RATIONALE="$REPO_ROOT/docs/design-rationale.md"
EVAL_SYSTEM="$REPO_ROOT/docs/evaluation-system.md"
README_MD="$REPO_ROOT/README.md"
CLAUDE_TEMPLATE="$REPO_ROOT/CLAUDE.md.template"
SUBREPO_COMMON_TEMPLATE="$REPO_ROOT/subrepo-templates/_common/CLAUDE.md.template"
AUTOFLOW_GUIDE="$REPO_ROOT/docs/autoflow-guide.md"
HOOK="$REPO_ROOT/.claude/hooks/check-autoflow-gate.sh"

PASS_COUNT=0
FAIL_COUNT=0
FAILED_ACS=()

pass() {
  echo "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED_ACS+=("$2")
}

# ---------- Helpers ----------

# Extract the body of "### Decision 13:" from docs/design-rationale.md.
# Body starts on the heading line and ends at the next "### Decision " or EOF.
extract_decision13_block() {
  awk '
    /^### Decision 13:/      { in_block = 1 }
    in_block && /^### Decision / && !/^### Decision 13:/ {
      if (printed_first_heading) { in_block = 0 }
    }
    {
      if (/^### Decision 13:/) { printed_first_heading = 1 }
    }
    in_block { print }
  ' "$DESIGN_RATIONALE"
}

# Slugify a heading like "## Foo Bar (baz)" → "foo-bar-baz".
slugify_heading() {
  # strip leading hashes and surrounding whitespace, lowercase, drop punctuation
  # except hyphen/underscore, collapse spaces to hyphens.
  printf '%s' "$1" \
    | sed -E 's/^#+[[:space:]]*//' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9 _-]//g' \
    | sed -E 's/[[:space:]]+/-/g' \
    | sed -E 's/-+/-/g' \
    | sed -E 's/^-//; s/-$//'
}

# ---------- AC-1: Decision 13 heading appears exactly once ----------
test_ac1_decision13_heading() {
  echo "AC-1: docs/design-rationale.md has '^### Decision 13:' exactly once"
  local count
  count=$(grep -c '^### Decision 13:' "$DESIGN_RATIONALE" 2>/dev/null)
  count="${count:-0}"
  if [ "$count" = "1" ]; then
    pass "exactly one '### Decision 13:' heading"
  else
    fail "expected 1 '### Decision 13:' heading, found $count" "AC-1"
  fi
}

# ---------- AC-2: Decision 13 body has all four sub-section markers ----------
test_ac2_decision13_subsections() {
  echo "AC-2: Decision 13 body contains all four bold sub-section markers"
  local block
  block=$(extract_decision13_block)
  if [ -z "$block" ]; then
    fail "Decision 13 block is empty (heading missing)" "AC-2"
    return
  fi
  local missing=()
  for marker in '**What it does**' '**Why it works this way**' '**Rejected alternatives**' '**What this means**'; do
    if ! printf '%s\n' "$block" | grep -F "$marker" >/dev/null 2>&1; then
      missing+=("$marker")
    fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    pass "all four sub-section markers present"
  else
    fail "missing sub-section markers: ${missing[*]}" "AC-2"
  fi
}

# ---------- AC-3: Meta vs. Instance Context heading + cross-link ----------
test_ac3_meta_instance_section() {
  echo "AC-3: docs/evaluation-system.md has Meta vs. Instance Context heading and link to design-rationale.md#decision-13"
  local heading_count
  heading_count=$(grep -c '^### Meta vs\. Instance Context' "$EVAL_SYSTEM" 2>/dev/null)
  heading_count="${heading_count:-0}"
  if [ "$heading_count" != "1" ]; then
    fail "expected 1 '### Meta vs. Instance Context' heading, found $heading_count" "AC-3"
    return
  fi
  if grep -F 'design-rationale.md#decision-13' "$EVAL_SYSTEM" >/dev/null 2>&1; then
    pass "heading present and cross-link to design-rationale.md#decision-13 found"
  else
    fail "heading present but cross-link 'design-rationale.md#decision-13' missing" "AC-3"
  fi
}

# ---------- AC-4: README — no Security/Performance category rows; canonical 5 present ----------
test_ac4_readme_categories() {
  echo "AC-4: README.md has no Security/Performance category rows; canonical 5 categories present"
  if grep -E '^\| (Security|Performance) \|' "$README_MD" >/dev/null 2>&1; then
    fail "README.md still contains '| Security |' or '| Performance |' table rows" "AC-4"
    return
  fi
  local missing=()
  for c in 'Correctness' 'Quality' 'Test Coverage' 'Consistency' 'Documentation'; do
    if ! grep -F "| $c |" "$README_MD" >/dev/null 2>&1; then
      missing+=("$c")
    fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    pass "no Security/Performance rows; all 5 canonical categories present"
  else
    fail "canonical categories missing in README.md: ${missing[*]}" "AC-4"
  fi
}

# ---------- AC-5: CLAUDE.md.template — no 'Security score <= 3'; no Sec/Perf rows; canonical 5 present ----------
test_ac5_template_categories() {
  echo "AC-5: CLAUDE.md.template has no 'Security score <= 3'; no Sec/Perf rows; canonical 5 categories present"
  if grep -F 'Security score <= 3' "$CLAUDE_TEMPLATE" >/dev/null 2>&1; then
    fail "CLAUDE.md.template still references 'Security score <= 3' as AUTO-FAIL trigger" "AC-5"
    return
  fi
  if grep -E '^\| (Security|Performance) \|' "$CLAUDE_TEMPLATE" >/dev/null 2>&1; then
    fail "CLAUDE.md.template still contains '| Security |' or '| Performance |' table rows" "AC-5"
    return
  fi
  local missing=()
  for c in 'Correctness' 'Quality' 'Test Coverage' 'Consistency' 'Documentation'; do
    if ! grep -F "| $c |" "$CLAUDE_TEMPLATE" >/dev/null 2>&1; then
      missing+=("$c")
    fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    pass "no Security AUTO-FAIL ref; no Sec/Perf rows; all 5 canonical categories present"
  else
    fail "canonical categories missing in CLAUDE.md.template: ${missing[*]}" "AC-5"
  fi
}

# ---------- AC-6: subrepo-templates/_common/CLAUDE.md.template unchanged vs main ----------
test_ac6_subrepo_template_unchanged() {
  echo "AC-6: subrepo-templates/_common/CLAUDE.md.template is byte-identical to main"
  local diff_out
  diff_out=$(git diff main -- "$SUBREPO_COMMON_TEMPLATE" 2>/dev/null)
  if [ -z "$diff_out" ]; then
    pass "git diff main -- subrepo-templates/_common/CLAUDE.md.template is empty"
  else
    fail "subrepo-templates/_common/CLAUDE.md.template differs from main" "AC-6"
  fi
}

# ---------- AC-7: Decision 13 — placeholder absent + concrete follow-up ref present ----------
# Tightening per delegation.md item 1:
#   (a) literal '<follow-up-issue-#>' must NOT appear anywhere in design-rationale.md
#   (b) within the Decision 13 block, EITHER:
#       - the placeholder phrase '(deferred — follow-up issue to be filed at SHIP)' appears, OR
#       - a '#NNN' token appears in the explicit phrase 'deferred follow-up issue #NNN' (case-insensitive)
#   The standalone 'Issue #19' mention does NOT satisfy AC-7.
test_ac7_decision13_followup_ref() {
  echo "AC-7: Decision 13 references deferred follow-up via the placeholder phrase or 'deferred follow-up issue #NNN'"
  if grep -F '<follow-up-issue-#>' "$DESIGN_RATIONALE" >/dev/null 2>&1; then
    fail "literal '<follow-up-issue-#>' placeholder still present in docs/design-rationale.md" "AC-7"
    return
  fi
  local block
  block=$(extract_decision13_block)
  if [ -z "$block" ]; then
    fail "Decision 13 block is empty (heading missing)" "AC-7"
    return
  fi
  # (b1): placeholder phrase
  if printf '%s\n' "$block" \
       | grep -F '(deferred — follow-up issue to be filed at SHIP)' >/dev/null 2>&1; then
    pass "placeholder phrase '(deferred — follow-up issue to be filed at SHIP)' present in Decision 13"
    return
  fi
  # (b2): 'deferred follow-up issue #NNN' (case-insensitive, NNN is one or more digits)
  if printf '%s\n' "$block" \
       | grep -iE 'deferred follow-up issue #[0-9]+' >/dev/null 2>&1; then
    pass "'deferred follow-up issue #NNN' phrase present in Decision 13"
    return
  fi
  fail "neither placeholder phrase nor 'deferred follow-up issue #NNN' phrase found in Decision 13 block" "AC-7"
}

# ---------- AC-8: Internal markdown links resolve in the four edited files ----------
# Parses [label](path) and [label](path#anchor) from each file.
# - path may be absolute-from-repo-root or relative to the file's directory.
# - external (http/https/mailto) links are skipped.
# - in-document anchors (path empty, only #anchor) are checked against headings of the same file.
# - cross-document anchors check the target file exists AND a heading slug matches.
test_ac8_link_resolution() {
  echo "AC-8: All internal markdown links in the four edited files resolve"
  local files=("$DESIGN_RATIONALE" "$EVAL_SYSTEM" "$README_MD" "$CLAUDE_TEMPLATE")
  local broken=()
  for f in "${files[@]}"; do
    if [ ! -f "$f" ]; then
      broken+=("source-missing:$f")
      continue
    fi
    local file_dir
    file_dir=$(dirname "$f")
    # Extract every [label](target) occurrence; one per line.
    # GNU/BSD-portable: use grep -Eo with a conservative regex (no nested parens in label).
    local links
    links=$(grep -Eo '\[[^]]+\]\([^)[:space:]]+\)' "$f" 2>/dev/null || true)
    [ -z "$links" ] && continue
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      # Strip trailing ')' and leading '[label]('.
      local target
      target=$(printf '%s' "$entry" | sed -E 's/^\[[^]]+\]\(//; s/\)$//')
      # Skip external links and mailto.
      case "$target" in
        http://*|https://*|mailto:*|'#'*':'*) continue ;;
      esac
      # Split into path and anchor.
      local path anchor
      path="${target%%#*}"
      if [ "$target" = "$path" ]; then
        anchor=""
      else
        anchor="${target#*#}"
      fi
      # Resolve path: empty means "this file"; otherwise resolve relative to file_dir.
      local resolved
      if [ -z "$path" ]; then
        resolved="$f"
      else
        # If the path is absolute (begins with '/'), treat as repo-relative.
        case "$path" in
          /*) resolved="$REPO_ROOT$path" ;;
          *)  resolved="$file_dir/$path" ;;
        esac
        if [ ! -e "$resolved" ]; then
          broken+=("$(basename "$f"): missing file: $target")
          continue
        fi
      fi
      # Anchor check: only if anchor non-empty AND resolved is a file (not a dir).
      if [ -n "$anchor" ] && [ -f "$resolved" ]; then
        # Build the set of heading slugs in the resolved file.
        local found_anchor=""
        # shellcheck disable=SC2034
        while IFS= read -r heading_line; do
          local slug
          slug=$(slugify_heading "$heading_line")
          if [ "$slug" = "$anchor" ]; then
            found_anchor="yes"
            break
          fi
        done < <(grep -E '^#{1,6} ' "$resolved" 2>/dev/null || true)
        if [ -z "$found_anchor" ]; then
          broken+=("$(basename "$f"): anchor not found: $target")
        fi
      fi
    done <<< "$links"
  done
  if [ ${#broken[@]} -eq 0 ]; then
    pass "all internal markdown links in the four edited files resolve"
  else
    fail "broken/missing link targets:" "AC-8"
    for b in "${broken[@]}"; do
      echo "      - $b"
    done
  fi
}

# ---------- AC-9: hook unchanged vs main ----------
test_ac9_hook_unchanged() {
  echo "AC-9: .claude/hooks/check-autoflow-gate.sh is byte-identical to main"
  local diff_out
  diff_out=$(git diff main -- "$HOOK" 2>/dev/null)
  if [ -z "$diff_out" ]; then
    pass "git diff main -- .claude/hooks/check-autoflow-gate.sh is empty"
  else
    fail ".claude/hooks/check-autoflow-gate.sh differs from main" "AC-9"
  fi
}

# ---------- AC-10: docs/autoflow-guide.md — no Security/Performance evaluation-category refs ----------
# Asserts:
#   (a) no '| Security |' or '| Performance |' evaluation-category table rows
#   (b) no 'Security score <= 3' or 'Performance score <= 3' AUTO-FAIL key references
#   (c) if any of the canonical 5 category names appear in a table-row form
#       (| Correctness |, | Quality |, | Test Coverage |, | Consistency |, | Documentation |),
#       then ALL 5 must appear (canonical 5-category presence)
test_ac10_autoflow_guide_categories() {
  echo "AC-10: docs/autoflow-guide.md has no Security/Performance evaluation-category refs; canonical 5 present if categorised"
  # (a)
  if grep -E '^\| (Security|Performance) \|' "$AUTOFLOW_GUIDE" >/dev/null 2>&1; then
    fail "docs/autoflow-guide.md still contains '| Security |' or '| Performance |' table rows" "AC-10"
    return
  fi
  # (b)
  if grep -E '(Security|Performance) score <= 3' "$AUTOFLOW_GUIDE" >/dev/null 2>&1; then
    fail "docs/autoflow-guide.md still references 'Security score <= 3' or 'Performance score <= 3' as AUTO-FAIL key" "AC-10"
    return
  fi
  # (c): if any canonical category appears as a table row, all 5 must appear
  local any_present=""
  for c in 'Correctness' 'Quality' 'Test Coverage' 'Consistency' 'Documentation'; do
    if grep -F "| $c |" "$AUTOFLOW_GUIDE" >/dev/null 2>&1; then
      any_present="yes"
      break
    fi
  done
  if [ -n "$any_present" ]; then
    local missing=()
    for c in 'Correctness' 'Quality' 'Test Coverage' 'Consistency' 'Documentation'; do
      if ! grep -F "| $c |" "$AUTOFLOW_GUIDE" >/dev/null 2>&1; then
        missing+=("$c")
      fi
    done
    if [ ${#missing[@]} -eq 0 ]; then
      pass "no Security/Performance evaluation-category refs; canonical 5 categories all present"
    else
      fail "canonical categories missing in docs/autoflow-guide.md: ${missing[*]}" "AC-10"
    fi
  else
    pass "no Security/Performance evaluation-category refs; no canonical-category table to verify"
  fi
}

# ---------- Run all ACs ----------
test_ac1_decision13_heading
test_ac2_decision13_subsections
test_ac3_meta_instance_section
test_ac4_readme_categories
test_ac5_template_categories
test_ac6_subrepo_template_unchanged
test_ac7_decision13_followup_ref
test_ac8_link_resolution
test_ac9_hook_unchanged
test_ac10_autoflow_guide_categories

# ---------- Summary ----------
echo ""
echo "==================================================="
echo "Issue #51 evaluation-revisit ACs — PASS: $PASS_COUNT, FAIL: $FAIL_COUNT"
if [ ${#FAILED_ACS[@]} -gt 0 ]; then
  echo "Failed ACs: ${FAILED_ACS[*]}"
fi
echo "==================================================="

if [ "$FAIL_COUNT" -eq 0 ]; then
  exit 0
else
  exit 1
fi
