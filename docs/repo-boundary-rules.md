# Repository Boundary Rules

> Defines the scope of each AI agent's access and the rules for cross-repository coordination.

---

## Core Principle

**Each AI agent operates within its assigned repository only.**

Cross-repository modifications require explicit coordination through the Orchestrator, ensuring traceability and preventing conflicting changes.

---

## Permission Matrix

| Agent | Own Repo | Other Repos | Orchestrator Repo |
|-------|----------|-------------|-------------------|
| **Developer AI** | Read + Write | Read only | Read only |
| **Test AI** | Read + Write (test files) | Read only | Read only |
| **Evaluation AI** | Read only | Read only | Read only |
| **Orchestrator AI** | — | Read only* | Read + Write |

*Exception: Orchestrator may make configuration-level changes in sub-repos when documented (see Exceptions below).

---

## Rules in Detail

### Rule 1: No Cross-Repo Direct Commits

An AI agent assigned to `repo-backend` **must not** commit to `repo-frontend`, even if the change is trivial (e.g., updating an API URL constant).

**Why**: Cross-repo commits bypass that repo's Auto-Flow evaluation cycle, creating unreviewed changes.

**Instead**: The Orchestrator creates a sub-issue in the target repo, and that repo's Developer AI handles it.

### Rule 2: Read Access Is Allowed

Any agent can **read** files from other repos to understand interfaces, contracts, or dependencies. This is encouraged for:
- Understanding API contracts
- Checking shared type definitions
- Verifying integration points

### Rule 3: Orchestrator Coordinates, Doesn't Implement

The Orchestrator AI's job is to:
- Break down cross-repo work into per-repo issues
- Sequence the work to avoid conflicts
- Verify integration after individual repos merge

The Orchestrator should **not** write implementation code in sub-repos.

### Rule 4: Interface Changes Require Coordination

When a change in one repo affects the interface used by another:

1. Developer AI raises a Discussion with proposed interface change
2. Orchestrator evaluates impact across all affected repos
3. Orchestrator creates issues in affected repos
4. Changes are implemented repo-by-repo in dependency order
5. Integration testing validates the change across repos

---

## Exceptions

### Documented Orchestrator Cross-Repo Actions

The Orchestrator may make the following changes in sub-repos:

| Action | Scope | Condition |
|--------|-------|-----------|
| Update shared config files | `.env.example`, CI config | When coordinating infra changes |
| Update version references | `package.json`, `pyproject.toml` | When bumping shared dependency versions |
| Add integration test hooks | Test config files | When setting up cross-repo testing |

All exceptions must be:
- Documented in the PR description
- Limited to configuration, not implementation
- Reviewed by a human

---

## Communication Flow

```
┌─────────────────────────────────┐
│        Orchestrator AI          │
│    ({{REPO_ORCHESTRATOR}})      │
├─────────────────────────────────┤
│  - Creates sub-issues           │
│  - Coordinates merge order      │
│  - Verifies integration         │
└───────┬───────────┬─────────────┘
        │           │
   ┌────▼───┐  ┌────▼────┐
   │Backend │  │Frontend │
   │  AI    │  │   AI    │
   │--------│  │---------|
   │Read/   │  │Read/    │
   │Write   │  │Write    │
   │own repo│  │own repo │
   └────────┘  └─────────┘
```

### Agent Teams Communication

Agents use `SendMessage` (Claude Code's built-in agent communication) to coordinate:

```
Orchestrator → Backend AI:
  "Implement new /users endpoint per issue #42. 
   See requirements in .autoflow-state/42/requirements.md"

Backend AI → Orchestrator:
  "Implementation complete. New endpoint: GET /api/v1/users.
   Response schema documented in docs/api.md"

Orchestrator → Frontend AI:
  "New backend endpoint available: GET /api/v1/users.
   Implement user list page per issue #43.
   Backend PR: repo-backend#15"
```

---

## Conflict Resolution

When two repos need changes that conflict (e.g., incompatible interface changes):

1. **Detect**: Orchestrator identifies the conflict during coordination
2. **Pause**: Both repos pause their Auto-Flow at current phase
3. **Resolve**: Orchestrator proposes resolution via Discussion Protocol
4. **Agree**: Resolution documented and agreed upon
5. **Resume**: Repos resume with the agreed approach

---

## Checklist for Cross-Repo Changes

Before starting a cross-repo change:

- [ ] Orchestrator has created tracking issue
- [ ] Sub-issues exist in each affected repo
- [ ] Merge order is defined
- [ ] Interface contracts are documented
- [ ] Rollback plan exists (what if one repo's change fails?)
