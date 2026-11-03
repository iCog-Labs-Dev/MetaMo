# A live run from selection to observed results

**Subsequent update:** [LIVE_MODES.md](LIVE_MODES.md) verifies all six live mode
transitions and introduces definite pre-open reader failure reporting. The run
recorded below used the older handler and remains historical. The current default
live-cycle script includes an additional failure-consumption cycle (eight cycles).

Verified 24 September 2026 at 19:02 UTC: **35 assertions passed across seven
consecutive cycles**, in one interpreter process, with one session and one active
native Core frame. The run completed in 48.96 seconds without timeout or retry.

The run used a controlled host driver around the real bridge and Core handlers.
It demonstrates the sequence below in one serialized session. It did not run the
unmodified autonomous Core polling/model-command loop or test the constitutional
mode transitions.

## Run this check again

From `MetaMo/applications/omegaclaw_v1`:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/verify_live_cycle.py
```

Use the verified dependencies, existing `ASI_API_KEY`, direct ASICloud connection
(`GATEWAY_URL` unset), and cached embedding model in [LIVE_SETUP.md](LIVE_SETUP.md).
The run makes real provider requests. It creates a fresh `/private/tmp/oc-cycle-*`
directory containing a synthetic inbox, approved input file, explicit host policy,
isolated ChromaDB/history, generated entry, logs, import report and JSON traces.
No credentials are copied into these artifacts.

`tools/live_cycle.metta` initializes the production startup imports and calls
`motivationContextBlock` for each cycle. It uses unchanged candidate generation,
appraisal, registry, mode evaluation, numeric scoring and concrete-operation
admission. Dispatch uses `coreLoopDispatchBegin` and `coreLoopDispatchCommand`
with the exact command selected by the bridge and its retained ticket.
There are no replacement scorers, provider doubles or substituted handlers.

The local channel supplies the initial execution confirmation. The controlled
driver retains that confirmation as fresh host input for the first six cycles,
then clears the fresh-input flag for the observation-only seventh cycle. It does
not claim six independently received messages or repeatedly ingest new frames.
The driver dispatches the selected command directly; an LLM does not generate
the execution command. Real ASICloud calls provide confirmation and semantic
signals. Local embeddings and real ChromaDB serve ingestion and restoration.

## Observed sequence

| Cycle | Controlled condition | Selection/execution and next-cycle evidence |
| --- | --- | --- |
| 1 | Approved file exists; policy permits reading | `execute-skill`, score 1.0; real `read-file` returns expected content. Cycle 2 consumes `Success`. |
| 2 | Remove only the generated input file after selection | Real reader cannot read it; Core returns `Unobserved / ExecutionUncertain`. Cycle 3 consumes `Unobserved`. |
| 3 | Operator restores the read-only dependency | Fresh bridge selection and ticket; real read succeeds. Cycle 4 consumes `Success`. |
| 4 | Revoke permission through trusted provisioning after selection | Retained ticket is blocked with `StaleSnapshot`. Cycle 5 consumes `Blocked`. |
| 5 | Permission remains denied before selection | `CandidateRejection execute-skill PermissionDenied`; no selected command, score 0; dispatch returns `MissingDecision`. |
| 6 | Explicit trusted restoration of permission | Fresh selection and ticket; real read succeeds. |
| 7 | Clear fresh-input flag and observe | Consumes `Success`; no executable selection. The same frame/task remains open. |

The file-removal experiment is an actual I/O failure and recovery. Core preserves
its conservative `Unobserved` classification: no synthetic `(Error ...)` result
or `Failure` callback is injected. Consequently, this run does **not** demonstrate
failure-triggered Rumination or claim that uncertain side effects can be retried
generally. The operator repair/retry here concerns only an explicitly authorized
local read. Task completion is not inferred from the read succeeding.

Only the exact temporary file is bound, using the existing host provisioner
and policy template. This scenario enables the native `read-file` handler;
the separate setup verification also exercised `show-current-frame`. Policies
retain global/frame permission checks and prospective budget/cost constraints.
The scenario neither adds dispatch authority nor implements resource settlement.

## Required Core fix

The first live attempts found that `cfv2-default-budget` in
`OmegaClaw-Core/src/context.metta` stored unevaluated `(maxOutputToken)` and
`(wakeupInterval)` calls when ContextFrames compiled before the loop module.
The published snapshot later contained numeric values, so the host's snapshot
comparison rejected configured operations with `UnsupportedOperation`.

The fix resolves those two configuration getters explicitly at runtime before
constructing the budget. It preserves the snapshot equality check and policy
gates. Keep this Core source overlay with the startup dependencies documented in
`LIVE_SETUP.md`; older Core sources do not reproduce this demonstration.

`tests/native_budget_test.metta` serializes the actual default/global/current
budgets before comparison. It fails against the former Core source and passes
all three assertions with the fix, without provider or memory services.

## Retained evidence and validation

- [Result report](../tests/LIVE_CYCLE_RESULTS_2026-09-24.json): exact invocation,
  source fingerprints, host configuration, assertion counts, timing and scope.
- [Complete cycle traces](../tests/LIVE_CYCLE_TRACE_2026-09-24.jsonl): 13 selection/
  outcome records, including snapshots, signals/mode evidence, decisions/scores,
  selected commands/tickets, rejection reasons and correlated outcomes.
- Original artifacts: `/private/tmp/oc-cycle-vn_p02wa/`, including `cycle.log`,
  `imports.json`, generated `cycle.metta`, policy variants and isolated storage.
- Trace verification confirms one active frame in every record, one session ID,
  and cycle sequence `1,1,2,2,3,3,4,4,5,5,6,6,7`. All source hashes still matched
  when the evidence was copied into this repository.

All **49 focused MeTTa files** passed after the Core fix, including the new budget
regression. Core dispatch passed **20 declared tests / 22 generated cases**.
Commands, from the application directory:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 ../../scripts/run-tests.py --root . --petta-runner ../../../run.sh --jobs 2 --timeout 60
swipl -q -s ../../../repos/OmegaClaw-Core/Autotests/dispatch/dispatch_test.pl
```

Logs: `/private/tmp/oc-cycle-regressions.log` and
`/private/tmp/oc-cycle-core-dispatch.log`. Earlier failed attempts remain in
`/private/tmp/oc-cycle-flhfad64` (sandbox network denial), `oc-cycle-071pssws` and
`oc-cycle-hi656nbn` (budget mismatch), and `oc-cycle-41ln6738` (diagnostic query
error). The successful invocation did not retry. The existing nonfatal Janus
module-import diagnostic is still present; this is not a warning-free loader claim.

All constitutional mode-transition acceptance, autonomous-loop verification,
durable recovery and live reasoner integration remain outside this evidence.
