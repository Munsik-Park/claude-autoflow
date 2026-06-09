# Issue & PR Title Guide

Issue and PR titles must convey **type → epic position → issue number** at a glance
when scanning a list view. Group the common prefix in brackets and describe the rest freely.

## Format

```
[type · epic-slice · #N]  free description    ← epic sub-issue PR
[type · epic-slice]       free description    ← epic sub-issue (number unknown at creation)
[type · #N]               free description    ← standalone issue / epic tracker / standalone PR
```

| Field | Description |
|-------|-------------|
| `type` | `feat` / `fix` / `chore` / `docs` — see table below |
| `epic-slice` | Epic number and slice code (e.g., `#73-S3f`, `#72-S5a`). Used only for epic sub-issues |
| `#N` | GitHub issue number. **May be omitted in issue titles** (unknown before creation); **required in PR titles** |
| free description | No length or language restriction |

## Type values

| type | When |
|------|------|
| `feat` | New feature implementation |
| `fix` | Bug fix |
| `chore` | Configuration, infrastructure, automation |
| `docs` | Documentation-only change |

## Examples

### Issue titles

```
[feat · #73-S3f]  Usage history tab — date filter + search
[feat · #72-S5a]  Member management table frontend
[feat · #N]       Enterprise member activity audit log
[fix  · #N]       API adapter track.fetch() removal — subtitle fetch failure
[chore · #N]      PAT rotation documentation
```

### PR titles

```
[feat · #73-S3f · #N]  Usage history tab — date filter + search
[feat · #72-S5a · #N]  Member management table frontend
[feat · #N]             Enterprise member activity audit log (submodule pointer)
[fix  · #N]             API adapter track.fetch() removal
[chore · #N]            PAT rotation documentation
```

## Prefix composition rationale

`epic-slice` and `#N` serve different purposes. Using both together is not redundant.

| Reference | Meaning | Issue | PR |
|-----------|---------|-------|----|
| `epic-slice` (e.g., `#73-S3f`) | Which Epic and which slice | Yes | Yes |
| `#N` (issue number) | Which GitHub issue is being closed | Optional | **Required** |

For non-epic issues (standalone issue, epic tracker), omit `epic-slice` and use `#N` only.

## Relationship to commit messages

Commit message rules (`CLAUDE.md` > Commit Rules) are maintained separately.

```
feat(#N): usage history tab — date filter + search   ← commit
[feat · #73-S3f · #N] usage history tab              ← PR title
```

Commits use `type(#N):` format; issue and PR titles use `[type · ref]` format.
Both formats include `type` and issue number, so cross-tracing is straightforward.

---

## Changelog

- 2026-06-02: Initial draft.
