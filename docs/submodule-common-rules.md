# Sub-Repository Common Rules

> Shared rules that apply to all sub-repositories in a multi-repo AutoFlow project.

---

## Applicability

These rules apply to every sub-repository (e.g., backend, frontend, infra, docs) that participates in the AutoFlow lifecycle under a central orchestrator.

---

## Required Files

Every sub-repository **must** contain:

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Sub-repo operating manual (use templates from `subrepo-templates/`) |
| `.gitignore` | Must include `.autoflow/issue-*.json` |
| `README.md` | Project-specific documentation |

---

## AutoFlow State Ownership

AutoFlow state lives in the host (orchestrator) repository under `.autoflow/issue-{N}.json` — one file per issue. Sub-repos do not own AutoFlow state. A sub-repo that finds an `.autoflow/` directory locally should treat it as residual from a misconfigured run; the canonical state is in the host repo.

The host's hook (`.claude/hooks/check-autoflow-gate.sh`) reads the state file and computes pass/fail directly from raw `scores`. Sub-repo AIs do not write to the state file — they receive instructions through `SendMessage` from the orchestrator.

---

## Submodule URL & Pointer Policy

Applies to host repositories that operate a **host-private fork** as the submodule source — i.e., the fork carries host-private changes that are **not** bound for the upstream repository. The host repo's submodule pointer therefore lives in fork commits, not upstream commits. `setup/init.sh` substitutes each submodule's fork URL when the framework is propagated to a project (see [`credentials.md`](credentials.md) and `.autoflow/submodules.yaml`).

### URL — `.gitmodules` fixed to the host-operated fork

- `.gitmodules` is **never modified** in a PR. PR diffs must not touch `.gitmodules` (the URL is fixed at framework init to the host-operated fork).
- No local fork-URL override is needed: the URL is the fork to begin with.

### Pointer SHA — host `{{DEFAULT_BRANCH}}` reachability

- A commit that exists only on a fork **feature branch** (not yet merged into the fork's `{{DEFAULT_BRANCH}}`) **must not** appear as the submodule pointer on host `{{DEFAULT_BRANCH}}`. Fork feature branches can be deleted or force-pushed at any time; relying on them is a stale-pointer footgun.
- **Dev branch exception**: while a host PR's dev branch is open, the submodule pointer may temporarily reference a fork feature-branch SHA (normal for in-progress work). Reachability against fork `{{DEFAULT_BRANCH}}` is enforced at host-`{{DEFAULT_BRANCH}}`-merge time.

### Multi-developer concurrent work

- `.gitmodules` is **never** modified — the URL stays fixed.
- Each developer commits **only the submodule pointer** for their issue's dev branch.

### Sub-repo cycle close-out

When a sub-repo work cycle is complete:

1. Merge the fork feature branch into the fork's `{{DEFAULT_BRANCH}}`.
2. Reconcile the host's submodule pointer to this cycle's sub-repo merge commit on fork `{{DEFAULT_BRANCH}}` (in the host PR's dev branch, before host PR merge). **[MUST]** When several cycles are in review at once, reconcile **against the current `origin/{{DEFAULT_BRANCH}}`**, not the branch's stale fork point: host-PR merges (one at a time) advance the pointer, so a stale-base bump leaves the host PR conflicting. Resolve by fork ancestry — if this cycle's merge commit (`TARGET`) is a **descendant** of the current pointer, set the dev gitlink to `TARGET` first (`git -C <sub-repo> checkout <TARGET>; git add <sub-repo>; git commit`) **then** merge `origin/{{DEFAULT_BRANCH}}` (with the dev pointer at `TARGET` ⊇ current, the submodule stays at `TARGET`, no content conflict); if the current pointer is a descendant (a regression) or the two diverge, **escalate to the operator**. **[MUST]** The end-state pointer must equal `TARGET` — verify `git ls-tree HEAD <sub-repo> == TARGET` before pushing (a bare `git merge origin/{{DEFAULT_BRANCH}}` from an older dev pointer resolves the gitlink to the older SHA, failing the pointer check).
3. The fork feature branch may then be deleted; the pointer SHA is preserved on fork `{{DEFAULT_BRANCH}}`.

This lifecycle makes the **Pointer SHA — host `{{DEFAULT_BRANCH}}` reachability** rule hold without requiring branch-protection rules on every fork feature branch.

### Framework propagation

Operators initializing this framework on another project run `setup/init.sh`, which substitutes each submodule URL to point at the operator's own fork (same model — host-operated fork, host-private changes allowed). The Pointer SHA rule is unchanged: host `{{DEFAULT_BRANCH}}` always points at a commit reachable in the operator's fork.

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

### 4. AutoFlow Reference
```markdown
## AutoFlow
This repository follows the AutoFlow lifecycle defined in:
{{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}/CLAUDE.md

All AutoFlow phases, evaluation criteria, and gate rules apply.
```

---

## Agent Behavior Rules

### DO
- Follow the AutoFlow phases in order
- Run tests before marking the TDD cycle complete
- Use the Discussion Protocol for ambiguities
- Reference the orchestrator's CLAUDE.md for process questions

### DO NOT
- Skip the evaluation gate (GATE:QUALITY)
- Modify files in other repositories
- Push directly to `{{DEFAULT_BRANCH}}`
- Ignore evaluation feedback during revision (REVISION)

---

## Change Surface Rules

Every changed line must trace to the issue's acceptance criteria or the agreed plan. The scope of a cycle is exactly what the issue asked for — adjacent improvements belong to a separate issue.

### Trace rule
- **[MUST]** Each touched file/line answers the question: "which AC or plan item requires this?" If the answer is "none — I noticed it while I was here", revert that line.
- **[MUST]** Before opening the PR, run `git diff <base>...HEAD` and self-audit: any hunk without an AC ID in its rationale is removed.

### Surrounding code
- **[MUST]** Match the existing style and naming in the file you edit, even if you would write it differently in a greenfield.
- **[MUST]** Leave adjacent code, comments, formatting, and import order untouched unless an AC requires the change.
- **[MUST]** Pre-existing dead code, suspicious patterns, or stylistic inconsistencies you notice in passing are reported in the cycle report (one line each, with file:line). Filing a separate issue is the follow-up path; do not remove or "improve" them in this cycle.

### Over-engineering guard
The trace rule rejects scope creep *across* the change surface; this guard rejects depth creep *inside* it. Keep the solution to the minimum the current AC needs:
- **Scope**: don't add features, configurability, or "improvements" beyond the AC. A bug fix doesn't clean up surrounding code; a simple feature doesn't gain extra options.
- **Documentation**: don't add docstrings, comments, or type annotations to code you didn't change. Comment only where the logic isn't self-evident.
- **Defensive coding**: don't add error handling, fallbacks, or validation for scenarios that can't occur. Trust internal code and framework guarantees; validate only at system boundaries (user input, external APIs).
- **Abstractions**: don't create helpers or abstractions for a one-time operation, and don't design for hypothetical future requirements.

### Orphans from this cycle
- **[MUST]** Imports, variables, and functions that **your** changes rendered unused are removed in the same commit.
- **[MUST]** Do not remove pre-existing unused symbols unless an AC explicitly requires it.

### REFINE scope
REFINE applies the same trace rule: refactor suggestions that touch code outside the cycle's change surface are rejected, recorded in the report, and (if worth pursuing) filed as a new issue. The refactor tool's findings are advisory, not licence to expand the change surface.

### GATE:QUALITY linkage
GATE:QUALITY's `Minimal implementation` item is scored against this section's trace rule: a diff with hunks that do not trace to an AC fails the item regardless of code quality.

---

## Reporting Format

When a teammate reports to the orchestrator (or to another teammate via `SendMessage`), the message must follow this shape to keep token cost bounded (see host [`CLAUDE.md`](../CLAUDE.md#cost-control) > Cost Control):

1. **Reference paths, not bodies**: cite `.autoflow/*` files, source files, and commit hashes by path/hash. Do NOT paste full file bodies or document sections into messages.
2. **One-line summaries**: each finding, fix, or status item gets one line. Tables of ≤ 10 rows are allowed for structured results (test counts, coverage percentages).
3. **Test output**: report the test runner's summary line (e.g. jest `Tests: 147 passed, 147 total`; pytest `147 passed`) + coverage percentage. Never paste per-case PASS/FAIL lines or the full coverage report.
4. **Cited code excerpts**: when quoting code is unavoidable (e.g., to point out a bug), keep excerpts ≤ 10 lines AND verify the excerpt against the live file at quoting time — stale working-memory snapshots are a known incident pattern.
5. **Evidence anchor (mandatory)**: every "done" / "PASS" / "fixed" claim must end with one verifiable anchor — pick whichever fits:
   - code change → full 40-char commit SHA
   - test pass  → the exact `Tests: N passed, N total` (or equivalent) summary line, with the command that produced it
   - file state → `path:line` plus the verbatim content of that line

   Anchors must be deterministically re-derivable by the orchestrator (`git show <SHA>` / re-running the test command / `git show HEAD:<file>`). Reports without an anchor are rejected, not interpreted.

---

## Credentials

Sub-repo AIs follow the three-tier credential model. Full schemas live in [`credentials.md`](credentials.md); the sub-repo-side behaviour is:

- **Secrets** stay in the sub-repo's own `.env.local` / `.env*.local`. The Submodule AI must not read, echo, or commit their contents — even when diagnosing "is the value set?" use indirect checks (`test -n "$VAR"`, service health).
- **Credential references** for this sub-repo's fork live in the host's `.autoflow/auth.local.yaml` under `gh_users.submodules.<this-repo-name>`. Sub-repo AIs may read this file (read access across the boundary is permitted; see [`repo-boundary-rules.md`](repo-boundary-rules.md)) but must not write to it.
- **DELIVER (`git push origin <branch>`)** uses the gh login resolved from `gh_users.submodules.<name>`. Verify with `gh auth status` before push. If the resolved login is missing, fall back to `gh_users.orchestrator`.

Required `.gitignore` entries in every sub-repo:

```
.env
.env.local
.env*.local
```

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

### AutoFlow Gate Integration
The `check-autoflow-gate.sh` hook can be integrated into CI to verify:
- Evaluation score meets threshold
- All AutoFlow phases completed in order
- State files are consistent
