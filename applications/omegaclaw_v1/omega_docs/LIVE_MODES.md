# Watching modes change in a live run

This report records a controlled run through the four constitutional modes using
real provider signals and Core handlers. It explains what changed, which checks
passed, and what the run did not test.

Verified 24 September 2026, 19:27 UTC: **61 assertions passed in ten cycles**,
with one session and at most one active native Core frame. All six required
transitions occurred through the real bridge and signal producers. The final
invocation completed in 33.182 seconds without timeout or automatic retry.

## Run this check again

From `MetaMo/applications/omegaclaw_v1`:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/verify_live_cycle.py --modes
```

Use the dependencies and provider configuration in [LIVE_SETUP.md](LIVE_SETUP.md),
including the existing `ASI_API_KEY`, direct ASICloud access, and cached local
embedding model. This makes real provider requests using synthetic messages.
The runner creates an isolated `/private/tmp/oc-cycle-*` inbox, file, ChromaDB,
history, host policy, generated entry, import report and logs. No credentials are
recorded. The process deadline is 180 seconds; timeout fails the run and terminates
its process group. Provider requests have a 30-second timeout and no transport retry.

The scenario uses production startup imports, native candidate selection and
scoring, actual Core `read-file`, real embeddings/ChromaDB, and real ASICloud
confirmation/semantic extraction. It never calls `setConstitutionalMode`, inserts
signals, changes registry thresholds, or substitutes a handler/provider/scorer.
The default registry uses one confirmation, zero hold and zero cooldown.
Retained `ModeObservation` records include the winning rule and timing evidence.

It remains a controlled serialized host driver, not the autonomous Core polling
and LLM command-generation loop. It dispatches the bridge's exact selected command
through the installed Core loop dispatch hooks. The local inbox supplies three
actual inputs: the initial read request, confirmation after repairing the file,
and controlled anger text. Only the first admits a frame; the latter two are
explicit same-task follow-ups. Each fresh-input flag is cleared on the next idle
cycle. No extra frames or sessions are created to force recovery.

## Observed transitions

| Cycle | Transition | Real cause |
| --- | --- | --- |
| 1 | Initial Engaged → Sleep | No admitted frame or qualifying signals; establishes idle baseline. |
| 2 | **Sleep → Engaged** | Admit the read task; provider-backed confirmation and frame presence activate wake. |
| 3 | **Engaged → Rumination** | The selected native reader finds its file absent before opening. Correlated `Failure` produces the `failure` signal and `RecoveryPending`. |
| 4 | Rumination retained | Failure is not counted again; unresolved recovery produces `stalled-progress`. |
| 5 | Rumination retained | Restore the file and receive the next explicit confirmation. A newly selected, authorized native read succeeds. |
| 6 | **Rumination → Engaged** | Consume that success; host bookkeeping clears pending recovery and its signals. |
| 7 | **Engaged → Threat** | Real semantic extraction recognizes the controlled anger message (`user-angry 0.95`). |
| 8 | **Threat → Engaged** | Clear fresh input; threat evidence is absent, no recovery remains, and the frame is still active. |
| 9 | **Engaged → Sleep** | Host-adjudicated completion followed by Core's actual STM frame completion leaves no active/current frame. |
| 10 | Sleep retained | No signals or selected command; completed work does not reappear. |

Completion checks the retained successful read against Core's dispatch ledger,
expected file content, current session and frame, and open commitment. Only then
does it record the host completion outcome and apply the terminal commitment
event. `cfv2-complete-current-frame-to-stm` performs actual frame completion;
the scenario verifies zero active references and one completed reference.

## Policy and duplicate checks

- Redelivering the actual failure callback returns `OutcomeDuplicate`. The
  failure count stays one through failure consumption, pending recovery and repair.
- Before the anger input, trusted provisioning removes file-read permission.
  Threat selects no executable command. The selected-path attempt is blocked
  with `MissingDecision`; a fresh authoritative Core ticket is explicitly blocked
  with `PermissionDenied`.
- Sleep rejects both the earlier successful ticket and `LegacyDispatch` when
  attempting the actual registered reader. Core's ledger remains at two executed
  handler records: one observed failure and one successful read. No additional
  handler execution is recorded during Threat, completion or Sleep.

## Reader change and compatibility

Preserve the updated **OmegaClaw-Core `src/skills.metta`** alongside the budget
overlay in [LIVE_CYCLE.md](LIVE_CYCLE.md). `read-file` now returns the typed value
`(Error read-file FileUnavailable)` when its pre-open existence check fails.
The existing outcome adapter classifies this as `Failure`; no new signal or
mode rule is needed. Empty file contents still represent a successful read.

Exceptions or races after that preflight check still propagate to Core's
conservative `Unobserved / ExecutionUncertain` result. The dispatcher does not
reclassify arbitrary handler failures or claim that side effects did not occur.
`FileUnavailable` means the preflight could not establish an existing file; it
does not distinguish every filesystem reason for unavailability.

The earlier seven-cycle report remains historical: its missing-file result was
`Unobserved` under the old handler. The default live-cycle script now consumes
the definite failure in an additional cycle before recovery. This change does
not migrate persisted state or add automatic retries to held continuation plans.

## Evidence and regressions

- [Result and transition events](../tests/LIVE_MODE_RESULTS_2026-09-24.json)
- [All 15 snapshot/selection/outcome traces](../tests/LIVE_MODE_TRACE_2026-09-24.jsonl)
- Original artifacts: `/private/tmp/oc-cycle-wpun4h8p/`, including generated
  configuration/entry, provider output, import report and source SHA-256 manifest.

The report verifies one session, all six labelled before/after pairs, at most one
active frame, empty idle/completed states, and unchanged execution counts after
recovery. Source fingerprints matched when evidence was retained.

All **50 focused MeTTa files** passed, including 11 new native-reader assertions
for nonempty/empty reads, definite absence, restoration and distinct uncertainty.
Existing selected-operation and continuation tests now expect definite failure
for pre-open file absence. Core dispatch passed **20 tests / 22 generated cases**,
including generic uncertain/partial-execution behavior.

The updated default `python3 tools/verify_live_cycle.py` command also passed:
37 assertions, eight cycles and 14 trace records, with artifacts retained at
`/private/tmp/oc-cycle-toxeg4qu/`. Its added cycle consumes definite failure
before the next explicit recovery confirmation.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 ../../scripts/run-tests.py --root . --petta-runner ../../../run.sh --jobs 2 --timeout 60
swipl -q -s ../../../repos/OmegaClaw-Core/Autotests/dispatch/dispatch_test.pl
```

Regression logs: `/private/tmp/oc-modes-regressions-final.log` and
`/private/tmp/oc-modes-core.log`. Earlier live artifacts retain a harness
completion-parser failure (`oc-cycle-x87q3ur1`) and a passing run before
empty-frame diagnostic correction (`oc-cycle-givnc7v8`). The final run did not
retry. The known nonfatal Janus module-import diagnostic remains present.

This verifies the recorded mode transitions for the bounded driver. It does not
establish autonomous command generation, durable restart
recovery, non-default live timing profiles, or live reasoner integration.
