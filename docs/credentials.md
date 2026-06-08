# Credentials & Runtime State

> Where secrets, credential references, and runtime state live across the AutoFlow lifecycle.

This document is the source of truth for credential handling. `CLAUDE.md` (orchestrator) and `submodule-common-rules.md` (sub-repo AIs) reference this file rather than duplicating its contents.

---

## Three-Tier Separation

| Tier | Location | Checked in? | Contents |
|------|----------|-------------|----------|
| Secret | `.env`, `.env.local`, `.env*.local` | No (gitignored) | Actual tokens, API keys, passwords |
| Credential reference | `.autoflow/auth.local.yaml` | No (gitignored) | gh login name, ssh key path, profile alias — no secret values |
| Project config | `.autoflow/config.yaml`, `.autoflow/submodules.yaml` | Yes | Placeholder values, repo URLs, fork ↔ upstream map |

The principle mirrors Hermes's `.env` / `auth.json` / `config.yaml` split: **secret material is isolated from references, and references are isolated from project configuration other contributors must share.**

---

## Directory Layout

```
<host repo root>/
├── .env.local                          # secrets — gitignored
├── .autoflow/
│   ├── config.yaml                     # project config — checked in
│   ├── config.yaml.example             # schema reference — checked in
│   ├── submodules.yaml                 # fork ↔ upstream map (multi-repo only) — checked in
│   ├── submodules.yaml.example         # schema reference — checked in
│   ├── auth.local.yaml                 # credential references — gitignored
│   ├── auth.local.yaml.example         # schema reference — checked in
│   ├── logs/                           # phase transition logs — gitignored
│   └── issue-{N}.json                  # runtime state per issue — gitignored (existing)
└── ...
```

`setup/init.sh` generates `config.yaml` (and, for multi-repo, a `submodules.yaml` stub) from the `.example` templates. `auth.local.yaml` is not auto-generated — copy the example yourself when you're ready:

```bash
cp .autoflow/auth.local.yaml.example .autoflow/auth.local.yaml
```

Each sub-repo follows the same pattern at its own root for `.env*` files. Sub-repos do not host their own `auth.local.yaml`; credential references for all repos live in the host's file.

---

## File Schemas

### `.autoflow/config.yaml` (checked in)

Project-level placeholder values resolved by `setup/init.sh`. Read by hooks and agents; never contains secrets.

```yaml
github_org: connev-ontology
repo_orchestrator: ontology-platform
default_branch: main
repos:
  backend:  { name: ontology-api }
  frontend: { name: saiso }
```

### `.autoflow/submodules.yaml` (checked in; multi-repo only)

Maps each sub-repo to its upstream and the fork host used at LAND.

```yaml
submodules:
  ontology-api:
    upstream: connev-ontology/ontology-api
    fork:     librechat-webhook/ontology-api
  saiso:
    upstream: connev-ontology/saiso
    fork:     librechat-webhook/saiso
```

Single-repo deployments omit this file.

### `.autoflow/auth.local.yaml` (gitignored)

Machine-local credential references. Holds only names/paths — never the secret itself.

```yaml
gh_users:
  orchestrator: librechat-webhook       # gh login used for host PRs
  submodules:
    ontology-api: dev-account-1         # gh login used for ontology-api fork
    saiso:        dev-account-1
ssh_keys:
  default: ~/.ssh/id_ed25519            # local-machine path
```

Fallback rule: if `gh_users.submodules.<name>` is missing, the orchestrator's login is used.

---

## Required `.gitignore` Entries

```
.env
.env.local
.env*.local
.autoflow/auth.local.yaml
.autoflow/logs/
.autoflow/issue-*.json
```

Sub-repos add the `.env*` lines to their own `.gitignore`.

---

## Rules

### [MUST] No AI reads `.env*` files

No phase (DIAGNOSE, ARCHITECT, RED, GREEN, REFINE, …) is permitted to `cat` / `Read` / `Bash` the contents of `.env`, `.env.local`, or `.env*.local`. The application reads these at runtime; the AI never needs to.

If a value is required for diagnosis (e.g., "does the service have the right API key set?"), the AI verifies presence indirectly (`test -n "$VAR"`, service health check) rather than reading the file.

### [MUST] AI output must not contain secret values

Outputs include: agent messages, commit messages, PR bodies, issue comments, `.autoflow/logs/`, evaluation reports. If the AI receives a secret value in user input by accident, it must mask it before any echo.

Secret-shape patterns (used by AUDIT; see `security-checklist.md`):

- GitHub PAT: `^ghp_`, `^gho_`, `^ghs_`, `^ghu_`
- OpenAI / Anthropic: `^sk-`, `^sk-ant-`
- AWS access key: `^AKIA[0-9A-Z]{16}$`
- Generic env line inside a code block: `^[A-Z_][A-Z0-9_]*=.+$`

### [MUST] LAND uses the gh login that matches the role

At LAND, PR creation must run under the gh login defined in `.autoflow/auth.local.yaml`:

- Host PR (orchestrator scope) → `gh_users.orchestrator`
- Sub-repo PR for `<name>` → `gh_users.submodules.<name>` (falls back to orchestrator)

Switch context before `gh pr create`:

```bash
gh auth switch --user "$LOGIN"     # or: GH_TOKEN=$(...) gh pr create ...
gh auth status                     # verify
```

This is the codified version of CLAUDE.md > LAND step 4's "the fork account lacks upstream merge permission" note: the orchestrator account opens the host PR, each fork account opens its own sub-repo PR.

### [MUST] Sub-repo AIs do not write to host `.autoflow/auth.local.yaml`

Sub-repo AIs may **read** `.autoflow/auth.local.yaml` (read access across the boundary is permitted; see `repo-boundary-rules.md`) but must not modify it. Credential references for all repos are centralised in the host file.

### [DENY] Do not commit secret-shaped strings

Pre-commit / hook-level scanning rejects commits whose diff matches any pattern from the secret-shape list above. If a legitimate value matches the pattern (test fixtures, examples), it must be relocated to a `.env*.example` file with the secret replaced by a placeholder.

---

## Multi-Profile (Optional)

Hermes uses `$HERMES_HOME` to isolate multiple agent profiles. AutoFlow does not need this: each host repository is already a natural isolation unit, and credential references are scoped per host repo in `.autoflow/auth.local.yaml`.

If you need to run two AutoFlow projects with different gh logins on the same machine, set the per-project login in each repo's `auth.local.yaml`. There is no global AutoFlow directory.

---

## Migration From the Pre-Credentials Layout

For an existing repository that predates this document:

1. Add the new lines to `.gitignore` (see above).
2. Move any committed `.env*` files into `.env*.example` with secrets stripped; the real `.env.local` stays gitignored.
3. Create `.autoflow/auth.local.yaml` with the gh login(s) currently used. Do not include passwords or tokens.
4. (Multi-repo) Create `.autoflow/submodules.yaml` from the existing fork/upstream remote URLs.
5. Re-run `git status` and `git diff --cached` to confirm no secret values are staged.
