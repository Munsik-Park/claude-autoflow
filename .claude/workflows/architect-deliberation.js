// ARCHITECT deliberation — isolated facilitation (Decision 8).
// Invoked by the orchestrator: Workflow({ name: "architect-deliberation", args: { issue: "N" } }).
// The Developer-AI and Test-AI sub-agents converge INSIDE this workflow; their
// round-by-round exchange stays in script variables and never enters the
// orchestrator's context. The orchestrator receives only the returned object.
// Requires Claude Code v2.1.154+ (Workflow runtime).
export const meta = {
  name: 'architect-deliberation',
  description: 'Isolated ARCHITECT facilitation: Developer-AI + Test-AI converge on feature + verification design in workflow sub-contexts; returns a single verdict.',
  phases: [
    { title: 'Draft', detail: 'dev drafts feature design, test drafts verification design (independent)' },
    { title: 'Converge', detail: 'cross-review rounds under the Discussion Protocol until mutual ACCEPT or the round cap' },
    { title: 'Ledger', detail: 'append the settled decisions (append-only)' },
  ],
}

const MAX_ROUNDS = 6 // Decision 7: explicit cap; a round = one Developer-AI <-> Test-AI exchange cycle.
// The Claude Code Workflow runtime delivers the `args` input to the script as a
// JSON STRING, not the parsed object the tool doc implies (verified empirically
// via the args-probe diagnostic: a `{issue}` object arrives as typeof === 'string').
// Normalize defensively: parse a string, accept an object if a future runtime
// passes one — forward-compatible either way.
const argv = typeof args === 'string'
  ? (() => { try { return JSON.parse(args) } catch (_) { return {} } })()
  : (args || {})
// System boundary: reject a missing required arg loudly rather than proceeding with a placeholder path.
if (!argv.issue) throw new Error('architect-deliberation: args.issue is required')
const issue = argv.issue
const feature = `.autoflow/issue-${issue}-feature-design.md`
const verif = `.autoflow/issue-${issue}-verification-design.md`
const ledger = `.autoflow/issue-${issue}-ledger.md`

const VERDICT = {
  type: 'object',
  additionalProperties: false,
  properties: {
    response: { type: 'string', enum: ['ACCEPT', 'COUNTER', 'PARTIAL'] },
    // Open concerns this party still has. ACCEPT REQUIRES this to be empty
    // (Discussion Protocol: a raised concern is never dropped unresolved).
    counters: { type: 'array', items: { type: 'string' } },
    // Grounds for ACCEPT: the dimensions verified + why each passed (Discussion Protocol:
    // ACCEPT must name the dimensions verified). ACCEPT REQUIRES this to be non-empty.
    accept_grounds: { type: 'array', items: { type: 'string' } },
  },
  required: ['response', 'counters', 'accept_grounds'],
}

phase('Draft')
console.log(`ARCHITECT facilitation for issue #${issue} (cap ${MAX_ROUNDS} rounds)`)

// Independent first drafts — the two perspectives do not see each other's draft yet.
await parallel([
  () => agent(
    `You are the Developer AI in AutoFlow ARCHITECT. Read .autoflow/issue-${issue}-*.md (issue analysis + plan inputs) and any repo code you need. Author the Feature Design Document — files to change, API interface, data structures, dependencies — and WRITE it to ${feature}. Honor docs/teammate-common-rules.md > Discussion Protocol and docs/submodule-common-rules.md > Change Surface Rules. Return a one-line summary only; the document body goes in the file, not the return.`,
    { label: 'dev-draft', phase: 'Draft', model: 'opus' },
  ),
  () => agent(
    `You are the Test AI in AutoFlow ARCHITECT. Read .autoflow/issue-${issue}-*.md and the relevant code. Author the Verification Design Document — each acceptance criterion -> verification type (automated / manual / environment-dependent) -> method; testability assessment; design-change requests for untestable items — and WRITE it to ${verif}. Return a one-line summary only.`,
    { label: 'test-draft', phase: 'Draft', model: 'opus' },
  ),
])

phase('Converge')
let round = 0
let converged = false
let openCounters = [] // unresolved concerns carried from the previous round into the next one.
let lastDev = null
let lastTest = null
// A grounded ACCEPT: ACCEPT response + no open counters + named grounds (dimensions verified).
const accepted = (v) => !!(
  v && v.response === 'ACCEPT' &&
  Array.isArray(v.counters) && v.counters.length === 0 &&
  Array.isArray(v.accept_grounds) && v.accept_grounds.length > 0
)
while (round < MAX_ROUNDS && !converged) {
  round++
  // Thread last round's open counters into this round so fresh sub-agents must resolve them.
  const carry = openCounters.length
    ? ` Open counters still unresolved from the previous round — you MUST address each before ACCEPT: ${JSON.stringify(openCounters)}.`
    : ''
  const [dev, test] = await parallel([
    () => agent(
      `You are the Developer AI. Round ${round} of ARCHITECT convergence. Read the current ${verif} and ${feature}. Apply the Discussion Protocol (UNDERSTAND -> VERIFY -> EVALUATE -> RESPOND). Round 1 is a mandatory devil's-advocate review: do NOT ACCEPT on round 1. If the verification design exposes a gap in the feature design, UPDATE ${feature} in place. Respond ACCEPT ONLY when both documents are mutually consistent and complete AND you have no open concerns — then return empty "counters" and list the dimensions you verified + why each passed in "accept_grounds". Otherwise return COUNTER/PARTIAL, list every open concern in "counters", and leave "accept_grounds" empty.${carry}`,
      { schema: VERDICT, label: `dev-r${round}`, phase: 'Converge', model: 'opus' },
    ),
    () => agent(
      `You are the Test AI. Round ${round} of ARCHITECT convergence. Read the current ${feature} and ${verif}. Apply the Discussion Protocol. Round 1 is a mandatory devil's-advocate review: do NOT ACCEPT on round 1. If the feature design changed testability, UPDATE ${verif} in place. Respond ACCEPT ONLY when every acceptance criterion has a concrete verification method (or a stated manual/mock alternative) AND you have no open concerns — then return empty "counters" and list the dimensions you verified + why each passed in "accept_grounds". Otherwise return COUNTER/PARTIAL, list every open concern in "counters", and leave "accept_grounds" empty.${carry}`,
      { schema: VERDICT, label: `test-r${round}`, phase: 'Converge', model: 'opus' },
    ),
  ])
  lastDev = dev
  lastTest = test
  // No agreement on the first exchange (round > 1), and both sides must give a grounded ACCEPT
  // with no open counters (a raised concern is never dropped).
  converged = round > 1 && accepted(dev) && accepted(test)
  openCounters = [...((dev && dev.counters) || []), ...((test && test.counters) || [])]
  console.log(`round ${round}: dev=${dev ? dev.response : 'null'}(${(dev && dev.counters && dev.counters.length) || 0}) test=${test ? test.response : 'null'}(${(test && test.counters && test.counters.length) || 0})`)
}

phase('Ledger')
const verdict = converged ? 'CONVERGED' : 'ESCALATE'
// Only a CONVERGED run records settled decisions under "ARCHITECT mutual ACCEPT".
// A non-convergence run records a single outcome entry under a DISTINCT authority so
// the append-only ledger is never polluted with un-agreed content (which would later
// block legitimate re-deliberation under the "no re-litigation" rule).
const acceptGrounds = converged
  ? [...((lastDev && lastDev.accept_grounds) || []), ...((lastTest && lastTest.accept_grounds) || [])]
  : []
const ledgerPrompt = converged
  ? `Append (do NOT rewrite or delete) to ${ledger} the settled ARCHITECT decisions. For each agreed design decision, append one entry: the decision (one line); its grounds (cite the verified dimensions ${JSON.stringify(acceptGrounds)} and the artifact path:line in ${feature} or ${verif}); authority "ARCHITECT mutual ACCEPT"; cycle/phase "ARCHITECT". If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Append-only — never edit existing entries. Return a one-line summary only.`
  : `Append (do NOT rewrite or delete) to ${ledger} EXACTLY ONE outcome entry — do NOT record any design decision as settled: decision "ARCHITECT did not converge — escalated at round ${round} of ${MAX_ROUNDS}"; grounds (unresolved counters: ${JSON.stringify(openCounters)}); authority "ARCHITECT non-convergence"; cycle/phase "ARCHITECT". If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Append-only. Return a one-line summary only.`
await agent(ledgerPrompt, { label: 'ledger', phase: 'Ledger', model: 'opus' })

return {
  phase: 'architect',
  verdict,
  artifacts: [feature, verif],
  ledger,
  rounds: round,
  summary: converged
    ? `ARCHITECT converged in ${round} round(s)`
    : `ARCHITECT did not converge within ${MAX_ROUNDS} rounds — escalate`,
  escalation: converged ? null : `No mutual ACCEPT within ${MAX_ROUNDS} rounds (reached round ${round})`,
}
