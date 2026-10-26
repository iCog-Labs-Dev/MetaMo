# Explicit session continuation

## Holding uncertain reads (F4.8)

An uncertain read is not a missing file. `hostCorrectionTarget` remains available
only for typed MissingInput recovery; timeout, unknown output or absent feedback
cannot create correction/resume authority. The existing resume guard also rejects
an outstanding Core invocation, independently of path permission or retry count.

The lifecycle now calls `observeHostUncertainty` before applying feedback and
clearing selection. Under Core's dispatch mutex, the trusted adapter looks up
the retained selected read's exact ticket/command. Only Core's canonical
`DispatchResult Unobserved ExecutionUncertain none` is republished through the
existing `ingestOperationOutcome` API. This closes the lost-callback gap where
Core had recorded uncertainty but continuation still appeared Ready. Correlation,
immutable callback handling and one-shot consumption retain their existing rules;
no outcome is inferred from elapsed time, silence or model text.

While Core retains an unresolved read invocation, operation capture returns no
executable bindings or fresh selected tickets. Final v1 dispatch revalidation
also returns `OutstandingInvocation`, including for a manually captured fresh
ticket. The original ticket replays its recorded uncertain result without another
handler call. Restoring file access or sending a current-owner correction or
follow-up does not resolve that observation. Previously completed reads, the held
cursor, plan revision, commitment and retry allowance remain intact.

These new capture/final-dispatch checks apply to unresolved `read-file` attempts
in the bounded read workflow. Existing general outstanding-invocation guards for
resume, planning and task handoff remain in use. Supported send behavior outside
this read-continuation boundary retains its existing semantics.

No uncertain-effect reconciliation API is added: the current workflow leaves
uncertain reads held for host review. A future release path must require trusted
evidence correlated to the original attempt. A user statement, timeout or new
ticket is not such evidence. Session reset or dispatcher restart is not proof
that a possible effect did not occur; durable recovery remains separate work.

The existing continuation fixture triggers a native file-open exception after
Core's existence check, then restores access. One case deliberately omits the
adapter callback and verifies authoritative recovery before selection, unchanged
prior-read evidence/counters, rejected resume, original-ticket replay, fresh-ticket
rejection and later idle cycles without another read. Another uses the actual
Core polling loop and receives correction/follow-up messages while the uncertain
read remains held, with no answer or additional handler effect. Provider/memory
services are doubled; the file handler and Core ledger are real. These permission
fixtures run as an unprivileged user and restore the synthetic file's permissions.

Verified 26 October 2026: all 75 MeTTa files pass (496 continuation test markers),
97 preparation/requirements/ingress/configuration Python tests, all four boundary
guards and Core dispatch's 20 declared tests / 22 generated cases pass. Reproduce
from the application directory with
`python3 ../../scripts/run-tests.py --root tests --jobs 4 --timeout 60`.
Local full-suite log: `/tmp/f48-metta-suite.log`. No live requests/messages were sent.

## Per-step retry limits (F4.7)

The trusted registry declares exactly one `(ContinuationRetryPolicy 2)` row.
The integer limit is 0–16; zero disables correction retries. The default allows
two accepted resumes per step after the initial attempt. Missing, duplicate or
invalid policy rejects plan installation before changing continuation state.
Changing registry policy affects newly installed plans only.

Installation captures `(ContinuationRetries SESSION COMMITMENT PLAN LIMIT COUNTS)`
with one `(StepRetries STEP-ID 0)` row for each original step, in plan order.
The exact session, open commitment snapshot and plan own these counters. Changing
a path or advancing the plan revision does not change step identity or reset its
allowance. Successful successor installation replaces the counters; session reset
clears them. The state is session-only and is not restored across restart.

F4.5's existing locked resume transition validates the retained state, then checks
the held step's count against its captured limit. Preparation computes the next
count without writing; only an accepted resume commits that increment alongside
the revised plan/evidence, with the existing single epoch invalidation. Denied or
malformed corrections, stale ownership, selected/uncertain invocations and replay
consume no additional retries. The count measures accepted resume transitions,
not observed successful reads or budget charges; an accepted resume consumes its
allowance even if the later model emits no command or execution fails.

At the limit, resume returns `(ContinuationRejected RetryLimitExceeded)`. The
pending step, correction, revision, successful-read evidence, counters and epoch
stay unchanged. F4.6's automatic hook uses the same guard, so later idle cycles
cannot dispatch another retry. The commitment stays open and the step stays Held
for host review. Another path or a higher registry limit cannot restart that
exhausted step. Invalid, missing or mismatched stored counters return
`InvalidRetryState` rather than silently starting over at zero. Retry state is
also included in dispatch freshness snapshots.

Verification uses the existing continuation fixture: native missing-file results,
explicit ingress and normal bridge cycles show one step consuming one retry and
succeeding while the next consumes its own two retries and remains held on the
third correction. Tests preserve the first read and assert no new handler result,
revision, counter or epoch mutation on exhaustion; malformed counters, changed
paths/policy, replay, zero allowance, reset and policy bounds are covered too.
All 75 MeTTa files pass, including 470 continuation test markers; 97 relevant
Python tests and all four boundary guards pass. Reproduce from the application
directory with `python3 ../../scripts/run-tests.py --root tests --jobs 4 --timeout 60`.
Local log: `/tmp/f47-metta-suite.log`. No live provider/channel calls were made.

## Automatic correction capture and fresh retry tickets (F4.6)

`prepareTaskStateForMetaMo` now calls `prepareAutomaticContinuationResume` after
consuming prior feedback and clearing the old selection through
`beginOperationCycleForFrame`. Before publishing the cycle's one frame bundle,
the hook checks a recorded correction through F4.4 and F4.5. No correction is a
no-op; stale, denied or unsupported corrections leave the read held. The existing
planning hook refreshes the resulting continuation view before snapshot capture.
No model proposal, correction text or plan grants permission.

A successful resume enters ordinary `captureCandidateOperations`, pending-read
filtering, admission, scoring and Core dispatch. The selected command retains
its newly captured ticket. The failed ticket's identity, epoch, captured context
and result remain immutable; replay returns the recorded failure without reading
again. Unexecuted pre-resume tickets are stale, and substituting the failed ticket
for the new selected ticket is rejected. This also applies when the corrected
command has exactly the same arguments as the failed command.

The real polling loop requires the matching Core `src/loop.metta` and
`src/dispatch.metta` changes: Core receives once and retains original text alongside
its legacy sanitized text. V1 startup opts into original text with
`configureCoreLoopIngest ingestHostMessage True`, preserving correction JSON quotes
without guessing how to reverse `_quote_` substitutions. One-argument callback
configuration and standalone Core retain legacy input handling. Channel
authentication and host ownership checks remain in their existing paths.

Existing Core-loop fixtures supply a task, an explicit correction after observed
clarification and a repeated correction. They never call plan/admission/resume APIs
to advance the task. Local scenarios cover a replacement path, identical-argument
retry, denied permission and stale revision. Positive runs retain the first read,
execute the corrected read once with a fresh ticket, answer from actual evidence,
complete the local task/frame and remain idle. A plan awaiting completion cannot
select its obsolete input-recovery clarification. The IRC socket-double scenario
uses the same hook and submits one question and one answer; its read commitment
stays open under the existing local-only read-completion contract. F4.7 now bounds
accepted resumes; F4.8 now holds uncertain reads. Live acceptance and trusted
uncertainty reconciliation remain separate work.

Verified 26 October 2026: all 75 MeTTa files pass (428 continuation test markers),
97 preparation/requirements/ingress/configuration Python tests, all four boundary
guards and Core dispatch's 20 declared tests / 22 generated cases pass. Run
`python3 ../../scripts/run-tests.py --root tests --jobs 4 --timeout 60` from the
application directory. Local full-suite log: `/tmp/f46-metta-suite.log`.
Providers/memory/sockets are doubled; no live requests/messages were sent.

## Resuming a held read (F4.5)

Trusted host callers pass F4.4's result to `(hostResumeContinuation ADMISSION)`.
The existing Core dispatch mutex spans fresh correction admission, exact comparison
with the supplied resolved step, safe-point checks, state changes and dispatch-epoch
invalidation. Earlier admission grants no durable authority: a replaced owner,
changed frame/session/revision/recovery, revoked binding or denied policy rejects
without changing the held plan. Both selection slots must be empty, and Core must
have no unresolved invocation. Use the ordinary host cycle boundary to clear an
old selection, even if its result has already been observed.

Success returns `(ContinuationResumed PLAN STEP NEW-REVISION)`. It replaces only
the held pending step and the same step in the evidence plan. Completed read
outcomes and their original tickets remain intact, and later pending steps retain
their order. The complete updated plan must preserve its existing shape and
unique-path rules. The plan revision advances exactly once; malformed or exhausted
revisions reject rather than wrap. Commitment identity/revision and task state do
not change.

The transition clears the resolved read-recovery record, pending correction,
clarification receipt and prepared-response readiness. It fences the last retained
operation outcome against continuation consumption, so an old failure or idle
no-action observation cannot hold or advance the resumed step. Original outcome
evidence remains in Core; host recovery posture still waits for observed success.
The projected continuation view is cleared until normal host publication refreshes
the Ready step. Core's epoch advances once, invalidating previously captured
decisions. Replaying the consumed correction returns `StaleCorrection` without
another revision/epoch change.

Resume itself invokes no provider, file handler, send or completion, and allocates
no ticket. Normal selection/capture still owns execution and final dispatch
revalidation. This is a trusted session-only API, not a model skill. F4.6 now
connects it to the automatic host cycle above. It supports the existing MissingInput
correction target;
general replanning and resolving uncertain effects remain outside this slice.
F4.7 now applies its per-step retry guard and F4.8 holds unresolved reads;
full recovery acceptance remains separately tracked.

The existing continuation regression performs a real first read, a missing second
read, explicit correction ingress, F4.4 admission and F4.5 resume. A normal cycle
then reads the replacement, and the existing answer collector accepts both actual
results without rereading the first file. Tests also cover preserved pending tails,
post-admission revocation, wrong resolved steps, replay, stale ownership/revision/
session, selected/uncertain invocations, invalid evidence, duplicate paths,
revision bounds, old-ticket rejection and pre-resume feedback fencing. External
providers/memory are doubled; no new test files or Core/Prolog edits are needed.

Verified 26 October 2026: all 75 discovered MeTTa files pass, including 418
continuation test markers; preparation/requirements/ingress Python suites pass
35/22/11 tests, and all four boundary guards pass. Reproduce from the application
directory with `python3 ../../scripts/run-tests.py --root tests --jobs 4 --timeout 120`.
Local full-suite log: `/tmp/f45-metta-suite.log`. No live provider/channel calls.

## Validating a corrected path (F4.4)

Trusted host callers validate F4.3's retained proposal through
`(hostAdmitCorrection (hostContinuationCorrection))`, after loading dispatch.
The supplied record must still equal the current held MissingInput correction.
Core's existing dispatch mutex covers that comparison and the existing
`hostAdmitContinuation` catalog/policy admission. Stale ownership, session, frame,
plan revision or recovery evidence returns `ContinuationRejected StaleCorrection`.

Admission checks one proposed `ExecutionStep`, retaining the held step ID. Relative
paths resolve lexically against the host working directory, using F3.3's resolver;
only an exact installed read binding can match. No basename search, glob/tilde
expansion, symlink following or file-content access occurs. The existing concrete
gate checks current global/frame skills, permissions, constraints, budgets and
mode restrictions. Missing/ambiguous bindings and denied paths retain their typed
`ContinuationRejected` reason. Command-like path strings remain inert data.

Success returns `(ContinuationCorrectionAdmitted ORIGINAL-CORRECTION RESOLVED-STEP)`.
The original record preserves the target and held recovery evidence for a later
ownership check. This is point-in-time admission, not durable authorization or
proof that the file exists. Rechecking after policy revocation can reject an
earlier success. Neither success nor rejection edits the plan, cursor, revision,
completed evidence, pending correction, clarification receipt, selection or ticket
ledger. No provider, file handler, send, reservation or completion is invoked.
F4.5 revalidates before applying a correction and F4.6 connects normal ticket
capture. F4.7 bounds retries and F4.8 holds uncertainty. F4.4 itself
does not resume or execute a read.

Verification extends the existing continuation fixture with allowed absolute,
relative and quoted paths, unconfigured paths/symlinks, inert and malformed input,
both-scope permission/skill/budget/constraint/cost denials, ambiguous bindings,
Sleep and stale ownership/revision/session checks. Before/after snapshots verify
unchanged host state and Core tickets/results. Real local/IRC Core-loop fixtures
also reject an unconfigured correction after a successful first read and missing
second read, preserving the completed evidence. External providers/sockets remain
doubled. Reproduce with the existing continuation test, preparation Python tests
and four boundary guards; no new test files or Core edits are required.

Verified 26 October 2026: all 75 discovered MeTTa files pass, including 366
continuation test markers; preparation/requirements/ingress Python suites pass
34/22/11 tests, and all four boundary guards pass. Full-suite reproduction from
the application directory:
`python3 ../../scripts/run-tests.py --root tests --jobs 4 --timeout 120`.
Local log: `/tmp/f44-metta-suite.log`. No live provider/channel calls were made.

## Correlating a correction (F4.3)

For a current Held/MissingInput read, `(hostCorrectionTarget)` returns
`(CorrectionTarget SESSION COMMITMENT PLAN STEP REVISION)`. The trusted host
can include these fields with its question. Explicit ingress uses bounded JSON:

```text
correction: {"session":"<session>","commitment":"<commitment>","plan":"inspect-two-files","step":"second","revision":0,"path":"reports/report.txt"}
```

Copy session/commitment/plan/step/revision from the actual target; the placeholders
above are not valid identities for a running task. A bare path or unmarked reply
does not identify a correction. All six fields are required exactly once;
identifiers/path are nonblank strings of at most 256 characters, and revision is
an integer from 0 through 9007199254740991. Unknown fields, duplicate fields,
control characters, malformed JSON and invalid types are rejected before routing.
IRC retains its existing envelope, batch and sender-ownership checks.

The existing ingress router checks the exact open commitment and native frame
under Core's dispatch mutex. The target must match the current session, owner,
plan, held step and plan revision. Only typed MissingInput recovery is eligible;
an uncertain attempt cannot become a correction target. Accepted input returns
`HostInput CorrectionRecorded TARGET` and retains
`ContinuationCorrection TARGET HELD-RECOVERY PATH`. Read it through
`hostContinuationCorrection`, which hides records displaced by a different
owner, session, held outcome or revision.

Identical redelivery returns the same receipt. A different proposal for an
already pending target returns `Held CorrectionAlreadyPending`; stale targets
return `Held StaleCorrection`. Correlation preserves the held cursor, prior read
evidence, clarification receipt, task state, response input, transport provenance
and dispatch tickets. It does not append the protocol message as fresh task input
or invoke a provider, file handler or send. Proposed paths remain inert data;
catalog/policy validation and resume are F4.4–F4.5.

Plan installation initializes the session-local plan revision to zero and clears
pending corrections; session reset does the same. F4.5 advances this revision
when changing the plan and invalidates old decisions under the existing mutex.
F4.3 neither edits the plan nor advances its revision. This is not restart-safe
correction storage or automatic interpretation of free-form replies.

Verification extends the existing continuation and ingress tests: valid/replayed
correction, conflicting path, stale session/owner/plan/step/revision, wrong frame,
replacement, reset and uncertain recovery. Actual Core ingress is exercised after
a missing second read on local and IRC profiles, with first-read evidence retained,
sender mismatch/cancellation checks and no additional handler invocation. External
providers and IRC sockets remain doubled.

Verified 24 October 2026: all 75 discovered MeTTa files pass, including 332
continuation assertions; ingress/preparation/requirements Python suites pass
11/33/22 tests, and all four boundary guards pass. Reproduce from the application
directory with `python3 ../../scripts/run-tests.py --root tests --jobs 4 --timeout 120`
and the existing `tests/host_ingress_test.py`, `tests/response_preparation_test.py`
and `tests/host_requirements_test.py` entry points. Local suite log:
`/tmp/f43-metta-suite.log`. No live provider or channel calls were made.

The host may install one bounded file-read plan for an admitted commitment.
`host_continuation.metta` owns this host bookkeeping; its location inside MetaMo
is not motivational authority. The module does not create a plan from user text,
register permissions, invoke a command, or complete a commitment. 

## Host setup

After composition/dispatch are loaded and the current frame is admitted:

1. Initialize Core dispatch and the operation session.
2. Open the host commitment through the existing trusted commitment API.
3. Provision exact read-file bindings and complete global/frame policies with
   `host_dispatch_config.provision`.
4. Before the first motivational cycle, install the explicit plan:

```metta
(hostBeginContinuation "inspect-two-files"
   (quote ((ExecutionStep "first" (read-file "/allowed/first.txt"))
           (ExecutionStep "second" (read-file "/allowed/second.txt")))))
```

A plan contains 1–16 steps with unique, nonempty string IDs of at most 256
characters. This slice supports only `read-file` with one nonempty string path
of at most 256 characters; the normal host provisioner additionally requires a
canonical allowlisted file. Plan/step IDs and commands must be ground data.
Validation inspects command structure without evaluating it. Installation returns
`ContinuationStarted`, or `ContinuationRejected` with `InvalidPlan`,
`AlreadyStarted`, `SessionAlreadyActive`, `MissingCommitment`, or `WrongFrame`.

Installation binds the plan to the session, current frame, and the open
commitment's ID and revision. It is allowed only at cycle zero with no selected
decision and no existing plan. `initOperationSession` clears continuation state;
install after that initialization, not before `motivatedOmegaclaw` resets the
session. Automatic production admission/startup provisioning remains host work.
These are trusted serialized host APIs, not model skills, concurrent callback
APIs or a security boundary against arbitrary code in the interpreter.

## Publication, selection and progress

Before snapshot publication, the host mirrors commitment state, consumes validated
operation feedback, then refreshes continuation. Only a newly applied, matching
session/frame/command decision can advance the current step. A separate consumed
decision marker prevents one success from advancing two steps, even if consecutive
steps use the same command. Unknown or stale observations do not advance the plan.

The runtime projects only the next step:

```metta
(ContinuationView "inspect-two-files" "first" Ready "(read-file \"/allowed/first.txt\")")
```

The command identity is inert text in the snapshot. It is compared with the
serialized identity of trusted host bindings, never parsed or executed by the
motivational consumer. The full plan and executable command data stay host-side.
No plan projects `NoContinuation`; held/finished plans project
`(ContinuationView ID None Held ())` or
`(ContinuationView ID None AwaitingCompletion ())`.

`executionContinuationNeededForBundle` reads this snapshot when the task is open
and there is no fresh message. Existing risk/caution rules still apply.
Before admission, concrete operation rows are restricted to the pending
`execute-skill` command. Multiple registered reads can therefore serve different
steps without selecting ambiguous arguments. Other candidates retain their normal
rules. Every selected read still passes the real typed gate and Core's final
revalidation; a plan grants no permissions.

- `Success` advances to the next step; after the last step, `AwaitingCompletion`
  prevents another plan execution while the commitment stays open.
- `Failure`, `Blocked`, or `Unobserved` holds the current step. A canonical
  no-action blocked observation also holds it. No automatic retry occurs.
- A frame/session/commitment/revision mismatch holds the plan. Returning to the
  old frame does not resume it. Terminal commitment events still own closure.
- A candidate rejected before dispatch cannot execute. If no dispatch observation
  is recorded, the pending step remains eligible for a later policy evaluation;
  a recorded blocked attempt holds it.

F4.5 now provides the bounded trusted correction/resume API above; arbitrary
replanning remains unsupported. Restarting a host session is an
explicit operator action, not evidence that uncertain effects can safely repeat.
There is no durable progress, restart recovery, general task planner, multi-frame
continuation, budget settlement or arbitrary-handler support.

## Held-read recovery classification (F4.1)

The host retains a newly consumed unsuccessful read observation in
`&continuation-recovery`. `hostContinuationRecovery` returns it only for the
current open owner and held step:

```metta
(HeldReadRecovery SESSION COMMITMENT FRAME COMMITMENT_REVISION PLAN STEP
   (ReadRecoveryNeed MissingInput FileUnavailable) ORIGINAL_OPERATION_OUTCOME)
```

`FileUnavailable` means required input is unavailable; it does not establish
whether the path is wrong, the file was deleted, or preflight failed for another
reason. A typed `PermissionDenied` is classified separately. Other explicit
blocked results or executed handler errors are `DefiniteFailure`, with their
original reason. Unobserved results are `Uncertainty`; undocumented results
conservatively yield `Uncertainty UnknownOutcome`.

If policy prunes the pending read before selection, Core records the canonical
`Blocked MissingDecision` outcome. When that same cycle's typed candidate
rejections contain `execute-skill PermissionDenied`, the host retains
`(ReadRecoveryNeed PermissionDenied (CandidateRejection execute-skill PermissionDenied))`.
Otherwise the result remains `DefiniteFailure MissingDecision`; the host does not
guess which policy condition prevented selection.

Classification occurs only after the existing applied-decision, session/frame,
pending-command and duplicate-consumption checks. The record preserves the exact
observation and plan/step ownership. Completed read evidence, the pending cursor,
and the consumption marker keep their existing semantics. Idle cycles do not
overwrite the retained reason; a successor plan or explicit session reset clears
it. Ownership displacement can hold a plan without inventing a read failure.

This is host-side bookkeeping, not a new signal substrate or motivational repair
rule. Constitutional modes do not establish recovery need. The existing
`ContinuationView` and bounded frame bundle remain unchanged. F4.1 neither sends
a clarification nor admits a correction or retry.

## Missing-input clarification (F4.2)

A current held `MissingInput` step becomes eligible for the existing
`ask-clarification` candidate. Configure exactly one question binding and the
normal destination-specific send permissions, egress and budget in both scopes:

```json
{"skill":"send", "candidate":"ask-clarification",
 "arguments":["Which allowed file should replace the unavailable file?"]}
```

The question text is operator-configured, not generated by another provider call.
Normal candidate admission, scheduling, exact-command selection, route validation
and Core dispatch still govern it. A missing/ambiguous binding or denied send
policy cannot produce a question. F4.2 grants no permission or retry authority.

Selection retains the exact held recovery and operation decision. When the next
host cycle consumes its validated outcome, it records:

```metta
(ClarificationObservation HELD_READ_RECOVERY Delivered ORIGINAL_SEND_OUTCOME)
```

`Delivered` means the channel's existing success contract: local stdout `Accepted`
or IRC complete transport submission. It does not mean recipient acknowledgement.
Blocked or uncertain selected attempts retain `Held` instead of `Delivered` and
are not automatically repeated. Empty model output produces no delivery receipt;
the question remains eligible for a later normal selection with a fresh ticket.

The receipt is keyed to the exact session, commitment/revision, frame, plan, step
and failed read observation. Idle cycles cannot send the question again or select
an unrelated final response for this held missing input. A successful question
does not clear read recovery, advance the cursor, add read evidence, or complete
the commitment. Session reset and successor plan installation clear the receipt.
Recovery and receipt state participate in the Core dispatch snapshot; the
selection association alone grants no authority and is excluded from that snapshot.

The existing continuation regression drives actual Core polling with automatic
two-file planning, a real missing-file result, one local question, and later idle
cycles. It also covers empty command output, denied egress, missing/ambiguous
bindings, stale tickets, an uncertain-send callback fixture, and the same question
through the real IRC handler with a socket double. No live provider/IRC calls run.
Correction correlation and resume remain F4.3 onward.

## Core helper interfaces

The compatible Core `src/helper.py` supplies two pure helpers returning integer
`0` or `1`, which v1 explicitly converts to MeTTa booleans. This avoids Janus's
opaque Python-boolean representation.

`is_result_status_question(message)` recognizes a narrow set of English
status-only questions, such as “Is it done?” and “What happened?”. Mixed action
requests, non-string input and input longer than 1,200 characters return zero.
Projection computes the hint from raw host input before display compaction and
publishes `result-status-question`. The lifecycle reads this bounded hint only
when a user-waiting signal is present. It neither executes nor closes work.

`task_needs_more_execution(task, observations)` supports explicit host JSON:

```json
{"task_id":"task", "steps":["first","second"]}
{"task_id":"task", "completed_steps":["first"], "status":"Ready"}
```

It returns one only for matching IDs, unique bounded steps, a proper completed
prefix, remaining work and `Ready` status. Malformed/duplicate fields, unknown
status, blocking, failure, uncertainty and arbitrary prose return zero. Each input
is bounded to 1,200 characters and the plan to 16 steps. This is a conservative
legacy compatibility interface; compacted prose cannot establish pending work.
The concrete v1 path uses the typed host plan instead of text inference.

## Verification

From the workspace root:

```sh
python3 repos/OmegaClaw-Core/Autotests/test_helper_lifecycle.py
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/task_continuation_test.metta
```

Five Python tests cover both helpers. The 70-assertion MeTTa regression uses real
Core ingestion, commitment APIs, ordinary production read-file configuration,
appraisal, selection, policy and dispatch. Two distinct files are read in order
without a fresh message between steps. Duplicate/stale outcomes, command replay,
policy denial/revocation, uncertain execution, explicit failure, malformed plans,
frame changes, reset, status routing and explicit host completion are checked.
Only external providers/memory are doubled; no scorer, candidate rule, read handler
or continuation function is replaced. The failure transition is tested directly
with a host-consumed failure fixture; pre-open missing-file failure uses real
dispatch. The updated native reader reports `FileUnavailable` as definite
`Failure`; uncertain exceptions remain separate. Both statuses hold the plan.

All 43 focused MeTTa files, eight import regressions, five Core helper tests,
six offline-service tests, ten provisioning tests and four boundary guards passed.
The current suite runner used a temporary shell wrapper delegating to the common
launcher. No runner, CI or Prolog source was changed. This establishes the bounded
offline continuation slice, not live deployment or the remaining mode scenarios.
