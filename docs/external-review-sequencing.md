# External Review -- Merge Sequencing

> Audience: the external reviewer who merges AutoFlow PRs, and the operator who bootstraps the host repository. AutoFlow ends at PR creation; this document covers what happens after.

## Operator prerequisites

Out-of-AutoFlow administration. Run once per host repo before the per-issue procedure can be exercised. The repository_dispatch CI workflow only takes effect once it is on the default branch (`main`); the host PR that introduces this design cannot self-bootstrap the gate, so the operator merges that PR with normal review and applies the steps below after merge.

### Label

```bash
gh label create blocked-by-subrepo \
  --color b60205 \
  --description "Host PR depends on a sub-repo PR not yet merged; do not promote draft to ready" \
  --repo {{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}

gh label create blocked-by-review \
  --color b60205 \
  --description "Automated review has unresolved Critical/High/Medium findings; do not promote draft to ready" \
  --repo {{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}
```

The `blocked-by-review` gate label is a **per-PR** review gate: it is attached to **every** PR opened for a cycle — the host PR and each sub-repo PR — and is removed by the automated reviewer (e.g. Codex) on **that same PR** only when **that PR's** review finds zero `Critical`/`High`/`Medium` findings. Each PR is reviewed on **its own diff**, so the review scope is each repo's actual code — for a multi-repo change the host PR's diff is only the `services/{{REPO_SUBMODULE}}` submodule-pointer bump, so the host review never substitutes for the sub-repo review. The label must therefore exist **in each sub-repo too**, not only the host — create it there with the same `gh label create blocked-by-review …` command but `--repo <sub-repo>`. This is distinct from `blocked-by-subrepo`, which is **host-only** and gates merge **order**, not review. Its removal is an advisory, human-honoured signal; the merge actor still performs promotion and merge manually.

### Branch protection

In repo settings -> Branches -> Branch protection rules -> `main`, add:

- Require status checks to pass before merging.
- Required status check: `subrepo-merged` (the context published by the repository_dispatch CI workflow).

This complements the existing protections (PR review >= 1, CI green).

### Dispatch token

The `gh api repos/{{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}/dispatches` POST that fires the `repository_dispatch` event requires a token with write access to the host repo's contents. The default `GITHUB_TOKEN` available inside a workflow cannot cross-repo dispatch; this token is held by the external reviewer outside any workflow context. Acceptable tokens:

- **Classic PAT** with `repo` scope (`repo` is the umbrella scope that includes `repo:status` and `public_repo` — sufficient for `repository_dispatch`).
- **Fine-grained PAT** with **`Contents: Write`** on `{{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}` (per the GitHub REST docs for `POST /repos/{owner}/{repo}/dispatches`). The `actions: write` permission controls `workflow_dispatch` (targeting a specific workflow file), not `repository_dispatch` (targeting the repo's event stream).

The token belongs to the external reviewer (the merge actor). Store it securely; do not commit.

### Token-as-merge-gate warning

**Threat model note**: the dispatch token is effectively a merge-gate credential. An attacker with this token can:

- Send a `subrepo-merged` event with any `client_payload` they choose.
- Cause label removal on the named host PR (if the host PR is OPEN and currently carries `blocked-by-subrepo`).

However, the workflow's machine verification (steps 2, 4, 5 of the repository_dispatch CI workflow) prevents the attacker from publishing the `subrepo-merged` status check unless all three of the following hold:

1. The host PR is OPEN and carries the `blocked-by-subrepo` label.
2. For multi-repo dispatches, the named upstream sub-repo PR is actually `merged: true` upstream and its recorded `merge_commit_sha` matches the dispatch payload (after lowercase normalization).
3. The host PR's `services/{{REPO_SUBMODULE}}` submodule pointer equals the named `merge_commit_sha`.

Compromise of the token alone, without coordinated control of both the upstream sub-repo and the host PR's head commit, cannot bypass the gate. The narrowed attack surface is "label removal on an open `blocked-by-subrepo` host PR" — which by itself does not enable merge, because the required `subrepo-merged` status check is not published.

A **host-only dispatch** is the exception: with the sub-repo triple absent, the upstream and pointer checks are skipped (they have an `if: env.PAYLOAD_BRANCH == 'multi-repo'` guard). The surface there is wider, but host-only PRs are exclusively created by the orchestrator's HANDOFF for changes with no sub-repo dependency. Reviewers should confirm the host PR's diff truly contains no `services/{{REPO_SUBMODULE}}` change before issuing a host-only dispatch on a PR they did not create.

## Per-issue procedure

The 8-step workflow that runs after the reviewer's `repository_dispatch`.

### Payload schema

Every `repository_dispatch` of type `subrepo-merged` MUST carry a `client_payload` matching this schema. The workflow's `Validate payload` and `Decide payload branch` steps enforce these rules; mismatches surface as workflow failures (exit codes 64, 65, 76).

```json
{
  "issue":            "<numeric string, host issue N>",
  "host_pr":          "<numeric string, host PR M>",
  "subrepo":          "<owner/repo, e.g. {{UPSTREAM_SUBREPO}}>",
  "subrepo_pr":       "<numeric string, sub-repo PR number>",
  "merge_commit_sha": "<40-char hex SHA from upstream PR merged event>"
}
```

| Field | Required? | Format |
|-------|-----------|--------|
| `issue` | always | `^[0-9]+$` |
| `host_pr` | always | `^[0-9]+$` |
| `subrepo` | optional (all-or-none triple) | `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$` |
| `subrepo_pr` | optional (all-or-none triple) | `^[0-9]+$` |
| `merge_commit_sha` | optional (all-or-none triple) | `^[0-9a-f]{40}$` (case-normalized to lowercase) |

The three sub-repo fields form an **all-or-none** triple: all three present (multi-repo cycle) or all three absent (host-only cycle). Any 1/3 or 2/3 partial state is a payload error (exit 76).

### Multi-repo cycle (sub-repo change present)

For an issue cycle whose host PR depends on a sub-repo PR:

1. AutoFlow's HANDOFF has already created the sub-repo PR(s) and the host PR (the latter as `--draft` with the `blocked-by-subrepo` label).
2. Review and merge the sub-repo PR(s) upstream (e.g., into `{{UPSTREAM_SUBREPO}}:main`). Record the merge commit SHA from the upstream PR page (URL fragment after `/commits/`).
3. Update the submodule pointer in the host PR's dev branch to the upstream merge commit, then push (or ask the original branch owner to push). This step prevents the pointer from regressing to the pre-merge commit. When this step is **delegated to AutoFlow**, follow [**Reconcile preflight**](#reconcile-preflight-concurrent-cycle-gitlink-guard) below first — it guards the concurrent-cycle gitlink conflict that otherwise leaves the host PR `CONFLICTING` and fails the CI `pr-merge` build `NOT_MERGEABLE` (so GitHub records no clean status).
4. Dispatch `subrepo-merged` to the host repo:
   ```bash
   gh api repos/{{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}/dispatches \
     --method POST \
     --field event_type=subrepo-merged \
     --raw-field 'client_payload={
       "issue":"<N>",
       "host_pr":"<M>",
       "subrepo":"{{UPSTREAM_SUBREPO}}",
       "subrepo_pr":"<upstream PR #>",
       "merge_commit_sha":"<40-char SHA of upstream merge commit>"
     }'
   ```
   The workflow runs all 8 steps (validate payload, decide payload branch, assert host PR state, assert host-only diff excludes sub-repo, assert upstream sub-repo PR merged, assert host PR submodule pointer, publish status check, remove label). On any verification failure, status publication and label removal are skipped; the host PR remains unmergeable until the reviewer corrects the payload and re-dispatches.

   Common failure modes:
   - **Exit 75** — re-check the host PR number; the PR may already be merged or may never have carried `blocked-by-subrepo`.
   - **Exit 76** — payload partial: ensure all three sub-repo fields are present together (or all three omitted for a host-only cycle).
   - **Exit 77** — upstream PR is not yet merged; complete the upstream merge first.
   - **Exit 78** — `merge_commit_sha` does not match the upstream PR's recorded merge commit; copy the SHA again from the GitHub upstream PR page.
   - **Exit 79** — the host PR's submodule pointer does not equal `merge_commit_sha`. Update the submodule pointer in the host PR's dev branch (step 3) and push, then re-dispatch.
   - **Exit 80** — host-only payload claimed but the host PR's diff contains `services/{{REPO_SUBMODULE}}` (the submodule pointer / gitlink itself) or paths under `services/{{REPO_SUBMODULE}}/`. Either the dispatch should be multi-repo (provide the sub-repo triple, with `merge_commit_sha` matching the new pointer) or the host PR genuinely should not change sub-repo files (revert the unintended pointer bump or path edit).
5. Verify the host PR's status check `subrepo-merged` is green and the `blocked-by-subrepo` label is absent.
6. Promote the host PR draft -> "Ready for review" (manual click).
7. Merge the host PR. The literal close-keyword line in the body closes the issue.

### Reconcile preflight (concurrent-cycle gitlink guard)

When step 3's pointer update is delegated to AutoFlow on explicit request, the dev branch may have forked *before* one or more **other** cycles' host PRs merged. Because every host-PR merge advances `main` and reconciles the `services/{{REPO_SUBMODULE}}` pointer (operator merges run one at a time), a naive pointer bump + push then leaves the host PR `CONFLICTING` and CI's `pr-merge` build fails `NOT_MERGEABLE` (GitHub records no clean status). This is the frequent failure when several cycles sit in external review at once. Guard it:

**Preflight** — before bumping, fetch and compare three pointers:

- `BASE` — the dev branch's merge-base-with-`main` pointer: `git ls-tree $(git merge-base origin/main HEAD) services/{{REPO_SUBMODULE}}`.
- `MAIN` — the current `origin/main` pointer (after `git fetch origin main`): `git ls-tree origin/main services/{{REPO_SUBMODULE}}`.
- `TARGET` — this issue's sub-repo `merge_commit_sha` (the commit the host pointer must equal for the `subrepo-merged` check, assertion 3 above).

If `MAIN == BASE`, no concurrent reconcile happened — bump to `TARGET` and push as before. If `MAIN != BASE`, a concurrent cycle already reconciled the pointer; resolve by **fork ancestry** (run `git -C services/{{REPO_SUBMODULE}} fetch origin main` first, then `git -C services/{{REPO_SUBMODULE}} merge-base --is-ancestor <a> <b>`):

| Relationship on the fork | Resolution |
|---|---|
| `TARGET` is a **descendant** of `MAIN` (fork `main` moved forward; `TARGET` already contains `MAIN`) | **Put `TARGET` on the dev gitlink first, *then* merge** — `git -C services/{{REPO_SUBMODULE}} checkout <TARGET>` → `git add services/{{REPO_SUBMODULE}} && git commit` → `git merge --no-edit origin/main`. With the dev pointer already at `TARGET` (⊇ `MAIN`), the submodule **stays at `TARGET`** and only non-gitlink files merge (`Fast-forwarding submodule services/{{REPO_SUBMODULE}} …` confirms a clean gitlink). **[MUST]** A bare `git merge origin/main` with the dev pointer still at `BASE` resolves the gitlink to **`MAIN`, not `TARGET`** (the 3-way gitlink merge takes *theirs* when *ours == base*) and fails the `subrepo-merged` pointer assertion (Exit 79) — so the pointer must be set to `TARGET` either before or after the merge, and verified (see the post-reconcile gate). |
| `MAIN` is a **descendant** of `TARGET` (host PRs merged out of fork-merge order; bumping to `TARGET` would **regress** the live pointer) | Do **not** push. **Escalate to the operator** — the merge order on host `main` diverged from the fork merge order. |
| `TARGET` and `MAIN` **diverge** (neither is an ancestor of the other) | Fork history diverged — **escalate to the operator**. |

**Post-reconcile gate** — before/after pushing, confirm **all three**, and do not report "reconciled" until all hold:

- **Pointer == `TARGET`**: `git ls-tree HEAD services/{{REPO_SUBMODULE}}` equals `TARGET` (this is `subrepo-merged` assertion 3 — a mismatch is `Exit 79`). Verify this *before* pushing.
- `gh pr view <host-PR> --json mergeable,mergeStateStatus` returns `mergeable: MERGEABLE` and `mergeStateStatus: CLEAN` (no longer `CONFLICTING`/`DIRTY`).
- The CI rebuild on the new head commit is `result: SUCCESS`, queried via the authenticated API (the environment provides `{{CI_URL}}` / `CI_USER` / `CI_API_TOKEN`):
  ```bash
  curl -s -u "$CI_USER:$CI_API_TOKEN" \
    "{{CI_URL}}/job/{{REPO_ORCHESTRATOR}}/job/PR-<n>/lastBuild/api/json?tree=number,result"
  ```
  **[MUST]** An **unauthenticated** call returns `403`/empty body — do **not** read that as "CI unreachable / down". A host PR that reads `mergeable: CLEAN` but whose latest CI build is `result: FAILURE` with a console `NOT_MERGEABLE` ran on the **pre-resolution (conflicted)** commit; re-verify after the post-push rebuild settles.

**Sequencing** — perform the reconcile against a **freshly-synced `main`**: run [Post-Merge Cleanup](git-workflow.md#post-merge-cleanup) for any prior cycles the operator has already merged (so `origin/main` and its pointer reflect the latest merge) *before* reconciling the current issue. This keeps `BASE ≈ MAIN` and turns most concurrent-cycle conflicts into a clean fast-forward.

### Host-only cycle shortcut

For an issue cycle with **no** sub-repo change, AutoFlow's orchestrator dispatches `subrepo-merged` itself at HANDOFF step 4 with the minimal payload (only `issue` and `host_pr`):

```bash
gh api repos/{{GITHUB_ORG}}/{{REPO_ORCHESTRATOR}}/dispatches \
  --method POST \
  --field event_type=subrepo-merged \
  --raw-field 'client_payload={"issue":"<N>","host_pr":"<M>"}'
```

The workflow's branch decision sees the three sub-repo fields absent and skips the upstream + pointer assertions (steps 5 and 6 are `if`-guarded on `env.PAYLOAD_BRANCH == 'multi-repo'`). Steps 1-4 still run (validate, decide, host PR state assert, host-only diff exclusion), then steps 7-8 (status publish, label remove). The reviewer then performs only the multi-repo procedure's step 6 (promote draft -> ready) and step 7 (merge).

Note that the orchestrator-initiated host-only dispatch is the **only** path where AutoFlow itself sends a `repository_dispatch`; for multi-repo cycles the dispatch comes from the external reviewer after the upstream merge.

**Workflow-enforced**: a host-only dispatch is accepted only if the host PR diff truly contains no change to `services/{{REPO_SUBMODULE}}` (the submodule pointer / gitlink path itself, reported by GitHub when only the submodule pointer is updated) and no paths under `services/{{REPO_SUBMODULE}}/`. The workflow runs `gh api repos/<owner>/<repo>/pulls/{N}/files --paginate` and rejects each `filename` that equals `services/{{REPO_SUBMODULE}}` or starts with `services/{{REPO_SUBMODULE}}/`; any match causes exit 80 and skips status publication. This converts the reviewer-attested host-only trust into a machine-checked invariant.

### Retry safety

The workflow runs publish-status before remove-label (steps 7 and 8). The ordering is deliberate:

- **Publish failure followed by retry**: the host PR still carries `blocked-by-subrepo` (step 8 has not run). A retry re-runs all assertions; on the multi-repo branch, step 3 finds the label intact and passes. The publish call is idempotent at the GitHub API layer (`POST /repos/{owner}/{repo}/statuses/{sha}` overwrites by `(sha, context)`), so the retry succeeds.
- **Remove failure followed by retry**: the status check is already green. A retry re-runs assertions; step 3 still passes on the multi-repo branch (label present) or on the host-only branch (label not required). The publish call is a no-op at the application layer (and idempotent at the API layer). The remove call retries.

The reverse ordering (remove first, publish second) is unsafe: a publish failure leaves the PR with no label and no status; a retry on the multi-repo branch then fails step 3 with exit 75 (missing label) and stalls. The publish-before-remove ordering eliminates this stall path.

## Why this exists

See [`autoflow-guide.md`](autoflow-guide.md) > HANDOFF > Merge Sequencing (the orchestrator-facing phase body; `CLAUDE.md` routes there via its Phase Playbook Loading Contract) and `design-rationale.md` for the design rationale behind this sequencing.
