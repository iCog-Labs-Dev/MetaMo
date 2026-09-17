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
