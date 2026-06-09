# Code Review Instructions

Source basis: synthesized from <https://claude.com/blog/code-review>. Do not treat this file as a copy of the article; it is the repo's operational review guide.

## Before Reviewing

- Read the issue summary, acceptance criteria, PR description, and full PR diff.
- For GitHub PRs or issues, use the local `gh` CLI for metadata, comments, checks, and diffs. Do not rely on public web access for private or permission-restricted repositories.
- Identify the changed surfaces, adjacent code that the diff depends on, and any external contracts affected by the change.
- If the PR crosses a repo boundary — submodule pointers, dispatch workflows, or merge sequencing — also check the relevant repo-boundary and external-review docs.
- Use repository documents as review evidence **only** when the PR links or names the relevant document/section, or when you independently discover directly relevant repo context while tracing the changed surface. Do not infer hidden design intent from unrelated repository documents, and do not treat a linked design doc as a reason to pass a change you cannot verify from the diff.
- Read the **linked issue's acceptance criteria** before judging correctness; a "does not satisfy the contract" finding must be checked against the actual AC reachable from the PR, not an assumed contract.

## Review Posture

- Optimize for depth over speed. The review should catch issues a skim would miss.
- Treat the review as a bug-finding pass, not a style pass or general advice pass.
- Look for concrete bugs, regressions, security issues, data loss risks, broken contracts, and missing tests.
- Scale review depth with PR size and complexity: trivial PRs get a lightweight pass; large, risky, or cross-boundary PRs get deeper inspection of adjacent code and failure paths.
- Do not merge, close issues, or perform release/deployment actions as part of review. These actions are outside the review role.
- Do not submit an approval or request-changes review state unless the user explicitly asks for that review state.
- Keep style, naming, and preference feedback out of blocking findings unless it creates a real maintainability or correctness risk.
- Review against the stated contract in the PR and its linked AC; do not expand the contract merely because a stricter invariant can be imagined. A finding that depends on an assumed, unstated contract is not a confirmed finding — downgrade it to `Low Confidence` or omit it.
- A finding's decision basis must be reachable from the PR: the diff, linked issues, or documents the PR explicitly references. Repo-level docs (ADRs, design docs, acceptance criteria) count as evidence only when the PR links or names them. Do not raise repeated `High` findings against an assumed contract the PR did not state.

## Review Method

- Search for possible bugs from multiple angles in parallel: changed behavior, adjacent dependencies, tests, security, operational flow, and user-facing contracts.
- Verify each suspected bug before reporting it. Trace the code path, compare it with the issue or PR claim, and check whether tests would catch it.
- Filter false positives aggressively. If the evidence is weak, move the item to `Low Confidence` or omit it.
- Rank confirmed findings by severity and user impact.
- Produce one high-signal overview instead of many scattered observations.
- Add inline-comment candidates only when a finding maps to a specific changed line.
- After completing a GitHub PR review, post the review result back to the PR using the local `gh` CLI unless the user explicitly says not to comment.
- Posting a review comment is allowed by default.
- After posting the PR review comment, remove the `blocked-by-review` label from the PR using `gh pr edit <PR_NUMBER> --remove-label blocked-by-review` when there are no confirmed `Critical`, `High`, or `Medium` findings. This is a required review-completion step because the label acts as a pipeline gate. Run it for externally triggered reviews as well as interactive reviews. Do not remove the label when any confirmed `Critical`, `High`, or `Medium` finding remains. If label removal fails, report the failure clearly and do not claim that the review workflow completed successfully.
- Submitting an approval or request-changes review state requires explicit user instruction.
- Merging, closing issues, and deploying are not allowed during review.

## Review Lenses

1. Security
- Authentication bypass
- Authorization or permission errors
- Secret leakage
- Injection or unsafe input handling
- Unsafe command execution

2. Correctness and Regression
- Behavior that no longer satisfies the issue or PR claims
- Broken API routes, schema contracts, config names, or feature flags
- State, retry, idempotency, race, rollback, and error-path bugs
- Adjacent-code assumptions invalidated by the diff

3. Tests
- Missing acceptance-criteria coverage
- Missing edge cases around failure, rollback, permissions, and boundary inputs
- Tests that assert mocks instead of the real runtime contract
- Flaky or environment-dependent tests introduced by the change

4. Architecture
- Layer violations
- Dependency direction problems
- Cross-repo or submodule boundary violations
- Runtime behavior that contradicts documented operational flow

5. Performance
- N+1 calls
- Expensive loops or repeated work on hot paths
- Unbounded queries, payloads, or memory growth

## Output Format

# Review Summary

A concise overview of the review result. State whether the PR has blocking findings, non-blocking findings, missing tests, or no material issues found.

# Findings

List confirmed findings first, ranked by severity. For each finding include:

- Severity: `Critical`, `High`, `Medium`, or `Low`
- File and line reference
- What breaks
- Why it breaks, with code-path evidence
- Suggested fix direction

# Inline Comment Candidates

Only include comments that should be placed on specific changed lines. Keep each comment focused on the concrete bug at that line.

# Missing Tests

List specific test gaps only when they materially affect confidence in the changed behavior.

# Low Confidence

Potential issues that need maintainer confirmation or more context.

If there are no findings in a section, say `None`.

## Legacy Mapping

If another workflow asks for the older local categories, map them as follows:

- `Must Fix`: `Critical` and `High` confirmed findings
- `Should Fix`: `Medium` and `Low` confirmed findings
- `Missing Tests`: same as above
- `Low Confidence`: same as above
