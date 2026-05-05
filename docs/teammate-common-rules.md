# Teammate Common Rules

> Shared rules that apply to all teammates (Test AI, Developer AI) participating in
> the Auto-Flow lifecycle in this repository.

The orchestrator (the main session) coordinates work; teammates are spawned as
Agents and execute the actual writing of code, tests, and documentation. The rules
below describe the contract every teammate honours.

---

## Identity

- The teammate understands, implements, and tests files within its assigned scope.
- The teammate may **read** any file in the repository.
- The teammate **may not modify** files outside the scope assigned by the dispatch
  instructions for the current issue.
- PR creation is the orchestrator's responsibility — the teammate's git work
  finishes at `git push` of its branch.

---

## Git Workflow

```bash
# At session start (after the orchestrator has prepared a branch in PREFLIGHT)
git status                  # confirm a clean working tree
git log --oneline -5        # confirm the recent history

# After completing the assigned work
git add <files> && git commit
git push -u origin <branch-name>
# The orchestrator opens the PR — report completion via SendMessage.
```

**Absolute rules**:

- No direct commits to the default branch (`main`).
- No work on a new branch while the previous PR is still unmerged.
- Always run `git status` before committing.
- No `feat`/`fix` commit while tests are failing — use `wip` instead.

---

## Commit Format

```
<type>(#<issue>): <description>

Next: <what comes next>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

`type`: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`.

---

## Session Protocol

At the start of each session:

```bash
git log --oneline -5        # what was last committed
git status                  # any uncommitted work?
```

1. Read the `Next:` line in the most recent commit and continue from there.
2. Read pending `SendMessage` from the orchestrator (delivered automatically via
   Agent Teams).

---

## Work Completion Process

```
Implement → /simplify → tests pass → push branch → SendMessage report
```

**Required content of the completion report** (`SendMessage(to: "team-lead")`):

- Files changed.
- Test results (pass/fail).
- Cross-cutting impact (interfaces, data structures, config).
- Caveats or known limitations.
- Branch name and final commit hash.

---

## Communication — Agent Teams

The orchestrator spawns teammates with `Agent` (`team_name`, `name`). Messages are
push-delivered.

| Action | Method | Note |
|--------|--------|------|
| Receive instruction from orchestrator | automatic (push) | message arrives via Agent Teams |
| Discuss with another teammate | `SendMessage(to: "name")` | direct, no orchestrator routing |
| Report to orchestrator | `SendMessage(to: "team-lead")` | completion, escalation |
| Mark task done | `TaskUpdate(status: "completed")` | then check `TaskList` |
| Cross-cutting impact notice | `SendMessage` | to affected teammate, or to lead |

---

## Discussion Protocol (Single Source of Truth)

The rules below govern every multi-AI discussion. They prevent groundless agreement
and force grounded judgement. The orchestrator's `CLAUDE.md` references this section
as the canonical Discussion Protocol.

**Response process**:

1. **UNDERSTAND** — restate the other party's proposal in concrete terms (a bare
   "I understand" is not acceptable).
2. **VERIFY** — actually **read** the relevant source files, schemas, and config.
   Memory alone is not enough.
3. **EVALUATE** — assess on at least two of:
   - Feasibility — is this possible with the current code/infrastructure?
   - Fit — does it follow existing patterns, naming, and layering?
   - Trade-offs — cost, maintenance, migration complexity?
   - Alternatives — is there a simpler path?
   - Scope — is the level of abstraction right?
4. **RESPOND** — exactly one of:
   - **ACCEPT** — name the dimensions verified and why each passed.
   - **COUNTER** — state the problem + a concrete alternative + evidence.
   - **PARTIAL** — accept the parts that pass; counter the parts that don't.
   - **ESCALATE** — fundamental disagreement → present both sides to the user.

**Anti-patterns (forbidden)**:

- "Sounds good" — no agreement without naming the dimension verified and why.
- Evaluating code/schema/config proposals without reading the file.
- Stacking new features on top of unverified proposals.
- Agreeing on the first exchange — at least one dimension must be reviewed as
  devil's advocate.
- Letting a raised concern go unanswered — re-raise until resolved.

---

## Quality Standards

- Read and understand the existing code before changing it.
- Run the relevant tests after each change and confirm they pass.
- Run `/simplify` after implementation as a self-optimization step.
- Do not add unnecessary refactors, comments, or type annotations.
- Do not introduce security vulnerabilities.
- Do not make changes outside the assigned scope.

---

## Documentation Rules

- Code/policy: English.
- Markdown docs: English (source of truth).
- HTML docs: Korean (translation), if maintained.
- Interface changes require updating the related docs.
