# Registry-driven mode transitions

Constitutional mode selection and scheduling promotion read the same trigger
definitions in `registry.metta`. They consume the existing `(signal kind strength)`
facts and, for mode selection, the bounded snapshot's current-frame presence.
No trigger evaluator creates signals, calls a provider, or mutates host frames.

Constitutional modes remain **Engaged, Threat, Rumination, Sleep**. Recovery,
Interactive, and Orienting remain scheduling classes; ContextFrames **Fast/Slow**
modes remain host-owned. A mode transition cannot relax policy admission.

## Registry records

| Record | Meaning |
| --- | --- |
| `(ModeSignalTrigger group kind enter exit)` | The named existing signal activates this group when its strength is at least the applicable threshold. Entries within a group are alternatives: any match suffices. |
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

## Default wake, recovery, and collision behavior

| Trigger group | Sources | Target | Transition priority |
| --- | --- | --- | ---: |
| `threat` | `danger` or `user-angry` | Threat | 40 |
| `recovery` | `failure`, `repeated-failure`, or `stalled-progress` | Rumination | 30 |
| `wake` | `user-waiting`, `execution-request`, or a current frame | Engaged | 20 |
| `sleep` | No current frame | Sleep | 10 |

All default signal entry/exit thresholds are zero. This retains presence semantics
for the existing nonnegative signal strengths: an absent signal does not match,
while a present zero-strength signal does. Each mode defaults to `(1 0 0)` timing:
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
(ModeSignalTrigger threat danger 0.8 0.4)
(ModeTransitionParameters Threat 2 2 2)
```

With that configuration:

1. Danger strength at least `0.8` must win selection on two consecutive refreshes
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
repeated idle-cycle checks remain in the same regression. Live validation remains
Task 6 in the integration plan.


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
    ((SignalTriggerEvidence kind phase threshold observations matched) ...)
    ((ContextTriggerEvidence condition matched) ...)))
```

`phase` is `Exit` for a rule targeting the before-mode and `Enter` otherwise.
`threshold` is the applicable inclusive bound; `observations` contains that
kind's actual `(signal kind strength)` records, or `()` for absence. This
separates missing evidence from present evidence below its threshold. Context
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
