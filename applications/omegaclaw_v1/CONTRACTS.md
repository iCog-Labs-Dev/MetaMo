# ContextFrames × MetaMo boundary contracts, version 1

Status: v1 wire constructors, shape validation, explicit consumers, shared wire
fixtures, and startup/default constructors implemented 16 September 2026.
Live host migration and identity/revision enforcement remain pending. This
document specifies the six Phase 2 boundary records. Existing
unversioned MeTTa records are legacy v0; they are not implicitly v1.

## Implemented API and scope

`contracts.metta` exposes the shared implementation in `contracts.pl`; the
context integration façade loads it once. It provides these executable APIs:

| API | Behavior |
| --- | --- |
| `publishFrameStateBundle`, `publishMetaMoPolicyOutput`, `publishAttentionDirective`, `publishReasonerProposal`, `publishExecutionOutcome`, `publishFrameVerificationEvidence` | Accept record ID, producer, context, and the corresponding typed payload; emit a validated v1 envelope or `ContractRejection`. |
| `integrationValidateRecord` | Returns exactly one `ContractValid SCHEMA 1` or `ContractRejection`; checks exact ordered fields, nested shapes, value types/enums, reference shapes, and local consistency invariants. |
| `integrationConsumeRecord` | Takes expected schema and envelope; explicitly validates and returns its payload, or a rejection. Never treats a v0 payload as v1. |
| `integrationRecordReference` | Returns a validated record's producer-qualified reference, or a rejection. |
| `integrationPolicyRecord` | Builds a policy envelope from ID, producer, context, mode, operation, admission, reason, priority, and optional proposal reference. |
| `integrationAttentionFromPolicy` | Takes ID, producer, policy envelope, target, and slice. Derives the decision reference, context, admission, reason, and priority; canonicalizes rejected directives to no action. |
| `integrationStartupPolicy`, `integrationStartupAttention` | Accept caller-allocated identity (and constitutional mode for policy); use the same envelope/payload constructors as normal output with `NoSnapshot`. |

These APIs inspect ground payloads as data. In MeTTa, quote literal payload data
that could otherwise be evaluated by the language before the boundary call.
Validation never evaluates the supplied claim, support, or prediction.

`ContractValid` establishes representation validity, **not authorization**.
The implementation does not allocate durable IDs, resolve references, authenticate
producers, enforce state/policy revisions, or implement the host dispatch ledger.
Relation-type and producer/source registration, deployment collection/text limits,
and resolution of typed policy references remain explicit host validation gates.
A caller must not dispatch solely because shape validation succeeded.

The existing live loop still uses explicit legacy v0 projection/scoring paths
until the host supplies v1 metadata and policy references. Its startup/reset
policy and attention defaults now use centralized `legacyStartup*` constructors;
the attention default includes the runtime `reason` field. No compatibility
conversion fabricates host revisions or observation identities.

The canonical v1 wire fixtures are `tests/fixtures/contracts_v1.pl`, shared by
`tests/contracts_v1_test.pl` (standalone host-facing shape tests) and
`tests/contracts_v1_test.metta` (the actual MeTTa publication/consumer API).
They are distinct from the earlier workspace-level JSON design fixtures, which
use a proposed direct-bundle encoding rather than this envelope.

Run from the workspace root:

```sh
swipl -q -s MetaMo/applications/omegaclaw_v1/tests/contracts_v1_test.pl -g run_tests -t halt
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/contracts_v1_test.metta
```

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
  `NoSnapshot`. `REVISION` is the host state revision, not a snapshot counter
  or frame revision. Revisions are nonnegative integers; their comparison is
  scoped to that host. A snapshot identifies the complete immutable admitted view,
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

## Identity, causality, and revision rules

### ID ownership and lifetime

IDs are opaque strings, never timestamps, array positions, text hashes, or
recycled native frame numbers. Producers must allocate IDs without reuse across
restart, using a durable allocator or collision-resistant random IDs. Prefixes
in examples are illustrative and have no parsing semantics. The same immutable
record delivered again retains its ID; recomputation creates a new record ID.
Resolving an ID requires its namespace and expected type. Wrong-type references
are `MalformedRecord`; unavailable references are `MissingReference`.

`HOST` denotes one durable host-state lineage. Ordinary restart preserves that
identity and all counters. Restoring an older backup, resetting counters, or
forking state creates a new host identity and invalidates outstanding contexts
from the old lineage. Producer namespaces likewise cannot be reused after their
identity ledger is lost. Cross-host frame references are unsupported in v1.

| Entity | Allocator and canonical reference | Lifetime and links |
| --- | --- | --- |
| Snapshot | Host; `(SnapshotRef HOST ID STATE-REV POLICY-REV)` | Immutable bundle; resolves to `(RecordRef HOST ID)`. Both revisions must equal those recorded with that bundle. |
| Frame | Host; `(FrameRef HOST ID REVISION)` | Stable ID for the work item, new revision on mutation. Bare payload frame IDs inherit `HOST` from context and resolve at the snapshot revision. |
| Proposal | Reasoner adapter; `(RecordRef PRODUCER ID)` | One proposal over one snapshot; its evidence and target belong to that admitted view. |
| Decision | MetaMo; `(RecordRef PRODUCER ID)` | One `MetaMoPolicyOutput`; references its proposal or `None` for a native candidate. |
| Directive | Scheduler adapter; `(RecordRef PRODUCER ID)` | One `AttentionDirective`; references exactly one decision except at startup. |
| Dispatch | Host scheduler; `(DispatchRef HOST ID)` | One durable attempt to dispatch a directive, including blocked attempts. Records decision, directive, proposal, target revision, and original snapshot. |
| Execution | Host executor; `(ExecutionRef HOST ID)` | One concrete execution attempt belonging to exactly one dispatch. Allocated durably before invocation; reused when reconciling that attempt. |
| Observation | Host observation adapter; `(ObservationRef HOST ID)` | Immutable observed data with provenance; records observed frame/relation revisions and execution reference when applicable. |
| Verification evidence | Host verification adapter; `(RecordRef PRODUCER ID)` | One `FrameVerificationEvidence`; links a relation revision, observations, and optional execution. |
| Outcome | Host scheduler/executor; `(RecordRef PRODUCER ID)` | One `ExecutionOutcome`; links dispatch, optional execution, decision, directive, optional proposal, observations, and verification records. |

Frame and relation IDs remain reserved after completion/deletion; a reused task
description is not the same work item. Native IDs that can be recycled must be
mapped to durable integration IDs. Evidence identity is distinct from proposal
identity, even if an observation supports multiple proposals.

### Revisions and snapshot consistency

The host maintains durable, monotonically increasing counters. Revisions are
compared for exact equality, never by wall-clock age or `>=` acceptance:

- **State revision:** advances on every committed change that can affect the
  admitted view or execution eligibility: frame creation/deletion, current-frame
  selection, goals, lifecycle/task state, status, mode, priority, results,
  relations/evidence, resource availability/reservations, new input, and wake
  state. Changes outside a bounded projection still advance this counter.
- **Policy revision:** advances on permission grants/revocations, constraints,
  skill/handler or candidate-registry changes, egress rules, and budget limits.
  These changes also advance the state revision. Any configuration used to
  interpret an operation or authorize dispatch must belong to this revision.
- **Frame/relation revision:** advances whenever that entity changes, including
  results and evidence write-back. Creation starts at `0`. A relation change
  advances its own revision and the host state revision; it need not change
  endpoint frame revisions unless those frames also change.
  The root is a versioned frame: changing its current-frame pointer, mode,
  global budget reference, or constraint reference advances its revision.
- **Budget/constraint revision:** advances on mutation of the referenced object;
  changing availability advances state, and changing policy advances both state
  and policy as above. References resolve to retained immutable versions.

Snapshot capture reads one consistent committed state after host lifecycle
bookkeeping. Root/current/index revisions and every policy reference must refer
to that same capture; never mix fields from different reads. Publishing another
snapshot without a state change may use the same revisions but a fresh snapshot
ID. Proposal, decision, and directive contexts must nevertheless match the exact
snapshot reference, not merely its numeric revisions.

Every frame target must resolve to a versioned frame in the admitted snapshot.
For a non-current target, a compact index entry establishes identity/revision
only; missing target policy or operation data requires a new admitted snapshot.
A mode-change target uses the snapshot's current frame and root revision.
Relation endpoints must have resolvable frame revisions in that admitted view.

V1 deliberately invalidates decisions on any host state revision change, even
an unrelated frame update. This is conservative and may cause recomputation.
A future dependency-based scheme can reduce invalidation; consumers must not
silently introduce it by ignoring the global revision.

### Dispatch linkage and stale-decision detection

The scheduler maintains the following durable host ledger entries. These are
host-internal linkage contracts, not additional `IntegrationRecord` schemas:

```metta
(DispatchLink
  (id (DispatchRef HOST ID))
  (context SNAPSHOT-REF)
  (decision DECISION-REF) (directive DIRECTIVE-REF)
  (proposal PROPOSAL-REF-OR-None)
  (target FRAME-REF-OR-None)
  (checked-state-revision STATE-REV)
  (checked-policy-revision POLICY-REV))
(ExecutionLink
  (id (ExecutionRef HOST ID))
  (dispatch DISPATCH-REF))
```

`checked-*` records the actual host revisions at the dispatch check, including
when it fails. The target is the requested frame revision from the snapshot,
not a later version substituted by the scheduler. A dispatch has at most one
execution attempt in v1; each authorized retry needs a new dispatch and execution
ID. An execution may comprise a handler's command batch, with observations
identifying its individual results. Handler-level partial execution and retry
semantics remain Phase 5 work.

Before any invocation or frame mutation, the scheduler must:

1. Resolve and validate the directive → decision → optional proposal chain;
   require identical contexts and agreement on operation, target, and admission.
   Resolve all target, policy, and supporting evidence references with their
   expected types. Unsupported or missing references cannot authorize dispatch.
2. Verify the snapshot belongs to the current host lineage. Compare its state
   and policy revisions with current authoritative counters, and verify target,
   relation, budget, and constraint revisions against the captured versions.
   Any mismatch is `StaleSnapshot`, even if the old policy admitted the action.
3. Revalidate policy for the resolved concrete handler, arguments, target, and
   cost. A matching revision is necessary, but does not itself grant permission.
4. Atomically couple the final revision/policy check with durable dispatch
   claiming, execution-ID allocation, and applicable resource reservation.
   Record reservation changes as new state revisions. A queued executor must
   use a host-enforced claim/fence: intervening changes invalidate the claim
   unless the host serializes them with the execution start. A separate earlier
   check followed by unguarded invocation does not satisfy this contract.

A directive found stale before execution allocation produces a linked `Blocked` outcome with reason
`StaleSnapshot` and execution `None`; it cannot be repaired by replacing its
context. Capture new state and recompute the proposal (if used), decision, and
directive with new IDs. Keep the old chain for audit. Malformed records use
`ContractRejection` instead of manufacturing a valid dispatch chain.
If a queued claim is invalidated after execution-ID allocation but before
invocation, retain that ID in the `Blocked` outcome and record that invocation
never started. Do not report `Blocked` for an invocation that may already have
run; reconcile it or report `Unobserved` with the allocated execution ID.

Once a directive has a recorded dispatch, redelivery returns that recorded
attempt; it must not allocate another execution. An explicit retry creates a
fresh decision/directive chain and a new dispatch. Unknown execution status
requires reconciliation using the existing execution ID, not blind replay.
IDs enable deduplication but do not guarantee exactly-once external effects;
durable claiming and handler idempotency/recovery must be implemented by the host.

### Outcome and evidence causality

The complete causal chain is:

```text
snapshot → proposal (optional) → decision → directive → dispatch → execution
    │                                                     │          │
    └─ frame/relation revisions                            └─ outcome ┘
                                                               │
                                              observations / verification
```

For example, decision `(RecordRef "metamo-A" "decision-1")` and directive
`(RecordRef "adapter-A" "directive-1")` both retain
`(SnapshotRef "host-A" "snapshot-1" 42 7)`. Dispatch
`(DispatchRef "host-A" "dispatch-1")` links these to target
`(FrameRef "host-A" "frame-1" 3)`; execution
`(ExecutionRef "host-A" "execution-1")` links back to that dispatch. Its outcome
retains the original snapshot even when recording results advances state to
`43`. A second unclaimed directive based on state `42` is now stale.

Outcomes and post-execution verification retain the original decision context;
they are historical observations and must not be discarded merely because the
host has advanced. Validate their causal links instead. Each execution-bound
observation must resolve to the same execution/dispatch as its outcome, and
each verification reference must resolve to evidence for the relevant relation
and frames. An observation shared across proposals does not imply it was
produced by those proposals' executions.

Standalone verification uses the snapshot on which verification was based and
execution `None`. Applying any evidence to a relation is a separate host mutation
using compare-and-set on its `RelationRef` revision. If that relation changed,
retain the observation but require revalidation before write-back. Duplicate
evidence must not increment relation revisions twice. Duplicate outcomes must
not cause a second reliability update, including after restart; conflicting
content under any existing identity is `IdentityConflict`.

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
  (id ROOT-ID) (revision NONNEGATIVE-INTEGER)
  (current-frame-id FRAME-ID-OR-None) (mode MODE)
  (global-budget BUDGET-REF) (global-constraints CONSTRAINTS-REF))
(FrameStateCurrent
  (id FRAME-ID) (revision NONNEGATIVE-INTEGER)
  (parent FRAME-ID-OR-None) (source SOURCE-ID)
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
  (dispatch DISPATCH-REF)
  (execution EXECUTION-REF-OR-None)
  (frame FRAME-ID-OR-None)
  (status EXECUTION-STATUS)
  (reason REASON)
  (observed-at UTC-MILLISECONDS)
  (execution-evidence OBSERVATION-REFS)
  (verification VERIFICATION-REFS))
```

`DISPATCH-REF` and `EXECUTION-REF` use the host-qualified references defined
above; decision/directive/proposal/verification references use `RecordRef`.
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
  (execution EXECUTION-REF-OR-None))
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
| Bundle | `contexts/context_projection.metta`, accessors/slices | Envelope, root/current revisions, explicit absent current frame, typed index/relations and policy references |
| Policy | `contexts/context_directives.metta`, `task_lifecycle.metta`, `bridge.metta` | Envelope, reason, proposal reference; identical startup/runtime shape |
| Attention | `contexts/context_directives.metta`, proposal conversion | Envelope, decision reference; startup currently lacks `reason` |
| Proposal | `reasoner_proposals.metta`, helpers, inference adapter | Named fields, ID in envelope, explicit targets and evidence references |
| Outcome | `recordReasonerProposalOutcome` arguments | Host-qualified dispatch/execution references and validated causal chain before deriving a grade |
| Verification | `contexts/context_relations.metta` | Relation identity/revision, observation references, timestamp, optional execution identity |

Do not append version fields directly to existing positional patterns. Boundary
adapters must validate and unwrap v1 explicitly. A v0 conversion requires the
host to supply missing identity, revisions, and evidence; it cannot manufacture
those from summaries. Keep legacy local fixtures separate from v1 fixtures.

Before enabling v1, shared host/MetaMo contract fixtures must cover all six
records; startup, admitted, rejected, and no-action output; absent current frame;
each proposal kind and outcome/evidence status; wrong schema/version/arity;
missing, duplicate, and unknown fields; invalid numbers; unresolved references;
context mismatch; stale revisions; and duplicate/conflicting IDs. In particular,
cover cross-host and wrong-type references; restart/backup-restore identity;
changed non-current target, root mode, relation, budget, or policy; equal numeric
revisions with different snapshot IDs; a policy change between check and execution
start; duplicate directive delivery; unknown execution reconciliation; late valid
outcomes after state advances; and stale/duplicate evidence write-back. These are
required shared coverage, not claims that the live runtime implements these checks.
The shared wire suites now cover all six shapes, constructors, startup and
no-action records, absent current frames, proposal/outcome/evidence variants,
malformed fields and versions, nonfinite numeric values, and local context/reference
consistency. Durable replay, reference resolution, stale-decision enforcement,
host rollout, collection limits, and lifecycle enforcement remain pending.
Phase 2 remains open until its implementation gates pass.
