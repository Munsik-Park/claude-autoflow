# Git Workflow

> Standard git procedures for projects using the Auto-Flow methodology.

---

## Branch Strategy

### Branch Types

| Type | Pattern | Purpose | Base Branch |
|------|---------|---------|-------------|
| Feature | `feature/<issue>-<desc>` | New functionality | `{{DEFAULT_BRANCH}}` |
| Fix | `fix/<issue>-<desc>` | Bug fixes | `{{DEFAULT_BRANCH}}` |
| Refactor | `refactor/<issue>-<desc>` | Code improvements | `{{DEFAULT_BRANCH}}` |
| Docs | `docs/<issue>-<desc>` | Documentation updates | `{{DEFAULT_BRANCH}}` |
| Chore | `chore/<issue>-<desc>` | Maintenance tasks | `{{DEFAULT_BRANCH}}` |

### Examples

```
feature/42-add-user-authentication
fix/87-resolve-memory-leak
refactor/103-simplify-data-pipeline
docs/55-update-api-reference
```

---

## Commit Messages

### Format

```
<type>(<scope>): <description>

[optional body — explain WHY, not WHAT]

Refs: #<issue-number>
```

### Types

| Type | When to Use |
|------|------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code restructuring (no behavior change) |
| `test` | Adding/updating tests |
| `docs` | Documentation changes |
| `chore` | Build, CI, tooling changes |
| `style` | Formatting only (no logic change) |

### Examples

```
feat(auth): add JWT token refresh endpoint

Implements automatic token refresh to prevent session expiration
during long-running operations. Tokens are refreshed 5 minutes
before expiry.

Refs: #42
```

```
fix(api): handle null response from external service

The payment gateway occasionally returns null instead of an error
object. This caused an unhandled exception in the order flow.

Refs: #87
```

---

## Pull Request Process

### Creating a PR (SHIP)

1. Ensure all commits are clean and well-described
2. Push the feature branch to remote
3. Create PR with the following template:

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

## Security Checklist
- [ ] Authentication & Authorization verified
- [ ] Input validation verified
- [ ] No sensitive data exposure
- [ ] Infrastructure isolation maintained
- [ ] Dependencies checked for CVEs

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass (if applicable)
- [ ] No existing tests broken
```

### PR Review Checklist (for Human Reviewers)

- [ ] Changes match the described issue
- [ ] Code is readable and follows project conventions
- [ ] Tests are adequate
- [ ] No security concerns
- [ ] Auto-Flow evaluation score is acceptable

---

## Merge Strategy

### Recommended: Squash and Merge
- Keeps `{{DEFAULT_BRANCH}}` history clean
- Each feature/fix becomes a single commit
- PR description becomes the commit body

### When to Use Regular Merge
- Large features where individual commits tell an important story
- Multi-phase implementations where history matters

---

## Protected Branch Rules

### `{{DEFAULT_BRANCH}}` Branch
- No direct pushes
- Require PR with at least 1 approval
- Require CI checks to pass
- Require Auto-Flow evaluation PASS (enforced by hook)

---

## Multi-Repo Coordination

When changes span multiple repositories:

1. **Orchestrator creates tracking issue** in the orchestrator repo
2. **Sub-issues created** in each affected repo
3. **Each repo follows its own Auto-Flow** independently
4. **Orchestrator coordinates merge order** to prevent broken states
5. **Integration testing** happens after all repos are merged

### Merge Order Rules
- Backend changes merge before frontend changes that depend on them
- Infrastructure changes merge before application changes
- Shared library changes merge before consumer changes
