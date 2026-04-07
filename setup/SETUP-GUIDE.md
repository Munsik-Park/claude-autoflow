# Manual Setup Guide

> For users who prefer to set up Auto-Flow manually instead of using `init.sh`.

---

## Prerequisites

- A GitHub repository (or multiple repos for multi-repo setup)
- Claude Code installed and configured
- Basic familiarity with the Auto-Flow methodology (see [docs/autoflow-guide.md](../docs/autoflow-guide.md))

---

## Step 1: Copy Template Files

Copy the following files to your orchestrator repository:

```bash
# Core files
cp CLAUDE.md.template    <your-repo>/CLAUDE.md.template
cp CLAUDE.local.md.example <your-repo>/CLAUDE.local.md.example

# Hook
mkdir -p <your-repo>/.claude/hooks/
cp .claude/hooks/check-autoflow-gate.sh <your-repo>/.claude/hooks/
chmod +x <your-repo>/.claude/hooks/check-autoflow-gate.sh

# Documentation
mkdir -p <your-repo>/docs/
cp docs/autoflow-guide.md           <your-repo>/docs/
cp docs/git-workflow.md             <your-repo>/docs/
cp docs/repo-boundary-rules.md      <your-repo>/docs/
cp docs/evaluation-system.md        <your-repo>/docs/
cp docs/security-checklist.md.template <your-repo>/docs/
cp docs/maintained-docs.md.template    <your-repo>/docs/
cp docs/submodule-common-rules.md      <your-repo>/docs/
```

---

## Step 2: Replace Placeholders

Open `CLAUDE.md.template` and replace all `{{PLACEHOLDER}}` values:

| Placeholder | Description | Example |
|------------|-------------|---------|
| `{{PROJECT_NAME}}` | Your project name | `my-saas-app` |
| `{{GITHUB_ORG}}` | GitHub org or username | `acme-corp` |
| `{{REPO_ORCHESTRATOR}}` | Orchestrator repo name | `my-saas-app` |
| `{{REPO_BACKEND}}` | Backend repo name | `my-saas-backend` |
| `{{REPO_FRONTEND}}` | Frontend repo name | `my-saas-frontend` |
| `{{REPO_INFRA}}` | Infrastructure repo name | `my-saas-infra` |
| `{{TECH_STACK_SUMMARY}}` | One-line tech stack | `Node.js + React + PostgreSQL` |
| `{{CI_SYSTEM}}` | CI tool | `github-actions` |
| `{{DEFAULT_BRANCH}}` | Default branch | `main` |

After replacing, rename the file:
```bash
mv CLAUDE.md.template CLAUDE.md
```

---

## Step 3: Customize Security Checklist

1. Open `docs/security-checklist.md.template`
2. Replace `{{PROJECT_NAME}}` and `{{TECH_STACK_SUMMARY}}`
3. Review each of the 5 security items
4. Replace the `<!-- PROJECT-SPECIFIC EXAMPLE -->` comment blocks with your actual requirements
5. Remove irrelevant examples
6. Rename:
   ```bash
   mv docs/security-checklist.md.template docs/security-checklist.md
   ```

---

## Step 4: Customize Maintained Docs

1. Open `docs/maintained-docs.md.template`
2. Replace placeholders
3. Add entries for your actual repositories and documents
4. Rename:
   ```bash
   mv docs/maintained-docs.md.template docs/maintained-docs.md
   ```

---

## Step 5: Customize Git Workflow

1. Open `docs/git-workflow.md`
2. Replace `{{DEFAULT_BRANCH}}` with your default branch name
3. Adjust branch naming conventions if needed
4. Adjust merge strategy if needed

---

## Step 6: Set Up Sub-Repository CLAUDE.md (If Multi-Repo)

For each sub-repository:

1. Choose the appropriate template:
   - `subrepo-templates/backend/CLAUDE.md.template` for backend repos
   - `subrepo-templates/frontend/CLAUDE.md.template` for frontend repos
   - `subrepo-templates/_common/CLAUDE.md.template` for other repos

2. Copy to the sub-repo:
   ```bash
   cp subrepo-templates/backend/CLAUDE.md.template <backend-repo>/CLAUDE.md
   ```

3. Replace all placeholders:
   - `{{REPO_NAME}}` → actual repo name
   - `{{REPO_ROLE}}` → role description
   - `{{GITHUB_ORG}}` → your org
   - `{{REPO_ORCHESTRATOR}}` → orchestrator repo name
   - `{{DEFAULT_BRANCH}}` → default branch
   - `{{*_COMMAND}}` → actual build/test/lint commands

---

## Step 7: Configure .gitignore

Add to your `.gitignore`:

```
# Auto-Flow state files
.autoflow-state/

# Claude Code local overrides
CLAUDE.local.md
```

---

## Step 8: Remove Optional Sections

If you're **not** using a multi-repo structure:

1. In `CLAUDE.md`, find and remove the block between:
   ```
   <!-- BEGIN: OPTIONAL SUBMODULE SECTION -->
   ...
   <!-- END: OPTIONAL SUBMODULE SECTION -->
   ```

2. You can skip:
   - `docs/repo-boundary-rules.md`
   - `docs/submodule-common-rules.md`
   - All `subrepo-templates/` files

---

## Step 9: Verify Setup

Run a quick verification:

```bash
# Check for any remaining placeholders
grep -r '{{' . --include='*.md' --include='*.sh' | grep -v '.template' | grep -v 'node_modules'

# If this returns results, you have unreplaced placeholders
```

---

## Step 10: Post-Setup Checklist

- [ ] `CLAUDE.md` has no remaining `{{placeholders}}`
- [ ] `docs/security-checklist.md` customized for your stack
- [ ] `docs/maintained-docs.md` lists your actual documents
- [ ] `.gitignore` includes `.autoflow-state/` and `CLAUDE.local.md`
- [ ] Hook is executable: `chmod +x .claude/hooks/check-autoflow-gate.sh`
- [ ] Sub-repo `CLAUDE.md` files created (if multi-repo)
- [ ] Team members have read `docs/autoflow-guide.md`

---

## Troubleshooting

### Hook not running
- Ensure the hook file is executable: `chmod +x .claude/hooks/check-autoflow-gate.sh`
- Verify `CLAUDE_PROJECT_DIR` is set by Claude Code

### Placeholders not replaced
- Run `grep -r '{{' .` to find remaining placeholders
- Check that `init.sh` completed without errors

### Evaluation not working
- Verify `.autoflow-state/` directory structure exists
- Check that `evaluation.json` follows the schema in `docs/evaluation-system.md`
- Verify `PASS_THRESHOLD` in `check-autoflow-gate.sh` matches your `CLAUDE.md`
