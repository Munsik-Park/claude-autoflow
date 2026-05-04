#!/usr/bin/env bash
# =============================================================================
# AC-D8 (tightened) — `grep -nF 'close issue' <file>` must return zero matches
#   inside the GATE:HYPOTHESIS-related sections of:
#     CLAUDE.md:
#       (a) Phase Definitions block
#       (b) Flow Control table
#       (c) Regression Rules table
#       (d) DIAGNOSE > Phase 3 FAIL clause
#       (e) Execution Principles
#     CLAUDE.md.template: same five sections (mirror)
#     docs/autoflow-guide.md: GATE:HYPOTHESIS section
# =============================================================================

set -u
. "$(dirname "$0")/lib.sh"
ID="AC-D8"

assert_section_clean() {
  local file="$1" desc="$2" content="$3"
  if printf '%s' "$content" | grep -qiF 'close issue'; then
    local hit
    hit=$(printf '%s' "$content" | grep -niF 'close issue' | head -3)
    fail "$ID" "${file} ${desc} contains 'close issue': ${hit}"
  fi
}

# --- CLAUDE.md sections ---
mdpath="$CLAUDE_MD"
[ -f "$mdpath" ] || fail "$ID" "$mdpath not found"

phase_def=$(awk '/^### Phase Definitions/{flag=1;next} /^### Execution Principles/{flag=0} flag' "$mdpath")
assert_section_clean "$mdpath" "Phase Definitions block"  "$phase_def"

flow_ctrl=$(awk '/^## Flow Control/{flag=1;next} /^### Regression Rules/{flag=0} flag' "$mdpath")
assert_section_clean "$mdpath" "Flow Control table"       "$flow_ctrl"

regr=$(awk '/^### Regression Rules/{flag=1;next} /^## /{if(flag){flag=0}} flag' "$mdpath")
assert_section_clean "$mdpath" "Regression Rules table"   "$regr"

phase3=$(awk '/^### Phase 3: Cross-Verification/{flag=1;next} /^## /{if(flag){flag=0}} flag' "$mdpath")
assert_section_clean "$mdpath" "Phase 3 FAIL clause"       "$phase3"

exec_p=$(awk '/^### Execution Principles/{flag=1;next} /^## Flow Control/{flag=0} flag' "$mdpath")
assert_section_clean "$mdpath" "Execution Principles"     "$exec_p"

# --- CLAUDE.md.template — mirror of the same five sections ---
tmpl="$CLAUDE_TEMPLATE"
[ -f "$tmpl" ] || fail "$ID" "$tmpl not found"

# Template uses the same heading conventions; if a section is missing in the
# template that's a pre-existing issue (covered by AC-D4), so only check what
# is present.
for header_pair in \
    '^### Phase Definitions:^### Execution Principles' \
    '^## Flow Control:^### Regression Rules' \
    '^### Regression Rules:^## ' \
    '^### Phase 3\\: Cross-Verification:^## ' \
    '^### Execution Principles:^## Flow Control'
do
  start="${header_pair%%:*}"
  end="${header_pair##*:}"
  body=$(awk -v s="$start" -v e="$end" '
    $0 ~ s {flag=1; next}
    flag && $0 ~ e {flag=0}
    flag' "$tmpl")
  if [ -n "$body" ]; then
    assert_section_clean "$tmpl" "($start)" "$body"
  fi
done

# --- docs/autoflow-guide.md GATE:HYPOTHESIS section ---
guide="$GUIDE"
[ -f "$guide" ] || fail "$ID" "$guide not found"
gh_section=$(awk '/^## GATE:HYPOTHESIS/{flag=1;next} /^## /{if(flag){flag=0}} flag' "$guide")
assert_section_clean "$guide" "GATE:HYPOTHESIS section" "$gh_section"

pass "$ID"
