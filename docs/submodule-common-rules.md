# Sub-Repository Common Rules

> Shared rules that apply to all sub-repositories in a multi-repo Auto-Flow project.

---

## Applicability

These rules apply to every sub-repository (e.g., backend, frontend, infra, docs) that participates in the Auto-Flow lifecycle under a central orchestrator.

---

## Required Files

Every sub-repository **must** contain:

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Sub-repo operating manual (use templates from `subrepo-templates/`) |
| `.gitignore` | Must include `.autoflow-state/` |
| `README.md` | Project-specific documentation |

---

## Auto-Flow State Ownership

Sub-repos **must NOT contain `.autoflow-state/`**. Auto-Flow state belongs exclusively to the orchestrator's host repo working tree. The host repo records every issue under `.autoflow-state/<sub-repo-id>/<issue-number>/`, where `<sub-repo-id>` is the submodule path basename (or `self` for single-repo deployments).

The `.claude/scripts/phase-set` helper enforces this boundary at write time: when `git -C "$CLAUDE_PROJECT_DIR" rev-parse --show-superproject-working-tree` returns a non-empty path (i.e., `CLAUDE_PROJECT_DIR` is inside a sub-repo working tree), `phase-set` exits with code 65 instead of writing. The `AUTOFLOW_ALLOW_SUBMODULE_STATE=1` escape hatch exists for testing/CI only — production orchestrator sessions must run from the host repo.

For the full design intent (host-vs-sub-repo separation, namespaced layout, intake artifact), see [design-rationale.md > Decision 10](design-rationale.md#decision-10-state-tree-is-namespaced-by-sub-repo-identifier).

The `.gitignore` requirement above is therefore a defense-in-depth measure: even if a misconfigured `phase-set` invocation slips through, the resulting `.autoflow-state/` directory inside a sub-repo never lands in version control.

---

## CLAUDE.md Requirements

Each sub-repo's `CLAUDE.md` must define:

### 1. Repo Identity
```markdown
## This Repository
- **Name**: {{REPO_NAME}}
- **Role**: [backend / frontend / infra / docs / ...]
- **Orchestrator**: {{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}
```

### 2. Tech Stack & Commands
```markdown
## Development Commands
- **Build**: `<build command>`
- **Test**: `<test command>`
- **Lint**: `<lint command>`
- **Format**: `<format command>`
```

### 3. Scope Boundaries
```markdown
## Scope
This AI agent may only modify files within this repository.
For cross-repo changes, raise a Discussion to the Orchestrator.
```

### 4. Auto-Flow Reference
```markdown
## Auto-Flow
This repository follows the Auto-Flow lifecycle defined in:
{{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}/CLAUDE.md

All Auto-Flow phases, evaluation criteria, and gate rules apply.
```

---

## Agent Behavior Rules

### DO
- Follow the Auto-Flow phases in order
- Run tests before marking the TDD cycle complete
- Use the Discussion Protocol for ambiguities
- Reference the orchestrator's CLAUDE.md for process questions

### DO NOT
- Skip the evaluation gate (GATE:QUALITY)
- Modify files in other repositories
- Push directly to `{{DEFAULT_BRANCH}}`
- Ignore evaluation feedback during revision (REVISION)

---

## Testing Standards

Every sub-repo must maintain:

1. **Unit tests** for business logic
2. **Integration tests** for API endpoints / component interactions
3. **No broken tests on `{{DEFAULT_BRANCH}}`** — all tests must pass before merge
4. **Test commands documented** in `CLAUDE.md` so Test AI can run them

---

## Dependency Management

### Internal Dependencies (Between Repos)
- Use **versioned APIs** or **published packages** — never import directly from sibling repos
- Document dependency versions in a central tracking document
- Coordinate version bumps through the Orchestrator

### External Dependencies
- Pin major versions to prevent breaking changes
- Run vulnerability scans as part of CI
- Document any known CVE exceptions with rationale

---

## Shared Conventions

To maintain consistency across all sub-repos:

### Code Style
- Follow the language-specific style guide chosen for the project
- Use automated formatters (Prettier, Black, gofmt, etc.)
- Enforce via CI — no style debates in reviews

### Documentation
- Update docs when changing public interfaces
- Keep README.md current
- API changes require updating the API documentation

### Error Handling
- Use consistent error formats across repos
- Log errors with enough context to diagnose
- Don't swallow errors silently

---

## CI/CD Integration

Each sub-repo should have CI that:

1. Runs on every PR
2. Executes: lint → build → test
3. Reports results back to the PR
4. Blocks merge on failure

### Auto-Flow Gate Integration
The `check-autoflow-gate.sh` hook can be integrated into CI to verify:
- Evaluation score meets threshold
- All Auto-Flow phases completed in order
- State files are consistent
