# Git Workflow

> Standard git procedures for projects using the Auto-Flow methodology.

---

## Branch Strategy

| Type | Pattern | Purpose | Base |
|------|---------|---------|------|
| Feature  | `feature/<issue>-<desc>`  | New functionality | `main` |
| Fix      | `fix/<issue>-<desc>`      | Bug fixes | `main` |
| Refactor | `refactor/<issue>-<desc>` | Code improvements | `main` |
| Docs     | `docs/<issue>-<desc>`     | Documentation updates | `main` |
| Chore    | `chore/<issue>-<desc>`    | Maintenance tasks | `main` |

Examples:

```
feature/42-add-user-authentication
fix/87-resolve-memory-leak
docs/55-update-api-reference
```

---

## Commit Messages

### Format

```
<type>(#<issue>): <description>

Next: <next action>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

`type`: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`.

The `Next:` line lets the next session pick up where this one left off (see
[`teammate-common-rules.md`](teammate-common-rules.md#session-protocol)).

---

## Git Clean Check

Used at PREFLIGHT (entry) and LAND (completion).

```bash
# 1. Working tree is clean
git status                       # must report nothing to commit, working tree clean

# 2. Synced with remote
git fetch origin
git log HEAD..origin/main --oneline   # must be empty (or handled)

# 3. Branch is from the latest main (PREFLIGHT only)
git checkout -b <type>/<issue>-<desc> main
```

If any check fails:

- Uncommitted changes → `git stash`, `git commit`, or discard with the user's
  approval (PREFLIGHT). At LAND, discuss with the user before discarding.
- Remote has new commits ahead → `git pull --rebase` and re-run.
- Wrong base → re-branch from latest main.

If the working tree cannot be made clean, **stop** and report. PREFLIGHT does
not advance to DIAGNOSE on a dirty tree.

---

## Pull Request Process

### Creating a PR (SHIP)

1. Verify all commits are clean and well-described.
2. Push the branch to remote (`git push -u origin <branch>`).
3. Create the PR using the template below.

```markdown
## Summary
[1-3 sentences describing the change]

## Changes
- [Bullet list of key changes]

## Issue
Closes #<issue-number>

## Auto-Flow Evaluation
- Score: [X/10]
- Report: [link or inline]

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass (if applicable)
- [ ] No existing tests broken
```

### PR Review Checklist (Human Reviewers)

- Changes match the described issue.
- Code is readable and follows project conventions.
- Tests are adequate.
- No security concerns.
- Auto-Flow evaluation score is acceptable.

---

## Merge Strategy

### Recommended: Squash and Merge

- Keeps `main` history clean.
- Each feature/fix becomes a single commit.
- PR description becomes the commit body.

### When to Use Regular Merge

- Large features whose individual commits tell an important story.
- Multi-phase implementations where history matters.

---

## Post-Merge Cleanup

After the PR is confirmed merged at LAND:

```bash
git checkout main
git pull origin main
git branch -d <branch>           # local branch
git push origin --delete <branch> # remote branch (if not auto-deleted)
```

The `.autoflow/issue-{N}.json` state file is preserved as history; only its
`active` field flips to `false`.

---

## Protected Branch Rules

### `main`

- No direct pushes.
- Require PR with at least 1 approval.
- Require CI checks to pass.
- Require Auto-Flow evaluation PASS (enforced by `.claude/hooks/check-autoflow-gate.sh`).

---

## Issue Auto-Close

The PR body includes a close keyword so that merging closes the issue
automatically.

```
Closes #<issue-number>
```

Recognised keywords: `Closes`, `Fixes`, `Resolves` (case-insensitive).
