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

IDs, frame IDs, descriptions, and reasons are nonblank Prolog strings. The host
must authenticate the source and decide whether an observed result actually
satisfies the commitment. Calling `record_outcome` is that trusted adjudication;
the store cannot independently prove the real-world task succeeded.

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

Trusted ingress must call `mm_commitment_open`; explicit cancellation/replacement
handlers must apply the corresponding events; a host completion adjudicator must
register confirmed outcomes. This change does not infer these events from user
text or automatically equate Core's `DispatchResult Executed` with completion.

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
