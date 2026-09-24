# Offline ContextFrames service boundaries

The final Task 5 local regression run passed all 18 commands without retries:
46 MeTTa files, 377 full-loop assertions, 64 Python tests, Core dispatch,
contract/commitment suites, four shell guards and the startup import audit.
See [the dated regression report](REGRESSION_RESULTS_2026-09-24.md) for exact
commands, results, source revisions, artifact paths and scope. Task 5's local
offline checklist is complete; live, durable recovery and CI acceptance remain
separate.

## Shared full-loop harness

From the MetaMo repository root:

```sh
python3 scripts/run-omegaclaw-offline.py --output /tmp/omegaclaw-offline
```

The default runs all four scenarios below, each in an isolated process through
`scripts/run-omegaclaw.py`. Select a subset with repeated `--scenario` options
(`scoring`, `modes`, `callbacks`, or `invalidation`).
`--workspace /absolute/path/to/PeTTa-workspace` selects the runtime independently
of the caller's working directory. `--timeout` bounds each scenario (300 seconds
by default). A timeout terminates the launcher and its child interpreter.

Use the dependency layout and source overlays in [DEPENDENCIES.md](../DEPENDENCIES.md),
including the common Python launcher and existing `scripts/petta-imports.pl`
resolver. Those local launcher overlays are currently untracked dependencies;
copy/include them when reproducing this checkout. No live provider keys, channels
or memory servers are needed. The Python offline guard rejects network access
and optional service imports; final completion markers require those imports to
remain absent.

`fixtures/full_loop.metta` centralizes provider/memory doubles, real Core and
MetaMo imports, runtime state allocation, session initialization, user ingestion,
and cycle/dispatch tracing. It delegates ingestion to Core, cycles to
`motivationContextBlock`, and execution to `coreLoopDispatchCommand`. The scorer,
mode evaluator, projection, policy gates and feedback validation are unchanged.
Scenario-specific binding configuration, initial motivational values and assertions
remain in the existing tests. `scoring` preserves its existing String-ID fixture;
`modes` retains Core's native ID and full frame-completion path.

| Boundary | Implementation |
| --- | --- |
| Semantic/provider and relation/memory services | Offline doubles; exact controlled semantic responses and empty memory. |
| Ingestion, frames, projection, appraisal, scoring, mode evaluation | Real Core/MetaMo code. |
| Policy admission, ticket capture/revalidation, dispatch, callback ingestion | Real Core/adapter code. |
| Successful execution | Existing Core readers against temporary fixture files. |
| Controlled failure | Test-only handler returning an error with an invocation counter, behind the real dispatch gate. |

The harness prints a unique artifact directory. It contains full stdout/stderr
logs and resolved-import reports per scenario, plus `summary.json` with commands,
exit codes, assertion counts, timings, source revisions and SHA-256 fingerprints
of harness/runtime sources and resolved imports. No logs are overwritten by a
subsequent invocation. With no `--output`, the run directory is created under the
system temporary directory. Keep the printed directory for later inspection.

`FullLoopCycleBegin` identifies the cycle attempt; `FullLoopCycle` records the
actual snapshot, mode evidence, state before/after, admitted candidates, retained
decision/score, selected operation and policy. `FullLoopDispatch` records the
attempted command/ticket, dispatch result and published outcome. Existing
`OutcomeScoringTrace` records retain the control-versus-observation score details.
Printing these records does not recompute selection, recapture tickets or apply
feedback. Missing or multiple bridge results remain visible to scenario checks.

The entry point requires the exact assertion count, the scenario completion
marker, a valid import report, exit code zero, and no assertion/interpreter error.
It writes a failure report and exits nonzero on interruption. It never retries a
failed scenario automatically. The ticket UUID `float_overflow` described in
historical results below is fixed by the updated Core `src/dispatch.pl` overlay:
ticket IDs are strings before serialization and ledger insertion. See
[DISPATCH.md](../DISPATCH.md#verification-and-limits). Older Core overlays still
have the failure; the harness itself does not retry or suppress it.

This implements Task 5's shared harness and scenario-coverage items. The original
two-scenario verification on 24 September 2026 passed all 239
integration assertions (59 scoring, 180 modes). Four harness tests covering
verdicts, subprocess output and timeout/child cleanup, eight import-resolution
checks, six offline-service tests and four shell guards passed. Earlier invocations
retained known UUID-parser failures as nonzero results. Invocation from outside
the repository resolved the same sources and correctly reported a scoring parser
interruption while completing the mode scenario.

### Complete session-only scenario coverage — 24 September 2026

| Requirement | Scenario and acceptance evidence |
| --- | --- |
| Success and motivational feedback | `scoring` (59 assertions): real Core read, observed success, next-cycle score change against a matched no-outcome control; operation success leaves the task open. |
| Failure and recovery | `modes` (180 assertions): counted controlled handler failure enters Rumination; blocked work does not resolve recovery; an observed successful read clears recovery and restores Engaged. |
| Required modes | `modes`: Sleep → Engaged, Engaged → Rumination, Rumination → Engaged, Engaged → Threat, Threat → Engaged, Engaged → Sleep, with retained trigger/timing evidence and explicit host completion. Threat cannot override denial; idle Sleep never invokes task work. |
| Duplicate delivery | `scoring` and `callbacks`: repeated dispatch returns the original result after file contents change; duplicate callbacks preserve the observation, motivation and single-success count; later cycles produce NoOutcome. |
| Mismatched callbacks | `callbacks` (46 assertions): alter a real dispatched outcome's session, cycle, frame, action, command, ticket, attempted command, status or result. Check typed rejection and unchanged observation/consumption state, recovery, motivation and self-model. Malformed, late and prior-session callbacks are also rejected. The next cycle consumes the valid observation once. |
| Stale/revoked decisions | `invalidation` (92 assertions): host state changes and returns to its original value; binding revocation and policy denial occur after selection. Old tickets are blocked even after the exact binding is restored. A new cycle must select a fresh ticket. |
| Denied/no-action | `invalidation`: permission denial, exhausted command budget, and absent bindings produce Rejected/none with zero priority, no admitted actions and no selected command. Dispatch returns MissingDecision; the next cycle retains Blocked feedback without success/failure fabrication or task closure. |
| No unauthorized or duplicate effects | `invalidation`: a controlled handler counter stays zero throughout rejected attempts. Fresh authorized selection invokes it once; ticket replay leaves the counter at one. Its observed failure appears in the next snapshot and activates Rumination. |

The new scenarios share `fixtures/boundary_loop.metta`, retain Core's native
symbolic frame ID, and open a host-owned commitment after real ingestion. They
use the existing trusted test bindings for an Interactive candidate; these are
execution-effect doubles, not production response handlers. Callback mutations
derive from an actual Core read outcome; no selected decision, snapshot, scorer,
gate, or mode transition is substituted. `FullLoopCallback` records every tested
callback and rejection alongside the existing cycle and dispatch traces.

One unretried default invocation passed **377 assertions across all four
scenarios**. The focused suite passed all **46 MeTTa files**. Supporting checks
passed: 15 runner-hardening tests, five harness tests, eight import regressions,
the provisioning/identity/service/reasoner/helper Python tests, Core dispatch and
shared contract/commitment tests, and all four shell guards. Logs, source hashes
and import reports are retained by the harness. The harness test also verifies
that a failed callback scenario makes the aggregate run fail while preserving
all four scenario results.

This closes the named offline coverage item, not live-provider/channel acceptance,
durable restart recovery, or deferred CI/reasoner integration. The other Task 5
checklist items remain separately tracked.

Test the entry point itself with:

```sh
python3 applications/omegaclaw_v1/tests/offline_harness_test.py
```

### Outcome/effect assertions and failed-run traces — 24 September 2026

The third Task 5 checklist item is verified by the following assertions:

| Obligation | Executable evidence |
| --- | --- |
| Outcome-driven score change | `outcome_scoring_test.metta` compares `scoringRespondScore` in matched no-outcome and observed-success branches, requiring a difference greater than `0.000001`. Both use the real decision context/scorer. This demonstrates a score change, not a winner reversal. |
| No duplicate motivational update | The same test compares the duplicate-delivery branch's decision, score, full motivational state and self-model with single delivery; success count remains one and later feedback is `NoOutcome`. |
| No unauthorized execution | `full_loop_invalidation_test.metta` asserts `&boundary-effects` stays zero after stale/revoked tickets and permission, budget and missing-binding denials. |
| No duplicate execution | After a fresh authorized selection, that counter becomes one and remains one after replay of the same ticket. |
| Failure preserves per-cycle evidence | `OfflineHarnessTests.test_failed_assertion_retains_real_cycle_and_dispatch_traces` runs real ingestion, snapshot/scoring, Core read dispatch and duplicate callback ingestion, then intentionally fails `!(test 1 2)`. It checks a nonzero harness result, failed `summary.json`, assertion-failure and missing-completion reasons, five preceding successful assertions, and saved `FullLoopCycleBegin`, `FullLoopCycle`, `FullLoopDispatch` and `FullLoopCallback` records. |
| Evidence is inspectable after process exit | The regression reads the saved stdout/stderr and import report, checks snapshot/decision/outcome fields remain present, and verifies the retained fixture source fingerprint. Existing timeout tests separately cover partial logs and descendant cleanup. |

The deliberate failure is a temporary scenario created by the Python test,
not an entry in the normal four-scenario manifest. Its interpreter exits before
the completion marker; the harness preserves the partial run rather than
reporting success or retrying. Production scoring and dispatch are unchanged.

Verified from the workspace root:

```sh
python3 MetaMo/applications/omegaclaw_v1/tests/offline_harness_test.py
python3 MetaMo/scripts/run-omegaclaw-offline.py --output /tmp/omegaclaw-outcome-acceptance
```

All **six harness tests** and **377 scenario assertions** passed. This closes
the outcome/effect/trace item within the bounded offline session-only scope;
live execution, durable recovery and the separate full-regression checklist
remain independently tracked.


Run from the PeTTa workspace root:

```bash
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/offline_ingestion_test.metta
python3 MetaMo/applications/omegaclaw_v1/tests/offline_services_test.py
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/bridge_cycle_test.metta
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/bridge_snapshot_test.metta
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/multiple_candidates_test.metta
```

The MeTTa test is also discovered by `scripts/run-tests.py`. It loads the actual
Core context/helper/utils modules and application composition. It ingests two
messages through `ctx-ingest-user-message`, stores and loads real frames, checks
the resulting relation endpoints and advisory evidence status, projects the
bounded bundle, and exercises real signal extraction, appraisal, numeric scoring,
and policy admission/rejection. The appraisal changes the real `respond` score
from the same neutral initial state; there is no fixed scorer or synthetic
`FrameStateBundle` replacing projection.

## Doubled boundaries

| Test-only Python module | Replaced external behavior |
| --- | --- |
| `fixtures/offline_services/frame_relation.py` | ChromaDB/vector retrieval and model relation classification. An in-memory list of previously supplied frame IDs replaces retrieval. The first frame has no relations; later frames receive at most five deterministic `RelatedButSeparate` relations in the production provider's wire format. |
| `fixtures/offline_services/lib_llm_ext.py` | Execution-intent confirmation and semantic extraction calls. Explicit `Offline` configuration returns zero confirmation and an empty semantic list, leaving ordinary host-derived signals and registry appraisal intact. |
| `fixtures/offline_services/offline_guard.py` | Test-process guard: forbids imports of optional service packages and socket connections, so installed packages/credentials cannot accidentally satisfy the test. |

Provider doubles validate their expected inputs and expose reset/call-count APIs.
Python tests cover relation direction, quoted IDs, deterministic replay/reset,
retrieval bounds, invalid inputs, and service/network blocking in a child process.
Host-generated IDs and timestamps remain real; determinism means reproducible
relations for the same IDs, not byte-identical wall-clock traces.

All replacements are explicitly imported by this test only. Production `run.metta`
keeps the real providers. Use a fresh launcher process; these modules intentionally
have the provider module names and must not share a Python interpreter with live
providers. The guard likewise lasts for the test process lifetime. There is no
fallback to these doubles when a production service is unavailable.

The fixture supplies bounded host configuration (`provider`, `embeddingprovider`,
token/wake settings and a compact skill listing), but does not override projection,
appraisal, scoring, candidate conversion, or feasibility functions. The composition
loads bundle accessors before signals because PeTTa needs those definitions when
compiling signal extraction.

## Scope and known limits

This closes optional-service dependencies for the tested ContextFrames loading
and message-ingestion path. It does not load all channel integrations or exercise
embeddings, real semantic classification, memory persistence, execution dispatch,
relation verification write-back, or the complete bridge execution-feedback loop.
The ingestion test uses an explicit observed host failure for appraisal.

## Full bridge regression — 23 September 2026

`bridge_cycle_test.metta` calls the production `motivationContextBlock` after
real Core message ingestion. It uses the same provider doubles and network guard,
plus test-only `query`/`remember` functions for the external memory boundary.
Persistence restoration and save scheduling remain real; the test does not
restore a previously serialized payload or exercise a storage backend.

The earlier empty-result failure had two causes: `idleAutonomyActive` was compiled
before its bundle accessor and needed explicit runtime evaluation, and relation
projection converted a structural list into a display string, leaving candidate
generation without a result. Projection now retains bounded typed relations and
preserves empty runtime text before adding any digest. Empty errors/results no
longer produce false failure/progress signals.

The regression passes 49 assertions across fresh-message cycles with empty and
nonempty relation lists, an observed error accompanying a fresh message, and idle
no-action. Each bridge call returns exactly one policy result. Checks cover the
published directive, real motivational state updates, self-model counters,
persistence scheduling and final signal cleanup. The focused suite passes 36
MeTTa files, alongside 32 Python tests, eight import regressions and four shell
boundary checks.

This does not establish execution dispatch or the complete feedback loop. A
separate probe of an active-task continuation without a fresh message reaches
`helper.is_result_status_question`, which is absent from the pinned Core helper;
`helper.task_needs_more_execution` is also referenced by lifecycle code but absent
there. Those host continuation interfaces still need implementation/integration
before claiming the successive execution-feedback scenarios. Live providers,
channels and restart recovery remain unverified. CI is unchanged.

## Snapshot consistency regression

`bridge_snapshot_test.metta` uses real ingestion and the existing trusted host
commitment test APIs. It verifies that `prepareTaskStateForMetaMo` refreshes
execution observations and commitment state before publishing the bundle.
The production entry point then passes that one value to
`motivationContextBlockForBundle`; decision/scoring callbacks retain it through
`omegaclawDecisionForBundle`, and autonomy bookkeeping receives it explicitly.

After capture, the test changes host frame/task/error/result state and replaces
the active-bundle cache. The original snapshot still determines appraisal,
candidate admission, numeric scoring, selection and the directive target. A later
publication sees the updated observations and an explicit commitment completion,
without changing the earlier snapshot. No motivational functions are doubled.

All 34 assertions pass, alongside 37 focused MeTTa files, 32 Python tests, eight
import regressions and four shell guards. These deliberately adversarial mutations
test snapshot isolation within the serialized motivational calculation; they do
not authorize execution against stale host state. The dispatcher must still
revalidate current state and policy before invoking a handler.

## Multiple feasible candidates

`multiple_candidates_test.metta` ingests a real Core task and exercises its open,
awaiting-first-execution state: the message has been ingested, no fresh message is
pending, and there are no execution observations. Existing registry rules generate
five feasible candidates. Scheduling retains `respond` and `ask-clarification`
in the Interactive class, so both reach the unchanged numeric scorer.

The first full bridge call selects `respond` under the default 1.0 score tie.
The test then lowers responsiveness and cooperation goals through `replaceGoal`;
it does not change registry rules, inject candidates, or replace scoring functions.
The resulting decision-context scores are approximately 0.567 for `respond` and
0.967 for `ask-clarification`. A second full bridge call selects the latter while
the host snapshot and generated candidates remain unchanged. Printed candidate,
score, and policy traces make the comparison inspectable.

Lifecycle bookkeeping now skips merging absent results, preserving the empty
observation. Status-question classification only runs for a waiting user, and
continuation classification requires an open task, no new message, and an actual
execution observation. Lazy guards prevent irrelevant eager Python calls. The
missing host classifiers documented above still need integration for scenarios
that require them; this test supplies no replacements for those functions.

All 30 assertions pass. The focused suite now passes 38 MeTTa files, with 32 Python
tests, eight import regressions and four shell boundary checks. The goal change is
a controlled motivational input, not an observed execution outcome; this verifies
Task 1's candidate competition requirement, not the execution-feedback MVP.


## Outcome-driven scoring — 23 September 2026

`outcome_scoring_test.metta` demonstrates the Task 3 score-change criterion with
real Core ingestion, bounded projection, the full bridge, typed admission,
scheduling, numeric scoring, Core dispatch, callback validation and next-cycle
feedback consumption. It passes 59 assertions. Run from the workspace root:

```sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/outcome_scoring_test.metta
```

Three matched branches start from identical host task state and motivational
configuration: no execution between cycles, one successful execution, and the
same success with duplicate dispatch/callback delivery. Session IDs differ by
construction. The test asserts equal first snapshots, admitted candidates,
scores, selected policy and post-cycle motivational state. All goal weights start
at 0.1 except `help_user=0.4`, `responsiveness=0.3`, and `cooperate=0.2`, keeping
scores below saturation. No goals, modulators or registry rules are changed
between cycles within a branch.

Initially, `respond` and `ask-clarification` both pass complete typed admission
and remain in the Interactive scheduling class. Their decision-time scores are
approximately 0.619500 and 0.410900; `respond` wins. Its exact selected command
runs through Core and returns an observed string, recorded with the originating
session/cycle/frame/action/ticket. The next snapshot projects `Success`, producing
progress appraisal 0.18 and opportunity 0.12 through the existing signal path.

| Measurement | No-outcome control, cycle 2 | Success, cycle 2 |
| --- | ---: | ---: |
| Decision-time `respond` score | 0.6973411356 | 0.6964411356 |
| Bridge-emitted post-transition score | 0.8208626279 | 0.8208240940 |
| Selected candidate | `respond` | `respond` |

Decision-time scores are inspected through the unchanged `decisionContext` and
`omegaclawScoreForBundle`, using the saved pre-cycle motivation and the bridge's
retained appraisal. They are distinct from the later emitted score and mapped
policy priority. Assertions require the score difference to exceed 0.000001.
Success slightly lowers the decision-time score here: the registry's progress
appraisal lowers urgency and raises persistence, with a net negative contribution
to this execution candidate's modulator bias. Success is not defined to increase
every candidate's score.

The control includes the same ordinary decay, homeostasis and cycle count, so a
mere first-to-second-cycle change cannot satisfy the test. Duplicate delivery
produces exactly the single-delivery scores, motivation and self-model state.
Changing the file after the first read verifies dispatch replay returns its
original result. A late callback is rejected; the following cycle has `NoOutcome`
and does not count success again. The task remains open throughout.

### Test-only host catalog and scope

`fixtures/outcome_scoring.py` supplies trusted test bindings: `respond` uses Core's
`read-file`, and `ask-clarification` uses `show-current-frame`. These local readers
stand in for Interactive execution effects; they do not send a response or ask a
question. The fixture reuses the existing validated atomic installer and complete
file/frame policies, including actual arguments, permissions and costs. Production
handler mappings are unchanged. Provider and memory boundaries use the existing
explicit offline doubles and network guard. No production functions, candidate
rules, scorer, or Prolog source are replaced or added.

Existing availability rules narrow the successful task's next cycle to `respond`;
the test claims an outcome-driven score change, not a winner reversal or two
post-success competitors. It establishes the bounded offline score-change item,
not live Interactive handler support, active multi-step continuation, commitment
completion, failure recovery or all constitutional mode transitions. The existing
ticket-parser `float_overflow` limitation documented in `DISPATCH.md` also applies.

Verification: the 41 existing focused MeTTa files passed via the common launcher,
as did eight import regressions, six offline-service Python tests, ten host-config
Python tests, and four shell boundary guards. The suite invocation of the new
file encountered the documented ticket-parser `float_overflow` after 37 passing
assertions; a standalone rerun passed all 59. This is not an uninterrupted green
42-file run. The checkout's `scripts/run-tests.py` still invokes a shell runner,
so the suite used a temporary shell wrapper delegating to the absolute path of
`scripts/run-omegaclaw.py`; no runner or CI source was changed.


## Active-task continuation

The missing Core lifecycle helpers are now implemented. The bounded two-read
continuation regression passes 70 assertions and the current focused suite passes
43 files. See [CONTINUATION.md](../CONTINUATION.md) for the exact host plan,
helper contracts, test commands and scope. It uses real ingestion and authorized
Core reads without a new message between steps. The earlier missing-helper probe
above is historical; arbitrary prose still cannot establish remaining execution,
and automatic live host plan provisioning remains separate work.


## Host signals and constitutional modes

From the MetaMo repository root:

```sh
python3 scripts/run-omegaclaw.py applications/omegaclaw_v1/tests/host_mode_transition_test.metta
```

This full-cycle test uses real Core ingestion, snapshot projection, appraisal,
selection, policy checks, and dispatch. The offline provider has an opt-in exact
input/response map; defaults still return no semantic signals. Controlled danger
and anger responses pass through `refreshSignals`, not direct signal insertion.
A test-only handler returns an explicit error through real dispatch, and the
normal Core file reader supplies the subsequent successful resolution.

Traces include session/cycle, frame, signals, mode before/after, timing counters,
and policy output. The test covers all six required mode transitions, persistent
recovery without repeated failure counts, frame/session expiry, terminal
commitment clearing, denied work in Threat, no task execution in Sleep, and
non-default confirmation/hold/cooldown behavior. See `../MODE_TRANSITIONS.md` for
host ownership and the exact lifecycle path exercised. This is offline evidence,
not a live provider/scheduler or durable-recovery demonstration. The existing
Core ticket-parser `float_overflow` limitation still applies.

Verification on 24 September 2026: all 44 MeTTa files passed in one suite run;
the final expanded host-mode test passed 111 assertions separately. Six
provider/guard and ten host-config Python tests, eight import checks, and four
shell boundary guards passed. Broad Python discovery also ran the existing
runner-hardening tests and reported 11 failed assertions/subtests and two errors
there (missing runner APIs, timeout handling, and incomplete failure detection).
Both that test file and `scripts/run-tests.py` are unchanged from HEAD; those
runner failures are not resolved by this signal-wiring change. Earlier focused
runs also encountered the documented intermittent Core ticket `float_overflow`;
the successful suite and final focused run did not.


The strengthened transition demonstration preserves Core's generated frame ID
and calls `cfv2-complete-current-frame-to-stm`, including completed storage/index
updates and next-frame selection. It no longer assigns a replacement String ID
or directly clears the current-frame cache for the completion scenario. Six
labelled `RequiredTransition` assertions compare the real before/after modes;
obsolete recovery/threat evidence and a second idle Sleep cycle are checked.
Native symbolic targets are supported by the typed operation and request gates,
with regression checks rejecting text/symbol mismatches and malformed IDs.

Strengthened verification on 24 September 2026: all 44 MeTTa files passed in one
suite invocation, including 134 host-mode assertions, 45 typed-policy assertions
and 36 request-admission assertions. Ten host-config and six offline-service
Python tests and all four shell boundary guards passed. No Core, Prolog, runner
or CI sources were changed for this follow-up.


## Mode evaluation diagnostics

`lastModeObservation` now appends the winning registry rule, requested target,
all rule matches (including rejected thresholds and losing groups), and the
actual current/target timing configuration and checks. See
[MODE_TRANSITIONS.md](../MODE_TRANSITIONS.md) for the complete diagnostic shape.
The full-loop test additionally covers inclusive entry/exit thresholds,
hysteresis, retained confirmation/hold/cooldown checks, and trace stability after
registry changes. Provider values still flow through real signal extraction;
no mode assignments or replacement evaluator establish these results.

Verification on 24 September 2026: the expanded host-mode regression completed
all 169 assertions in a standalone run. The other 43 MeTTa files passed the suite
invocation, including the existing timing/threshold component tests, and all four
shell boundary guards passed. The suite's host-mode run and several focused
retries were interrupted by the documented Core ticket UUID `float_overflow`;
no failing assertion preceded those interruptions. The final focused process
exited successfully. This is not an uninterrupted green 44-file suite result,
and the existing parser limitation remains unresolved by this diagnostics change.


## Denied operations in Threat and Sleep

The full-loop regression now explicitly attempts the registered failing command
while in Sleep after task/frame completion. Its handler increments an invocation
counter, and the preceding four authorized dispatches establish that this effect
works. Sleep attempts with the current missing-decision ticket, a previously
executable ticket, and `LegacyDispatch` all return
`(DispatchResult Blocked MissingDecision none)` without incrementing the counter.
Another full Sleep cycle and dispatch attempt likewise leave it unchanged.
The command arguments are quoted data, so evaluating the test itself cannot
invoke the handler. Existing Threat checks cover permission revocation after
selection and no executable selection with the denied policy still installed.

Verification on 24 September 2026: the full host-mode test passed all 180
assertions in one process with exit code zero. This follow-up changes only the
MeTTa test and documentation; no production code, fixture Python or Prolog was
changed. Live validation remains separate.
