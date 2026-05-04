# Claude AutoFlow Template

A reusable template for structured, evaluation-gated AI-assisted software development with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Auto-Flow is a **14-phase development lifecycle** that ensures quality through multi-agent role separation, independent analysis, and quantified evaluation gates. This template lets you adopt the methodology in any project.

---

## What Is Auto-Flow?

Auto-Flow structures every code change through a defined lifecycle:

```
PREFLIGHT    Pre-Work                — Git clean check, branch creation
DIAGNOSE     3-Phase Analysis        — Independent bias-free analysis
GATE:HYPOTHESIS  Hypothesis Gate     — Scored hypothesis assessment (gate, bug issues only)
ARCHITECT    Plan Synthesis          — Merge analyses into a plan
GATE:PLAN    Plan Evaluation         — Scored plan assessment (gate)
DISPATCH     Task Assignment         — Delegate to Test AI and Developer AI
RED          Test Writing            — Tests from acceptance criteria (Red)
GREEN        Implementation          — Minimum code to pass tests
VERIFY       Green Verification      — All tests pass + minimal check
REFINE       Refactor                — Code cleanup, Green re-confirmation
GATE:QUALITY Evaluation             — Scored quality assessment (gate)
REVISION     Revision (if needed)   — Fix evaluation feedback
SHIP         PR & Review             — Submit for human review
LAND         Merge & Close           — Human approves and merges
```

### Key Features

- **Multi-Agent Roles**: Orchestrator, Developer, Test, and Evaluation AIs with separated responsibilities
- **3-Phase Independent Analysis**: Structure, Issue, and Cross-Verification analysis to prevent tunnel-vision bias
- **Evaluation Gate**: 10-point scoring system with defined PASS threshold (>= 7.5)
- **Hook Enforcement**: Shell hook validates Auto-Flow state before allowing commits/PRs
- **Multi-Repo Support**: Orchestrator pattern for coordinating work across multiple repositories

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

The setup wizard will ask for your project configuration and generate all files.

### Option B: Manual Setup

See [setup/SETUP-GUIDE.md](setup/SETUP-GUIDE.md) for manual setup instructions.

---

## Repository Structure

```
claude-autoflow/
│
├── README.md                          # This file
├── CLAUDE.md.template                 # Core template (placeholders)
├── CLAUDE.local.md.example            # Local override example
│
├── .claude/
│   └── hooks/
│       └── check-autoflow-gate.sh     # Auto-Flow gate hook
│
├── docs/
│   ├── autoflow-guide.md              # Phase-by-phase Auto-Flow guide
│   ├── git-workflow.md                # Git procedures
│   ├── repo-boundary-rules.md         # Cross-repo coordination rules
│   ├── submodule-common-rules.md      # Sub-repo shared rules
│   ├── security-checklist.md.template # Security checklist (customizable)
│   ├── maintained-docs.md.template    # Document registry template
│   └── evaluation-system.md           # Evaluation scoring details
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

The `CLAUDE.md` file is the operating manual for Claude Code. It defines:
- The Auto-Flow lifecycle and rules
- Agent roles and permissions
- Evaluation criteria and PASS threshold
- Git workflow and security requirements

### 2. Multi-Agent Separation

Different AI agents handle different responsibilities:

| Agent | Role | Can Write To |
|-------|------|-------------|
| **Orchestrator** | Coordinates, delegates | Orchestrator repo |
| **Developer** | Implements features | Assigned sub-repo |
| **Test** | Writes and runs tests | Test files in assigned repo |
| **Evaluation** | Scores quality | Nothing (read-only) |

### 3. Evaluation Gate

At GATE:QUALITY, an independent Evaluation AI scores the work across 5 categories:

| Category | Weight |
|----------|--------|
| Correctness | 25% |
| Quality | 20% |
| Test Coverage | 20% |
| Consistency | 20% |
| Documentation | 15% |

> This is the Meta (template-repo) default. Instance projects typically swap Consistency/Documentation for Security/Performance — see [docs/evaluation-system.md > Meta vs. Instance Context](docs/evaluation-system.md#meta-vs-instance-context).

**Overall score >= 7.5** is required to proceed, with no individual category below 7.

### 4. Hook Enforcement

The `check-autoflow-gate.sh` hook reads `.autoflow-state/` files to prevent:
- Committing before evaluation passes
- Creating PRs without meeting the PASS threshold
- Skipping required phases

---

## Customization

### Placeholders

Templates use `{{UPPER_SNAKE_CASE}}` placeholders:

| Placeholder | Description |
|------------|-------------|
| `{{PROJECT_NAME}}` | Your project name |
| `{{GITHUB_ORG}}` | GitHub organization or username |
| `{{REPO_ORCHESTRATOR}}` | Orchestrator repository name |
| `{{REPO_BACKEND}}` | Backend repository name |
| `{{REPO_FRONTEND}}` | Frontend repository name |
| `{{TECH_STACK_SUMMARY}}` | One-line tech stack description |
| `{{CI_SYSTEM}}` | CI tool (github-actions, jenkins, etc.) |
| `{{DEFAULT_BRANCH}}` | Default branch (main, master) |

### Single vs. Multi-Repo

- **Single repo**: Remove the `<!-- OPTIONAL SUBMODULE SECTION -->` from `CLAUDE.md`, skip `subrepo-templates/` and boundary rule docs
- **Multi-repo**: Keep everything, create sub-repo `CLAUDE.md` files using the templates

### Evaluation Tuning

- Adjust category **weights** to match your priorities (e.g., raise the AUTO-FAIL category's weight for higher-risk projects) — set `AUTO_FAIL_KEY` to switch the AUTO-FAIL category between contexts
- Adjust **PASS threshold** in both `CLAUDE.md` and `check-autoflow-gate.sh`
- Add **custom categories** (e.g., Accessibility for frontend-heavy projects) — see [docs/evaluation-system.md](docs/evaluation-system.md) for the customization mechanism

---

## Documentation

| Document | Description |
|----------|-------------|
| [**Design Rationale**](docs/design-rationale.md) | **Read first** — why every design decision was made |
| [Auto-Flow Guide](docs/autoflow-guide.md) | Detailed phase-by-phase lifecycle |
| [Evaluation System](docs/evaluation-system.md) | Scoring, PASS criteria, output format |
| [Git Workflow](docs/git-workflow.md) | Branch naming, commits, PR process |
| [Repo Boundary Rules](docs/repo-boundary-rules.md) | Cross-repo coordination rules |
| [Sub-Repo Common Rules](docs/submodule-common-rules.md) | Shared rules for sub-repos |
| [Security Checklist](docs/security-checklist.md.template) | Customizable security items |
| [Setup Guide](setup/SETUP-GUIDE.md) | Manual setup instructions |

---

## Post-Setup Checklist

After running `init.sh` or completing manual setup:

- [ ] `CLAUDE.md` generated with no remaining `{{placeholders}}`
- [ ] `docs/security-checklist.md` customized for your tech stack
- [ ] `docs/maintained-docs.md` lists your actual documents
- [ ] `.gitignore` includes `.autoflow-state/` and `CLAUDE.local.md`
- [ ] Hook is executable (`chmod +x .claude/hooks/check-autoflow-gate.sh`)
- [ ] Sub-repo `CLAUDE.md` files created (if multi-repo)

---

## Contributing

Contributions are welcome! Please:

1. Fork this repository
2. Create a feature branch (`feature/your-change`)
3. Follow the existing documentation style
4. Submit a PR with a clear description

---

## License

[MIT](LICENSE)
