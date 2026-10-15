# Explicit commitment lifecycle

A commitment is host-owned work that remains open until the host records an
explicit terminal event. Its lifetime is independent of goal weights, motives,
modulators, decay, candidate scores, constitutional mode, and autonomy phases.

This implementation provides a **single-current-commitment, session-only** host
store in `commitments.pl`, with a read-only MeTTa adapter. Storage lives alongside
the MetaMo integration code, but its meaning and write authority belong to the
host. These local records are not additions to the six versioned wire schemas.

## Terminal events

```metta
(CommitmentEvent "event-id" "commitment-id" 0
   (Completed "outcome-id"))

(CommitmentEvent "event-id" "commitment-id" 0
   (Abandoned "User cancelled the request"))

(CommitmentEvent "event-id" "commitment-id" 0
   (Superseded "replacement-id" "Replacement task description"
      "User replaced the original requirement"))
```

The numeric field is the expected commitment revision. An open commitment begins
at revision zero; an accepted terminal event increments it once.

| Event | Required evidence and effect |
| --- | --- |
| `Completed` | A previously registered, host-adjudicated `Completed` outcome for this exact commitment and revision. A returned command, successful delivery, or text saying “done” is insufficient by itself. |
| `Abandoned` | A nonblank reason. The event preserves the reason and closes the commitment as abandoned, not completed. |
| `Superseded` | A fresh replacement ID, nonblank description, and reason. Atomically marks the predecessor superseded and opens the replacement at revision zero in the same frame. |

An ID cannot be reused after termination. A new open call cannot overwrite an
existing open commitment. Failed or unobserved outcomes do not authorize completion.
Late completion of a predecessor cannot terminate its successor, and an outcome
for another commitment cannot be borrowed as completion evidence.

Accepted event IDs are retained for replay: an identical event returns its recorded
result without repeating the transition. Different content with the same accepted
ID returns `ConflictingReplay`. Rejected events make no lifecycle changes and are
not added to the accepted-event history.

## Trusted host APIs

These Prolog APIs are intentionally **not exported as model skills**:

| API | Purpose |
| --- | --- |
| `mm_commitment_open(Id, Frame, Summary, Result)` | Establish an explicit commitment after host task admission. Repeating the same open record is harmless; changing or reusing its identity is rejected. |
| `mm_commitment_record_outcome(Outcome, Id, Revision, Status, Result)` | Register the host's adjudicated outcome: `Completed`, `Failed`, or `Unobserved`. Reusing an outcome ID with conflicting content is rejected. |
| `mm_commitment_apply(Event, Result)` | Validate identity, revision, evidence/reason, and lifecycle state, then apply a terminal event. |

Commitment/event IDs, descriptions, and reasons are nonblank Prolog strings.
Frame IDs preserve Core's native nonblank symbol or string, including its type. The host
must authenticate the source and decide whether an observed result actually
satisfies the commitment. Calling `record_outcome` is that trusted adjudication;
the store cannot independently prove the real-world task succeeded.

## Automatic admission (F2.1)

`prepareHostStartup` now calls `host_dispatch_config.admit_startup_commitment`
through Core's existing post-ingestion prepare hook. It opens a UUID-named
commitment through `mm_commitment_open` when the current Active/Focused
UserDirective frame matches Core's last admitted frame and supplies a nonblank
task summary. Native frame identity is read and retained inside the host query;
it is not converted to a string through Python. The existing
`refreshTaskCommitment` mirrors the authoritative record before selection.

Admission reads and mutation share the dispatch mutex. Repeated preparation
retains the existing commitment without changing its revision or invalidating
dispatch tickets. A different frame cannot replace an open commitment, and
polling a previously committed frame cannot reopen its terminal commitment.
`&last-host-commitment-admission` exposes the opened, retained, skipped, or
rejected result for diagnostics. No admission API is registered as a model skill.

This connects task opening only. Automatic completion,
per-task policy provisioning, and response preparation
remain later F2 work. Direct Core ingestion can still admit a frame that is
rejected while an earlier commitment stays open; the production ingress hook
below handles follow-ups before frame creation. Startup policy remains bound
to its first configured frame.

`tests/host_startup_test.metta` exercises the real Core prepare hook with offline
services, including native identity, duplicate preparation with a retained
dispatch ticket, invalid admission inputs, open-commitment protection, and
terminal-state preservation. `tests/commitments_test.pl` also checks symbol/string
identity distinction and malformed frame IDs.

Example host code, after the adapter has loaded:

```prolog
mm_commitment_open("c1", "frame-1", "Inspect the requested file", OpenResult),
% Only after the host confirms that this commitment was fulfilled:
mm_commitment_record_outcome("o1", "c1", 0, 'Completed', OutcomeResult),
mm_commitment_apply(
    ['CommitmentEvent', "e1", "c1", 0, ['Completed', "o1"]], EventResult).
```

Only `commitmentSnapshot` and `commitmentEvents` are exported to MeTTa. The former
returns `NoCommitment` or `(CommitmentSnapshot id frame revision status summary)`;
the latter returns accepted events in insertion order.

Mutations share Core dispatch's lock and advance its session revision when the
dispatcher is loaded. This invalidates outstanding tickets after commitment
changes. Supersession commits both records and the event in one Prolog transaction.
The offline path uses the same mutex without requiring a configured dispatcher.

## Explicit same-task follow-ups (F2.2)

The v1 startup installs `ingestHostMessage` through Core's optional
`configureCoreLoopIngest` callback. The polling loop invokes that callback
before frame creation; its standalone default remains `ctx-ingest-user-message`.
Deploy the matching Core `src/dispatch.metta` and `src/loop.metta` changes with
this adapter. The existing post-ingestion prepare hook still performs F2.1.

Use `follow-up: include examples` to explicitly associate input with the current
open commitment. The marker is case-insensitive and permits surrounding
whitespace; its body must be nonblank. Input is bounded to 4096 characters.
`host_ingress.py` recognizes this syntax without model inference, while
`host_ingress.metta` owns the routing rules:

- An explicit follow-up requires an open commitment whose native frame ID
  exactly matches the current Active/Focused frame. The host records the message
  through Core's existing `cfv2-record-message-for-current-frame` API. It creates
  no frame, replaces no deliverable, and changes no commitment ID or revision.
- While a commitment is open, unmarked, ambiguous, or unrelated input returns
  `HostInput Held ExplicitFollowupRequired`. It does not attach to that frame,
  create another frame, or terminate the commitment. Held input is not marked
  fresh for the current task's signal extraction. It produces no automatic reply.
- An explicit follow-up without an open commitment, with a mismatched current
  frame, or with an inactive frame is held. Routing never switches or unblocks
  frames. Without an open commitment, ordinary input uses existing Core admission.
- Unmarked cancellation/replacement language is not interpreted as a lifecycle event.
  Even an explicit follow-up saying “done” is message data, not completion proof.

The host checks ownership and records the message under Core's dispatch mutex;
accepted mutations advance its epoch, invalidating earlier tickets. Immediate
duplicate follow-ups for the same owner and text do not append another history
entry or invalidate a new ticket. This is session-local suppression, not a
durable message-ID ledger. Input text is quoted data throughout the boundary.
`&last-host-input` exposes the routing result. No routing helper is a model skill.

Tests exercise the real ingress callback, typed dispatch, frame history, and
commitment state. `host_ingress_loop_test.metta` additionally runs five turns of
the real Core polling loop: initial task, explicit follow-up, unrelated text,
explicit replacement, and explicit cancellation.
Only external channel/provider/memory boundaries are doubled. Follow-up text
does not alter a read plan or its required evidence; automatic replanning and
response generation remain separate increments.

## Explicit cancellation (F2.3)

Use `cancel: no longer needed` to abandon the current open commitment. The marker
is case-insensitive; the trimmed reason must be nonblank and obeys the same input
bounds as follow-ups. Bare `cancel` remains ambiguous while work is open.
The reason is stored as data in the existing `Abandoned` event, never evaluated.

The current native frame must match the commitment owner. Cancellation is allowed
for blocked work too, without activating or completing the frame. The host checks
the exact commitment identity, frame, and revision again when applying the event.
It returns `HostInput Cancelled` with the owner and new revision; stale decisions
are held. A repeated cancellation while the commitment is terminal adds no event.
This is not durable channel-message deduplication across different tasks.

Ownership checks, abandonment, and pending-command revocation share the dispatch
mutex. The event invalidates captured tickets; the host also revokes configured
commands targeting the cancelled frame and clears the prepared operation, so a
new ticket cannot execute the old task's commands. Previously executed effects
are not undone. Cancellation is not fresh task input, and the normal prepare hook
mirrors the terminal commitment into `task-open = False` without reopening it.
No completion outcome is registered and no further Core change is required.

The ingress tests cover missing reasons/owners, mismatched frames, blocked work,
inert reasons, repeated and delayed decisions, terminal-state preservation, and
dispatch rejection with both old and new tickets. The polling-loop test checks
that the replacement owner becomes Abandoned on the fifth turn.

## Explicit replacement (F2.4)

Use `replace: Summarize document B` to supersede the current open commitment.
The case-insensitive marker requires a nonblank new task description and obeys
the same input bounds as follow-ups. The host records the fixed reason
`Explicit user replacement`; the new description is quoted data, never code.
Unmarked replacement language remains held while a commitment is open.

The host rechecks the exact predecessor identity, native frame, and revision
under the dispatch mutex. The existing `Superseded` event atomically retains the
predecessor as terminal and opens a UUID-named successor at revision zero on the
same frame. `HostInput Replaced` reports predecessor ID, successor ID, native frame,
and successor revision. Missing owners, frame mismatches, and stale decisions
are held. A blocked frame remains blocked.

As with cancellation, the event invalidates old dispatch tickets and the host
revokes the frame's configured command bindings and clears the prepared operation.
The normal prepare hook publishes the successor's description as `active-task`
and clears the predecessor's execution-observation accumulator. Replacement is
fresh input. It does not create another frame or rewrite the frame's original
deliverables/history; the commitment snapshot supplies the current task identity
and description. Neither task is marked completed.

Repeating the exact replacement message against its unchanged successor returns
the original receipt without another event. This session-local receipt is not
durable channel-message deduplication. Replaying an admitted predecessor decision
cannot supersede the successor. A different explicit replacement can supersede it.

Per-task command provisioning remains F2.8: replacement alone does not authorize
the successor to execute the predecessor's commands. Automatic replanning and
response preparation also remain separate work. No Core changes or new Prolog
files are required. `host_replacement_test.metta` covers retained predecessor
records, new identities, replay/staleness, inert descriptions, blocked frames,
and dispatch revocation. The polling-loop test replaces on turn four and cancels
the successor on turn five.

## Publication and motivation separation

Before publishing a frame bundle, `prepareTaskStateForMetaMo`:

1. Performs existing host execution-observation bookkeeping.
2. Calls `refreshTaskCommitment` to mirror the authoritative commitment into
   the legacy `task-open` and `active-task` fields.
3. Publishes and caches the bounded snapshot consumed by MetaMo.

An open record keeps the task open. A terminal record clears the task summary and
execution-observation accumulator. Changing commitment identity also clears that
accumulator so it does not initially carry into the replacement. Host ingestion
must still correlate and clear stale raw result buffers; these legacy strings are
not authoritative commitment outcomes.

`completeTaskIfTerminal` and `completePreviousTaskIfSuccessful` are retained only
as nonmutating compatibility functions returning `False`. Neither result text nor
the last selected candidate can close work. Without a managed host commitment,
the adapter preserves legacy task state; it does not invent an identity or infer
completion. A new message alone is not an abandonment or supersession event.

## Scope and remaining integration

Trusted ingress opens commitments and routes explicit cancellation and replacement
through the existing event API. A host completion adjudicator that registers
confirmed outcomes remains pending. The adapter does not automatically
equate Core's `DispatchResult Executed` with completion.

The store is local to one process and tracks one current commitment. It is not a
durable event log, a multi-frame commitment scheduler, or a restart recovery
protocol. It does not change ContextFrames' separate goal-completion commands.
Motivational persistence does not save or restore this authoritative host store.

## Verification

From the workspace root:

```sh
swipl -q -s MetaMo/applications/omegaclaw_v1/tests/commitments_test.pl -g run_tests -t halt
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/commitment_lifecycle_test.metta
bash MetaMo/applications/omegaclaw_v1/tests/commitment_boundary_test.sh
```

Host tests cover the three terminal events, missing reasons/evidence, uncertain
outcomes, stale revisions, replay conflicts, atomic replacement, old completion
events, and dispatch invalidation. Adapter tests exercise real decay/writeback,
homeostasis, Sleep, result text, and publication without implicit termination.
