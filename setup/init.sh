#!/usr/bin/env bash
# =============================================================================
# Auto-Flow Template — Interactive Setup Script
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
echo -e "${BLUE}║     Auto-Flow Template — Setup Wizard       ║${NC}"
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

GITIGNORE="${PROJECT_ROOT}/.gitignore"
if [[ ! -f "$GITIGNORE" ]] || ! grep -q ".autoflow/issue-" "$GITIGNORE" 2>/dev/null; then
  info "Updating .gitignore..."
  cat >> "$GITIGNORE" << 'GITIGNORE_EOF'

# Auto-Flow state files (working files, not committed)
.autoflow/issue-*.json

# Claude Code local overrides
CLAUDE.local.md
GITIGNORE_EOF
  success "Updated .gitignore"
fi

if [[ "$REPO_BACKEND" == "none" && "$REPO_FRONTEND" == "none" && "$REPO_INFRA" == "none" ]]; then
  warn "No sub-repos configured — running in single-repo mode."
  warn "DELIVER pushes a single branch and INTEGRATE / LAND collapse to a single PR flow."
  warn "You may want to remove the Sub-Repository List rows from CLAUDE.md."
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
echo ""
echo "Next steps:"
echo "  1. Review the generated CLAUDE.md."
echo "  2. Customize docs/security-checklist.md for your stack."
echo "  3. Confirm the hook is executable:"
echo "     chmod +x .claude/hooks/check-autoflow-gate.sh"
echo "  4. For multi-repo projects: create each sub-repo's CLAUDE.md from subrepo-templates/."
echo "  5. See setup/SETUP-GUIDE.md for further details."
echo ""
