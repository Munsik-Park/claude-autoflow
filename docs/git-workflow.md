# Git Workflow

> Standard git procedures for projects using the AutoFlow methodology.

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

Used at PREFLIGHT (entry) and HANDOFF (completion).

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
  approval (PREFLIGHT). At HANDOFF, discuss with the user before discarding.
- Remote has new commits ahead → `git pull --rebase` and re-run.
- Wrong base → re-branch from latest main.

If the working tree cannot be made clean, **stop** and report. PREFLIGHT does
not advance to DIAGNOSE on a dirty tree.

---

## Pull Request Process

### Creating a PR (SHIP)

1. Verify all commits are clean and well-described.
2. Confirm the gh login matches the role context — host PR under `gh_users.orchestrator`, sub-repo PR under `gh_users.submodules.<name>`. Switch with `gh auth switch --user <login>` if needed and verify with `gh auth status`. See [`credentials.md`](credentials.md).
3. Push the branch to remote (`git push -u origin <branch>`).
4. Create the PR using the template below.

```markdown
## Summary
[1-3 sentences describing the change]

## Changes
- [Bullet list of key changes]

## Issue
Closes #<issue-number>

## AutoFlow Evaluation
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
- AutoFlow evaluation score is acceptable.

---

## Merge Strategy

### Recommended: Squash and Merge

- Keeps `main` history clean.
- Each feature/fix becomes a single commit.
- PR description becomes the commit body.

### When to Use Regular Merge

- Large features whose individual commits tell an important story.
- Multi-phase implementations where history matters.

### Merge Sequencing (external review)

For host PRs with sub-repo dependencies (multi-repo deployments — see `CLAUDE.md` > Deployment Topology), the merge order is sub-repo → pointer bump → host. The host PR is created as a draft with the `blocked-by-subrepo` label at HANDOFF; the label is auto-removed and a required status check `subrepo-merged` is published by `.github/workflows/handoff-sequence.yml` when the reviewer dispatches `subrepo-merged` after merging the sub-repo PR upstream.

Full reviewer-facing procedure: [`external-review-sequencing.md`](external-review-sequencing.md).

See also: [`autoflow-guide.md`](autoflow-guide.md) > HANDOFF > Merge Sequencing (external review).

### Pointer reconciliation — concurrent-cycle gitlink guard

When a **reconcile request** (pointer bump after the sub-repo PR merges) is delegated to AutoFlow and several cycles are in external review at once, the dev branch may have forked before another cycle's host PR merged and reconciled the `services/{{REPO_SUBMODULE}}` pointer. A naive bump + push then leaves the host PR `CONFLICTING`. Before bumping, compare `BASE` (dev's merge-base pointer), `MAIN` (current `origin/main` pointer), and `TARGET` (this issue's `merge_commit_sha`); if `MAIN != BASE`, resolve by fork ancestry:

```bash
git fetch origin main && git -C services/{{REPO_SUBMODULE}} fetch origin main
# TARGET descendant of MAIN: put TARGET on the dev gitlink FIRST, then merge main.
# A bare `git merge origin/main` with the dev pointer still at BASE resolves the
# gitlink to MAIN (3-way merge takes theirs when ours==base), NOT TARGET.
if git -C services/{{REPO_SUBMODULE}} merge-base --is-ancestor <MAIN> <TARGET>; then
  git -C services/{{REPO_SUBMODULE}} checkout <TARGET>
  git add services/{{REPO_SUBMODULE}} && git commit -m "chore(#<N>): reconcile services/{{REPO_SUBMODULE}} pointer to <TARGET>"
  git merge --no-edit origin/main          # dev gitlink TARGET ⊇ MAIN -> submodule stays at TARGET
  test "$(git ls-tree HEAD services/{{REPO_SUBMODULE}} | awk '{print $3}')" = "<TARGET>" || echo "POINTER != TARGET — fix before push"
fi
# MAIN descendant of TARGET (would regress the pointer) OR divergent -> do NOT push; escalate to operator
```

Before/after pushing, verify **all three**: (1) `git ls-tree HEAD services/{{REPO_SUBMODULE}}` == `TARGET` (a mismatch is `Exit 79`); (2) `gh pr view <PR> --json mergeable` == `MERGEABLE`; (3) CI rebuild result (authenticated API call to `{{CI_URL}}`). **[MUST]** An unauthenticated CI call may return `403`/empty — never read that as "CI down". Run the reconcile against a freshly-synced `main` (Post-Merge Cleanup of prior merges first) so `BASE ≈ MAIN`. Full procedure: [`external-review-sequencing.md`](external-review-sequencing.md) > Reconcile preflight.

---

## Post-Merge Cleanup

Performed at PREFLIGHT of the next cycle once the prior PR is observed merged
or closed (or by the live session if it observes the decision first). Apply it
to **every** resolved cycle found during prior-cycle resolution, including ones
from earlier cycles:

```bash
git checkout main
git pull origin main
git branch -d <branch>             # local branch
git push origin --delete <branch>  # remote branch (if not auto-deleted)
scripts/cleanup/cleanup-issue.sh <N>  # delete the resolved issue's .autoflow/issue-<N>.* + issue-<N>-* files (rm-deny-safe wrapper; accepts multiple Ns)
```

**Delete** the resolved issue's `.autoflow/issue-{N}*` management files (state
JSON, decision ledger, design docs, reports) at cleanup via
`scripts/cleanup/cleanup-issue.sh <N>` (pass one or more `N`), so each later
PREFLIGHT reads only live cycles. They are gitignored working scratch; the
durable record lives in the GitHub PR/issue and commit history.

**[MUST] Use the wrapper, not a bare `rm`.** `cleanup-issue.sh` is invoked by
path, so the Bash command carries no `rm` token, and it removes only the
resolved issue's files on an **exact number boundary** — `issue-<N>.*` and
`issue-<N>-*` (NOT a bare `issue-<N>*` glob, which would also match `issue-<N>3`
/ a prefix-collision sibling like `123` for `N=12`) — with a digits-only `N`
guard, `find -delete` scoped to `.autoflow/` at `maxdepth 1`. This keeps cleanup
working under a broad `rm` permission deny: Claude Code precedence is
**deny > allow**, so an `rm` allow-exception cannot override a broad
`Bash(rm:*)` deny — only a non-`rm` wrapper survives it. Allow-list the wrapper
(`Bash(./scripts/cleanup/cleanup-issue.sh:*)`) so it never prompts.

---

## Protected Branch Rules

### `main`

- No direct pushes.
- Require PR with at least 1 approval.
- Require CI checks to pass.
- Require AutoFlow evaluation PASS (enforced by `.claude/hooks/check-autoflow-gate.sh`).

---

## Issue Auto-Close

The PR body includes a close keyword so that merging closes the issue
automatically.

```
Closes #<issue-number>
```

Recognised keywords: `Closes`, `Fixes`, `Resolves` (case-insensitive).
