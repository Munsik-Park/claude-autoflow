# GATE:HYPOTHESIS FAIL — Canonical Comment Template

When `.claude/scripts/post-hypothesis-fail` runs, it renders this template and
posts the result to the GitHub issue. The issue is left open; the disposition
decision (close as superseded / rescope / leave open / split) belongs to the
human author of the issue, not to the orchestrator.

This is an **evaluation observation, not a disposition decision**. See
[design-rationale.md > Decision 6](design-rationale.md#decision-6-structure-evaluation-fail-is-an-observation-not-a-disposition)
for the rationale.

---

## Template

```markdown
## GATE:HYPOTHESIS — Evaluation Observation (FAIL)

**Posted:** {{TIMESTAMP_UTC}}
**Issue:** #{{ISSUE_NUMBER}}
**Verdict:** FAIL

### Disclaimer
This is an **evaluation observation, not a disposition decision**. The fresh
Evaluation AI judged that the existing structure may handle the concern. The
disposition (close as superseded / rescope / leave open / split) is a human
decision. The Auto-Flow pipeline has terminated locally; the issue is left
open.

### Scores
{{SCORES}}

### Rationale
{{RATIONALE}}

### Analysis links
- Phase A (structure analysis): {{ANALYSIS_LINK}} — `analysis/phase-a.md`
- Phase B (issue analysis):     `analysis/phase-b.md`
- Phase 3 (cross-verification): `analysis/phase-3.md`
- Evaluator output:             `evaluation-hypothesis.json`

### Suggested next steps (human decides)
- close as superseded
- rescope the issue
- leave open for further investigation
- split into multiple issues
```

### Placeholder reference

| Token | Substituted value |
|---|---|
| `{{TIMESTAMP_UTC}}` | UTC ISO-8601 timestamp at comment-post time |
| `{{ISSUE_NUMBER}}` | The GitHub issue number (no `#` prefix) |
| `{{SCORES}}` | A formatted block of the per-category scores from `evaluation-hypothesis.json` |
| `{{RATIONALE}}` | The `rationale` field from `evaluation-hypothesis.json` |
| `{{ANALYSIS_LINK}}` | Path to `analysis/phase-3.md` (and siblings) — under `.autoflow-state/archive/...` after archive |

### Idempotency

Each FAIL run appends a NEW comment with a fresh `{{TIMESTAMP_UTC}}`. Prior
comments are NEVER edited. If the human re-opens disposition by reverting and
re-running, the comment thread documents every cycle.

---

## Worked Example

The following block shows what the rendered comment looks like for a fictional
issue #1234 whose evaluation JSON contained:

```json
{
  "phase": "GATE:HYPOTHESIS",
  "issue": "#1234",
  "evaluator": {
    "role_marker": "[role:eval-hypothesis]",
    "session_id": "ev-2026-05-04-abc"
  },
  "scores": {
    "structural_overlap":         { "score": 9, "reason": "preflight-sync handles this case" },
    "code_change_necessity":      { "score": 4, "reason": "no code change beyond docs" },
    "structural_change_necessity":{ "score": 3, "reason": "no new mechanism needed" }
  },
  "average": 5.33,
  "verdict": "FAIL",
  "rationale": "preflight-sync already covers the proposed sync trigger; the request appears to duplicate an existing mechanism."
}
```

### Rendered comment

```markdown
## GATE:HYPOTHESIS — Evaluation Observation (FAIL)

**Posted:** 2026-05-04T20:31:12Z
**Issue:** #1234
**Verdict:** FAIL

### Disclaimer
This is an **evaluation observation, not a disposition decision**. The fresh
Evaluation AI judged that the existing structure may handle the concern. The
disposition (close as superseded / rescope / leave open / split) is a human
decision. The Auto-Flow pipeline has terminated locally; the issue is left
open.

### Scores
| Category | Score | Reason |
|---|---|---|
| structural_overlap | 9 | preflight-sync handles this case |
| code_change_necessity | 4 | no code change beyond docs |
| structural_change_necessity | 3 | no new mechanism needed |
| **average** | **5.33** | — |

### Rationale
preflight-sync already covers the proposed sync trigger; the request appears
to duplicate an existing mechanism.

### Analysis links
- Phase A (structure analysis): `.autoflow-state/archive/self/1234-20260504T203112.123456789Z/analysis/phase-a.md`
- Phase B (issue analysis):     `.autoflow-state/archive/self/1234-20260504T203112.123456789Z/analysis/phase-b.md`
- Phase 3 (cross-verification): `.autoflow-state/archive/self/1234-20260504T203112.123456789Z/analysis/phase-3.md`
- Evaluator output:             `.autoflow-state/archive/self/1234-20260504T203112.123456789Z/evaluation-hypothesis.json`

### Suggested next steps (human decides)
- close as superseded
- rescope the issue
- leave open for further investigation
- split into multiple issues
```
