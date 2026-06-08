// Regression harness for the deliberation workflow scripts.
//
// These tests lock the pure control-flow logic of the reference workflows —
// convergence rule, counter threading, ledger-authority branching, VERIFY
// next_action mapping, missing-response handling, and the arg guards — by running
// each script against a mock runtime. They do NOT exercise a live Claude Code
// Workflow runtime (that is the operator-side smoke scenario in
// docs/teammate-contracts.md > Facilitator > Verification scenarios); they catch
// the control-flow logic-bug class without spawning real agents.
//
// Run: node test/workflows/run.mjs
//
// The mock passes the runtime globals (args, phase, parallel, agent, console) as
// function parameters. A script that references a workflow global NOT in this set
// (e.g. a stray `log`) throws a ReferenceError here — which catches that ABI-mismatch
// class. Caveat: an AsyncFunction body can still see Node ambient globals (process,
// Buffer, globalThis, ...), so this guard does not prove the script is free of *every*
// non-workflow global — only that it does not reference an undefined one. The scripts
// use solely the injected globals; a stricter `vm`-sandbox check is a possible follow-up.
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor

function load(rel) {
  const src = readFileSync(join(root, rel), 'utf8').replace(/^export const meta/m, 'const meta')
  return new AsyncFunction('args', 'phase', 'parallel', 'agent', 'console', src)
}

const arch = load('.claude/workflows/architect-deliberation.js')
const verify = load('.claude/workflows/verify-cause-branch.js')

const mockConsole = { log() {} }
const phase = () => {}
// Mirror the documented parallel(): concurrent, and a thunk that throws resolves to null.
const parallel = (thunks) => Promise.all(thunks.map((t) => Promise.resolve().then(t).catch(() => null)))

function makeAgent(responder, calls) {
  return async (prompt, opts = {}) => {
    const label = opts.label || ''
    calls.push({ label, prompt })
    return responder(label, prompt)
  }
}

const runArch = (args, responder) => {
  const calls = []
  return arch(args, phase, parallel, makeAgent(responder, calls), mockConsole).then((result) => ({ result, calls }))
}
const runVerify = (args, responder) => {
  const calls = []
  return verify(args, phase, parallel, makeAgent(responder, calls), mockConsole).then((result) => ({ result, calls }))
}

let failures = 0
async function test(name, fn) {
  try {
    await fn()
    console.log(`  ok    ${name}`)
  } catch (e) {
    failures++
    console.log(`  FAIL  ${name}\n        ${e.message}`)
  }
}

// ---- ARCHITECT ----------------------------------------------------------------

await test('ARCHITECT: converges at round 2 with a grounded ACCEPT, ledger = mutual ACCEPT', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['c1'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['feasibility: existing structure supports it'] }
  }
  const { result, calls } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.rounds, 2)
  assert.match(calls.find((c) => c.label === 'ledger').prompt, /ARCHITECT mutual ACCEPT/)
})

await test('ARCHITECT: first-exchange ACCEPT cannot converge (round 1 blocked)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] } // ACCEPT every round
  }
  const { result } = await runArch({ issue: '1' }, responder)
  assert.equal(result.rounds, 2, 'must not stop at round 1')
  assert.equal(result.verdict, 'CONVERGED')
})

await test('ARCHITECT: ACCEPT without grounds never converges -> ESCALATE + non-convergence ledger', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: [] }
  }
  const { result, calls } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.rounds, 6)
  const ledger = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledger, /ARCHITECT non-convergence/)
  assert.doesNotMatch(ledger, /ARCHITECT mutual ACCEPT/)
})

await test('ARCHITECT: ACCEPT carrying open counters does not converge', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: ['still open'], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
})

await test('ARCHITECT: unresolved counter is threaded into the next round prompt', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['SCHEMA_GAP_42'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '1' }, responder)
  assert.match(calls.find((c) => c.label === 'dev-r2').prompt, /SCHEMA_GAP_42/)
})

await test('ARCHITECT: missing args.issue throws at the boundary', async () => {
  await assert.rejects(
    () => arch(undefined, phase, parallel, makeAgent(() => 'x', []), mockConsole),
    /args\.issue is required/,
  )
})

await test('ARCHITECT: args delivered as a JSON string (real runtime form) resolves issue', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft') || label === 'ledger') return 'ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  // The Workflow runtime delivers args as a JSON STRING, not an object — pre-fix
  // this threw "args.issue is required"; the argv normalizer must resolve it.
  const { result } = await runArch(JSON.stringify({ issue: '7' }), responder)
  assert.match(result.artifacts[0], /issue-7-/)
})

// ---- VERIFY -------------------------------------------------------------------

const combos = [
  [{ verdict: 'fix_test', reason: 'x' }, { verdict: 'no_problem', reason: 'x' }, 'RED'],
  [{ verdict: 'no_problem', reason: 'x' }, { verdict: 'fix_impl', reason: 'x' }, 'GREEN'],
  [{ verdict: 'fix_test', reason: 'x' }, { verdict: 'fix_impl', reason: 'x' }, 'SEQUENTIAL_FIX'],
  [{ verdict: 'no_problem', reason: 'x' }, { verdict: 'no_problem', reason: 'x' }, 'EVALUATION_AI'],
]
for (const [tv, iv, expected] of combos) {
  await test(`VERIFY: ${tv.verdict} + ${iv.verdict} -> ${expected}`, async () => {
    const responder = (label) => {
      if (label === 'ledger') return 'ledger ok'
      if (label === 'test-self-check') return tv
      if (label === 'impl-self-check') return iv
      return 'x'
    }
    const { result } = await runVerify({ issue: '1', failLog: '/tmp/f.log' }, responder)
    assert.equal(result.next_action, expected)
  })
}

await test('VERIFY: null self-check recorded as "missing" (not no_problem) -> EVALUATION_AI', async () => {
  const responder = (label) => {
    if (label === 'ledger') return 'ledger ok'
    if (label === 'test-self-check') return null // simulate skip/error
    if (label === 'impl-self-check') return { verdict: 'no_problem', reason: 'x' }
    return 'x'
  }
  const { result, calls } = await runVerify({ issue: '1', failLog: '/tmp/f.log' }, responder)
  assert.equal(result.test_self_check, 'missing')
  assert.equal(result.next_action, 'EVALUATION_AI')
  assert.match(calls.find((c) => c.label === 'ledger').prompt, /test self-check=missing/)
})

await test('VERIFY: missing args.failLog throws at the boundary', async () => {
  await assert.rejects(
    () => verify({ issue: '1' }, phase, parallel, makeAgent(() => 'x', []), mockConsole),
    /args\.failLog is required/,
  )
})

await test('VERIFY: args delivered as a JSON string (real runtime form) resolves issue + failLog', async () => {
  const responder = (label) => {
    if (label === 'test-self-check') return { verdict: 'fix_test', reason: 'x' }
    if (label === 'impl-self-check') return { verdict: 'no_problem', reason: 'x' }
    return 'ledger ok'
  }
  // String args must resolve BOTH issue and failLog (else the failLog guard throws);
  // next_action RED proves fix_test + no_problem mapped over a string-delivered payload.
  const { result } = await runVerify(JSON.stringify({ issue: '1', failLog: '/tmp/f.log' }), responder)
  assert.equal(result.next_action, 'RED')
})

console.log(failures ? `\n${failures} test(s) FAILED` : '\nall workflow regression tests passed')
process.exit(failures ? 1 : 0)
