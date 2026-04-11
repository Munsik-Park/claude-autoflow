# Claude AutoFlow Template — Work Plan

> **Goal**: Generalize the Claude Code operating methodology (Auto-Flow) from `ontology-platform` into a publicly reusable template repository that can be easily ported to other projects.

---

## Background and Scope

### What Is Being Ported
The Claude Code operating know-how embedded in `Munsik-Park/ontology-platform`'s CLAUDE.md, hooks, and docs:
- Auto-Flow (PREFLIGHT–LAND) development lifecycle
- 3-Phase independent structure analysis (bias prevention)
- Multi-agent role separation (orchestrator / Developer AI / Test AI / Evaluation AI)
- Hook-based evaluation gate (`check-autoflow-gate.sh`)
- Discussion Protocol
- Evaluation system (10-point scale, PASS criteria)

### Assumed Structure
- **Top orchestration repo** (this template is the target) + **function-specific sub-repos**
- Sub-repo examples: `frontend`, `backend`, `infra`, `docs`, and similar common forms
- Cross-repo boundary rules (no direct modification across services)

---

## Deliverables (Repo Structure)

```
claude-autoflow-template/
│
├── README.md                          # Overview + porting guide
├── CLAUDE.md.template                 # Core template (with placeholders)
├── CLAUDE.local.md.example            # Local override example
│
├── .claude/
│   └── hooks/
│       └── check-autoflow-gate.sh     # Generic hook (no modification needed)
│
├── docs/
│   ├── autoflow-guide.md              # Auto-Flow step-by-step detail
│   ├── git-workflow.md                # Git procedure (generic)
│   ├── repo-boundary-rules.md         # Cross-repo boundary rules (generalized)
│   ├── submodule-common-rules.md      # Sub-repo common rules (generalized)
│   ├── security-checklist.md.template # Security checklist (generalized + replacement guide)
│   ├── maintained-docs.md.template    # Maintained document list template
│   └── evaluation-system.md           # Evaluation system description
│
├── subrepo-templates/
│   ├── frontend/
│   │   └── CLAUDE.md.template         # CLAUDE.md for frontend sub-repo
│   ├── backend/
│   │   └── CLAUDE.md.template         # CLAUDE.md for backend sub-repo
│   └── _common/
│       └── CLAUDE.md.template         # Common sub-repo rules
│
└── setup/
    ├── init.sh                        # Interactive initialization script
    └── SETUP-GUIDE.md                 # Manual porting guide
```

---

## Phase-by-Phase Work Plan

### Phase 1: Separation and Analysis (Preparation)
**Goal**: Clearly separate the current `ontology-platform` content into a "generic layer" and a "project-specific layer."

| Task | Description | Deliverable |
|------|-------------|-------------|
| 1-1 | Read CLAUDE.md line by line and tag each item for generalizability | Analysis notes |
| 1-2 | Extract list of project-specific elements | Placeholder list |
| 1-3 | Confirm generalizability scope for each file in docs/ | Per-file handling policy |

**Project-Specific → Generic Mapping (Confirmed)**

| Current (Specific) | Template (Generic) |
|--------------------|--------------------|
| Service names like `ontology-api`, `saiso` | `{{REPO_BACKEND}}`, `{{REPO_FRONTEND}}`, etc. |
| Org name `connev-ontology` | `{{GITHUB_ORG}}` |
| OAuth 2.1, Keycloak, SPARQL security items | 5 generic web-service security items + replacement guide |
| Cross-service boundary rules | Cross-repo boundary rules |
| Agent Teams (`SendMessage`) | Keep as-is (generic Claude Code feature) |
| Fork/upstream structure | Optional (single-repo / multi-repo options) |

---

### Phase 2: Core File Authoring

#### 2-1. Authoring `CLAUDE.md.template`
**The most important file.** Authored according to these principles:

- **Fixed sections** (no modification needed): Auto-Flow step definitions, evaluation system, hook gate, Discussion Protocol
- **Replacement sections** (placeholders): Sub-repo names, org name, security stack, role names in commit ownership table
- **Optional sections** (commented out): Blocks to remove for projects not using a sub-module structure

Placeholder format: `{{UPPER_SNAKE_CASE}}`

Key placeholder list:
```
{{PROJECT_NAME}}          - Project name
{{GITHUB_ORG}}            - GitHub organization name
{{REPO_ORCHESTRATOR}}     - Orchestration repo name
{{REPO_BACKEND}}          - Backend repo name (multiple allowed)
{{REPO_FRONTEND}}         - Frontend repo name
{{REPO_INFRA}}            - Infrastructure repo name (optional)
{{TECH_STACK_SUMMARY}}    - One-line tech stack summary (for security checklist)
{{CI_SYSTEM}}             - CI tool (Jenkins / GitHub Actions / CircleCI / etc.)
{{DEFAULT_BRANCH}}        - Default branch name (main / master)
```

#### 2-2. Verifying `check-autoflow-gate.sh` for Generic Use
The current hook is already written generically. Items to verify:
- `CLAUDE_PROJECT_DIR` environment variable dependency → keep (Claude Code standard)
- No hardcoded paths → no modification needed
- Issue-number-based state file pattern → keep

#### 2-3. Authoring `docs/repo-boundary-rules.md`
Generalize `ontology-platform`'s "Cross-Project Boundary Rules" into cross-repo rules:
- Read/write scope for each repo's AI
- Cross-repo change coordination procedure (using Agent Teams)
- Exception cases where the orchestrator commits directly

#### 2-4. Authoring `docs/security-checklist.md.template`
Generalize the current platform-specific items (OAuth 2.1, Keycloak, SPARQL, RabbitMQ, C2C):

**5 Generic Items (for general web services)**:
1. Authentication/Authorization — endpoint access control
2. Input validation — SQL/NoSQL/external input escaping
3. Data exposure — preventing sensitive data in logs/responses
4. Infrastructure isolation — preventing internal service port exposure
5. Dependency vulnerabilities — checking external library CVEs

Include a "project-specific example" block as a comment after each item to guide replacements.

#### 2-5. Authoring `subrepo-templates/`
Minimal CLAUDE.md templates for each sub-repo type:
- Define the repo's own scope
- Communication method with the top orchestrator
- How to perform Test AI / Developer AI roles
- Links to common rules

#### 2-6. Authoring `setup/init.sh`
```bash
# Interactive initialization flow
1. Enter project name
2. Enter GitHub org/user name
3. Enter sub-repo list (frontend, backend, infra, ...)
4. Choose CI system (GitHub Actions / Jenkins / Other)
5. Enter tech stack summary
6. Substitute CLAUDE.md.template → CLAUDE.md
7. Substitute security-checklist.md.template → security-checklist.md
8. Output completion message
```

---

### Phase 3: README and Documentation

#### 3-1. Authoring `README.md`
- What this template is (introduction to the Auto-Flow methodology)
- Quick Start: run `init.sh` or manual porting
- Repo structure description
- Post-porting checklist
- How to contribute (CONTRIBUTING.md)

#### 3-2. Authoring `docs/autoflow-guide.md`
Extract the Auto-Flow explanation embedded in CLAUDE.md into a standalone document:
- Purpose and completion criteria for each phase
- Flow Control table
- Regression rules
- Execution principles

#### 3-3. Authoring `docs/evaluation-system.md`
Standalone documentation of the evaluation system:
- Meaning of the 10-point scale
- PASS criteria
- Categories per evaluation type
- Output format (JSON)
- Integration with the hook

---

### Phase 4: Validation

| Task | Method |
|------|--------|
| 4-1 Placeholder completeness check | `grep -r '{{' .` to confirm no missing placeholders |
| 4-2 init.sh functional validation | Run it and verify substitution results |
| 4-3 Hook functional validation | Use test state files to verify gate-blocking scenarios |
| 4-4 Porting simulation to another project | Porting test on a mock project (e.g., `todo-app`) |

---

## Work Environment and Recommended Order

### Where to Work

| Phase | Environment | Reason |
|-------|-------------|--------|
| Design discussion / direction decisions | Claude.ai chat (here) | Conversational decision-making |
| File creation / git operations | **Claude Code** | Direct file creation, bash execution, iterative edits |
| Final review / feedback | Claude.ai chat or Claude Code | By preference |

### Prerequisites Before Starting
1. Create a new public repo on GitHub (e.g., `claude-autoflow-template`)
   - Recommended: enable the "Template repository" checkbox
2. Create it with only a `README.md` in its initial state
3. `git clone` in Claude Code, then begin work

### First Command in Claude Code
```
I want to turn this repo into claude-autoflow-template.
Please read the work plan (claude-autoflow-template-workplan.md)
and start from Phase 1.
```

---

## Core Design Principles (Maintain During Work)

1. **Do not touch Auto-Flow logic** — Phase definitions, evaluation criteria, and hook logic stay generic as-is
2. **Minimize placeholders** — Only what is essential. Too many raises the porting cost
3. **Optional sections as comments** — A "remove from here to here" guide for projects that don't need sub-modules
4. **Keep sub-repo CLAUDE.md thin** — Reference the orchestrator CLAUDE.md rather than copying it
5. **Portable without init.sh** — Support manual porting via `SETUP-GUIDE.md`

---

## Open Decisions (Confirm Before Starting)

| Item | Option A | Option B | Current Status |
|------|----------|----------|----------------|
| Repo name | `claude-autoflow-template` | `auto-flow-template` | Undecided |
| Sub-module structure default | git submodule approach | Independent repo approach | Undecided |
| Language | Korean README | English README | English recommended (public repo) |
| License | MIT | Apache 2.0 | Undecided |
