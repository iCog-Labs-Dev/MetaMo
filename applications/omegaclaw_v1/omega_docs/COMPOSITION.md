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

### Reading a cycle summary

`formatCycleSummary EVENT` returns text from a retained `CycleSelection` event
and its correlated events in the current bounded trace window.
`printCycleSummary EVENT` prints it; `printLastCycleSummary` selects the latest
retained cycle even when execution or assessment events arrived afterward:

```metta
!(printLastCycleSummary)
```

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

## Checking imports and initialization

From the MetaMo repository root:

```bash
python3 scripts/run-tests.py --root applications/omegaclaw_v1 --import-report-dir /tmp/omegaclaw-imports
python3 scripts/import-resolution-test.py
python3 applications/omegaclaw_v1/tests/reasoner_boundary_test.py
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
