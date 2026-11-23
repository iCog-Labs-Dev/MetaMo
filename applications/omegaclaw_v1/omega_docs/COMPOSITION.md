# Loading modules without losing state

Use `scripts/run-omegaclaw.py` to load this application. It resolves package paths
and loads each physical module once. `composition.metta` defines the application's
import order; `run.metta` adds the host and starts it. Importing composition alone
does not start a channel or restore a task.

## Why import order matters

PeTTa's native importer processes a file on every import. Each MeTTa function
definition adds another global Prolog clause, and each top-level `bind!` runs
again. Rebinding a state replaces its value; rebinding a space loses the
previous space reference and its accumulated contents.

The v1 dependency graph previously loaded context leaves directly, through
`context_integration`, and again through leaf dependencies. For example, the
facade imports `context_accessors`, `context_policy` imports it again, and
`context_directives` imports both. The scoring tests also imported the registry
twice. These routes explain repeated accessor/directive results and repeated
allocation of directive and relation-evidence state.

There was a separate setup issue: the reasoner integration test imported the
runnable minimal-loop test, executing its initialization and six assertions as
a side effect. Finally, the production import order placed proposals before the
decision scorer. PeTTa could compile the unresolved scorer call as data; using
the production composition in the reasoner test reproduced an arithmetic type
error on `omegaclawScoreForBundle`.

## Loading rules

- Use `scripts/run-omegaclaw.py` for v1 execution and import auditing. Native
  `petta`/`run.sh` do not provide these import semantics.
- Named imports resolve from explicit roots: this MetaMo checkout, the selected
  PeTTa `lib/`, and that workspace's two `repos/` dependencies. Relative imports
  resolve from the importing source file, not the initial entry file or shell.
- Canonical physical paths identify modules. Direct, named, facade, `..`, and
  symlink routes to the same file share one successful load.
- A successful MeTTa module load compiles definitions, adds registry facts, and
  runs allocation forms once. Subsequent imports preserve state and space
  contents; they are not a reset API.
- Modules become loaded only after successful completion. A load error aborts
  execution; failed imports are not treated as successfully cached modules.
  Partial effects are not rolled back, so restart after a failed load.
- Cyclic imports fail explicitly rather than exposing partially loaded modules.
- Loading one MeTTa module into a second space fails explicitly. PeTTa function
  compilation is global; a second space is not an isolated copy of module code.
  This launcher is intended for v1's single-space module composition.
- Python imports verify the loaded module's `__file__` against the requested
  physical file. Errors and same-name module collisions are not silently ignored.

## Composition and initialization

`composition.metta` owns the application import order: shared core, configuration
and state adapters, pure factual schema/readers, modes, context facade, signal
production/appraisal, homeostasis/lifecycle, candidate generation, decision
scoring, bounded trace records, persistence, and bridge. It does not
import the optional proposal adapter or inference engines.

### Retained diagnostic events

`trace.metta` owns a volatile newest-first window exposed by `metaMoTraceEvents`;
`lastCycleTrace` reads the latest retained selection. Events have the shape
`(MetaMoTraceEvent STAGE IDENTITY CYCLE-REFERENCE FIELDS)`. They are diagnostics
and grant no execution authority. Initialization clears this window.

- `CycleSelection` is captured after homeostasis and before signal cleanup.
  It retains the published snapshot reference where available, motivational and
  self-model values before/after the cycle, factual signals, appraisals, mode
  observation, admitted/rejected candidates, policy and selected decision.
- `Execution` is appended only for an accepted outcome callback. Its identity
  preserves the original operation context and ticket; its result remains
  ungraded. Rejected callbacks and duplicate delivery add no event.
- `Assessment` is appended when the explicit reasoner assessment path retains a
  grade. It uses the retained outcome identity and original receipt decision,
  including when newer cycles have already run. It neither edits the selection
  or execution event nor invokes comparison or learning again.

For example, `traceEventField (lastCycleTrace) state-before` returns its retained
`TraceValue`. An observed empty value remains `(TraceValue ())`; missing evidence
uses `TraceUnavailable` with a reason. The legacy path uses a separately tagged
cycle/frame identity rather than inventing a host session or dispatch ticket.

The window holds at most 32 events and each event at most 20 fields. Field data
up to 2048 serialized characters stays structured; larger fields become bounded
`TraceSummary` text with a SHA-256 digest and original length. Oversized identities
are omitted rather than truncated into a potentially incorrect correlation key.
Oldest events are evicted. This window is not durable audit storage.
The Python support module checks sizes, hashes text and formats retained data. Trace capture does
not start optional reasoners, call providers, rerun selection or consume feedback.

### Clarifying uncertain requests

When the host requirements assessment is `Uncertain` with no established tool
work, the host prepares one fixed clarification through `ask-clarification` and
the normal send admission/dispatch path. This question does not mark the task
answer-ready or complete. Idle cycles neither ask again nor call a provider again.
After a successful send, the next ordinary message from the same authorized owner
is routed as a follow-up to that task and assessed afresh. The retained question
input/context and actual dispatch receipt must match; denied, stale or uncertain
sends cannot open this follow-up path. Explicit replacement/cancellation and
existing tool requirements retain their normal behavior.

### Reading a cycle summary

`formatCycleSummary EVENT` returns text from a retained `CycleSelection` event
and its correlated events in the current bounded trace window.
`printCycleSummary EVENT` prints it; `printLastCycleSummary` selects the latest
retained cycle even when execution or assessment events arrived afterward:

```metta
!(printLastCycleSummary)
```

Automatic printing is disabled by default. Enable it in the host startup JSON:

```json
"trace_printing": {"enabled": true, "max_chars": 6000}
```

`max_chars` is an integer from 256 to 12000; the default is 12000. Each emission
batch, including correlated cycle summaries, stays within this character limit
and labels truncation. Cycles flush after signal cleanup from the already retained
snapshot. Dispatch callbacks, explicit assessment and parameter derivation flush
after their retention work completes, outside host dispatch/parameter locks.
Later evidence renders the original cycle again with its retained identities;
empty flushes and duplicate callbacks produce no additional summary.

Programmatic callers can use `(configureTracePrinting (TracePrintConfig True 6000))`
and `(flushMetaMoTrace)`. Recording queues at most 32 event references when enabled;
it performs no console I/O. Disabling printing clears the queue but preserves
`metaMoTraceEvents`, `lastCycleTrace` and `formatCycleSummary`. Initialization clears
the history and queue while retaining the configured emission setting. Automatic
output replaces the bridge's unconditional raw context/dispatch dumps, uses only
admitted summaries and evidence references, and never fetches missing evidence.

The labelled summary shows session, cycle and frame identity, typed factual values
with quantity/estimate units, signed per-signal appraisal contributions before
dimension clamping, and named goal/modulator/self-model changes with before,
after and delta values. It describes selection; execution is a separate event.
Legacy runs explicitly report the absence of a host session identity.

Compact signal values and appraisal contributions are captured alongside their
original evidence, and state names/indices are retained with the vectors. Rendering
never reads current signals, registry labels or motivational state to reconstruct
an earlier cycle. Missing/rejected data is labelled unavailable; oversized data is
labelled summarized. An observed empty list or unchanged state prints `none`.
Output is capped at 12000 characters with an explicit truncation marker.

The summary separates constitutional posture, ContextFrames Fast/Slow mode,
scheduling class and operation directive. Compact mode evidence retains the
winning transition rule, matched predicates with their original thresholds and
entry/hold/cooldown checks. Pending transitions identify the unsatisfied timers.
Transition rule priorities are labelled separately from scheduling ranks.
If a session change clears mode evidence during preparation, the field stays
explicitly unavailable and diagnostic capture does not interrupt native operation.

The scheduling view retains up to 32 admitted entries in their original order,
their effective class/rank and whether they reached the highest admitted class.
Lower classes keep their admission and are labelled deferred. Recorded policy
rejections retain their original reasons; unavailable candidates are not invented
as rejected entries. Rejected work has no numeric score assigned by the display.

The native traversal copies up to 32 scores as they are calculated, then freezes
the first decision's native and post-hook winners before safety-counter updates.
Later bimonad probes cannot replace those numbers. Printing never invokes a scorer.
Decision-time native scores and the published score after state update are labelled
separately. If a selection hook changed the winner, this is explicit; adjusted
decision scores remain unavailable in this view. The retained candidate/directive,
concrete command and original ticket describe selection, not execution success.

### Dispatch, budget and optional reasoner observations

The rendered view joins later observations by retained cycle, ticket and proposal
identities. A new callback or grade can enrich an older cycle's displayed summary;
the original selection and execution records stay immutable. Printing never reads
live accounting/engine state or invokes collectors, comparators or learners.

`BudgetSettlement` events copy the touched accounts before/after settlement inside
the host's locked accounting callback. They retain planned/actual account costs,
the Core result and the original ticket. Output shows spent/reserved balances and
remaining availability separately for each scope. Unknown usage remains pending
with its reservation held; an absent accounting event is unavailable, not a zero
charge. Accounting diagnostics cannot fail the host settlement. Core ledger
observations are labelled separately if no accepted host callback is retained.

The optional `reasoners/host_reasoner_trace.metta` copies intake status and
adapter/configuration/phase identity, individual proposals and their original
predictions, admission results and parameter-batch statuses at existing retention
points. Claims, engine-specific support and evidence remain typed data with the
existing field bounds. Native operation loads no reasoner module for printing.
Empty/unavailable/timed-out intake does not manufacture a prediction or grade.

Grades are separate `Assessment` events joined to their exact invocation/proposal
reference. Canonical serialized keys preserve symbol/string ID distinctions
across Python rendering. A rejected alternative does not borrow the primary's grade; missing
assessment stays explicitly ungraded. Displaying a grade does not update source
reliability or deliver engine feedback. Proposal admission alone makes no claim
that a reasoner caused the selection.

`ParameterUpdate` events distinguish Pending, Applied and stale statuses. Queued
changes remain proposed until an Applied status is observed. The latest retained
status is shown with its original grade/batch identity, queued context and status
context, so later application is not relabelled as part of the earlier cycle.
Observer failures cannot change the producer's admission, assessment or learning
return value. The 32-event diagnostic window can evict older details; it is not a
replacement for the host/coordinator audit ledgers.

Printing remains explicit. Configurable automatic runtime emission is separate work.

`factual_signals.metta` contains representation validators and pure typed snapshot
readers without allocating state. It loads before mode/scheduling triggers, while
mode definitions load before the context policy gates that call them. Signal
producers still load after the context accessors they use. Focused module imports
must preserve this dependency order; moving the context facade ahead of modes while moving the complete signal
module would compile policy dependencies as unresolved data.

Reasoner integration is deferred. `reasoners/reasoner_integration.metta` is an opt-in
extension loaded after composition; it owns `reasoner_proposals` and engine
loading. Tests needing proposal admission without inference import only
`reasoner_proposals` after composition. The dependency points from the optional
adapter into the core's policy/scoring APIs; the core does not call the adapter.
Wire schemas and optional proposal references remain shared data contracts.

`run.metta` imports the host dependencies and this common composition, then calls
`motivatedOmegaclaw` explicitly. Importing `composition.metta` allocates defaults
but does not start a channel, initialize a task, or restore persistence.

The context facade is the public bundle of context modules. Consumers needing
the complete boundary import it once instead of listing its children as well.
Context leaves do not import one another. The facade loads accessors before
policy, then directives, so this graph also compiles once under native `run.sh`.
Focused tests may import individual leaves only when they explicitly load their
prerequisites in order and do not also import the facade.

The context integration test and focused context tests use explicit host source
paths so native PeTTa does not silently skip an unregistered OmegaClaw-Core
namespace. From the workspace root, the integration test also runs directly:

```bash
sh run.sh MetaMo/applications/omegaclaw_v1/tests/context_integration_test.metta -s
```

This command passes all 77 assertions without the custom import cache. A native
runner regression check prevents the caching launcher from concealing future
duplicate imports. This does not give native PeTTa general import-once semantics.

`tests/fixtures/minimal_loop.metta` contains shared offline definitions and
imports the same application composition. Its scenario reset is the explicit
`initMinimalLoopFixture` function. Importing the fixture neither resets a live
scenario nor executes test assertions. The minimal-loop and reasoner tests each
call setup once, in their own process.

The native reasoner test previously returned sixteen `nars` alternatives for
its first scalar assertion: `reasoner_integration` reimported both `lib_import`
and `reasoner_proposals` after the fixture's composition had loaded them.
The extension requires composition first. Proposal imports now belong exclusively
to the extension, alongside its engine adapter; composition no longer loads them.
This preserves one-time compilation and proposal-state allocation under native
PeTTa. Do not separately import the proposal module and the full inference
extension into the same native process.

Host helper and ContextFrames imports live at each test entry point, using
explicit source paths. They are no longer hidden behind a package alias that
native PeTTa does not register. The reusable fixture receives those host
definitions from its caller. Engine libraries resolve beside the compiler
actually running, and runnable forms in engine libraries produce an explicit
load error rather than silently leaving inference calls unresolved.

After the earlier context-import repair, the minimal-loop overflow was no
longer reproducible in the current tree. Both the minimal loop (6 assertions)
and real NARS/PLN integration (18 assertions) now pass under native `run.sh`
and under the same native compiler constrained to a 64 MiB stack. The existing
inference, evidence, negative-premise, rejection, and reliability assertions
are unchanged. No deduplication or blanket result collapsing was added.

## Benchmark record formats

`tools/reasoner_benchmark_formats.py` defines version-one scenario and result
JSON records through `validate_scenario` and `validate_result`. These pure
validators return the original record unchanged and perform no runtime imports,
provider calls, fixture execution or file writes. Examples live in
`tests/fixtures/reasoner_benchmark/`. They are illustrative, not measured runs;
the example result explicitly reports that no runner is connected.

| Scenario field | Meaning |
| --- | --- |
| `schema_version`, `scenario_id`, `description` | Format version and versioned scenario identity. |
| `source_versions` | Exact v1/Core revisions, plus any other relevant source revisions. Replace example placeholders with resolved revisions. |
| `adapter` | Registered adapter ID, adapter version, engine version and configuration version. `disabled` uses null adapter/engine versions. An optional `registration` path names trusted MeTTa registration code relative to v1. |
| `configuration` | Independent collection, influence, assessment and learning flags; influence cap in 0..1; seed or null when unsupported. |
| `initial_state` | Existing fixture path relative to v1, reset entry point, policy profile, motivational initialization, memory initialization, ordered inputs and serialized exogenous observations. Fixture/profile meanings are pinned by the source revisions. |
| `episodes` (optional) | Episode cycle counts, explicit carry state and optional matching `roles` (`calibration` then `evaluation`). Defaults to one evaluation episode with no incoming state. |
| `evaluation` (optional) | Independently scored task checks, each with a run cycle and a supported versioned oracle. Missing checks leave task outcomes unmeasured. |
| `resource_limits` | Positive cycle/time bounds and a serialized existing `ReasonerIntakeLimits` record for fact, proposal, engine, provider and retained-record bounds. |

A result retains the full scenario, a unique `run_id`, status (`completed`,
`failed`, `timed_out` or `unavailable`), error reason, elapsed milliseconds,
`trace_references` and a measurements object. Completed means the run finished,
not that its task succeeded or its predictions were correct. Failed runs can
retain partial traces. Omit unmeasured metrics instead of recording zero; a
missing grade must not become a failed prediction or a reliability update.
Matched runs also retain `runtime_configuration`: observed capabilities, effective
controls, contract/configuration/engine versions, influence settings, intake status,
actual dispatch result and hashes of resolved source files. Adapter version labels
are declarations; source hashes identify the code actually loaded.

Each trace reference contains `artifact`, `stage`, `identity` and `cycle_ref`.
The last two retain exact native serialized trace keys, such as
`TraceDecisionRef` and `TraceCycleRef`; preserve quoting and symbol/string
distinctions. The artifact locates exported structured events, independently of
truncated console output. Empty references mean no trace was retained. Export
must happen before volatile history eviction when the runner is connected.

### Isolated comparison launching

`tools/benchmark_reasoners.py` accepts one or more scenario JSON paths. An optional
trusted executable MeTTa driver through `--entry` selects process-only smoke tests;
without it the runner executes the matched configuration matrix below. Each comparison starts the
common `scripts/run-omegaclaw.py` launcher in a fresh process group. The optional
launcher `--runtime-dir` changes runtime cwd without changing compiler/package
resolution; ordinary invocations keep the workspace cwd.

For a process-boundary smoke check using the existing callback integration test:

```bash
python3 applications/omegaclaw_v1/tools/benchmark_reasoners.py \
  applications/omegaclaw_v1/tests/fixtures/reasoner_benchmark/scenario.example.json \
  --entry applications/omegaclaw_v1/tests/full_loop_callbacks_test.metta \
  --output /tmp/reasoner-comparisons
```

Each retained temporary run directory contains `scenario.json`, `result.json`,
`execution.json`, import-resolution data, stdout/stderr logs, fresh `memory/`,
driver `output/` and a private `runtime/`. Chroma uses the private memory path;
history reads/writes and cwd-relative episode history use the private runtime
path. Inherited live host configuration is removed. The driver receives absolute
`OMEGACLAW_BENCHMARK_SCENARIO`, `OMEGACLAW_BENCHMARK_MEMORY`,
`OMEGACLAW_BENCHMARK_OUTPUT`, and `OMEGACLAW_BENCHMARK_RUN_ID` values. These
locations are kept for inspection after success or failure; remove them manually
when no longer needed.

Nonzero exits, assertion/interpreter errors, unavailable launcher processes and
wall-clock timeouts produce failure results with logs. Timeout is taken from
`max_elapsed_ms`; remaining workers in the process group are stopped on every
exit. Other valid comparisons continue after a failure. Malformed input documents
are retained separately in uniquely named `input-errors-*.json` files, since they
cannot form a valid scenario/result record. The CLI exits unsuccessfully if any
run or input fails.

The explicit-entry smoke path passes the declared scenario unchanged; its trusted
driver must consume and apply it. The smoke check above verifies process execution,
not performance of its format example. No task scores, grades or causal trace
references are invented from console output; measurements/references stay empty
until their actual collection is connected.

### Matched runtime comparisons

One deterministic `bounded-read-v1` episode is connected. It admits one user task,
installs the same policy profile, runs native selection and dispatch, then runs a
second cycle to apply observed feedback. Provider/memory services are doubles;
Core admission, file reading, budgets, callbacks and NARS/PLN inference are real.
The engines receive equivalent native implications from the admitted user-waiting
signal to a recommendation; the fixture does not fabricate inference results.

```bash
python3 applications/omegaclaw_v1/tools/benchmark_reasoners.py \
  applications/omegaclaw_v1/tests/fixtures/reasoner_benchmark/read.scenario.json \
  --output /tmp/reasoner-matched
```

The default matrix has nine fresh-process runs: native with no reasoner, and NARS
and PLN in shadow/advisory modes with learning independently off/on. Assessment
retains the scenario's flag. Advisory runs explicitly configure a zero influence
cap: they exercise the advisory route while preserving native selection. Positive
caps still require native predictive-evidence checks; the harness does not invent
calibration grades to pass them. Rejected requests remain failed comparisons.

Additional adapters use `--matrix PATH`, a JSON list of objects containing the
existing `adapter` and `configuration` records. The optional adapter `registration`
module calls normal registration/runtime APIs before selection. The supplied
`rule.matrix.json` and `rule_adapter.metta` demonstrate this with a labelled rule
adapter double, not another native engine or a production learning implementation:

```bash
python3 applications/omegaclaw_v1/tools/benchmark_reasoners.py \
  applications/omegaclaw_v1/tests/fixtures/reasoner_benchmark/read.scenario.json \
  --matrix applications/omegaclaw_v1/tests/fixtures/reasoner_benchmark/rule.matrix.json \
  --output /tmp/reasoner-registered
```

Capabilities come from the actual selected registration, not an engine-name table.
Learning enabled is a requested/effective control, not proof of native learning:
the current built-ins declare no feedback capability. Reports retain supported
feedback stages separately and make no claim that a flag trained an engine.

The MeTTa driver in `tools/reasoner_benchmark_driver.metta` uses fixture hooks
`RESET(INPUT, POLICY)` and
`benchmarkConfigureAdapter(ID)`, then existing cycle/dispatch calls. The supplied
fixture implements these as `benchmarkSetup` and bounded engine-rule setup.
Python supplies scenario data and writes a small entry containing imports and one
driver invocation; initialization, adapter controls and the cycle loop live in MeTTa. Other
registered adapters need registration/configuration changes, not a new selector
or dispatcher. Initial state observations are retained in `output/initial-state.json`.
`tests/fixtures/reasoner_benchmark/controlled.scenario.json` shows a runnable
four-cycle scenario with scheduled inputs, file changes and seeded initialization.
The offline fixture accepts partial motivational overrides (`goals`, `anti_goals`,
`modulators`, `self`), host mode/status/priority/posture, explicit supported operations
and global/frame resource allowances. Native restore and policy checks still apply.
Ordered `inputs` use null for idle cycles. Scheduled `observations` declare a cycle
and file contents, semantic classifier scores or confirmation scores. File changes
operate on the run's temporary file; dispatch results come from the real handler.
Classifier observations require a message in that cycle and retain native provenance.

Each declared cycle runs normal selection and dispatch. `output/trajectory.jsonl`
retains that run's inputs, observations, decisions, callbacks, factual signals,
motivational state and causal trace identities. Divergent runs keep their own
outcomes; a previous callback is never substituted for a different decision.
The final callback may still await next-cycle consumption when the cycle bound ends.

Optional seeds control Python, Python hashing and Prolog RNG. Engine seeding is
reported unsupported rather than implied. Results retain observed Git revisions,
loaded source hashes, effective native inference limits and initial host policies,
bindings and budget accounts. Fresh initial memory is required; importing another
comparison's memory, opaque observation strings and unsupported fixture controls
produce unavailable results.

Independent comparisons start in fresh processes with fresh sessions and private
memory/runtime directories. In-process engine state, reliability weights, mutable
registry parameters, budgets and pending evidence therefore belong to one run.
`runtime_configuration.isolation` records the child's PID, run identity, private
paths and episode policy. External services or adapter-owned storage outside those
paths require their own isolation; these offline fixtures do not certify that state.

Continuous experiments can declare `episodes.cycles: [2, 2]`. Counts must sum to
`max_cycles`; inputs and observations still use absolute run cycle numbers.
Multiple episodes require an explicit `carry` list containing `engine_state`,
`memory`, `reliability_weights`, `learned_parameters`, `budgets`, `pending_evidence`,
`host_state`, `motivational_state` and `rng_state`. The controlled scenario shows
this declaration. Episode boundaries label the trajectory (`episode`,
`episode_cycle`); they do not reload adapters, replenish budgets, drop pending
feedback, reinitialize motivation or reseed RNGs. Native authority/freshness checks
continue to apply to carried evidence. Separate runs give independent episodes;
selective carry/reset policies are rejected until those reset paths are validated.
Learning remains independently configured and is never inferred from episode count.

The learning probe adapter is a test double: its supported observation callback
makes fixed synthetic edits to its own value/private memory and real reliability
and parameter stores. Tests check that episode two retains them, learning disabled
leaves them untouched, and the next configuration starts clean. This demonstrates
state isolation and continuity, not a calibrated learning rule or engine improvement.

A matched result is completed only after the driver confirms episode completion,
selected adapter, effective controls, engine/configuration versions and cap. Enabled
collection must actually produce runtime intake. Completion itself is not a task-success or prediction-quality grade, nor evidence
that positive influence improves outcomes. Those measurements have separate
retained evidence and coverage below.

This format validation checks JSON structure and basic configuration consistency.
Existing runtime validators remain authoritative for native intake limits,
observations, permissions and causal ownership. The records do not authorize
fixture execution or certify trace artifacts. Larger scenario datasets,
additional task oracles, external resource instrumentation and broader performance
validation remain separate implementation steps.

## Benchmark measurements

Normal matrix runs populate `result.json.measurements`. Legacy `--entry` smoke
runs remain unmeasured.

`read.scenario.json` declares an `evaluation.checks` entry with `cycle: 1` and
`oracle: "read-file-content-v1"`. This checks a real read task: the run-owned file
is independently read before selection, and its contents are compared with the
exact retained command, callback and ticket. A response claiming success is not
sufficient. Other task types need their own independently verifiable oracle;
finishing a benchmark process does not complete an arbitrary natural-language task.

Post-run prediction scoring supports the declared `ExpectedOperationResult`
schema with the versioned built-in exact-result semantics. It uses only immutable
receipts for the exact retained primary proposal. Unsupported/custom comparator
routes, uncertain outcomes, identity conflicts and unobserved alternatives stay
ungraded. Duplicate identities count once. The receipt itself remains ungraded;
benchmark comparisons live separately in measurements and never call assessment,
feedback or reliability-update APIs. This remains true when runtime assessment
and learning are disabled. Prediction agreement does not establish causal influence.

Each role retains raw task, prediction and policy records plus counts and rates.
`coverage_percent` uses all eligible checks/proposals; `positive_percent` uses
verified checks only (task success, prediction confirmation or policy compliance).
`negative_percent` gives the corresponding failure/refutation/violation rate.
`ungraded_percent` and ungraded reasons expose missing coverage. An empty
denominator produces null, not a fabricated zero or perfect result. Prediction
confidence mean squared error is reported only for verified binary outcomes.
Policy auditing independently checks supported executed read/frame operations
against their pre-selection bindings, ownership, permissions, constraints and
remaining budgets. Blocked attempts are not violations; unsupported audits remain
ungraded.

Latency includes observed cycle/dispatch wall time, with nearest-rank p50/p95;
full child-process elapsed time separately includes startup and compilation.
Resource reports distinguish actual native engine-step reservations, engine
reservation calls, reasoner-provider call reservations and offline classifier
calls. Resource totals describe observed usage, with cycle coverage;
a timeout may leave a partially observed run. Counters are differenced before role grouping to avoid counting calibration
usage again in evaluation. Reserved steps are not internal instruction counts.
Provider tokens/cost and engine instruction counts remain unavailable (null) where
instrumentation does not expose them. Limits are never substituted for measured use.
Native metering is opt-in, process-local and enabled only by the benchmark fixture.

`controlled.scenario.json` uses calibration followed by evaluation episodes. Roles
must match declared episode counts and cannot return to calibration after evaluation.
Scoring occurs after the process exits and cannot change its influence or learning
configuration. Measurements never promote an influence cap. Positive influence still
requires explicit configuration and native validation of retained predictive evidence;
these offline fixture results are not a claim of general reasoner improvement.
The exact-result adapter is a deterministic comparison double, not a trained engine.

## Checking imports and initialization

`tests/trace_support_test.py` checks readable retained output and runs the bridge,
normal polling loop, and local acceptance path. Coverage includes real selection,
egress denial, no action, Rumination/Sleep transitions and uncertain execution with
held budget reservations. The shared local/IRC acceptance fixture compares state,
pending feedback, tickets, budgets and evidence before/after explicit printing and
queued emission. A neutral selection probe counts traversals; temporary spies
watch provider and send-handler entry points during printing. Existing provider,
send and read counts must also remain unchanged. Providers and channel transports
are doubles; admission, selection, dispatch, accounting and outcome application
use the real runtime. The optional reasoner boundary test separately preserves
collection counts, adapter notifications, receipts, assessments and reliability.

From the MetaMo repository root:

```bash
python3 scripts/run-tests.py --root applications/omegaclaw_v1 --import-report-dir /tmp/omegaclaw-imports
python3 scripts/import-resolution-test.py
python3 applications/omegaclaw_v1/tests/reasoner_boundary_test.py
python3 applications/omegaclaw_v1/tests/trace_support_test.py
python3 scripts/run-omegaclaw.py applications/omegaclaw_v1/run.metta --audit --report /tmp/omegaclaw-run-imports.json
```

Use `--workspace /absolute/path/to/PeTTa` on the standalone launcher, or
`--petta-runner /absolute/path/to/PeTTa/run.sh` on the suite, to select a different
workspace explicitly. The `run.sh` argument selects the compiler directory;
v1 tests still execute through the common launcher.

JSON reports list each declared import edge's owner, request, kind, and physical
target. They include transitive MeTTa imports, declared Prolog helpers, and the
two inference engine files. Repeated edges are expected where dependencies are
shared; they do not imply repeated execution. Audit mode parses source without
executing application Python, MeTTa setup, or channel startup. It does not audit
transitive Python package imports or arbitrary computed imports inside functions;
imports reached at execution still use the same resolver.

Validation after this change: all 12 v1 MeTTa test files passed, including a new
12-assertion composition test. Eight import/runner regression tests passed. The tests
cover state/evidence preservation, singleton registry facts and function results,
explicit fixture setup, symlink identity, shell-directory independence, missing
sources, application-free auditing, cycle detection, and cross-space rejection.
No live channel or persistence backend was started. CI/CD YAML remains unchanged.


Host continuation loads after the commitment adapter and before lifecycle
publication. `hostRefreshContinuation` is called directly before snapshot capture;
its command-bearing host values must not be passed through dynamic `eval`.
Only inert command identity text enters the bounded continuation view. Commitment
imports now belong to the composition so native loading still occurs once.
