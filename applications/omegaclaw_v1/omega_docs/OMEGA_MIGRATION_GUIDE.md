# Migrating the MetaMo integration to Omega

Prepared: 25 November 2026.

Move the working motivation and optional reasoner integration onto Omega's current
host architecture. Keep Omega responsible for frames, concrete operations and
execution. Preserve the existing motivational and reasoner behavior through
small, tested changes rather than replacing Omega with the older host.

This is an implementation guide, not a claim that migration has been performed.
The target files were inspected, but Omega was not installed or executed for this
document. Compatibility remains subject to the checks below.

## 1. Reference revisions and scope

| Component | Reference |
| --- | --- |
| Source MetaMo checkout | `b93cbedfde34391cc8a7b52e6a3600305be1c2ef` |
| Target repository | <https://github.com/iCog-Labs-Dev/Omega> |
| Inspected target commit | `ca386c071f09e0aee60ad67d1782493ad820a26b` |
| Source application | `MetaMo/applications/omegaclaw_v1/` |
| Source host | Workspace `repos/OmegaClaw-Core/` |
| Runtime | PeTTa, SWI-Prolog and Python/Janus; record exact local revisions and versions before starting |

Pin the target commit for the first migration. If a different Omega revision is
chosen, repeat the compatibility audit before implementing against it. Preserve
the actual source host files and hashes: a repository name or upstream revision
does not identify local changes in the copied Core directory.

Initial scope is behavior parity: motivation, exact operation dispatch, observed
feedback, optional reasoners, traces, and the supported maintenance connection.
Relation verification write-back, integer persistence migration, additional
maintenance algorithms and new benchmark environments are separate work.

## 2. What changed in Omega

### ContextFrames remain, but their ownership and lifecycle changed

The inspected target retains the familiar `Frame` fields, `RootFrame`, Fast/Slow
modes and many `cfv2-*` functions. This supports reuse of the bounded projection
contract; it does not establish full behavioral compatibility.

| Existing integration dependency | Target location or behavior | Migration consequence |
| --- | --- | --- |
| Core `src/context.metta` | `plugins/context/contextframe.metta` | Adapt imports and access through the plugin owner. Do not load a second copy of frame state. |
| Context initialization mixed with host startup | `plugins/context/context.metta`, `loadOmegaPlugin` | Coordinate initialization with plugin loading; enable frames explicitly. |
| Frame helpers in Core `helper.py` | Plugin `frame_helpers.py` | Separate frame-specific calls from remaining host helpers; verify Python module identity. |
| Core relation backend | Plugin `frame_relation.py` | Use the target backend and audit relation semantics before reusing projections. |
| Frame tools | Plugin `contextframeskill.metta` | Reuse tool registration rather than importing the old skill catalog wholesale. |
| Context handling inside the loop | `src/context_provider.metta` | Map integration phases onto the documented event interface. |
| Old LLM helper/provider imports | `src/providers.metta`, `src/providers.py`, provider plugins | Adapt provider calls at the host boundary; preserve structured results and resource accounting. |
| Old direct channel imports | Channel plugins configured in `config/plugins.yaml` | Keep target channel ownership; adapt observed send results without starting duplicate connections. |
| Old dispatch bridge and loop hooks | No matching `src/dispatch.metta` or `src/dispatch.pl` in the inspected target tree | Port required dispatch guarantees deliberately; a package rename is insufficient. |

The context plugin is disabled by default. In standalone configuration its
documented switch is `contextFrame=enabled`; launcher configuration uses
`--context-frame enabled`. The plugin must also remain listed in
`config/plugins.yaml`. An enabled integration requiring frames should reject an
incompatible startup explicitly. Plain Omega must still work when the integration
is not enabled.

The target also adds related-frame prompt composition and bounded frame-history
pruning/archival. Keep those host features. Audit the bounded facts supplied to
MetaMo separately from the larger prompt projection; do not expose raw history
just because the context provider can render it.

### Existing context events are useful, but incomplete for exact dispatch

| Target event | Existing purpose | Integration use and limit |
| --- | --- | --- |
| `(Input message isNew)` | Admit input before prompt rendering; return user-role text | Admit once, then prepare task-owned host work. Avoid duplicate admission in both the adapter and frame plugin. |
| `Prompt` | Render current working context | Render an already prepared bounded motivational summary. Rendering must not rerun selection or consume feedback. |
| `BeforeRequest` | Return a token retained for the later batch | Preserve the originating frame/request association. A frame ID alone is not the existing dispatch ticket or invocation identity. |
| `(AfterTools token commands results)` | Record a batch against its originating frame | Preserve target history recording. This batch callback alone cannot guarantee per-command validation or capture an outcome before an intermediate slot is replaced. |
| `Idle` | Perform context-specific idle behavior | Preserve frame-mode handling and schedule only explicitly available, pending maintenance through normal dispatch. |

There is **one active context provider**. Registering another replaces it. A
MetaMo plugin must not silently displace the frame provider and lose admission,
history or idle behavior. Choose one explicit integration arrangement: extend the
frame provider at the required phases, or install one integration provider that
delegates each frame event exactly once. Test the chosen order. Do not introduce
a general event bus or callback-stacking framework for this migration.

The inspected loop converts provider tool calls into expressions and evaluates
them, then emits `AfterTools`. Existing provider tool validation is not proof of
the integration's ownership, policy, budget or exact-ticket checks. Inspect and
test the actual execution path before treating it as equivalent.

## 3. Ownership and code reuse

Keep MetaMo as an explicit dependency during the first migration, pinned to a
known revision. An Omega-side integration plugin can initialize and connect that
dependency. Do not copy the entire older host into Omega to satisfy imports.
Once parity is established, packaging the dependency differently is a separate
decision. Avoid having two independently maintained copies of the same logic.

| Responsibility | Owner after migration | Source code to assess |
| --- | --- | --- |
| Motivation state, appraisal, homeostasis and constitutional posture | MetaMo | `core/`, `dynamics/`, application `adapter.metta`, `registry.metta`, `mode_layer.metta`, `signals.metta`, `omegaclaw_appraisal.metta`, `homeostasis.metta` |
| Frame storage, focus, admission and related-frame composition | Omega context plugin | Target plugin implementation; source `contexts/` defines the bounded interface to preserve |
| Task preparation, clarification, continuation and completion | Host integration using Omega APIs | `host_operations.py`, `host_requirements.py`, `host_ingress.*`, `host_completion.metta`, `host_continuation.metta`, `task_lifecycle.metta` |
| Candidate eligibility and motivational selection | MetaMo and its existing application boundary | `candidate_selection.metta`, `scheduling.metta`, `omegaclaw_decision.metta`, `operation_selection.metta` |
| Concrete commands, permissions, reservations, execution and callbacks | Omega plus the ported host dispatch boundary | Application `dispatch.metta`, `dispatch.pl`, `budget_accounting.metta`, old Core dispatch files and loop hooks |
| Proposal intake, attribution, assessment and adapter feedback | Existing optional reasoner integration | `reasoners/`; keep engine-specific semantics inside adapters |
| Trace records and printing | Existing diagnostics connected to target lifecycle | `trace.metta`, `trace_support.py`, reasoner trace readers |
| Memory maintenance effects | Host or explicitly supported engine worker | `host_maintenance.*`; keep unavailable capabilities unavailable |
| Persistent motivational state | MetaMo storage boundary using target memory APIs | `persistence.metta`; retain current encoding for the parity migration |

Classify each old host change as **already provided by Omega**, **required and
missing**, or **obsolete**. Record the replacement API and a regression test.
Port behavior only for the second category; avoid reintroducing old configuration,
provider, channel or prompt implementations that Omega has replaced.

## 4. Establish a reproducible baseline

1. Record source MetaMo, PeTTa and dependency revisions, working-tree changes,
   Python/SWI versions and the exact source host files used by the launcher.
2. Retain existing import audits, test outputs and deterministic benchmark exports.
3. Save copies of memory and configuration before any compatibility experiment.
   Start migration runs with new empty memory and output directories.
4. Run pinned Omega unchanged using its documented mock provider/channel support
   and test commands. Inspect mock identifiers and configuration at the pinned
   revision rather than guessing CLI flags.
5. Establish which differences are expected upstream changes and which are regressions.

Example source checks, from the `MetaMo` repository root:

```sh
git rev-parse HEAD
git status --short
python3 scripts/import-resolution-test.py
python3 applications/omegaclaw_v1/tests/reasoner_boundary_test.py
python3 applications/omegaclaw_v1/tests/reasoner_benchmark_test.py
bash applications/omegaclaw_v1/tests/adapter_boundary_test.sh
bash applications/omegaclaw_v1/tests/dispatch_boundary_test.sh
bash applications/omegaclaw_v1/tests/commitment_boundary_test.sh
```

These are source-baseline commands, not evidence that the target is migrated.
Also run the relevant existing MeTTa fixtures through the common source launcher.
Assertions that depend on old file layout need deliberate updates later; do not
delete their behavioral obligations simply to make the target tests pass.

Create a separate target checkout rather than replacing `repos/OmegaClaw-Core`.
The following is preparation for implementation, not something this guide ran:

```sh
git clone https://github.com/iCog-Labs-Dev/Omega.git Omega-migration
git -C Omega-migration switch --detach ca386c071f09e0aee60ad67d1782493ad820a26b
git -C Omega-migration switch -c integrate-metamo
```

Follow the pinned target's dependency instructions in an isolated environment.
Reusing the old environment can hide dependency and Python import collisions.

## 5. Implement in stages with a working checkpoint after each

### Stage A — imports, plugin loading and explicit startup

- Add one thin Omega integration entry point. Use `loadOmegaPlugin` and the
  target plugin configuration; initialize only after required frame APIs exist.
- Decide how the MetaMo dependency is resolved. The current
  `scripts/petta-imports.pl` hard-codes `repos/OmegaClaw-Core`; it cannot simply be
  reused unchanged. Preserve one audited resolver for test and normal startup.
- Import target frame code through its owner. The plugin imports into
  `&plugin-context`; confirm actual function/state visibility in the running
  compiler instead of assuming MeTTa spaces isolate compiled definitions.
- Reject module-name collisions and prove Python/Janus callers refer to the
  same initialized module object. Never load both old and new `frame_relation`.
- Make disabled integration a genuine no-op. Disabled reasoners must not load
  engine state, make provider calls or initialize reasoner audit stores.

**Exit:** pinned Omega starts normally without the integration. Enabled startup
loads exactly one frame state and one MetaMo state, with recorded import paths.
Failures report the missing capability without silently selecting another host.

### Stage B — bounded frame publication and native motivation

- Map the target current/root frame and relations to the existing bounded bundle.
  Preserve source identities, status, ownership, policies and resource fields.
- Ingest each input once; initialize or refresh its commitment through the
  existing lifecycle. Do not allow scalar motivational decay to close it.
- Apply previously observed outcomes, prepare concrete host work, then publish
  one snapshot. Use that snapshot for mode evaluation and candidate selection.
- Preserve constitutional posture, scheduling class and frame Fast/Slow mode as
  separate concepts. Preserve native candidate order and existing policy floors.
- Read the bounded state when rendering; do not make prompt generation a second
  cycle. Repeated rendering must not change motivation, invoke handlers or call providers.

**Exit:** source/target fixtures agree on admitted candidates, selected native
operation and meaningful state transitions after normalizing ephemeral IDs.
Reasoners remain disabled. A prompt-only demonstration does not complete Stage C.

### Stage C — exact command selection and guarded dispatch

This is the central compatibility checkpoint. The source installs
`configureCoreLoopIngest`, `configureCoreLoopPrepare`, `configureCoreLoopContext`,
`configureCoreLoopCommandSource` and `configureCoreLoopDispatch` hooks. Their
presence in the older host does not imply corresponding support in Omega.

- Reuse target execution APIs where they meet the contract. Add the smallest
  explicit hook at the actual execution boundary for guarantees that are absent.
- Carry the selected concrete command and original ticket as data. Do not ask
  the LLM to reproduce a selected command or treat matching text as authorization.
- Make selection ownership explicit: Omega's provider-produced tool batch and
  MetaMo's retained operation must not both execute independently. Preserve the
  baseline's permitted command scope and reject unrelated or extra operations.
- Validate current ownership, command identity, policy and available resources
  before execution. Reserve once and settle against the actual observed outcome.
- Capture each command's immutable result with its original session, frame,
  operation and ticket before another command or callback can replace it.
- Preserve idempotent delivery, uncertain consumption and late-result handling.
  A batch-level success string is not a substitute for a structured command result.
- Preserve target tool-call IDs and tool-response messages. A native selected
  operation must not acquire a fabricated provider call ID merely to fit formatting.

**Exit:** denied or stale operations have no handler effect; valid operations
execute once; duplicate callbacks do not settle or apply feedback twice. Multi-call
batches cannot bypass the selected operation, scopes or resource allowances.

### Stage D — completion and ordinary conversation

- Adapt preparation/provider interfaces without changing task ownership rules.
- Preserve confirmed send, failed send and uncertain transport outcomes. A send
  request or queued message alone must not complete the frame.
- Record results against the originating frame even if a tool changes focus.
  Coordinate the integration callback with target `AfterTools` so neither history
  nor completion is applied twice.
- Exercise greetings, ambiguous requests, clarification, concrete file work,
  failure recovery, cancellation and replacement through the actual target loop.
- Verify idle cycles do not resend prior content or invoke providers without
  admitted useful work. Keep local diagnostics separate from outbound messages.

**Exit:** ordinary tasks complete without stranded commitments or repeated
responses, and uncertain execution remains visible rather than becoming success.

### Stage E — optional reasoners, assessment and influence

- Reconnect automatic bounded facts and evidence references at the existing
  pre-selection point. Optional mode advice needs its separate pre-mode point,
  using the same published snapshot; do not attach predictions retrospectively.
- Retain existing proposal validators and invocation/configuration identities.
  Keep the `llm` source and `llm-motivational-proposal` adapter identity unless a
  separately reviewed source-contract change is required.
- Preserve engine namespace isolation. Omega's NAL/PLN libraries must not silently
  collide with the integration's prefixed local engines or share experiment state.
- Start with pure shadow collection: no selection influence or reliability updates.
  Test empty, invalid, unavailable, timed-out and stale proposals preserving native behavior.
- Route observations through the existing coordinator. Resolve comparators from
  retained configuration; preserve unsupported/uncertain predictions as ungraded.
- Enable assessment, learning and influence independently. Keep influence zero
  until predictive evidence and an explicit configuration justify a positive cap.
- Preserve primary proposal attribution to the exact operation/ticket. Shadow
  agreement is not proof that advice caused the selection.

**Exit:** native and zero-influence selections match under equivalent conditions;
NARS/PLN derive proposals through the actual target cycle; observation/feedback
delivery is automatic and idempotent. Ungraded cases leave reliability unchanged.

### Stage F — supported maintenance, persistence and traces

- Reconnect pending-work publication and the supplied memory-rent worker through
  normal target dispatch, including session-owned Sleep work without a frame.
- Retain policy gates, bounded batches, preemption and no double application of
  bridge-owned homeostasis/decay. Sleep must reject restructuring.
- Leave recharge, replay and production restructuring unavailable unless real
  bounded workers are installed. The Rumination probe is not a production worker.
- Start with empty target memory; adapt the existing motivational save/restore
  path and verify parser behavior before testing copies of old snapshots.
- Do not restore old host task state implicitly with motivational values. Persisted
  sessions, frame IDs and ticket identities must not become new execution authority.
- Preserve structured traces and optional bounded printing. Capture selection
  before signal cleanup and later execution/assessment as distinct events.

**Exit:** actual maintenance effects and save/restore round-trips pass tests;
printing changes no state and invokes no providers, engines or handlers.

### Stage G — migrate the harness to the target runtime

- Keep the scenario/result formats, process isolation, independent outcome
  checks and exporter. Replace old host-specific fixtures and launcher resolution
  where needed; do not create a benchmark-only target selector or dispatcher.
- The current runner hard-codes old host history paths and clears only selected
  inherited settings. Audit target configuration/environment variables, memory,
  history, provider and channel settings; prove every child uses private resources.
- Compare old/new native runs, then target native/NARS/PLN shadow and zero-influence
  runs with matched initial policies, operations, inputs and limits.
- Normalize only nondeterministic IDs, timestamps and private paths for semantic
  comparisons. Preserve original artifacts and all within-run causal references.
- Keep failures as results. Never fill missing target evidence with source output.
  Report unsupported grades separately from refuted predictions.

**Exit:** repeatable comparisons execute through the target loop, export complete
causal artifacts and demonstrate isolation. Matching the small read scenario proves
parity only; improved task quality requires a separate experiment.

## 6. Required regression matrix

Extend existing tests where their responsibilities still apply. Add focused target
integration coverage to the target's existing context/plugin tests rather than
creating a parallel test framework.

| Case | Required observation |
| --- | --- |
| Plain Omega, integration absent | Existing host behavior; no MetaMo initialization or required frame plugin |
| Enabled integration with disabled/broken frames | Explicit incompatible startup; no partial execution |
| Reasoner disabled | No engine calls; native motivation/dispatch remain usable |
| New input and repeated prompt rendering | One admission and one publication/selection per intended cycle |
| Valid selected command | Exact retained command/ticket; actual effect and callback |
| Extra, denied or ownership-stale tool call | No unauthorized effect; no replacement ticket rescuing stale advice |
| Frame switch during tool batch | Original result recorded against its originating frame |
| Duplicate callback or retry | One budget settlement, one lifecycle update, one feedback application |
| Timeout or uncertain result | Explicit uncertainty; reservations retained when consumption is unknown |
| Empty/stale reasoner intake | Independently valid native operation preserved |
| Shadow and zero influence | Same native selection and tie ordering |
| Unsupported prediction | Ungraded, with reason; unchanged reliability |
| Sleep without a task frame | Only configured session-owned maintenance; no invented task frame |
| Rumination probe / absent worker | Probe scope explicit; unsupported production operation unavailable |
| Enabled trace printing | Bounded local output; no repeated selection or extra side effects |
| Restart and old snapshot copy | Validated motivational restoration; no stale execution authority |
| Reversed benchmark run order | No engine, evidence, budget, memory or learned-state leakage |

Useful existing source suites include import resolution, adapter/dispatch/commitment
boundaries, `reasoner_boundary_test.py`, `reasoner_benchmark_test.py`, host ingress,
requirements, completion, maintenance, trace, snapshot and context fixtures. Target
coverage includes `tests/src_context_plugin.metta`, `tests/src_context_tools.metta`,
`tests/test_frame_provider_integration.py` and history-pruning tests at the pinned
revision. Discover their documented runner before invoking them.

## 7. Commit strategy, rollback and completion

Use small commits by responsibility: dependency resolution, context publication,
dispatch boundary, lifecycle, reasoner connection, maintenance, and harness. Keep
behavior corrections separate from moves/renames. Do not combine the migration
with a broad host directory reorganization.

For every stage retain the revision, configuration, test output, import paths and
representative traces. Stop at the last passing checkpoint when a later stage
fails. Revert the relevant code change or use the preserved source checkout and
its original private memory/configuration; do not downgrade a mutated target data
store in place. A plugin startup failure may leave side effects, so retry after
correction in a fresh process rather than assuming registration was rolled back.

Migration is complete when:

- Enabled execution uses Omega's real startup, context and tool loop, without
  silently importing the old host loop or frame store.
- Native behavior and exact operation/ticket/policy/budget guarantees pass the
  regression matrix, including real effects and callback recording.
- Reasoners remain optional, interchangeable and independently configurable.
- Supported maintenance and persistence work, with unavailable capabilities
  explicitly reported rather than simulated as successful work.
- Offline comparisons use the same target connection as ordinary operation and
  retain separate original traces, outcome checks and declared denominators.
- Configuration, dependency setup, opt-in behavior and limitations are documented
  well enough for another developer to reproduce the result.

After offline parity, perform a separately configured bounded live smoke run.
Start with a private/local test channel and explicit operations; retain observed
transport outcomes. Only then switch normal deployments to the new host.

## 8. Reference target sources

All links below are pinned to the inspected target revision:

- [Context plugin behavior and activation](https://github.com/iCog-Labs-Dev/Omega/blob/ca386c071f09e0aee60ad67d1782493ad820a26b/plugins/context/README.md)
- [Context plugin lifecycle implementation](https://github.com/iCog-Labs-Dev/Omega/blob/ca386c071f09e0aee60ad67d1782493ad820a26b/plugins/context/context.metta)
- [Frame state and operations](https://github.com/iCog-Labs-Dev/Omega/blob/ca386c071f09e0aee60ad67d1782493ad820a26b/plugins/context/contextframe.metta)
- [Context-provider boundary](https://github.com/iCog-Labs-Dev/Omega/blob/ca386c071f09e0aee60ad67d1782493ad820a26b/src/context_provider.metta)
- [Runtime loop and tool execution](https://github.com/iCog-Labs-Dev/Omega/blob/ca386c071f09e0aee60ad67d1782493ad820a26b/src/loop.metta)
- [Plugin API and dependency/loading rules](https://github.com/iCog-Labs-Dev/Omega/blob/ca386c071f09e0aee60ad67d1782493ad820a26b/docs/reference-plugin-api.md)
- [Configured plugins](https://github.com/iCog-Labs-Dev/Omega/blob/ca386c071f09e0aee60ad67d1782493ad820a26b/config/plugins.yaml)
