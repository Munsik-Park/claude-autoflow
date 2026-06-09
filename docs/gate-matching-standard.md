# Gate-Matching Standard

> The canonical specification for how AutoFlow PreToolUse hook gates match
> commands and order their checks. All AutoFlow hook scripts in this
> repository converge on this standard.

## Reference Implementation

The reference implementation is the AutoFlow gate hook in this repository.

- File: `.claude/hooks/check-autoflow-gate.sh`

Every gate-hardening change cites this document as the pattern source.

## Rule P1 — Boundary-Anchored Command Matching

Hook gates MUST NOT anchor command detection with a bare line-start `^`.
A `^git push` / `^gh pr create` pattern fails to match the most common
real command forms (`cd <dir> && git push`, `a && gh pr create`,
`ENV=v git push`), silently bypassing the gate.

Use a shared command-boundary prefix plus a word boundary on the command
token:

```sh
CMD_BOUNDARY='(^|[;&|]|&&|\|\|)[[:space:]]*'
# match examples (applied to SCAN, see below):
#   ${CMD_BOUNDARY}git[[:space:]]+push\b
#   ${CMD_BOUNDARY}gh[[:space:]]+pr[[:space:]]+create\b
#   ${CMD_BOUNDARY}gh[[:space:]]+pr[[:space:]]+merge\b

# SCAN = command with body text removed before matching:
#   1. drop from the first heredoc introducer (`<<`) onward
#   2. delete single/double-quoted substrings (inline --body "...")
SCAN=$(printf '%s' "${COMMAND%%<<*}" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
```

Backtick and `(` are deliberately **excluded** from the boundary set:
including them (to catch command substitution) made any body text quoting
a prohibited token false-positive, and command-substitution evasion
(`` `gh pr merge` ``) is explicitly out of this gate's threat model — the
gate prevents the agent from merging *as a normal action*, not a
determined adversary, who has unbounded other evasions anyway.

`CMD_BOUNDARY` matches the start of the command, or the position after a
shell separator (`;`, `&`, `|`, `&&`, `||`). The trailing `\b` prevents
prefix false-negatives. All gates in a hook share the single
`CMD_BOUNDARY` definition for consistency.

### Body-stripping refinement (applied)

The gate matches `SCAN`, not the raw command. `SCAN` removes the two
places body text lives — the heredoc body (everything from the first `<<`)
and quoted substrings (inline `--body "..."`) — *before* the boundary
match. A real chained command outside quotes (`... --body "x" && gh pr
merge 1`) is preserved and still denied; a body that merely *mentions* a
prohibited token no longer false-positives.

Discovery: the original pattern (boundary set including backtick/`(`,
matched against the whole command) false-positived on this pattern's own
`gh pr create` heredoc and was confirmed against `git commit` / inline
`--body` bodies. The refinement above resolves all observed cases; the
regression matrix covers heredoc, inline `--body`, `git commit` body, and
the preserved-real-chain case.

**Residual (accepted, documented):** an *unquoted* multi-token body (rare,
usually invalid shell) or a command-substitution-wrapped prohibited token
is not stripped. This is intentional — it is adversarial evasion, outside
the gate's threat model (preventing routine agent merge/push, not a
hostile operator). No further refinement is planned unless a realistic
non-adversarial false-positive surfaces.

## Rule P2 — Unconditional Denies Precede the Activity Check

A hook has two classes of gate:

1. **Absolute prohibitions** — actions AutoFlow must never perform via the
   agent's tools regardless of state (e.g. `gh pr merge`, push to the
   default branch). These MUST be placed in an unconditional block that
   executes **before** any active-issue / state lookup, so that tearing
   down or deactivating the state file cannot nullify them.
2. **Conditional gates** — score- or phase-dependent checks (e.g. push only
   after AUDIT + GATE:QUALITY pass). These run **after** the activity check;
   being state-scoped is correct for them.

Placing an absolute prohibition after an `active != true → exit 0` guard
makes it state-gated: a terminal phase that sets `active:false` (or removes
the state file) silently disables the prohibition. The correct ordering is
`1. Unconditional blocks` → then `2. Activity check — bypass if no
current-issue`.

Behavioural consequence (intended, not a regression): the agent's Bash
tool can never run `gh pr merge` or a default-branch push in a governed
repository, even outside an active flow. Merging is performed by humans /
external review through GitHub, not through the agent — consistent with
the HANDOFF terminal-phase model.

## Verification Requirement

Each gate-hardening change ships a regression matrix that asserts BOTH
directions:

- **Deny holds**: `cd x && git push`, `a && gh pr merge`, `git push origin
  <default>` are blocked; `gh pr merge` blocked even with no/inactive state.
- **No over-block**: a legitimate `git push -u origin dev/YYYY-MM-DD` and a
  non-merge `gh pr create` are allowed.

The legitimate-allow cases are mandatory — an over-broad pattern that
blocks the normal HANDOFF push is a release blocker.
