#!/usr/bin/env bash
# =============================================================================
# Auto-Flow Template — Interactive Setup Script
# =============================================================================
# Replaces placeholders in template files with your project-specific values.
#
# Usage:
#   chmod +x setup/init.sh
#   ./setup/init.sh
#
# This script will:
#   1. Ask for your project configuration
#   2. Generate CLAUDE.md from CLAUDE.md.template
#   3. Generate security-checklist.md from its template
#   4. Generate maintained-docs.md from its template
#   5. Set up .gitignore
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

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

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Auto-Flow Template — Setup Wizard       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ---------------------------------------------------------------------------
# Detect project root
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
info "Project root: ${PROJECT_ROOT}"
echo ""

# ---------------------------------------------------------------------------
# Gather configuration
# ---------------------------------------------------------------------------
echo -e "${YELLOW}── Project Configuration ──${NC}"
echo ""

prompt PROJECT_NAME     "Project name"
prompt GITHUB_ORG       "GitHub organization or username"
prompt REPO_ORCH        "Orchestrator repository name" "${PROJECT_NAME}"
prompt DEFAULT_BRANCH   "Default branch name" "main"
prompt CI_SYSTEM        "CI system (github-actions / jenkins / circleci / other)" "github-actions"
prompt TECH_STACK       "Tech stack summary (one line)"

echo ""
echo -e "${YELLOW}── Sub-Repositories ──${NC}"
echo ""

prompt REPO_BACKEND     "Backend repository name (or 'none' to skip)" "none"
prompt REPO_FRONTEND    "Frontend repository name (or 'none' to skip)" "none"

echo ""
echo -e "${YELLOW}── Configuration Summary ──${NC}"
echo ""
echo "  Project:       ${PROJECT_NAME}"
echo "  Organization:  ${GITHUB_ORG}"
echo "  Orchestrator:  ${REPO_ORCH}"
echo "  Default Branch:${DEFAULT_BRANCH}"
echo "  CI System:     ${CI_SYSTEM}"
echo "  Tech Stack:    ${TECH_STACK}"
echo "  Backend Repo:  ${REPO_BACKEND}"
echo "  Frontend Repo: ${REPO_FRONTEND}"
echo ""

echo -en "${BLUE}?${NC} Proceed with setup? (y/N): "
read -r confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  info "Setup cancelled."
  exit 0
fi

echo ""

# ---------------------------------------------------------------------------
# Replace placeholders in a file
# ---------------------------------------------------------------------------
replace_placeholders() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "$src" ]]; then
    warn "Template not found: ${src} — skipping"
    return
  fi

  cp "$src" "$dest"

  # Core placeholders
  sed -i "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" "$dest"
  sed -i "s|{{GITHUB_ORG}}|${GITHUB_ORG}|g" "$dest"
  sed -i "s|{{REPO_ORCHESTRATOR}}|${REPO_ORCH}|g" "$dest"
  sed -i "s|{{DEFAULT_BRANCH}}|${DEFAULT_BRANCH}|g" "$dest"
  sed -i "s|{{CI_SYSTEM}}|${CI_SYSTEM}|g" "$dest"
  sed -i "s|{{TECH_STACK_SUMMARY}}|${TECH_STACK}|g" "$dest"

  # Sub-repo placeholders
  if [[ "$REPO_BACKEND" != "none" ]]; then
    sed -i "s|{{REPO_BACKEND}}|${REPO_BACKEND}|g" "$dest"
  fi

  if [[ "$REPO_FRONTEND" != "none" ]]; then
    sed -i "s|{{REPO_FRONTEND}}|${REPO_FRONTEND}|g" "$dest"
  fi

  success "Generated: ${dest}"
}

# ---------------------------------------------------------------------------
# Generate files
# ---------------------------------------------------------------------------
info "Generating files..."
echo ""

# CLAUDE.md
replace_placeholders \
  "${PROJECT_ROOT}/CLAUDE.md.template" \
  "${PROJECT_ROOT}/CLAUDE.md"

# Security checklist
replace_placeholders \
  "${PROJECT_ROOT}/docs/security-checklist.md.template" \
  "${PROJECT_ROOT}/docs/security-checklist.md"

# Maintained docs
replace_placeholders \
  "${PROJECT_ROOT}/docs/maintained-docs.md.template" \
  "${PROJECT_ROOT}/docs/maintained-docs.md"

# Git workflow
replace_placeholders \
  "${PROJECT_ROOT}/docs/git-workflow.md" \
  "${PROJECT_ROOT}/docs/git-workflow.md"

# ---------------------------------------------------------------------------
# Set up .gitignore
# ---------------------------------------------------------------------------
GITIGNORE="${PROJECT_ROOT}/.gitignore"
if [[ ! -f "$GITIGNORE" ]] || ! grep -q ".autoflow-state" "$GITIGNORE" 2>/dev/null; then
  info "Updating .gitignore..."
  cat >> "$GITIGNORE" << 'GITIGNORE_EOF'

# Auto-Flow state files (working files, not committed)
.autoflow-state/

# Claude Code local overrides
CLAUDE.local.md
GITIGNORE_EOF
  success "Updated .gitignore"
fi

# ---------------------------------------------------------------------------
# Optional: Remove submodule section if no sub-repos
# ---------------------------------------------------------------------------
if [[ "$REPO_BACKEND" == "none" && "$REPO_FRONTEND" == "none" ]]; then
  warn "No sub-repos configured. You may want to remove the 'Sub-Repository Rules' section from CLAUDE.md"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
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
echo "  1. Review the generated CLAUDE.md"
echo "  2. Customize docs/security-checklist.md for your stack"
echo "  3. Set up sub-repo CLAUDE.md files using subrepo-templates/"
echo "  4. Configure your CI to run check-autoflow-gate.sh"
echo "  5. See setup/SETUP-GUIDE.md for detailed instructions"
echo ""
