# PR Body Authoring Guide

Reference guide for writing PR bodies. Applies to both the AI orchestrator and manual PR authors.
This is a living document — principles may be added over time.

## Principles

### 1. Claim accuracy

The behaviors, verifications, and protection scope promised in the PR body must match
exactly what is actually implemented. Overstated claims (promises stronger than reality)
are caught during review and create additional round-trips.

- Strong language (machine-verified, fully enforced, idempotent, atomic, race-free, etc.)
  is only used when the implementation genuinely satisfies that level.
- Partial guarantees are stated partially — "X is machine-verified, Y is reviewer-attested"
  can and should be separated when that distinction exists.

### 2. Rejected alternatives

If alternatives were considered and rejected during the implementation decision process,
expose them in the body together with the rejection rationale. This allows reviewers to
assess whether the rejection is well-founded.

- Be precise about the rejection reason: "architectural boundary violation" vs.
  "cost trade-off" are distinct.
- Does not apply to trivial PRs (typo fixes, etc.).

### 3. Limitations and known gaps

State explicitly the paths this PR does not cover, residual risks, and items requiring
follow-up work. This prevents reviewers from re-catching issues already known to the author.

- Use a "What this PR does not cover" section or an inline paragraph in the body.
- Cross-reference follow-up issue numbers where available.

### 4. Explicit links to decision basis (PR-reachability)

The reviewer must be able to reach the decision basis starting from the PR. A document
existing in the repository is not sufficient — the PR must explicitly state which ADR /
design note / architecture context / acceptance criteria it relied on, in `path > section`
form.

- ADR / design note / architecture context are linked explicitly. If an ADR is not
  required, state the reason in one line ("ADR not required: ...").
- The linked issue's acceptance criteria must be reachable from the PR (issue link +
  AC section, or stated inline in the body). This prevents repeated false `High`
  findings caused by unverified AC.
- `.autoflow/*` scratch files are gitignored and therefore unreachable from the PR —
  do not link them as review evidence; move any decision basis the reviewer needs into
  linked issues or committed documents.

Policy: Repository documents may be used as review evidence only when the PR links or
names the relevant document/section, or when the reviewer independently discovers
directly relevant repo context while tracing the changed surface. Do not rely on
reviewers to infer hidden design intent from unrelated repository documents.

---

## Application

This guide is advisory. Some sections may not apply depending on PR type.

- [`autoflow-guide.md`](autoflow-guide.md) > HANDOFF cross-references this guide (AI orchestrator).
- Manual PR authors should consult the same principles.

When adding a new principle, preserve the format (name + body + 1-2 examples) and add
a one-line Changelog entry.

---

## Changelog

- 2026-06-05: Principle 4 (explicit links to decision basis / PR-reachability) added.
- 2026-05-22: Initial draft.
