# ContextFrames × MetaMo boundary contracts, version 1

Status: specification; runtime migration and shared host/adapter contract tests
are pending. This document specifies the six Phase 2 boundary records. Existing
unversioned MeTTa records are legacy v0; they are not implicitly v1.

## Encoding and compatibility

Every boundary message uses this envelope:

```metta
(IntegrationRecord
  (schema SCHEMA 1)
  (record-id ID)
  (producer PRODUCER)
  (context CONTEXT)
  (payload PAYLOAD))
```

- `SCHEMA` is one of `FrameStateBundle`, `MetaMoPolicyOutput`,
  `AttentionDirective`, `ReasonerMotivationalProposal`, `ExecutionOutcome`, or
  `FrameVerificationEvidence`. Its payload constructor must match.
- `ID` is a nonempty opaque string, unique within the producer's durable ID
  namespace. References use `(RecordRef PRODUCER ID)`. Re-delivery retains the
  same ID and identical content. The host authenticates producer identity;
  the `producer` field alone establishes no authority.
- `PRODUCER` is a configured host, MetaMo, reasoner adapter, or executor identity.
- `CONTEXT` is `(SnapshotRef HOST SNAPSHOT-ID REVISION POLICY-REVISION)` or
  `NoSnapshot`. Revisions are nonnegative integers; their comparison is scoped
  to that host. A snapshot identifies the complete immutable admitted view,
  including current-frame and lifecycle state. Derived messages copy its context.
- `NoSnapshot` is permitted only for startup/no-action policy and attention
  output. It is forbidden for proposals, bundles, outcomes, and evidence.
- Version is an integer per schema. Changing field presence, ordering, types,
  enum meaning, or defaults requires a new version. Consumers accept only
  explicitly supported versions; they must not guess a compatible shape.
- Named fields are required exactly once, in the order shown. No extra fields
  are accepted in v1. Lists use `(...)`; an empty list is `()`. Optional scalar
  values use `None`, never an empty string or an omitted field.
- `True` and `False` are the only booleans. A `UnitValue` is a finite number in
  `[0, 1]`; NaN, infinity, and out-of-range values are invalid. Runtime numbers
  remain numbers; integer persistence encoding is a separate migration.
- `Text` is display-only text. `Data` is a bounded, parsed expression treated
  only as data, never evaluated. Deployment must declare shared input limits
  before enabling v1; exceeding a limit rejects the record. This specification
  does not authorize truncating IDs, evidence references, or policy records.

An invalid/unsupported record produces an internal
`(ContractRejection REASON SCHEMA VERSION RECORD-REF-OR-None)` and no dispatch,
frame mutation, evidence write-back, or reliability update. Reasons include
`MalformedRecord`, `UnsupportedSchema`, `UnsupportedVersion`, `InvalidValue`,
`MissingReference`, `StaleSnapshot`, and `IdentityConflict`. Unknown enum values
are invalid, rather than silently mapped to a permissive default.

## 1. FrameStateBundle

Producer: host projection. Consumer: MetaMo and admitted-fact extraction.
The envelope snapshot ID equals its record ID. Payload:

```metta
(FrameStateBundle
  (root ROOT)
  (current CURRENT-OR-None)
  (index (FrameStateIndex (active REFS) (completed REFS)))
  (relations RELATIONS)
  (runtime RUNTIME)
  (policy (HostPolicyRef HOST POLICY-ID POLICY-REVISION)))
```

Nested record shapes:

```metta
(FrameStateRoot
  (id ROOT-ID) (current-frame-id FRAME-ID-OR-None) (mode MODE)
  (global-budget BUDGET-REF) (global-constraints CONSTRAINTS-REF))
(FrameStateCurrent
  (id FRAME-ID) (parent FRAME-ID-OR-None) (source SOURCE-ID)
  (status STATUS) (frame-mode MODE) (priority UNIT-VALUE)
  (goal-summary TEXT) (history-summary TEXT) (deliverable-summary TEXT)
  (results-summary TEXT) (budget BUDGET-REF) (constraints CONSTRAINTS-REF)
  (certified-method TEXT))
(FrameStateRuntime
  (new-message BOOLEAN) (message-present BOOLEAN) (message-summary TEXT)
  (task-open BOOLEAN) (task-execution-observed OBSERVATION-REFS)
  (active-task-summary TEXT) (last-results-summary TEXT) (error TEXT)
  (wake-loops NONNEGATIVE-INTEGER) (next-wake-at UTC-MILLISECONDS-OR-None)
  (budget-state BUDGET-REF))
(FrameIndexRef (id FRAME-ID) (revision NONNEGATIVE-INTEGER) (status STATUS))
(FrameStateRelation
  (id RELATION-ID) (revision NONNEGATIVE-INTEGER)
  (source-frame FRAME-ID) (target-frame FRAME-ID) (relation-type TYPE)
  (reason TEXT) (confidence UNIT-VALUE) (evidence-status RELATION-EVIDENCE-STATUS))
```

`REFS` and `RELATIONS` are lists of the respective records, not compacted text.
`MODE` is `Fast | Slow`; it is distinct from a constitutional mode. `STATUS` is
`Active | Focused | Completed | Blocked | Abandoned | Superseded`. The host
adapter must explicitly map its native statuses into these values. Relation
`TYPE` must be in a shared versioned host relation-type registry.
`RELATION-EVIDENCE-STATUS` is `Unverified | VerificationRequired | Confirmed |
Refuted | Unresolved`. `VerificationRequired` is a pending verification request,
not a verification observation; evidence records below use only the last three
values. Projection must preserve observed evidence instead of overwriting it
with a pending status.

Budget and constraint references are respectively
`(BudgetRef HOST ID REVISION)` and `(ConstraintsRef HOST ID REVISION)`, resolving
to immutable, typed host policy data within the envelope's policy revision.
No permission is inferred from a reference's presence: admission requires the
referenced data to be available and validated. Missing policy means rejection
of work requiring that policy. Defining the policy payload and its enforcement
belongs to the remaining Phase 2 policy-data task and Phase 3.

The current frame ID must agree with the root; `current None` requires
`current-frame-id None`. Runtime budget reference equals the current frame's
budget reference when a current frame exists; otherwise it is the root budget.
The host publishes this snapshot after authoritative lifecycle bookkeeping.
Consumers must not combine it with later mutable task state. Summaries and the
`certified-method` label cannot establish permissions or certification.

## 2. MetaMoPolicyOutput

Producer: MetaMo. Consumer: scheduler policy adapter. Its record ID identifies
the decision; an attention directive references that record.

```metta
(MetaMoPolicyOutput
  (mode CONSTITUTIONAL-MODE)
  (operation-class CANDIDATE-OR-none)
  (feasibility ADMISSION)
  (reason REASON)
  (priority UNIT-VALUE)
  (proposal PROPOSAL-REF-OR-None))
```

`CONSTITUTIONAL-MODE` is `Engaged | Threat | Rumination | Sleep`.
`ADMISSION` is `Admitted | Rejected`. Candidates come from the shared candidate
registry. Policy/directive `REASON` is `Feasible | NotInitialized | NoCandidate |
InvalidProposal | NoActiveFrame | InactiveFrame | FrameModeMismatch |
BudgetExhausted | SleepModeOperationalWork | PolicyRejected | StaleSnapshot`.
`Feasible` is used only for admission; adding reasons requires a schema update.
Execution outcome reasons are a nonempty diagnostic symbol and do not determine
status or permissions.
Rejected output has priority `0`. A rejection may retain the requested candidate
for diagnosis; `none` always means no action and must have `Rejected` admission.
A native candidate has `proposal None`; an inferred candidate references its
proposal. Priority is a scheduling hint, not frame priority or authorization.

## 3. AttentionDirective

Producer: MetaMo's scheduler adapter. Consumer: scheduler.

```metta
(AttentionDirective
  (decision DECISION-REF-OR-None)
  (target FRAME-ID-OR-None)
  (slice SLICE)
  (task CANDIDATE-OR-none)
  (admission ADMISSION)
  (reason REASON)
  (priority UNIT-VALUE)
  (source MetaMo))
```

`SLICE` is `None | CurrentFrameSummary | CurrentFrameTask |
CurrentFrameAndRelations`. Decision context must equal directive context.
Admission and priority must agree with the referenced policy output. An admitted
record requires a decision reference, a registered task, and the target required
by that operation's handler. Rejected/no-action records have `slice None`,
`task none`, and priority `0`. An attention directive never authorizes a frame
switch or mode transition merely by naming a target: the scheduler resolves the
referenced proposal and its explicit kind, then applies the transition handler.

## 4. ReasonerMotivationalProposal

Producer: reasoner adapter. Consumer: MetaMo proposal validation/scoring.

```metta
(ReasonerMotivationalProposal
  (source SOURCE)
  (kind KIND)
  (target TARGET)
  (candidate CANDIDATE)
  (claim DATA)
  (support DATA)
  (confidence UNIT-VALUE)
  (evidence (EvidenceReferences OBSERVATION-REFS))
  (prediction DATA))
```

The envelope ID replaces the legacy positional proposal ID. `SOURCE` is
`nars | pln | llm | rule-engine | human-adapter`; it must match the configured
producer's source. Required claim, support, and prediction cannot be empty.
Confidence is engine confidence, not a calibrated success probability.

| Kind | Required target | Candidate meaning |
| --- | --- | --- |
| `propose-candidate` | `(FrameTarget ID)` | Registered proposed work |
| `request-attention` | `(FrameTarget ID)` | Registered attention operation |
| `request-frame-switch` | `(FrameTarget ID)` | `defer`, matching the existing adapter |
| `request-mode-change` | `(ModeTarget Fast)` or `(ModeTarget Slow)` | `defer`; frame is the context snapshot's current frame |

Resolve legacy `current-frame` to an explicit frame ID before publication.
Targets must be within the admitted view and the operation must be checked for
that actual target. Evidence references identify host-admitted observations;
NARS/PLN recommendations require nonempty supporting evidence. Claim, support,
and prediction are data and cannot become executable commands. A prediction is
not execution evidence. No supported conclusion means no proposal record.

## 5. ExecutionOutcome

Producer: host scheduler/executor. Consumers: proposal grading and host audit.
This is an observation of execution, distinct from MetaMo's derived
`ReasonerProposalOutcomeEvent`, which contains a grade.

```metta
(ExecutionOutcome
  (decision DECISION-REF)
  (directive DIRECTIVE-REF)
  (proposal PROPOSAL-REF-OR-None)
  (dispatch DISPATCH-ID)
  (execution EXECUTION-ID-OR-None)
  (frame FRAME-ID-OR-None)
  (status EXECUTION-STATUS)
  (reason REASON)
  (observed-at UTC-MILLISECONDS)
  (execution-evidence OBSERVATION-REFS)
  (verification VERIFICATION-REFS))
```

`EXECUTION-STATUS` is `Completed | Failed | Blocked | Unobserved`. `Completed`
and `Failed` require an execution ID and nonempty execution evidence. `Blocked`
may have no execution ID if dispatch was prevented. `Unobserved` explicitly
means no confirmed execution result; it must not be converted into completion
or used for reliability learning. An operation that does not require a frame
may use `frame None`; otherwise frame identity must match the resolved target.

Context references the decision's original snapshot; observations can occur
later. Verification references identify independently observed evidence,
never a status copied from the prediction. The host checks all referenced IDs
belong to this dispatch. Duplicate outcome record IDs are processed once;
conflicting content under the same identity is rejected. Rules for transitions
between successive outcomes and durable retry accounting remain Phase 5 work.

## 6. FrameVerificationEvidence

Producer: host verification adapter. Consumers: host relation store and grading.

```metta
(FrameVerificationEvidence
  (relation (RelationRef HOST RELATION-ID REVISION))
  (source-frame FRAME-ID)
  (target-frame FRAME-ID)
  (relation-type TYPE)
  (reason TEXT)
  (prior-confidence UNIT-VALUE)
  (evidence-status EVIDENCE-STATUS)
  (observed-at UTC-MILLISECONDS)
  (observations OBSERVATION-REFS)
  (execution EXECUTION-ID-OR-None))
```

`EVIDENCE-STATUS` is `Confirmed | Refuted | Unresolved`. An observation reference
is `(ObservationRef HOST ID)` resolving to an immutable admitted host observation.
`Confirmed` and `Refuted` require nonempty observations. `Unresolved` makes no
positive or negative claim. Source/target/type/prior must match the referenced
relation revision; later application to a changed relation requires host review,
not blind overwrite. Prior confidence alone never establishes evidence status.
Evidence may originate outside an execution, hence optional execution identity.
Only the host writes back relations; MetaMo can consume/capture evidence.

## Startup and no-action outputs

Startup uses the same envelope and payload arity as runtime emission. IDs are
fresh within the producer namespace, context is `NoSnapshot`, and defaults are:

```metta
(MetaMoPolicyOutput
  (mode Engaged) (operation-class none) (feasibility Rejected)
  (reason NotInitialized) (priority 0) (proposal None))
(AttentionDirective
  (decision None) (target None) (slice None) (task none)
  (admission Rejected) (reason NotInitialized) (priority 0) (source MetaMo))
```

The configured constitutional default replaces `Engaged` if different, using the
same enum. After a valid cycle, no-action output retains its snapshot context
and uses `NoCandidate` or the actual rejection reason; a no-action directive
references that policy decision. No placeholder proposal, execution outcome,
or verification evidence is emitted at startup.

## Migration and acceptance

Current producers/consumers that must migrate together:

| Schema | Existing implementation | Required v1 change |
| --- | --- | --- |
| Bundle | `contexts/context_projection.metta`, accessors/slices | Envelope, explicit absent current frame, typed index/relations and policy references |
| Policy | `contexts/context_directives.metta`, `task_lifecycle.metta`, `bridge.metta` | Envelope, reason, proposal reference; identical startup/runtime shape |
| Attention | `contexts/context_directives.metta`, proposal conversion | Envelope, decision reference; startup currently lacks `reason` |
| Proposal | `reasoner_proposals.metta`, helpers, inference adapter | Named fields, ID in envelope, explicit targets and evidence references |
| Outcome | `recordReasonerProposalOutcome` arguments | Host observation record validated before deriving a grade |
| Verification | `contexts/context_relations.metta` | Relation identity/revision, observation references, timestamp, optional execution identity |

Do not append version fields directly to existing positional patterns. Boundary
adapters must validate and unwrap v1 explicitly. A v0 conversion requires the
host to supply missing identity, revisions, and evidence; it cannot manufacture
those from summaries. Keep legacy local fixtures separate from v1 fixtures.

Before enabling v1, shared host/MetaMo contract fixtures must cover all six
records; startup, admitted, rejected, and no-action output; absent current frame;
each proposal kind and outcome/evidence status; wrong schema/version/arity;
missing, duplicate, and unknown fields; invalid numbers; unresolved references;
context mismatch; stale revisions; and duplicate/conflicting IDs. Host rollout,
validators, collection limits, and lifecycle enforcement are not implemented by
this specification. Phase 2 remains open until its implementation gates pass.
