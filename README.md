# Claude AutoFlow Template

A reusable template for structured, evaluation-gated AI-assisted software development with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Auto-Flow is a 16-phase development lifecycle (PREFLIGHT → LAND) that ensures
quality through multi-agent role separation, independent analysis, and
quantified evaluation gates. This template is the **generalized form** of the
methodology originally implemented in `ontology-platform` — a multi-sub-repo
deployment orchestrator. The only changes from upstream are:

1. **Name generalization** — numeric `STEP 0~9` (and `5a/5b/5c/5d/5.5/5.7`) identifiers replaced by semantic phase names.
2. **Identifier placeholders** — service-specific names (`ontology-api`, `saiso`, etc.) replaced by `{{REPO_*}}`/`{{GITHUB_ORG}}` placeholders.

Every rule, retry cap, evaluation category, and pass threshold is preserved
from upstream. Single-repo projects are supported as the degenerate case
(DELIVER pushes one branch, INTEGRATE / LAND collapse to a single PR flow).

---

## What Is Auto-Flow?

Auto-Flow structures every code change through a defined lifecycle:

```
PREFLIGHT       Pre-Work          — Git clean check, branch creation
DIAGNOSE        3-Phase Analysis  — Independent bias-free analysis
GATE:HYPOTHESIS Hypothesis Eval   — Scored hypothesis assessment (gate, bug issues only)
ARCHITECT       Plan Synthesis    — Feature design + verification design
GATE:PLAN       Plan Evaluation   — Scored plan assessment (gate)
DISPATCH        Task Assignment   — Delegate to Test AI and Developer AI
RED             Test Writing      — Tests from acceptance criteria (Red)
GREEN           Implementation    — Minimum code to pass tests
VERIFY          Test Run + Check  — All tests pass + minimal-implementation check
REFINE          Refactor          — Code cleanup, Green re-confirmation
VALIDATE        Verification Done — automated + manual + maintained-docs check
AUDIT           Security Audit    — Independent project-specific security audit
GATE:QUALITY    Completion Eval   — Scored quality assessment (gate)
DELIVER         Sub-Repo Push     — each Submodule AI pushes its fork branch; Teammate shutdown
INTEGRATE       Integration Test  — system build, health check, functional test
LAND            PR + Merge + Close — sub-repo PRs first → pointer bump → host PR → merge → cleanup
```

The happy-path flow at a glance (regression edges and human-escalation paths
are omitted; see [`docs/autoflow-guide.md`](docs/autoflow-guide.md) for the
full diagram):

```mermaid
flowchart LR
    PRE([PREFLIGHT]) --> DIA[DIAGNOSE]
    DIA --> HYP{{GATE:HYPOTHESIS}}
    HYP --> ARC[ARCHITECT]
    ARC --> PLAN{{GATE:PLAN}}
    PLAN --> DIS[DISPATCH]
    DIS --> RED[RED]
    RED --> GREEN[GREEN]
    GREEN --> VER[VERIFY]
    VER --> REF[REFINE]
    REF --> VAL[VALIDATE]
    VAL --> AUD{{AUDIT}}
    AUD --> QUAL{{GATE:QUALITY}}
    QUAL --> DEL[DELIVER]
    DEL --> INT[INTEGRATE]
    INT --> LAND([LAND])

    classDef gate fill:#fff8e1,stroke:#f57f17,color:#bf360c
    class HYP,PLAN,AUD,QUAL gate
```

### Key Features

- **Multi-Agent Roles** — Orchestrator, Submodule AI (Developer), Test AI, Evaluation AI with separated responsibilities.
- **3-Phase Independent Analysis** — Structure / Issue / Cross-Verification analyses to prevent tunnel-vision bias.
- **Evaluation Gates** — 10-point scoring system with a defined PASS threshold (≥ 7.5, each ≥ 7, security ≤ 3 → block).
- **Hook Enforcement** — A shell hook validates Auto-Flow state before allowing Agent spawns, `git push`, or `gh pr create`.
- **Multi-Sub-Repo Support** — orchestrator pattern for coordinating work across submodules; single-repo is the degenerate case.

---

## Quick Start

### Option A: Automated Setup

```bash
# Clone this template
git clone https://github.com/<your-org>/claude-autoflow.git my-project
cd my-project

# Run the interactive setup
chmod +x setup/init.sh
./setup/init.sh
```

The setup wizard asks for project configuration and generates the files.

### Option B: Manual Setup

See [`setup/SETUP-GUIDE.md`](setup/SETUP-GUIDE.md) for manual setup.

---

## Repository Structure

```
claude-autoflow/
│
├── README.md
├── CLAUDE.md.template                 # Core operating manual (placeholders)
├── CLAUDE.local.md.example            # Local override example
│
├── .claude/
│   └── hooks/
│       └── check-autoflow-gate.sh     # Auto-Flow gate hook
│
├── docs/
│   ├── design-rationale.md            # Why every rule exists — read first
│   ├── autoflow-guide.md              # Phase-by-phase Auto-Flow guide
│   ├── evaluation-system.md           # Evaluation scoring details
│   ├── git-workflow.md                # Git procedures
│   ├── repo-boundary-rules.md         # Cross-repo coordination rules
│   ├── submodule-common-rules.md      # Sub-repo shared rules + Discussion Protocol
│   ├── security-checklist.md.template # Security checklist (customizable)
│   └── maintained-docs.md.template    # Document registry template
│
├── subrepo-templates/
│   ├── _common/
│   │   └── CLAUDE.md.template         # Generic sub-repo template
│   ├── backend/
│   │   └── CLAUDE.md.template         # Backend-specific template
│   └── frontend/
│       └── CLAUDE.md.template         # Frontend-specific template
│
└── setup/
    ├── init.sh                        # Interactive setup script
    └── SETUP-GUIDE.md                 # Manual setup guide
```

---

## How It Works

### 1. CLAUDE.md Drives AI Behavior

`CLAUDE.md` is the operating manual for Claude Code. It defines the Auto-Flow
lifecycle and rules, agent roles and permissions, evaluation criteria, and the
Git workflow.

### 2. Multi-Agent Separation

| Agent | Role | Can Write To |
|-------|------|--------------|
| **Orchestrator** | Coordinates, delegates | Host repo (rules, config, infra, bulk docs) |
| **Submodule AI (Developer)** | Implements features per sub-repo | Files within the assigned sub-repo |
| **Test AI** | Writes and runs tests | Test files within the assigned sub-repo |
| **Evaluation AI** | Scores quality | Nothing (read-only) |

### 3. Evaluation Gates

At GATE:HYPOTHESIS, GATE:PLAN, AUDIT, and GATE:QUALITY, a freshly spawned
Evaluation AI scores the work. PASS = average ≥ 7.5, each item ≥ 7, security
score ≤ 3 → automatic rework. Categories and weights are customisable per
project.

### 4. Hook Enforcement

`check-autoflow-gate.sh` reads `.autoflow/issue-{N}.json` to prevent Agent
spawns, `git push`, and `gh pr create` from running before the corresponding
gate has passed. The hook computes verdicts directly from raw `scores` — it
never trusts an AI-supplied `pass` field.

---

## Customization

### Placeholders

Templates use `{{UPPER_SNAKE_CASE}}` placeholders:

| Placeholder | Description |
|-------------|-------------|
| `{{PROJECT_NAME}}` | Project name |
| `{{GITHUB_ORG}}` | GitHub organization or username |
| `{{REPO_ORCHESTRATOR}}` | Host (orchestrator) repository name |
| `{{REPO_BACKEND}}` | Backend sub-repo name (optional) |
| `{{REPO_FRONTEND}}` | Frontend sub-repo name (optional) |
| `{{REPO_INFRA}}` | Infrastructure sub-repo name (optional) |
| `{{DEFAULT_BRANCH}}` | Default branch (typically `main`) |
| `{{CI_SYSTEM}}` | CI tool (e.g., `github-actions`, `jenkins`) |
| `{{TECH_STACK_SUMMARY}}` | One-line tech stack description |
| `{{COMMUNICATION_LANGUAGE}}` | Language for user communication (e.g., `English`, `Korean`) |

### Single-Repo vs. Multi-Repo

- **Multi-repo** (default): leave the sub-repo placeholders filled in; sub-repos use `subrepo-templates/`.
- **Single-repo**: leave only `REPO_ORCHESTRATOR` and skip the sub-repo placeholders. The lifecycle's DELIVER and INTEGRATE phases collapse to no-ops or single-PR flows.

### Evaluation Tuning

- Adjust category **weights** to match your priorities.
- Adjust the **PASS threshold** in both `CLAUDE.md` and `check-autoflow-gate.sh`.
- Add **custom categories** as needed.

---

## Documentation

| Document | Description |
|----------|-------------|
| [**Design Rationale**](docs/design-rationale.md) | **Read first** — why every design decision was made |
| [Auto-Flow Guide](docs/autoflow-guide.md) | Detailed phase-by-phase lifecycle |
| [Evaluation System](docs/evaluation-system.md) | Scoring, PASS criteria, output format |
| [Git Workflow](docs/git-workflow.md) | Branch naming, commits, PR process |
| [Repo Boundary Rules](docs/repo-boundary-rules.md) | Cross-repo coordination |
| [Sub-Repo Common Rules](docs/submodule-common-rules.md) | Discussion Protocol, sub-repo rules |
| [Security Checklist](docs/security-checklist.md.template) | Customisable security items |
| [Setup Guide](setup/SETUP-GUIDE.md) | Manual setup instructions |

---

## Post-Setup Checklist

After running `init.sh` or completing manual setup:

- [ ] `CLAUDE.md` generated with no remaining `{{placeholders}}`.
- [ ] `docs/security-checklist.md` customised for your tech stack.
- [ ] `docs/maintained-docs.md` lists your actual documents.
- [ ] `.gitignore` includes `.autoflow/issue-*.json` and `CLAUDE.local.md`.
- [ ] Hook is executable (`chmod +x .claude/hooks/check-autoflow-gate.sh`).
- [ ] Sub-repo `CLAUDE.md` files created (if multi-repo) using `subrepo-templates/`.

---

## Contributing

1. Fork this repository.
2. Create a feature branch (`feature/your-change`).
3. Follow the existing documentation style.
4. Submit a PR with a clear description.

Note: this repository is the **generalized form** of `ontology-platform`'s
Auto-Flow methodology. New methodology changes belong in the upstream project
first; this repository tracks rather than diverges.

---

## License

[MIT](LICENSE)
