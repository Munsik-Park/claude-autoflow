# Manual Setup Guide

> For users who prefer to set up Auto-Flow manually instead of using `init.sh`.

---

## Prerequisites

- A GitHub repository (or multiple repos for multi-sub-repo setup).
- Claude Code installed and configured.
- Basic familiarity with the Auto-Flow methodology
  (see [`docs/autoflow-guide.md`](../docs/autoflow-guide.md)).

---

## Step 1: Copy Template Files

Copy the following files to your orchestrator (host) repository:

```bash
# Core files
cp CLAUDE.md.template          <your-host-repo>/CLAUDE.md.template
cp CLAUDE.local.md.example     <your-host-repo>/CLAUDE.local.md.example

# Hook
mkdir -p <your-host-repo>/.claude/hooks/
cp .claude/hooks/check-autoflow-gate.sh <your-host-repo>/.claude/hooks/
chmod +x <your-host-repo>/.claude/hooks/check-autoflow-gate.sh

# Documentation
mkdir -p <your-host-repo>/docs/
cp docs/autoflow-guide.md              <your-host-repo>/docs/
cp docs/design-rationale.md            <your-host-repo>/docs/
cp docs/evaluation-system.md           <your-host-repo>/docs/
cp docs/git-workflow.md                <your-host-repo>/docs/
cp docs/repo-boundary-rules.md         <your-host-repo>/docs/
cp docs/submodule-common-rules.md      <your-host-repo>/docs/
cp docs/security-checklist.md.template <your-host-repo>/docs/
cp docs/maintained-docs.md.template    <your-host-repo>/docs/
```

---

## Step 2: Replace Placeholders

Open `CLAUDE.md.template` and replace every `{{PLACEHOLDER}}`:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{PROJECT_NAME}}` | Project name | `my-saas-app` |
| `{{GITHUB_ORG}}` | GitHub org or username | `acme-corp` |
| `{{REPO_ORCHESTRATOR}}` | Orchestrator (host) repo name | `my-saas-app` |
| `{{REPO_BACKEND}}` | Backend sub-repo name (optional) | `my-saas-backend` |
| `{{REPO_FRONTEND}}` | Frontend sub-repo name (optional) | `my-saas-frontend` |
| `{{REPO_INFRA}}` | Infrastructure sub-repo name (optional) | `my-saas-infra` |
| `{{DEFAULT_BRANCH}}` | Default branch | `main` |
| `{{CI_SYSTEM}}` | CI tool | `github-actions` |
| `{{TECH_STACK_SUMMARY}}` | One-line tech stack | `Node.js + React + PostgreSQL` |
| `{{COMMUNICATION_LANGUAGE}}` | Language for user communication | `English` |

After replacing, rename the file:

```bash
mv CLAUDE.md.template CLAUDE.md
```

For single-repo projects, leave the sub-repo placeholders unset and remove the
sub-repo rows from the Repository Structure table.

---

## Step 3: Customise the Security Checklist

1. Open `docs/security-checklist.md.template`.
2. Replace `{{PROJECT_NAME}}` and `{{TECH_STACK_SUMMARY}}`.
3. Review each of the 5 security items.
4. Replace the `<!-- PROJECT-SPECIFIC EXAMPLE -->` comment blocks with your
   actual requirements; remove irrelevant examples.
5. Rename:

   ```bash
   mv docs/security-checklist.md.template docs/security-checklist.md
   ```

---

## Step 4: Customise Maintained Docs

1. Open `docs/maintained-docs.md.template`.
2. Replace placeholders.
3. List your actual documents (host repo + each sub-repo).
4. Rename:

   ```bash
   mv docs/maintained-docs.md.template docs/maintained-docs.md
   ```

---

## Step 5: Set Up Sub-Repository CLAUDE.md (multi-repo only)

For each sub-repository:

1. Choose the appropriate template from `subrepo-templates/`:
   - `subrepo-templates/backend/CLAUDE.md.template` for backend repos
   - `subrepo-templates/frontend/CLAUDE.md.template` for frontend repos
   - `subrepo-templates/_common/CLAUDE.md.template` for other repos

2. Copy to the sub-repo:

   ```bash
   cp subrepo-templates/backend/CLAUDE.md.template <backend-repo>/CLAUDE.md
   ```

3. Replace placeholders:
   - `{{REPO_NAME}}` → actual sub-repo name
   - `{{REPO_ROLE}}` → role description (e.g., `Backend API service`)
   - `{{GITHUB_ORG}}` → your org
   - `{{REPO_ORCHESTRATOR}}` → orchestrator repo name
   - `{{DEFAULT_BRANCH}}` → default branch
   - Build/test/lint/format command placeholders → actual commands

---

## Step 6: Configure `.gitignore`

Add the following to the host repo:

```
# Auto-Flow per-issue state files (host repo only)
.autoflow/issue-*.json

# Claude Code local overrides
CLAUDE.local.md
```

Each sub-repo's `.gitignore` should also include `.autoflow/issue-*.json` as
defence-in-depth — the canonical state lives in the host, but residual files
must not be committed.

---

## Step 7: Verify Setup

```bash
# Check for any remaining placeholders
grep -r '{{' . --include='*.md' --include='*.sh' | grep -v '.template' | grep -v 'node_modules'
# If this returns results, you have unreplaced placeholders.
```

---

## Step 8: Post-Setup Checklist

- [ ] `CLAUDE.md` has no remaining `{{placeholders}}`.
- [ ] `docs/security-checklist.md` is customised for your stack.
- [ ] `docs/maintained-docs.md` lists your actual documents.
- [ ] `.gitignore` includes `.autoflow/issue-*.json` and `CLAUDE.local.md`.
- [ ] Hook is executable: `chmod +x .claude/hooks/check-autoflow-gate.sh`.
- [ ] Sub-repo `CLAUDE.md` files created (multi-repo only).
- [ ] Team members have read `docs/autoflow-guide.md`.

---

## Troubleshooting

### Hook not running
- Confirm the hook is executable: `chmod +x .claude/hooks/check-autoflow-gate.sh`.
- Confirm `CLAUDE_PROJECT_DIR` is set by Claude Code.

### Placeholders not replaced
- Run `grep -r '{{' .` to find remaining placeholders.
- Check that `init.sh` completed without errors.

### Evaluation not working
- Confirm `.autoflow/issue-{N}.json` exists and `active` is `true`.
- Confirm the evaluation JSON follows the schema in `docs/evaluation-system.md`.
- Confirm the PASS thresholds in `CLAUDE.md` and `check-autoflow-gate.sh` agree.
