#!/usr/bin/env bash
# =============================================================================
# AutoFlow Template — Interactive Setup Script
# =============================================================================
# Replaces placeholders in template files with project-specific values.
#
# Usage:
#   chmod +x setup/init.sh
#   ./setup/init.sh
#
# Generates:
#   1. CLAUDE.md from CLAUDE.md.template
#   2. docs/security-checklist.md from its template
#   3. docs/maintained-docs.md from its template
#   4. .gitignore (or updates an existing one)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

sed_inplace() {
  local expr="$1"
  local file="$2"
  local tmp="${file}.tmp"
  sed "$expr" "$file" > "$tmp" && mv "$tmp" "$file"
}

prompt() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="${3:-}"

  if [[ -n "$default_value" ]]; then
    echo -en "${BLUE}?${NC} ${prompt_text} [${default_value}]: "
  else
    echo -en "${BLUE}?${NC} ${prompt_text}: "
  fi

  read -r input
  input="${input:-$default_value}"

  if [[ -z "$input" ]]; then
    error "Value required for: ${prompt_text}"
  fi

  eval "$var_name='$input'"
}

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     AutoFlow Template — Setup Wizard       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
info "Project root: ${PROJECT_ROOT}"
echo ""

echo -e "${YELLOW}── Project Configuration ──${NC}"
echo ""

prompt PROJECT_NAME            "Project name"
prompt GITHUB_ORG              "GitHub organization or username"
prompt REPO_ORCHESTRATOR       "Orchestrator (host) repository name" "${PROJECT_NAME}"
prompt DEFAULT_BRANCH          "Default branch name" "main"
prompt CI_SYSTEM               "CI system (github-actions / jenkins / circleci / other)" "github-actions"
prompt TECH_STACK              "Tech stack summary (one line)"
prompt COMMUNICATION_LANGUAGE  "Language for user communication" "English"

echo ""
echo -e "${YELLOW}── Sub-Repositories (enter 'none' to skip) ──${NC}"
echo ""

prompt REPO_BACKEND            "Backend sub-repo name (or 'none')" "none"
prompt REPO_FRONTEND           "Frontend sub-repo name (or 'none')" "none"
prompt REPO_INFRA              "Infrastructure sub-repo name (or 'none')" "none"
prompt REPO_SUBMODULE          "Primary submodule dir under services/ — used by handoff-sequence.yml (or 'none')" "none"

echo ""
echo -e "${YELLOW}── Configuration Summary ──${NC}"
echo ""
echo "  Project:        ${PROJECT_NAME}"
echo "  Organization:   ${GITHUB_ORG}"
echo "  Orchestrator:   ${REPO_ORCHESTRATOR}"
echo "  Default Branch: ${DEFAULT_BRANCH}"
echo "  CI System:      ${CI_SYSTEM}"
echo "  Tech Stack:     ${TECH_STACK}"
echo "  Language:       ${COMMUNICATION_LANGUAGE}"
echo "  Backend:        ${REPO_BACKEND}"
echo "  Frontend:       ${REPO_FRONTEND}"
echo "  Infrastructure: ${REPO_INFRA}"
echo "  Submodule path: services/${REPO_SUBMODULE}"
echo ""

echo -en "${BLUE}?${NC} Proceed with setup? (y/N): "
read -r confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  info "Setup cancelled."
  exit 0
fi

echo ""

replace_placeholders() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "$src" ]]; then
    warn "Template not found: ${src} — skipping"
    return
  fi

  cp "$src" "$dest"

  sed_inplace "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" "$dest"
  sed_inplace "s|{{GITHUB_ORG}}|${GITHUB_ORG}|g" "$dest"
  sed_inplace "s|{{REPO_ORCHESTRATOR}}|${REPO_ORCHESTRATOR}|g" "$dest"
  sed_inplace "s|{{DEFAULT_BRANCH}}|${DEFAULT_BRANCH}|g" "$dest"
  sed_inplace "s|{{CI_SYSTEM}}|${CI_SYSTEM}|g" "$dest"
  sed_inplace "s|{{TECH_STACK_SUMMARY}}|${TECH_STACK}|g" "$dest"
  sed_inplace "s|{{COMMUNICATION_LANGUAGE}}|${COMMUNICATION_LANGUAGE}|g" "$dest"

  if [[ "$REPO_BACKEND" != "none" ]]; then
    sed_inplace "s|{{REPO_BACKEND}}|${REPO_BACKEND}|g" "$dest"
  fi
  if [[ "$REPO_FRONTEND" != "none" ]]; then
    sed_inplace "s|{{REPO_FRONTEND}}|${REPO_FRONTEND}|g" "$dest"
  fi
  if [[ "$REPO_INFRA" != "none" ]]; then
    sed_inplace "s|{{REPO_INFRA}}|${REPO_INFRA}|g" "$dest"
  fi
  if [[ "$REPO_SUBMODULE" != "none" ]]; then
    sed_inplace "s|{{REPO_SUBMODULE}}|${REPO_SUBMODULE}|g" "$dest"
  fi

  success "Generated: ${dest}"
}

info "Generating files..."
echo ""

replace_placeholders \
  "${PROJECT_ROOT}/CLAUDE.md.template" \
  "${PROJECT_ROOT}/CLAUDE.md"

replace_placeholders \
  "${PROJECT_ROOT}/docs/security-checklist.md.template" \
  "${PROJECT_ROOT}/docs/security-checklist.md"

replace_placeholders \
  "${PROJECT_ROOT}/docs/maintained-docs.md.template" \
  "${PROJECT_ROOT}/docs/maintained-docs.md"

# Substitute the submodule path in handoff-sequence.yml (an executable workflow,
# not a .template file). Single-repo projects (REPO_SUBMODULE=none) do not use it.
HANDOFF_WF="${PROJECT_ROOT}/.github/workflows/handoff-sequence.yml"
if [[ -f "$HANDOFF_WF" ]]; then
  if [[ "$REPO_SUBMODULE" != "none" ]]; then
    sed_inplace "s|{{REPO_SUBMODULE}}|${REPO_SUBMODULE}|g" "$HANDOFF_WF"
    success "Substituted submodule path in handoff-sequence.yml"
  else
    warn "handoff-sequence.yml still contains {{REPO_SUBMODULE}} — set a submodule and re-run, edit it by hand, or delete it for single-repo projects."
  fi
fi

GITIGNORE="${PROJECT_ROOT}/.gitignore"
ensure_gitignore_line() {
  local line="$1"
  if [[ ! -f "$GITIGNORE" ]] || ! grep -qxF "$line" "$GITIGNORE" 2>/dev/null; then
    echo "$line" >> "$GITIGNORE"
  fi
}
info "Ensuring .gitignore entries..."
[[ -f "$GITIGNORE" ]] || { echo "# AutoFlow .gitignore" > "$GITIGNORE"; }
ensure_gitignore_line ".autoflow/issue-*.json"
ensure_gitignore_line ".autoflow/auth.local.yaml"
ensure_gitignore_line ".autoflow/logs/"
ensure_gitignore_line ".env"
ensure_gitignore_line ".env.local"
ensure_gitignore_line ".env*.local"
ensure_gitignore_line "CLAUDE.local.md"
success "Updated .gitignore"

info "Generating .autoflow/ runtime files..."
mkdir -p "${PROJECT_ROOT}/.autoflow"

AUTOFLOW_CONFIG="${PROJECT_ROOT}/.autoflow/config.yaml"
if [[ -f "$AUTOFLOW_CONFIG" ]]; then
  warn "Exists, skipping: ${AUTOFLOW_CONFIG}"
else
  replace_placeholders \
    "${PROJECT_ROOT}/.autoflow/config.yaml.example" \
    "$AUTOFLOW_CONFIG"
fi

if [[ "$REPO_BACKEND" != "none" || "$REPO_FRONTEND" != "none" || "$REPO_INFRA" != "none" ]]; then
  AUTOFLOW_SUBMODULES="${PROJECT_ROOT}/.autoflow/submodules.yaml"
  if [[ -f "$AUTOFLOW_SUBMODULES" ]]; then
    warn "Exists, skipping: ${AUTOFLOW_SUBMODULES}"
  else
    replace_placeholders \
      "${PROJECT_ROOT}/.autoflow/submodules.yaml.example" \
      "$AUTOFLOW_SUBMODULES"
    warn "Edit ${AUTOFLOW_SUBMODULES} and replace <FILL_IN_FORK_OWNER> entries."
  fi
fi

if [[ ! -f "${PROJECT_ROOT}/.autoflow/auth.local.yaml" ]]; then
  info "auth.local.yaml not created (machine-local secrets file)."
  info "  Copy the example when you're ready:"
  info "    cp .autoflow/auth.local.yaml.example .autoflow/auth.local.yaml"
fi

if [[ "$REPO_BACKEND" == "none" && "$REPO_FRONTEND" == "none" && "$REPO_INFRA" == "none" ]]; then
  warn "No sub-repos configured — running in single-repo mode."
  warn "DELIVER pushes a single branch and INTEGRATE / HANDOFF collapse to a single PR flow."
  warn "You may want to remove the Sub-Repository List rows from CLAUDE.md."
fi

# ---------------------------------------------------------------------------
# Submodule fork URL re-pointing (multi-repo only)
# ---------------------------------------------------------------------------
# Per docs/submodule-common-rules.md > Submodule URL & Pointer Policy,
# .gitmodules must point at the operator-controlled fork (not upstream).
# When this framework is propagated, each submodule URL must be retargeted
# to the new operator's fork. Iterates over every submodule in .gitmodules.
# Skip gracefully when .gitmodules is absent (single-repo projects).
GITMODULES="${PROJECT_ROOT}/.gitmodules"
if [[ -f "$GITMODULES" ]]; then
  echo ""
  echo -e "${YELLOW}── Submodule Fork URLs ──${NC}"
  echo "Per docs/submodule-common-rules.md > Submodule URL & Pointer Policy,"
  echo ".gitmodules must point at your operator-controlled fork (not upstream)."
  echo ""

  path_lines=$(git config --file "$GITMODULES" --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)

  if [[ -z "$path_lines" ]]; then
    info "No submodules found in .gitmodules — skipping submodule URL prompt."
  else
    while IFS= read -r path_line; do
      sm_path=$(echo "$path_line" | awk '{print $2}')
      sm_key=$(echo "$path_line" | awk '{print $1}' | sed 's/^submodule\.//;s/\.path$//')
      current_url=$(git config --file "$GITMODULES" --get "submodule.${sm_key}.url" 2>/dev/null || echo "")
      sm_basename=$(basename "$sm_path")

      echo "Submodule: ${sm_path}"
      echo "  current URL: ${current_url}"
      prompt NEW_SUBMODULE_URL \
        "  Operator fork URL for ${sm_path}" \
        "https://github.com/${GITHUB_ORG}/${sm_basename}.git"

      if [[ -n "$current_url" && "$current_url" != "$NEW_SUBMODULE_URL" ]]; then
        sed_inplace "s|${current_url}|${NEW_SUBMODULE_URL}|" "$GITMODULES"
        success "Updated .gitmodules ${sm_path} URL → ${NEW_SUBMODULE_URL}"
      else
        info "${sm_path} URL unchanged."
      fi
    done <<< "$path_lines"

    warn "Run \`git submodule sync\` and \`git submodule update --init --recursive\` to pick up the new URLs."
  fi
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Setup Complete!                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo "Generated files:"
echo "  - CLAUDE.md (from CLAUDE.md.template)"
echo "  - docs/security-checklist.md"
echo "  - docs/maintained-docs.md"
echo "  - .gitignore (updated)"
echo "  - .autoflow/config.yaml"
if [[ "$REPO_BACKEND" != "none" || "$REPO_FRONTEND" != "none" || "$REPO_INFRA" != "none" ]]; then
  echo "  - .autoflow/submodules.yaml (stub — edit fork owners)"
fi
echo ""
echo "Next steps:"
echo "  1. Review the generated CLAUDE.md and .autoflow/config.yaml."
echo "  2. Customize docs/security-checklist.md for your stack."
echo "  3. Copy the credentials reference template:"
echo "     cp .autoflow/auth.local.yaml.example .autoflow/auth.local.yaml"
echo "     (edit gh_users / ssh_keys — see docs/credentials.md)"
echo "  4. Confirm the hook is executable:"
echo "     chmod +x .claude/hooks/check-autoflow-gate.sh"
echo "  5. For multi-repo projects: edit .autoflow/submodules.yaml fork owners,"
echo "     then create each sub-repo's CLAUDE.md from subrepo-templates/."
echo "  6. See setup/SETUP-GUIDE.md for further details."
echo ""
