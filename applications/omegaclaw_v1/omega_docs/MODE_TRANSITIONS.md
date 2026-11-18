# How the application changes mode

The application chooses its constitutional mode from facts in the current
snapshot: whether a user is waiting, a failure is unresolved, a threat estimate
is present, or a frame exists. Mode selection and scheduling promotion share the
trigger definitions in `registry.metta`. They read typed `FactualSignal` values
with source references; evaluating a trigger does not call a provider or change
host frames.

Constitutional modes remain **Engaged, Threat, Rumination, Sleep**. Recovery,
Interactive, and Orienting remain scheduling classes; ContextFrames **Fast/Slow**
modes remain host-owned. A mode transition cannot relax policy admission.

## Registry records

| Record | Meaning |
| --- | --- |
| `(ModeFactTrigger group kind IsTrue)` | The boolean fact must be True; explicit False and absence do not match. |
| `(ModeRatioTrigger group kind unit enter exit)` | A valid ratio activates the group when its score meets the inclusive threshold in the declared unit. Entries within a group are alternatives. |
| `(ModeContextTrigger group condition)` | Activate the group from `frame-present` or `frame-absent` in the supplied snapshot. This is a computed condition, not a new signal. |
| `(ModeTransitionRule group mode priority)` | An active group proposes a constitutional mode. The highest numeric transition priority wins. |
| `(ConstitutionalModeDefault mode)` | Fallback when no transition rule matches. Also used by motivational initialization. |
| `(ModeTransitionParameters mode entry hold cooldown)` | Consecutive target confirmations, minimum held cycles, and cooldown cycles, respectively. |
| `(ModeTransitionOption urgent-bypass True)` | Permit a more urgent target to bypass the current hold and cooldown, but never its entry confirmations. Set to `False` to apply timers to every transition. |
| `(SchedulingPromotion candidate group class)` | Promote an already-available, admitted candidate when the group's signal entry threshold is met. Scheduling retains the highest applicable class. |

Registry data is trusted configuration. Supply one timing row per supported mode,
one default, and one `urgent-bypass` option. Entry counts must be positive integers;
hold/cooldown counts must be nonnegative integers. Use finite signal thresholds
in the producer's units, with exit thresholds at or below entry thresholds, and
positive transition priorities. These are configuration requirements, not a new
untrusted configuration ingestion/validation API.

The timing and default lookups require a single matching row. Replace a row when
changing configuration rather than appending a conflicting duplicate. Missing or
ambiguous required rows cannot produce a normal transition update.

## Wake, recovery, and competing triggers

| Trigger group | Sources | Target | Transition priority |
| --- | --- | --- | ---: |
| `threat` | `danger` or `user-angry` | Threat | 40 |
| `recovery` | `failure`, `repeated-failure`, or `stalled-progress` | Rumination | 30 |
| `wake` | `user-waiting`, `execution-request`, or a current frame | Engaged | 20 |
| `sleep` | No current frame | Sleep | 10 |

Default ratio entry/exit thresholds are zero; boolean rules test truth. Missing
ratios never match. Production omits zero classifier estimates from factual rows
while retaining them in their source; an explicitly supplied valid zero ratio
meets a zero threshold in the pure reader. Each mode defaults to `(1 0 0)` timing:
one observation, no minimum hold, and no cooldown.

- **Wake:** from Sleep, a current frame or a qualifying wake signal selects
  Engaged, unless threat or recovery takes precedence. A user-waiting signal can
  wake the motivational posture even before a frame exists; frame-dependent work
  still requires its normal admission checks.
- **Recovery:** a qualifying failure/repeat/stall signal selects Rumination and
  promotes `self-improve` to scheduling class Recovery. It does not create a fifth
  constitutional mode. When recovery evidence clears, selection returns to Engaged
  if wake conditions apply, or Sleep without a frame or other qualifying signal,
  subject to configured timers.
- **Collisions:** evaluate all matching rules. Threat beats recovery, recovery
  beats wake, and wake beats sleep with the default priorities. Tied priorities
  retain the first declared matching rule. Signal iteration order does not choose
  the winner. Rules with priority zero or less do not beat the default fallback.
- **Host wakes:** Core's timer, wake-loop counters, and Fast/Slow switches remain
  host behavior. This change neither implements a timer nor automatically emits
  a signal when Core wakes. Selection runs when the motivation cycle refreshes.

These transition priorities differ from the seven scheduling ranks in
[SCHEDULING.md](SCHEDULING.md). For example, a recovery signal can hold the
constitutional mode at Rumination while an admitted Interactive candidate beats
ordinary Rumination-class work. Mode posture and work selection serve different
purposes.

## Entry/exit thresholds and timing

For a rule targeting the current constitutional mode, the evaluator uses its
**exit** threshold to decide whether evidence still supports staying. Other
rules use **entry** thresholds. This provides hysteresis: entering may require
stronger evidence than remaining in a mode.

For example, replace the default danger trigger with:

```metta
(ModeRatioTrigger threat danger classifier-score 0.8 0.4)
(ModeTransitionParameters Threat 2 2 2)
```

With that configuration:

1. Danger score at least `0.8` must win selection on two consecutive refreshes
   to enter Threat. Clearing the evidence or changing the winning target resets
   its confirmation count.
2. Once in Threat, danger at least `0.4` still supports staying there.
3. If Threat stops winning, the mode remains held for the required two complete
   refreshes before a lower-priority exit can occur. The cooldown must also expire.
4. Higher-priority transitions may bypass timers when `urgent-bypass` is enabled;
   required entry evidence and confirmation counts still apply.

Both hold and cooldown are measured in **motivation refreshes**, not seconds,
LLM calls, command counts, or resource units. Age starts at zero on entry; cooldown
starts at the destination mode's configured value. On a retained-mode refresh,
age increases and cooldown decreases toward zero. Exit checks use the counters
at the start of that refresh. With the example above, the third lower-priority
refresh can exit after the first two retained refreshes.

Scheduling promotion shares the signal rows but always uses **entry** thresholds.
It has no independent timers or signal history. Consequently, held Threat posture
alone does not force a threat scheduling promotion after qualifying entry evidence
has disappeared. Admission still precedes scheduling, and a scheduling class
cannot authorize an operation.

## State and APIs

`ModeTransitionState` contains the tracked mode, held-cycle count, pending target,
consecutive target count, and remaining cooldown. This is local session bookkeeping,
not another signal store. It does not survive restart as an authoritative record.

- `modeTargetFromContext signals hasFrame current` computes the desired mode
  using registry rules and thresholds without updating state.
- `modeTransitionStep state signals hasFrame` applies that selection and timing
  as a pure function, returning the next bookkeeping record.
- `refreshConstitutionalMode bundle` reads existing signals and the supplied
  frame snapshot, then updates constitutional mode and transition bookkeeping.
- `constitutionalModeFromSignals bundle` reports the desired target before
  timing; it may differ from the mode retained by a hold or cooldown.
- `modeTransitionState` exposes the current counters for diagnostics.
- `setConstitutionalMode mode` is the explicit initialization/reset path. It
  resets timing counters; an invalid mode leaves both stored values unchanged.

If legacy code directly restores a different constitutional-mode value, the next
refresh discards counters belonging to the old mode. Normal callers should use
the setter or refresh API.

## Tests

From the workspace root:

```sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/mode_transition_test.metta
python3 MetaMo/scripts/run-tests.py --root MetaMo/applications/omegaclaw_v1 --petta-runner ./run.sh --jobs 2
```

Tests cover wake, each recovery signal, entry and exit, simultaneous triggers,
registry edits changing both mode selection and scheduling, threshold boundaries,
confirmation reset, hold/cooldown, urgency override, equal-priority collisions,
default selection, mode separation, and preservation of existing signal facts.

The minimal-loop fixture includes `stalled-progress`; its expected posture is
therefore Rumination under these rules, while its response remains admissible.

## Host observation wiring

The serialized bridge finishes host bookkeeping and publishes one snapshot before
refreshing signals and the mode evaluator. A fresh message produces `user-waiting`
and any provider-extracted semantic signals. Merely lacking a result no longer
produces `stalled-progress`: admitting new work is not an observed execution stall.
Frame presence remains a snapshot context condition, not a stored signal.

Concrete execution feedback is consumed once. A validated failure creates
session/frame/commitment-owned host recovery bookkeeping. The first cycle emits
`failure` or `repeated-failure`; later cycles with unresolved recovery emit the
existing `stalled-progress` signal. Those later cycles do not replay the failure
or increment failure statistics. `NoOutcome`, `Blocked`, and `Unobserved` do not
resolve an existing failure and do not independently invent one.

For this bounded single-frame path, a validated success in the same current owner
resolves recovery. A terminal commitment, a changed frame/commitment, or a new
session discards the old recovery state. This is not a multi-frame recovery queue
or a durable restart guarantee. Recovery is exposed only as `RecoveryPending` or
`NoRecovery` in the bounded snapshot; raw outcomes remain host-side. Legacy error
projection retains its existing compatibility behavior.

`lastModeObservation` retains `(ModeObservation operation-context frame-id signals
before after evaluation)` after signal cleanup. `before` and `after` are complete
`ModeTransitionState` records, including confirmation, hold, and cooldown counters.
The before-state is normalized to the current mode using the same restoration
rule as the evaluator. The appended evaluation field is described below; this
local diagnostic format is not a versioned integration wire contract.
The trace is diagnostic and cannot authorize execution. Provider threat evidence
is transient: without a new message, it is absent on the next refresh; configured
mode holds may still retain Threat.

`tests/host_mode_transition_test.metta` exercises the six required transitions,
recovery across idle cycles, stale/duplicate outcomes, session/frame cleanup,
explicit terminal commitment events, Threat policy denial, Sleep without task
execution, and non-default confirmation/hold/cooldown timing. It runs the real
bridge, admission, scoring, and dispatcher. Only external services and one failing
handler are doubled. The admitted frame keeps Core's generated symbolic ID.
Typed policy and request admission accept that native target without converting
it to a text ID; operation/snapshot/scope identity comparisons remain exact.
Commitment APIs retain their existing textual frame reference contract.

The completion scenario calls `cfv2-complete-current-frame-to-stm` after explicit
host commitment adjudication. Core performs completion bookkeeping, moves the
original frame into completed storage, updates its index, clears the current
cache, and runs next-frame selection. Assertions establish one matching completed
record, no active refs, and no current frame. The next two full bridge cycles
remain in Sleep with no signals or executable selection. Core's `pin` handler is
used unchanged; this is not a demonstration of durable external persistence or
live channel/provider behavior.

Each required transition has a labelled `RequiredTransition` trace and asserts
both modes from the bridge's retained before/after record:

| Trace label | Transition | Evidence and clearing |
| --- | --- | --- |
| `wake` | Sleep → Engaged | Real task admission; user-waiting without false stalled-progress. |
| `execution-failure` | Engaged → Rumination | A dispatched handler error produces failure and pending recovery. |
| `resolved-recovery` | Rumination → Engaged | A successful read clears recovery; failure, repeated-failure and stalled-progress are absent. |
| `threat-input` | Engaged → Threat | The provider boundary supplies danger evidence to the real signal producer. |
| `cleared-threat` | Threat → Engaged | Consumed input no longer produces danger; recovery is absent. |
| `completed-task` | Engaged → Sleep | Host completion and next-frame selection leave no current frame or trigger evidence. |

The additional anger-input, timing, policy-denial, frame/session expiry and
repeated idle-cycle checks remain in the same regression. Bounded live validation
now passes all six transitions with real providers and native read outcomes;
see [LIVE_MODES.md](LIVE_MODES.md) for the live results and driver scope.


## Retained rule and timing evidence

The appended record has this shape:

```metta
(ModeEvaluation winning-rule requested-target rule-evidence timing-evidence)
```

`winning-rule` is the exact `(ModeTransitionRule group mode priority)` selected
by the existing priority/tie rules, or `(ModeDefault mode)` when none wins.
The requested target can differ from the after-mode while entry confirmations,
hold or cooldown delay a transition. Both selection and diagnostics use
`modeChooseRule`; the target-only APIs retain their existing results.

Each rule, including losing and inactive rules, has:

```metta
(ModeRuleEvidence (ModeTransitionRule group mode priority) active
  (TriggerEvidence
    ((FactTriggerEvidence (kind kind) (predicate IsTrue)
       (observed value) (provenance refs) (matched matched)) ...
     (RatioTriggerEvidence (kind kind) (predicate (AtLeast unit threshold))
       (phase phase) (observed value) (provenance refs) (matched matched)) ...)
    ((ContextTriggerEvidence condition matched) ...)))
```

`phase` is `Exit` for a rule targeting the before-mode and `Enter` otherwise.
`threshold` is the applicable inclusive ratio bound; `value` is the exact typed
value or `NoObservation`. `refs` contains its accepted source references or `()`
for absence. False, missing evidence, and a ratio below threshold remain distinct. Context
checks retain the evaluated frame-presence condition. Active groups that lose
on priority remain visible, making collisions inspectable.

```metta
(ModeTimingEvidence
  (current current-mode (ModeTiming entry hold cooldown))
  (target requested-target (ModeTiming entry hold cooldown))
  (urgent-bypass configured-enabled qualifies)
  (checks next-confirmation-count confirmations-met hold-met cooldown-clear))
```

These checks use counters at the start of refresh. A change requires entry
confirmations and either a qualifying urgency bypass or both hold and cooldown
checks. If the requested target already equals the current mode, the evaluator
retains it and resets pending confirmations; the recorded transition checks do
not add a condition for staying. `modeTimingEvidence` supplies the same calculation
to the transition step and diagnostics, rather than reimplementing timer logic
in the bridge.

The bridge captures this evaluation before refreshing the mode, under the
existing serialized, fixed-registry-per-cycle assumption. Stored values survive
signal cleanup and later registry edits unchanged. No evidence helper mutates
signals, host state or registry configuration.

Full-loop tests now exercise danger entry at `0.8` and exit at `0.4`, including
the exact boundaries, just-below values, and `0.6` retaining Threat while being
insufficient to enter it. They assert the retained phase/threshold and match,
winning and losing groups, confirmation and hold/cooldown checks, absence after
input consumption, and historical trace stability after a registry edit.


## Typed facts in mode decisions

Mode decisions use typed facts directly; the older numeric strength projection is retired. Mode and scheduling
matching are independent of `SignalAppraisalRule` coefficients. The same typed
predicates generate retained evidence and matching results. Latest mode evidence
pins its session sources; reset clears it and expires old references. September
JSON/JSONL artifacts remain historical and have not been rewritten.

## Maintenance capability inventory

Inventory checked 18 November 2026. `MaintenanceCapability` rows in
`registry.metta` record operation, implementation owner, handler names as inert
data, availability and reason. `Unassigned` means no concrete handler owns that
operation yet. These records register no candidates, bindings or permissions.
Posture, scheduling priority and a reasoner's candidate vocabulary do not prove
that a maintenance handler exists.

`BookkeepingOnly` runs through the existing cycle. MetaMo owns motivational
decay immediately after the motivational state update
(`BridgeAfterMotivationUpdate`) and homeostatic correction after self-model
feedback (`BridgeAfterSelfModelUpdate`), once per cycle in every posture.
The maintenance policy excludes these operations from worker registration,
queue intake and dispatch, even if a work class is declared for them. A rent
sweep accounts for queued charges without changing motivational state or
reapplying those corrections.

`PrimitiveOnly` denotes a
building block, and `LifecycleOnly` denotes explicit task completion. Neither
is a dispatchable maintenance capability. `Unavailable` marks missing or
incompatible implementations. Memory-rent accounting now has an `Available`
host implementation, which still needs an explicit policy binding and queued
observations. Other missing handlers stay unavailable; declaring their class
does not enable them.

### Bootstrap parameters and numeric representation

`BootstrapParameterPolicy` declares when initial choices may be replaced:

- Appraisal weights use graded outcomes and validated updates at cycle boundaries.
  Only existing `LearnableParameter` entries are writable; their bounds and maximum
  steps still apply. Other appraisal rules retain their current fixed status.
- Relation priors yield to verified evidence through host-authorized write-back.
  No numeric relation prior is invented here. A prior supplies neither confirmation
  nor permission to merge frames. Concrete relation write-back remains pending.
- Selection influence requires predictive performance and explicit bounded
  configuration under `ReasonerInfluencePolicy`: at least three distinct eligible
  outcomes, a mean grade of at least 0.75, and an aggregate cap no greater than 0.10.
  Influence starts disabled; meeting the performance requirement does not enable it.

These declarations describe replacement conditions; they do not enable a learner,
reasoner, write-back path or new mutable parameter.

`NumericRepresentationPolicy` allows volatile floats and requires scaled integers
for saved numbers. `PersistedNumberScale` declares units per one, encoded bounds
and rounding. Normalized motivational values, relation confidence, influence,
grades and mode thresholds use scale 10000 and integer range 0–10000. Signed
appraisal coefficients use the same scale with range -10000–10000. For example,
0.175 is saved as 1750; decode by dividing by 10000. Round to nearest with ties
away from zero. Counts remain exact integers in 0–9007199254740991. Encoding bounds
do not widen existing learning or influence limits.

The legacy motivational snapshot writer still saves floats. Applying these
declarations to save/restore requires the separate versioned encoding migration;
no existing float snapshot is silently reinterpreted as scaled integers.

### Declared work classes and limits

`MaintenanceWorkClass` maps `BoundedSweep` to Sleep and `Restructuring` to
Rumination. `MaintenanceWork` assigns an operation to one class and its initial
per-cycle limits. `maintenanceWorkFitsMode OPERATION MODE` reads only that class
membership, with Sleep restricted to `BoundedSweep` even if the registry remaps
`Restructuring` to Sleep. The same check runs at selection and final dispatch;
a retained Rumination command cannot run after switching to Sleep. Normal
permission/resource gates and salience/stakes inputs still apply.
It returns false for unknown operations, missing/ambiguous mappings
and mismatched modes. It never measures elapsed time to decide whether work is
cheap, and grants neither handler availability nor dispatch authority.

The limits constructor is
`(MaintenanceWorkLimits MAX-ITEMS MAX-ENGINE-STEPS MAX-PROVIDER-CALLS MAX-ELAPSED-MS)`.
These are seed ceilings for each operation's total work in one cycle, not a fresh
allowance for each item or retry. The host adapter enforces item and worker-time
ceilings and normal dispatch policy/resource checks. Engine/provider ceilings
are passed to trusted adapter workers, which must enforce them through their own
supported mechanisms and honor their learning controls. The supplied accounting
worker uses neither engines nor providers. Unused budget creates no pending work.

`MaintenanceOperationContract` supplies the exact permission list, command/resource
costs and observed result constructor for a connected worker. The supplied
`memory-rent` contract requires `maintenance.memory-rent`, one `commands/units`
credit per invocation and `MemoryRentAccounted` result details. Its existing
work limits are 16 items, zero engine steps, zero provider calls and 1000 ms.
Rent amounts are observed bookkeeping entries, not additional command charges.
No token, byte or resource-recharge meter is inferred from them.

The host checks the operation contract during ordinary resolution, then uses the
normal policy gate, budget reservation, original operation/ticket and actual
completion callback. Queue intake and proposal collection never execute workers.
A completed worker consumes its allowance once per operation per cycle; capturing
another ticket or delivering another batch cannot reset it. Replaying the original
ticket returns its immutable result. The next cycle may process remaining items.
Only the latest used context per operation is retained.

A worker result must be ground, bounded to 4096 serialized characters and carry
the contract's result constructor. The supplied rent worker validates observed
integer charges and its resulting ledger total. Invalid results or timeouts leave
the local transaction uncommitted and dispatch unobserved; they do not manufacture
a success receipt. This rollback does not cover external adapter side effects.
Receipts record observations without grades. Assessment still requires an
explicitly configured comparator and enabled assessment controls.

Only memory-rent has a supplied concrete operation contract and worker. Trusted
adapters must declare a contract before registering another operation, enforce
its engine/provider limits and return their declared observed result. Test probes
declare their own contract; they do not supply production restructuring support.

| Operation | Class / posture | Maximum items per cycle | Engine steps | Provider calls | Elapsed ceiling |
| --- | --- | --- | --- | --- | --- |
| Motivational decay | BoundedSweep / Sleep | 22 goal/modulator values | 0 | 0 | 1000 ms |
| Memory rent bookkeeping | BoundedSweep / Sleep | 16 memory records | 0 | 0 | 1000 ms |
| Recharge accounting | BoundedSweep / Sleep | 1 resource account | 0 | 0 | 1000 ms |
| Important episode replay | BoundedSweep / Sleep | 2 important episodes | 8 | 0 | 1000 ms |
| Memory compression | Restructuring / Rumination | 8 source records | 8 | 0 | 1000 ms |
| Memory re-encoding | Restructuring / Rumination | 8 source records | 8 | 0 | 1000 ms |
| Evidence restructuring | Restructuring / Rumination | 8 evidence records | 8 | 0 | 1000 ms |

The one-second ceiling and eight-step inference ceiling start from the current
local reasoner allowance. Zero provider calls keeps external inference disabled
by these declarations. Item limits are initial policy choices, not measured
capacity or proof of predictive value. A future handler can require tighter
limits; increasing a limit never changes its class. Compression finishing in
one millisecond remains Rumination work. Episode retrieval, garbage collection
and legacy cleanup do not acquire sweep membership from their names or speed.

The decay row classifies its bookkeeping role; it does not move the existing
bridge decay call into a Sleep-only path or schedule a second copy. Existing
homeostasis also continues at its current cycle point in every posture. All
other missing handlers retain their `Unavailable` inventory status. Class
declarations alone register no additional candidates or command bindings.

### Existing cycle bookkeeping

| Operation / owner | Inputs and effects | Limits | Observable result |
| --- | --- | --- | --- |
| Motivational decay / MetaMo: `decayMetamoState` in `adapter.metta` | A motivational state; returns goals and modulators moved toward registry baselines. No memory rent or commitment termination. | Eleven goals and eleven modulators; existing decay rate and normalized values. Already called once by the bridge before write-back. | Returned motivational state and subsequent live values. No separate dispatch receipt. |
| Homeostatic correction / MetaMo: `runHomeostasis` in `homeostasis.metta` | Current signals, motivational values and registry rules; corrects declared goals/modulators toward set-points. | One pass over configured rules with bounded steps and eight declared targets. Already called by the bridge after self-model update. | `lastHomeostaticCorrections` and updated values, including unchanged/rejected corrections. |

Reuse these existing owners when connecting posture work. Scheduling another
copy would double-apply bookkeeping. Energy and fatigue currently retain valid
values: `updateSelfModel` does not measure consumption or implement recharge.
Budget reservation/settlement also does not replenish resources.

### Missing maintenance operations

No implementation owner is assigned for the remaining operations below. Their eventual
handlers belong in the host or a supported reasoner adapter, outside the mode
regulator. Inputs and results below describe the missing contract, not an API
that can currently be called.

| Operation / status | Inputs and intended effect still to define | Missing bounds and observable result |
| --- | --- | --- |
| Recharge accounting / unavailable | An explicitly defined resource and recovery/update law; account for replenishment. | No recharge law, justified delta, cycle limit or observed before/after resource result. Setting `energy` alone is not a recharge implementation. |
| Episode replay / unavailable | Identified important episodes and a supported replay consumer; process a bounded selection. | No bounded selection/processing handler, replay item/engine limits or processed-evidence result. Retrieval alone does not replay episodes. |
| Memory compression / unavailable | Identified source records and a retained replacement with provenance. | No bounded compressor, publication mechanism or verified source-to-result receipt. |
| Memory re-encoding / unavailable | Identified existing records and a declared destination representation. | No migration handler, batch/provider limits or verified replacement result. Embedding new text is not existing-store re-encoding. |
| Evidence restructuring / unavailable | Identified evidence and supported causal/inductive results. | No supported adapter operation, bounded update mechanism or observed evidence revision. |

### Existing host and memory primitives

| Handler / owner | Inputs and effects | Existing limits / gaps | Observable result |
| --- | --- | --- | --- |
| `episodes` / Core `src/memory.metta`, `src/helper.py:around_time` | Timestamp; retrieves history lines near the closest timestamp. No replay or importance ranking. | `maxEpisodeRecallLines` defaults to 20 and controls the returned window, but `around_time` reads and buffers the entire history file. No scan/time/character bound. | Numbered history text, or no matching timestamp; no processing receipt. |
| `query` / Core memory and `petta_lib_chromadb` | Text embedded locally or by a configured provider; nearest-memory retrieval without restructuring. | `maxRecallItems` defaults to 20; provider and storage work have no maintenance-specific cost/deadline contract. | Timestamp/content pairs; provider/storage failures can propagate. |
| `remember` / Core memory and `petta_lib_chromadb` | Text, embedding and timestamp; appends a new record. No compression or replacement of existing evidence. | One record per call; text/provider/storage work needs explicit bounds before maintenance use. | Backend record ID; Core exposes `REMEMBER-SUCCESS` rather than retaining that ID in a maintenance receipt. |
| `forget_id`, `forget_ids` / `repos/petta_lib_chromadb/lib_chromadb.py` | Supplied IDs; deletes memory records. No policy selecting eligible records. | List validation exists, but no maximum batch, rent policy, protected-evidence checks or maintenance dispatch contract. | Deleted ID or ID list from the backend. Not exposed by the current v1 command catalog. |
| `gc` / Core `src/skills.pl` | No input; Prolog garbage/atom collection and stack trimming. No semantic memory rent or restructuring. | No per-call work/deadline or accounting bound. | Boolean success; no semantic-memory result or maintenance receipt. |
| `cfv2-maintain-frame` / Core `src/context.metta` | Current ContextFrame state; touches the current frame or selects the next frame if none is focused. | Can change host focus; no sweep/replay/compression operation or maintenance contract. | Current/selected frame. The `ctx-maintain-frame` alias delegates here. |

### ContextFrame compatibility and lifecycle exclusions

| Handler / owner | Inputs, effects and result | Compatibility and limits / status |
| --- | --- | --- |
| `compact-frame` / Core `src/skills.metta` | Caller-supplied summary; attempts to update history, rebuild it and return the current frame. | **Unavailable:** references legacy `&ctx-history-summary`, `ctx-record-history`, `ctxHistorySummaryLimit` and `ctx-rebuild-history`. The current context module uses `&cfv2-*` state and does not supply those helper definitions. Text truncation does not establish bounded memory compression. |
| `clear-frame-junk` in Core `src/skills.metta` | Summary; attempts to clear legacy hypotheses, results and deliverables, then rebuild history. | **Do not reuse:** writes `&ctx-*` variables. Core `src/context.metta` defines the same public name with a different implementation, so the public name is not a sufficient compatibility guarantee. |
| `cfv2-clear-current-frame-junk` / Core `src/context.metta` | Summary and a current frame; clears current hypotheses/results, updates history/timestamp, returns `FRAME-JUNK-CLEARED` or `NO-CURRENT-FRAME-TO-CLEAR`. | Uses current `&cfv2-*` fields, but has no maintenance ownership/protection checks, bounded work contract or v1 dispatch binding. Clears evidence that may still matter to an open task. **Unavailable** for scheduled maintenance until those requirements are supplied. |
| `cfv2-complete-current-frame-to-stm/ltm` / Core `src/context.metta` | Completion summary; stores a summary, marks/removes the active frame, clears its cache and selects another frame. Returns a completion status. | **LifecycleOnly:** current ContextFrame implementation, but changes task lifecycle and focus. Must remain behind explicit validated commitment completion; never use as a cleanup or compression shortcut. STM's supplied `pin` skill is a `PIN-SUCCESS` stub. LTM calls the external memory store without maintenance-specific work bounds. |

### Reasoner capabilities

The built-in `nars` and `pln` registrations in `reasoners/host_reasoner.metta`
declare candidate proposals and two prediction schemas, with empty native
feedback capabilities. Their candidate lists include `self-improve` and `learn`;
these are proposal vocabulary, not replay, consolidation or learning handlers.

`reasonerQuery` in `reasoners/reasoner_integration.metta` takes admitted Sentence
facts, a query and inference limits. It returns native truth/evidence or no
conclusion, preserving engine-specific semantics. The built-in runtime limits
are 128 facts, 4096 payload nodes, 16 proposals, 8 engine steps, queue bound 40,
zero provider calls and a 1000 ms intake timeout. Those bound candidate inference,
not a persistent replay/restructuring job. Neither built-in adapter exposes one.
Engine library inference/revision rules alone do not supply a host maintenance
operation or supported native assessment feedback.

The trusted host command catalog in `host_dispatch_config.py` resolves
`read-file`, `show-current-frame`, `send` and explicitly configured
`host-maintenance` commands with approved candidate mappings. Adding a name to
a policy skill list still grants no handler. There is no separate maintenance
scheduler or automatic engine/provider activation.

## Connected task-owned maintenance

`host_maintenance.metta` supplies bounded snapshot readers, factual producers and
eligibility. `host_maintenance.pl` owns the trusted queue and executor. Pure
composition loads no queue backend or engine; the host dispatcher installs the
local memory-rent worker during its normal initialization. Work remains opt-in.

### Concrete host accounting

The host queues already observed retention charges as
`(MemoryRentCharge MEMORY-ID INTEGER-UNITS)` records. The local worker records
their sum in a session/commitment-owned retention-accounting ledger and consumes
at most 16 records per cycle. It reads or deletes no memories, invents no rent
formula and changes no energy, motivational urgency or task lifecycle. Charges
must come from trusted host observations; the mode regulator does not produce
them. This is retention-charge accounting, not a complete retention/rent policy.

The observable result is
`(MaintenanceCompleted memory-rent BATCH-ID COUNT (MemoryRentAccounted TOTAL))`.
Core records the original ticket/result and the ordinary outcome callback records
success. That success is internal maintenance: it does not assert user-task
progress, reset the task failure streak or resolve a task recovery hold.
Identical ticket delivery does not apply the accounting twice. Batch IDs
also reject conflicting input and recognize identical completed delivery. A batch
can contain at most 128 items and 16384 serialized characters; retained pending
and completed batch identities together are capped at 128 for the session.
Amounts and ledger totals are bounded nonnegative integers.

To expose this job, trusted configuration must contain:

```json
{"skill": "host-maintenance", "arguments": ["memory-rent"]}
```

Both policy scopes must grant the `host-maintenance` skill and the exact
`maintenance.memory-rent` permission, with an available command budget. The
catalog derives a cost of one command unit and the existing `defer` candidate.
Restructuring operations map to `self-improve`. It rejects unknown operations,
arbitrary candidate overrides and attempts to dispatch existing bridge decay or
homeostasis again. Multiple pending operations in one class use configured
binding order; only the first available pending operation resolves for that
candidate, avoiding multiple concrete commands competing under one label.

### Availability, provenance and execution

Before mode evaluation, the ordinary frame snapshot includes bounded
`MaintenanceStatus` rows: operation, candidate, handler availability, pending count
and batch identity. Payloads stay in the host queue. The existing factual signal
path derives `sweep-handler-available`, `sweep-ready-items`,
`restructuring-handler-available` and `restructuring-ready-items`, with the same
published observation reference. Ready counts include only jobs whose handlers
are available. A configured but empty queue produces explicit zero; no configured
bindings add no maintenance facts to the native signal path.

Candidate generation requires positive ready-item facts and a matching snapshot
row with available handler, pending work and class/posture eligibility. Native
admission, scheduling ranks, selection and exact-ticket dispatch remain in use.
Host-only accounting works with no reasoner selected. New user input can wake
the system and select independently valid native work ahead of a sweep.

Private host APIs `mm_maintenance_register(OP, DEPENDENCY, WORKER)` and
`mm_maintenance_queue(OP, ID, ITEMS, RESULT)` support additional trusted adapters.
`DEPENDENCY` is `Host` or an explicitly selected reasoner adapter's string ID.
`WORKER(ITEMS, LIMITS, DETAILS)` owns its operation semantics, bounded engine use
and native feedback/learning rules. Neither API is exported as a model skill.
Built-in NARS/PLN adapters still provide no replay, compression or native learning
worker. Unsupported operations cannot borrow a class declaration as a capability.

The executor rechecks owner, selected engine and posture, requires Core's pending
ticket/reservation boundary, and applies its item and elapsed limits. Direct
expression evaluation cannot invoke a job before dispatch. The local accounting
and queue updates are transactional. Failed/timed-out work remains unconsumed,
holds further work for that operation and leaves Core's outcome uncertain; it
does not become success or trigger an automatic retry. External adapters must
provide their own idempotent/transactional effect boundary; a Prolog transaction
cannot roll back an external service or native engine's private state.

Task-owned queues retain their active user frame and open-commitment checks.
Idle local accounting has the separate session scope described below. Host
dispatch initialization resets the session-only queue/ledger. Ordinary cycles
neither reset the queue nor apply existing homeostatic/decay corrections twice.

`tests/host_maintenance_test.metta` exercises actual local accounting, provenance,
empty and consumed queues, bounded batch continuation, duplicate/conflicting
delivery, policy/budget denial, revoked handlers, native wake selection and
unchanged commitments. A clearly labelled transactional probe tests the generic
Rumination adapter, missing dependencies and timeout rollback; it does not claim
to implement real compression or native engine learning.

## Session-owned idle accounting

Sleep can run local memory-rent accounting with no current task frame. Its owner
is `(SessionMaintenanceOwner SESSION ROOT-ID)` and its policy/account target is
`(SessionTarget SESSION)`. Both identities come from the actual host session;
no frame or commitment is created to authorize the operation. Queued task work
and session work cannot consume each other's observations or target budgets.

Opt in with an `idle_maintenance` section in the existing trusted host profile:

```json
"idle_maintenance": {
  "session": {
    "skills": ["host-maintenance"],
    "permissions": ["maintenance.memory-rent"],
    "egress": [],
    "constraints": [],
    "budgets": [
      {"resource": "commands", "unit": "units", "available": 2, "status": "Open"}
    ]
  },
  "commands": [{"skill": "host-maintenance", "arguments": ["memory-rent"]}]
}
```

The profile's existing `global` scope must also explicitly grant this skill and
permission with an available command budget. Each invocation reserves/settles
one global command unit and one session command unit. Native root constraints
and the root budget status still apply. Reinstalling or raising a policy ceiling
does not replenish spent/reserved accounting balances. The task's frame policy
does not grant idle permission, and idle permission cannot authorize task work.

Normal startup installs the optional idle profile when no admitted task is
focused. Repeated polling is idempotent and preserves captured tickets. Removing
the section revokes idle grants without deleting queued observations or resetting
budgets. Default profiles provide no idle authority. Trusted hosts may also call
`host_dispatch_config.provision_idle()` after configuring startup.

Only the supplied local memory-rent worker is supported in this scope. Recharge,
replay, restructuring, sends and arbitrary commands retain their existing task
requirements; a selected engine or a broader permission list cannot extend this
exception. Admission requires Sleep, no current frame, no new message and a
managed observation for the exact session. The selector's empty-frame exception
is restricted to the corresponding ready `defer` candidate; ordinary empty-frame
bundles still select no work.

Core reuses the same immutable ticket/result, policy checks, cost reservation
and outcome callback. New input, a focused task, a changed session or revoked
policy invalidates captured idle authority. A subsequent session cannot consume
the previous owner's queue. Idle work can resume after focus clears while an
unrelated commitment remains open, preserving that commitment and its frame
record. Maintenance receipts still do not assert task progress or clear recovery.

The normal-loop tests cover absent frames and commitments, exact session targets,
both-scope budgets and permissions, root policy denial, idempotent provisioning,
wake-up before ingestion, stale tickets, valid task dispatch, open-commitment
preservation, session rollover, revocation and non-replenishing budget ceilings.
