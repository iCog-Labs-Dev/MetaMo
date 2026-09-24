# Explicit session continuation

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

There is no resume/replan API in this slice. Restarting a host session is an
explicit operator action, not evidence that uncertain effects can safely repeat.
There is no durable progress, restart recovery, general task planner, multi-frame
continuation, budget settlement or arbitrary-handler support.

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
with a host-consumed failure fixture; missing-file uncertainty uses real dispatch.

All 43 focused MeTTa files, eight import regressions, five Core helper tests,
six offline-service tests, ten provisioning tests and four boundary guards passed.
The current suite runner used a temporary shell wrapper delegating to the common
launcher. No runner, CI or Prolog source was changed. This establishes the bounded
offline continuation slice, not live deployment or the remaining mode scenarios.
