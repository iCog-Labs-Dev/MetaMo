# Scheduling preemption

The v1 application selects work in this order:

**Threat-remediation > Recovery > Interactive > Orienting > Engaged > Rumination > Sleep**

These are scheduling classes. They do not add constitutional modes or change
ContextFrames execution modes:

| Concept | Values | Purpose |
| --- | --- | --- |
| Scheduling class | The seven classes above | Choose which admitted work competes this cycle. |
| Constitutional mode | Engaged, Threat, Rumination, Sleep | Motivational posture and additional policy restrictions. |
| ContextFrames execution mode | Fast, Slow | Host/frame execution context and compatibility. |

Names such as Engaged and Sleep overlap, but their meanings and APIs remain
separate. Selecting Interactive work does not set the constitutional mode to
Interactive; that value is still rejected by `setConstitutionalMode`.

## Selection rules

1. Existing availability rules determine which candidates are relevant.
2. Admission rejects work that violates the applicable gate.
3. Scheduling keeps only candidates in the highest remaining class.
4. Existing motivational scores select within that class. Equal scores retain
   input order.

For example, an admitted Recovery candidate with score zero preempts an admitted
Engaged candidate with score one. If Recovery work is rejected, it cannot suppress
otherwise admitted work. Lower-priority actions are deferred, not added to policy
rejection diagnostics. Empty input, unknown-only input, and all-rejected input
produce no action.

The bridge filters admitted actions before the bimonad cycle, including any
consensus scoring. The bundle-aware decision facade also applies the filter so
direct callers use the same order. The old unbound `omegaclawDecide` scoring
utility remains a score-only path; v1 runtime decisions use a bound frame bundle.

## Candidate mapping

The registry declares each candidate's base class and the fixed class ranks.
Scheduling reads existing signal facts; it maintains no additional signal or
numeric salience state.

| Class | Existing candidate mapping |
| --- | --- |
| Threat-remediation | `verify-frame-state`, `defer`, and `ask-clarification` are promoted here when `danger` or `user-angry` is present. |
| Recovery | `repair-failure`; also `self-improve` when `failure`, `repeated-failure`, or `stalled-progress` is present. |
| Interactive | `respond`, `ask-clarification` unless promoted for threat remediation. |
| Orienting | `retrieve-memory`, `search-knowledge`, `recall-goals`, and `verify-frame-state` unless promoted. |
| Engaged | `execute-skill`, `learn`, `background-work`, `invent-goal`, `plan-goal`. |
| Rumination | `self-improve` without a recovery trigger. |
| Sleep | `defer` without a threat trigger, and `none`. These are current fallback candidates; this change does not implement a maintenance sweep. |

Signal presence uses the existing application's presence semantics; scheduling
does not invent a new strength threshold. Removing a trigger removes its promotion
on the next selection. A constitutional Threat mode alone does not promote every
candidate to threat remediation. Candidate type `safety` is also not a scheduling
rank or an authorization grant.

Preemption applies to the candidates available and admitted for this cycle. It
does not create otherwise unavailable work, switch frames, cancel an in-flight
handler, reserve resources, or implement a host-wide queue. Core still revalidates
the actual command before execution. Existing preliminary candidate gates remain
distinct from concrete host permission, egress, and cost checks.

## APIs

- `schedulingPriorityOrder`: return the registry's declared order.
- `schedulingPriorityRank class`: return rank 1–7, or zero for an unknown class.
- `schedulingPriorityPreempts higher lower`: strict comparison of two known
  classes. Equal or unknown classes do not preempt.
- `schedulingPriorityForCandidate signals candidate`: classify existing work.
- `scheduleAdmittedActions signals actions`: preserve the full actions and their
  order at the highest known rank; return an empty list if no known rank exists.

The historical `constitutionalModePreemptionOrder`,
`constitutionalModePreemptionRank`, and `constitutionalModePreempts` functions
remain compatibility aliases. Their names are historical; new code should use
the scheduling APIs. In particular, a known class no longer “preempts” an unknown
value simply because the unknown value maps to zero.

## Verification

From the workspace root:

```sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/scheduling_test.metta
python3 MetaMo/scripts/run-tests.py --root MetaMo/applications/omegaclaw_v1 --petta-runner ./run.sh --jobs 2
bash MetaMo/applications/omegaclaw_v1/tests/adapter_boundary_test.sh
```

The scheduling tests exercise all 21 higher/lower class pairs in both input
orders through real admission and selection, using a lower numeric score for
the higher class. They also cover simultaneous signals, trigger removal,
same-class scoring and ties, rejected high-priority work, no-action output, and
independence from constitutional and Fast/Slow modes. Poison scoring values
confirm that rejected and deferred actions never reach the numeric scorer.
