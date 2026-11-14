# Loosely coupled reasoner integration

Status: optional collection, admission, attribution, receipts and controlled assessment/learning connected; bounded influence remains proposed

The integration should connect the existing reasoner adapters to the normal
OmegaClaw runtime through an optional host coordinator. MetaMo should receive
validated advisory proposals and published source weights. Core should continue
to own concrete operations, execution and observations. Each reasoner should
keep its own representation, inference rules and native learning behavior.

The implementation should reuse the existing proposal, policy, dispatch and
assessment modules. It needs runtime connection points and adapter registration;
it does not require replacing those implementations or migrating every record.

## Current foundation and remaining connection

The following are implemented and should be reused:

| Existing module | Responsibility to retain |
| --- | --- |
| `composition.metta` | Native application composition, independent of optional reasoners. |
| `reasoners/reasoner_proposals.metta` and `reasoners/reasoner_proposal_helpers.metta` | Proposal representation checks, admission/conversion, audit, read-only reliability influence and ungraded execution receipts. |
| `reasoners/reasoner_integration.metta` | Bounded NARS/PLN queries and conversion of supported conclusions into proposals. |
| `reasoners/reasoner_engines.pl` | Loading the original PeTTa libraries with separate function namespaces. |
| `reasoners/reasoner_host_evidence.metta` and `.pl` | Trusted attribution of a retained proposal to an actual selection, dispatch ticket and observation. |
| `reasoners/reasoner_outcome_assessment.metta` | External prediction comparison, grade validation, assessment audit and application-level source weighting. |
| `bridge.metta` and `operation_selection.metta` | Published cycle snapshot, candidate admission, selection and retention of the exact host operation. |

Explicitly enabled startup now connects shadow proposal collection, retained
native decisions and capability-based outcome notifications through the normal
bridge and dispatch callbacks. Automatic causal attribution, assessment, learning
and proposal influence remain separate work.

Existing relationships are documented in [COMPOSITION.md](COMPOSITION.md),
[CONTRACTS.md](CONTRACTS.md), [SCHEDULING.md](SCHEDULING.md) and
[DISPATCH.md](DISPATCH.md). Existing reasoner APIs and assessment semantics are
described in [README.md](README.md#nars--pln-proposal-integration).

## Implemented local adapter records

`reasoners/host_reasoner_contracts.metta` now defines pure MeTTa, opt-in representation
contracts using the existing factual, typed-policy and proposal-data helpers. They allocate no state, load no engine, register
no adapter and install no runtime hook. The connected shadow coordinator is described below; remaining runtime stages
are still proposed. Import `lib_import` before the contract module
when using it outside the application composition.

| Validator | Success | Rejection |
| --- | --- | --- |
| `validateReasonerAdapterRegistration record` | `(ReasonerContractValid ReasonerAdapterRegistration 1)` | `(ReasonerContractRejected InvalidRegistration)` |
| `validateReasonerInvocation record` | `(ReasonerContractValid ReasonerInvocation 1)` | `(ReasonerContractRejected InvalidInvocation)` |
| `validateReasonerIntakeResult record` | `(ReasonerContractValid ReasonerIntakeResult 1)` | `(ReasonerContractRejected InvalidIntakeResult)` |

All fields shown below are required in exactly this order. Extra, missing,
duplicate or reordered fields, wrong constructors/arities and non-ground values
reject. Quote literal input so it is inspected as data.

```metta
(ReasonerAdapterRegistration
  (adapter "nars-local")
  (contract-version 1)
  (configuration-version "config-1")
  (source nars)
  (capabilities
    (ReasonerCapabilities
      (proposal-kinds (propose-candidate))
      (candidates (respond))
      (prediction-schemas ("ExpectedOperationResult"))
      (feedback (Decision Observation Assessment))))
  (limits
    (ReasonerIntakeLimits
      (max-facts 128)
      (max-payload-nodes 4096)
      (max-proposals 16)
      (max-session-records 128)
      (max-engine-steps 100)
      (max-engine-queue 40)
      (max-provider-calls 0)
      (provider-cost (ReasonerProviderCostLimit (unit "USD") (amount 0)))
      (timeout-ms 1000))))
```

Capability collections are duplicate-free. Proposal kinds and candidates use the
existing proposal vocabulary; sources are `nars`, `pln`, `llm`, `rule-engine` or
`human-adapter`. Prediction schema names are adapter-specific strings (at most
32). Feedback supports `Decision`, `Observation` and `Assessment`. Empty lists
are valid, including an adapter with observation feedback but no proposals.
A schema name does not register a comparator or promise it is implemented.

Identifiers are nonblank strings of 1–256 Unicode characters without control
characters. Native frame IDs additionally accept symbols, preserving symbol/string
identity and rejecting booleans and `None`/`none` markers. Contract version is
exactly integer `1`; cycle, revision and deadline are integers in
`0..9007199254740991`. Numeric strings, booleans and floating-point counts reject.

Limit ceilings are representation bounds: facts 4096, payload nodes 65536,
proposals 128, session records 4096, engine steps 1000000, engine queue 65536,
provider calls 128 and timeout 3600000 ms. Payload nodes, session records and
timeout must be positive; other count limits may be zero. Provider cost requires
an explicit unit string and a finite amount in `0..9007199254740991`. These are
configured upper bounds, not measured usage or grants. Existing host limits,
including the 128-link evidence store, remain independently applicable.

An invocation has the following exact fields. `CAPABILITIES` and `LIMITS` below
stand for complete nested records of the shapes above, not scalar placeholders
accepted by a validator.

```text
(ReasonerInvocation
  (invocation-id "invocation-1")
  (adapter "nars-local")
  (contract-version 1)
  (configuration-version "config-1")
  (session "session-1")
  (cycle 0)
  (frame Frame-A)
  (publication (ReasonerPublicationRef "publication-1"))
  (commitment (ReasonerCommitmentRef "commitment-1" 0))
  (phase CandidateIntake)
  (capabilities CAPABILITIES)
  (limits LIMITS)
  (evidence ((SessionObservationRef "session-1" 0)))
  (deadline-ms 1000))
```

The publication reference is an opaque host-issued identity for the exact
published view; the validator neither allocates it nor requires a v1 wire
migration. Commitment is either `NoCommitment` or the exact reference shown.
Phase is `ModeIntake` or `CandidateIntake`. Evidence is a duplicate-free list of
at most 128 typed `ObservationRef` or `SessionObservationRef` values. Session
references must match the invocation session; host references require nonblank
host/observation strings. Deadline is an absolute Unix timestamp in milliseconds;
the example's value is shape-valid but expired. Validation does not read the clock.

```metta
(ReasonerIntakeResult
  (invocation-id "invocation-1")
  (adapter "nars-local")
  (status Timeout)
  (proposals ())
  (diagnostics
    ((ReasonerIntakeDiagnostic DeadlineExceeded "deadline exceeded"))))
```

Status is `Proposals`, `NoConclusion`, `Unavailable`, `Timeout` or `InvalidOutput`.
Only `Proposals` may carry proposals and it requires at least one. Other statuses
require an empty list; none creates a negative prediction grade. Results allow
at most 128 proposals and 16 diagnostics. Each proposal must have the existing
exact ten-field `ReasonerMotivationalProposal` shape with bounded inert contents
(depth 16, 1024 nodes, 256 children per list and 1200 characters per scalar).
This checks transport representation and the existing proposal value contract;
host evidence resolution and policy admission remain separate. Diagnostics use the exact constructor above,
a string of at most 1200 characters, and one of `NoSupportedConclusion`,
`AdapterUnavailable`, `DeadlineExceeded`, `MalformedOutput`, `LimitExceeded` or
`AdapterError`. Diagnostics may be empty and never execute their contents.

### Proposal values and adjacent provenance

Intake results now reuse `reasonerProposalValid` for the original ten-field
`ReasonerMotivationalProposal`, including target, candidate, claim, support,
confidence, evidence and prediction. The pure validators live in
`reasoners/reasoner_proposal_helpers.metta`; importing contracts still allocates no audit
state and loads no engines.

Trusted callers can use
`bindReasonerProposalInvocation REGISTRATION INVOCATION ENGINE-VERSION PROPOSAL`
to construct this local record:

```text
(ReasonerInvokedProposal
  (registration REGISTRATION)
  (invocation INVOCATION)
  (engine-version "engine-build-1")
  (proposal PROPOSAL))
```

`validateReasonerInvokedProposal` returns
`ReasonerContractValid ReasonerInvokedProposal 1` or
`ReasonerContractRejected InvalidInvokedProposal`. The builder returns the exact
record on success or that rejection. The original proposal is unchanged;
invocation identity, session/cycle/frame, publication, commitment, phase and
configuration version remain beside it. Engine version is a required bounded,
nonblank string supplied by the adapter. Registration and invocation must agree
on adapter, contract/configuration versions, capabilities and limits; proposal
source must match registration. This initial binding requires identical capability
and limit declarations rather than accepting negotiated subsets.

Use `llm` as the proposal and registration source, and
`"llm-motivational-proposal"` as the LLM adapter identity. That reserved adapter
identity rejects any other source. It does not add a source enum or install an
LLM loader/provider.

These pure checks preserve metadata as inert data. They do not establish engine
version authenticity, resolve evidence, enforce capabilities, check a deadline or
admit a proposal against current host ownership and policy. The optional coordinator now retains these envelopes during shadow intake.

Matching invocation/adapter/configuration identities against retained host state,
restricting invocation capabilities/limits to the registration, enforcing time
and resource limits, deduplicating intake and resolving evidence authority remain
coordinator work. A standalone valid result does not establish its origin,
freshness or eligibility. These local records do not replace the existing proposal
constructor or any versioned wire record.

Run the focused offline checks from the workspace root:

```sh
python3 MetaMo/scripts/run-omegaclaw.py MetaMo/applications/omegaclaw_v1/tests/host_reasoner_contracts_test.metta
python3 MetaMo/applications/omegaclaw_v1/tests/reasoner_boundary_test.py
```

`reasoners/host_reasoner.metta` provides the optional trusted `prepareHostReasoner` entry
point. It validates and retains a registration, including its configuration
version, and leaves the previous value unchanged on rejection.
`hostReasonerRegistration` reads that value, initially `()`.

Trusted host code registers adapters with
`registerHostReasoner REGISTRATION (quote LOADER)`. Registration validates the
record and retains its loader without invoking it. Identical registration is
idempotent; conflicting bindings reject. `selectHostReasoner "adapter-id"` invokes
that trusted loader, requires literal True, and retains the registration only on
success. `hostReasonerSelection` returns the selected ID or `disabled`, separately
from prepared configuration. Repeating selection does not load twice; changing a successful selection
requires a fresh process. `selectHostReasoner disabled` loads nothing before any
adapter is selected. These functions are not registered model skills.

Normal startup reads `reasoner=disabled` (default), `reasoner=nars` or
`reasoner=pln` from the common launcher's existing runtime arguments. Another name
selects an adapter registered by trusted host code before startup. Unknown or
multiple selections reject before entering the agent loop. Disabled startup does
not import the coordinator, load engines or allocate reasoner audit state.

The built-in registrations declare candidate proposals, the existing candidates,
`ExpectedOperationResult` predictions and no feedback capability. Other adapters
may declare only their supported stages. NARS/PLN reuse the existing inference
extension, which loads both local engines in separate namespaces; selection
retains one adapter. Selection enables no collection, provider, grading or learning.
Independent controls enable bounded shadow intake and declared adapter feedback.

## Ownership

| Component | Owns | Consumes from its neighbors |
| --- | --- | --- |
| Core and ContextFrames | Frames, task lifecycle, concrete commands, permissions, resources, dispatch and authoritative observations. | Admitted scheduling decisions and explicit host requests. |
| MetaMo | Motivational state, regime selection, feasibility, scheduling precedence, candidate scoring and bookkeeping. | One bounded published snapshot, advisory proposals and validated parameter values. |
| Host coordinator | Adapter registration, bounded intake, evidence resolution, cycle correlation, attribution and feedback routing. | Host snapshots, adapter results, decisions and Core receipts. |
| Reasoner adapter | Translation between the host view and its engine, supported proposals and engine-specific feedback handling. | Bounded admitted facts and observations in an explicitly supported format. |
| External assessor and learner | Comparing predictions with observations and proposing or applying validated learning updates. | Retained predictions, authoritative evidence and explicit update policies. |

The coordinator belongs to the application's host integration layer. Its location
inside `omegaclaw_v1` does not make inference, execution or learning a motivational
responsibility. MetaMo does not import an engine to select native work, and
reasoners do not receive Core mutation or dispatch capabilities through intake.

## Boundary contracts

Use a registered set of trusted adapter functions, selected by host configuration.
Model-generated records cannot name a function, install an adapter or enable a
provider. Function names, transport choices and provider details stay behind
registration rather than entering candidate scoring.

The proposed coordinator has three responsibilities:

| Boundary | Input | Output and effect |
| --- | --- | --- |
| Collect proposals | A bounded host view, invocation identity and limits. | A bounded list of existing proposal records plus intake diagnostics. No execution or motivational-state mutation. |
| Attribute selection | Retained proposal decisions and the host's final selected operation. | At most one primary proposal attribution to the actual ticket, before invocation. |
| Process feedback | A correlated Core observation and retained attribution. | An ungraded receipt; optionally a separate external assessment and validated feedback delivery. |

These are proposed interfaces, not function names already available in the
runtime. Keep them as direct in-process calls initially. A queue, remote service
or general plugin framework is unnecessary for establishing the boundary.

### Invocation context and freshness

Keep host correlation metadata beside the existing proposal rather than adding
host fields to every engine's representation. The context should retain:

- An invocation ID and the exact operation session, cycle and native frame ID.
- The published bundle identity and the applicable commitment ID/revision.
- Adapter identity, contract/configuration version and bounded evidence view.
- The permitted proposal kinds/candidates, inference limits and deadline.

Specify exact types and arities for any new context or result records before
using them. Native frame IDs retain their types; a symbol and a string with the
same printed text do not identify the same frame. An intake response must match
the invocation that requested it. A valid proposal ID alone proves no freshness,
ownership or evidence authority.

An adapter may return proposals, no supported conclusion, unavailable, timeout
or invalid output. These outcomes need distinct diagnostics. Neither absence nor
timeout is evidence against a prediction. Reject late or mismatched responses;
do not relabel them with the current cycle or silently recapture another bundle.

Scope proposal IDs by adapter and invocation in the host metadata. Identical
redelivery contributes once; the same scoped ID with changed contents rejects.
This does not require changing the existing proposal constructor or making an
engine allocate host dispatch identities.

### Engine semantics and fact translation

Reuse the current proposal shape:

```text
(ReasonerMotivationalProposal
    ID SOURCE KIND TARGET CANDIDATE CLAIM SUPPORT
    CONFIDENCE EVIDENCE-REFERENCES PREDICTION)
```

The host supplies admitted factual records and stable references from the
published view. Each adapter decides how to encode supported facts for its
engine. Preserve NARS truth components and evidence stamps, PLN truth values,
negative evidence, and the distinction between missing and false observations.
The coordinator must not reinterpret confidence as proof or assert a queried
recommendation as a premise.

The optional pure `reasoners/reasoner_fact_translation.metta` module implements
`translateReasonerAdmittedView ENGINE VIEW OBSERVATION-CONFIDENCE` for `nars`
and `pln`. The inference extension imports it; default composition does not.
Standalone callers load `lib_import`, `host_reasoner_contracts`, the factual
signal registry declarations they need, then `reasoner_fact_translation` once.
The public contract facade retains its existing API and dependency imports;
`reasoners/host_reasoner_contract_data.metta` holds the definitions for consumers whose
prerequisites are already loaded. This avoids duplicate compilation of shared
helpers under native PeTTa.
The caller supplies the exact admitted invocation and data:

```text
(ReasonerAdmittedView
  (invocation INVOCATION)
  (signals (FACTUAL-SIGNAL ...))
  (native-facts ((ReasonerNativeFact nars SENTENCE) ...)))
```

Success returns `(ReasonerTranslatedFacts (invocation INVOCATION)
(engine ENGINE) (facts SENTENCES))`; failure returns
`(ReasonerTranslationRejected REASON)` without partial facts. The invocation is
preserved exactly. Pass the returned sentence list to the existing reasoner
query/proposal APIs. This function does not invoke an engine or collect proposals.

Boolean observations become `(SignalHolds FRAME KIND)` with truth frequency 1
for explicit True and 0 for explicit False. Missing observations produce no
premise; callers omit them rather than supplying `NoObservation` as a fact.
Ratio and quantity observations become `(SignalValue FRAME KIND TYPED-VALUE)`
with frequency 1, preserving the value and unit. A classifier score is never
converted into truth strength. Observation confidence is an explicit finite
adapter encoding parameter in `[0,1]`, supplied by trusted adapter configuration;
it expresses support assigned to the observation encoding, not outcome
probability. No default or calibrated certainty is invented.

Native sentences preserve engine-specific terms, both `stv` components, negative
support and the original evidence list unchanged. NARS implication remains `==>`;
PLN implication remains `Implication`. Mixed-engine native records reject.
Typed signal validation reuses the existing registry. Duplicate signal kinds,
malformed facts and missing/duplicate/undeclared evidence references reject the
whole view. References must be included in the invocation's admitted evidence
set. Fact count and payload node limits come from that invocation, with depth
and scalar bounds enforced by the existing data walker.

Translation never reads raw host/frame state, the observation store, current
signal spaces or provider output. The caller remains responsible for admitting
and authenticating the view, including the engine rules it contains; reference
membership alone is not evidence authority. Deadlines, current ownership,
selection influence, causal attribution and assessment remain coordinator work.
Offline integration tests exercise both real engines on these translated facts,
including negative evidence and missing premises.

Retain the existing separate NARS/PLN namespaces and query budgets. Their shared
proposal boundary does not imply shared implication syntax or truth revision.
Additional engines implement the same host contract through another adapter.

Keep `llm` as the existing proposal source value initially. Represent
`llm-motivational-proposal` as the registered adapter's role/identity in host
metadata. Adding it as a literal source value would require an explicit contract
change because the current source validator does not accept that spelling.

Prediction syntax stays adapter-specific. An adapter must declare which
comparator can evaluate its predictions and which observations that comparator
requires. It must produce the prediction before the observation. A candidate
label alone cannot supply a prediction, derivation or expected result.

## Connected shadow coordinator

`reasoners/host_reasoner_coordinator.metta` extends the existing host registration
and selection boundary. Its state and callback helper load only for explicit
reasoner startup. The default-disabled bridge performs no reasoner invocation.
Candidate collection runs after concrete operation admission and before final scheduling;
Collected candidate proposals now pass the existing native feasibility, concrete
dispatch-policy, availability and scoring checks before scheduling. With influence
disabled, the native candidate pool and scores remain unchanged.

`reasoners/host_reasoner_admission.metta` consumes the exact operation rows captured
for native admission; it never captures another command or ticket. Unsupported
and ambiguous bindings reject with the native reasons. Rejected proposals are
not scored. Feasible but unavailable work rejects as `CandidateUnavailable`.
Only admitted proposals use `omegaclawScoreForBundle`, with the same state supplied
to the native cycle; confidence and source reliability do not multiply that score.

`hostReasonerAdmissions` exposes bounded batches:
`(HostReasonerAdmissions CONTEXT INVOCATION-ID DECISIONS)`, with each decision
stored as `(HostReasonerProposalAdmission ORIGINAL-ENVELOPE
ReasonerMotivationalDecision OPERATION)`. `OPERATION` is the exact captured
`HostOperation`, including command and ticket, for accepted proposals, or `()`
for rejection. The envelope preserves the exact proposal and
provenance. `Accepted` means admitted to consideration, not selected or executed.
Existing native actions and tie order are preserved, and duplicate candidate
advice adds no extra action or score. Repeat admission of an invocation does not
rescore or reissue an earlier permission; it preserves the current native pool.

Mode-stage advice is also assessed before evaluation, but no concrete mode or
cross-frame handler is supplied by the supported runtime catalog. Such requests
therefore retain an explicit rejection rather than gaining execution authority.
Final dispatch still runs Core's current-state, exact-command, ticket and budget
checks. Bounded advisory weighting and grading remain separate integration work.

Proposals and predictions are retained before native selection or mode evaluation.
First-time intake after the corresponding decision is refused; existing intake
redelivery cannot allocate another prediction. Admission/rejection, actual native
decisions, mode observations and execution outcomes remain separate records.

`hostReasonerSelections` exposes bounded, immutable selection audit rows:
`(HostReasonerSelection CONTEXT INVOCATION-ID OperationDecision PRIMARY)`.
Before adapter notification and dispatch, the first accepted `propose-candidate`
entry in retained intake order whose exact captured operation matches the native
selection becomes `(HostReasonerPrimary ORIGINAL-ENVELOPE OPERATION ShadowAgreement)`.
Confidence does not break ties. The host rechecks current ownership, deadline,
command, ticket, dispatch epoch and snapshot, and requires no existing execution
receipt. No match gives an empty primary. Failed attribution preserves native
selection and never creates a replacement ticket. Replays cannot replace the
primary or assign the same ticket to another invocation, and observed execution
cannot acquire attribution retrospectively.
`ShadowAgreement` is an evaluation association, not evidence that the reasoner
caused selection; it grants no causal learning credit or execution authority.

Boundary regressions pause after intake/admission and before native selection.
They cover mismatched advice commands/tickets, duplicate proposal IDs with
conflicting predictions, competing invocation claims on an attributed ticket,
and commitment replacement. Failed attribution preserves independently valid
native dispatch; a ticket invalidated by an ownership change remains blocked by
Core. The tests compare the ticket ledger before selection and after dispatch
to ensure neither attribution failure nor replay allocates a replacement.

`hostReasonerReceipts` retains `(HostReasonerReceipt OUTCOME-REF SELECTION OUTCOME)`
during the accepted dispatch callback, before adapter notification. Capture checks
the exact retained selection and accepted callback against Core's immutable
command/ticket receipt. `OUTCOME-REF` reuses `(ReasonerOutcomeRef SESSION TICKET-ID)`.
Identical delivery does not append evidence; conflicting delivery cannot replace
it. Capture remains bounded by invocation audit limits. Failed capture cannot
publish fabricated feedback or change native dispatch. Later slot replacement
does not erase captured evidence. Receipts contain no grade.

After enabling assessment and explicitly loading `reasoner_outcome_assessment`, trusted host code can call
`(assessHostReasonerProposalOutcome ORIGINAL-ENVELOPE OUTCOME-REF)` outside MetaMo.
Routes resolve by the retained adapter ID, configuration version and declared
prediction schema. The built-in `ExpectedOperationResult` route defaults to
`compareReasonerOperationResult`, version `exact-operation-result-1`.
`hostReasonerAssessments` holds bounded, idempotent
`(HostReasonerAssessment OUTCOME-REF ENVELOPE COMPARATOR COMPARISON)` records;
the envelope retains invocation and configuration provenance. This path performs
no reliability update or engine learning, and callback capture never invokes it.
Blocked, unobserved, unsupported and non-primary predictions stay deferred.
Rejected alternatives need independent authoritative evidence; another operation's
result is not grounds for grading them. No such observation adapter is installed
by the operation-result route.

`reasoners/host_reasoner_comparators.metta` supplies trusted route registration:

```metta
(configureHostReasonerComparator "adapter-id" "ExpectedOperationResult"
  "exact-v1" compareReasonerOperationResult)
```

Register before intake. Configuration accepts only schemas declared by that
adapter and trusted function symbols. Identical registration is idempotent;
changed or first-time registration after intake rejects, including replacing an
implicit default or unsupported route. Registry size is bounded by the existing
adapter and schema registration limits. The prediction constructor names its
schema; it never supplies an executable comparator.

The assessment's comparator field retains
`(HostReasonerComparator (adapter ID) (configuration-version VERSION)
(schema SCHEMA) (version COMPARATOR-VERSION) (function SYMBOL))`.
Calls receive quoted retained prediction/observation data, run outside the
recording mutex with the invocation's elapsed-time allowance, and never read or
swap the legacy global comparator. Unsupported routes and unresolved comparisons
remain deferred. Malformed, nonfinite or out-of-range grades reject without an
assessment or learning marker, preserving the receipt for a valid retry.
Identical assessment/learning delivery returns the original record; conflicting
delivery rejects without changing grades, reliability or adapter feedback counts.

Trusted code configures runtime behavior and stages alongside a registered adapter:

```metta
(configureHostReasonerRuntime "adapter-id"
  (quote (HostReasonerRuntime "engine-version" collectAdapter notifyAdapter
    () 0.9)))
(configureHostReasonerControls "adapter-id"
  (HostReasonerControls (collection True) (influence False)
    (assessment True) (learning False)))
```

The four controls default to `False`; configuring a runtime or selecting an
adapter does not enable them. Startup exposes the same controls through
`reasoner-collection`, `reasoner-influence`, `reasoner-assessment` and
`reasoner-learning` Boolean arguments. Configuration is immutable after the first
retained invocation; repeated identical configuration is harmless. Invalid or
late changes preserve the previous controls. Enabling influence currently rejects
as `UnsupportedInfluence`; no weighting formula is supplied by these switches.

Collection permission creates invocations and admission audits. Influence
permission is separate: without it, an eligible proposal cannot add an action to
the native pool. Assessment permission allows explicit preview and retained grades
without reliability changes. Learning permission gates all adapter notifications,
because engine notification handlers may train their native state. Local decisions,
receipts and diagnostic getters remain available without engine feedback.

`learnHostReasonerOutcome OUTCOME-REF` is a separate explicit learning entry point.
It reads an existing validated assessment, reuses the source reliability learner,
and retains `(HostReasonerLearning OUTCOME-REF ASSESSMENT BEFORE AFTER)` once.
Only a newly committed update attempts `Assessment` feedback through the trusted
runtime notifier, and only when the retained adapter declares that capability.
Replay skips both learning and feedback; inference and adapter calls stay outside
the recording mutex. Engines without feedback support receive no invented update.
Application source weighting remains separate from engine-specific truth revision.

Adapters that support mode advice or transition predictions can additionally opt
in before any invocation is retained:

```metta
(configureHostReasonerModeIntake "adapter-id")
```

This enables `ModeCollect` after factual signal refresh and before mode evaluation.
The same collector receives phase `ModeIntake` and an empty action list. Candidate
collection receives phase `CandidateIntake`, after concrete operations are captured
and admitted, before scheduling or selection. Both invocations retain the same
published snapshot, facts and evidence identities; invocation IDs differ. No
snapshot is recaptured between them. Both phases retain the existing current-frame
invocation requirement; frameless idle cycles continue native mode evaluation
without advice. Candidate-only adapters receive one call;
adapters declaring only mode changes skip candidate collection. Disabled startup
still loads no coordinator or reasoner state.

Mode intake accepts declared `request-mode-change` advice through the existing
Fast/Slow target contract, or `request-attention` proposals carrying transition
predictions for the current frame. It does not extend that target vocabulary to
constitutional modes or change the actual mode. Candidate-stage mode-change
requests reject. The adapter owns the prediction schema and interpretation.

`ModeObserved` retains the actual `ModeObservation` against an already-retained
pre-mode invocation and reports it through declared `Decision` feedback. It cannot
create a missing prediction or attach a candidate-stage prediction to a transition.
First-time mode collection after that context's transition has been observed
returns `LateModeIntake`; duplicate delivery preserves the original invocation.
The same audit capacity is shared by both phases. Neither path grades predictions,
changes native selection, or relaxes admission. Timeout or invalid advice leaves
native mode evaluation and scheduling available.

The last two fields are admitted engine-native facts and an explicit observation
encoding confidence. Rules and their stable evidence stamps come from trusted
configuration; the empty default invents no rules. The configuration is frozen
once that adapter has a retained cycle. It grants no execution permission.

The collector receives `(INVOCATION ADMITTED-VIEW ADMITTED-ACTIONS)` as quoted
data and returns the existing `ReasonerIntakeResult`. The notifier receives
`(STAGE INVOCATION PAYLOAD)`, where STAGE is `Decision` or `Observation`, only
when the registration declares that feedback capability. Each adapter owns its
feedback interpretation; the built-in stateless NARS/PLN query adapters declare
no feedback and perform no native learning. A custom adapter may support either
notification independently.

The host supplies typed signals from the same published snapshot. Signal
references are checked against its retained source owner and deduplicated without
changing their identities. Configured native facts retain their truth values,
negative evidence and stable rule references. Invocation records retain session,
cycle, frame, commitment revision, publication, engine/configuration provenance
and a deadline. The built-in version label is `local-libraries`; a trusted host
should configure an exact engine version when reproducibility requires it.

Counts and payload bounds reuse the existing registration/invocation limits.
Collection now uses `reasonerRuntimeCollect`: it verifies the exact session,
cycle, native frame identity and open commitment revision, captures current
host state under the dispatch mutex, then releases the mutex before calling
the adapter. It refuses collection when the calling thread already holds that
mutex. Before accepting the response it checks ownership/state again and checks
the absolute invocation deadline, including preparation time. Expired and late
responses cannot become proposals, even if a callback absorbs a timeout signal.
Session evidence must resolve to the current publication owner; native rule
`ObservationRef` values remain explicit trusted host configuration.

Built-in queries retain their existing step allocation. Calls through
`reasonerQuery` now additionally reserve their requested steps from one shared
invocation allowance and enforce the declared queue ceiling, including repeated
queries by a custom adapter. Offline queries outside collection are unchanged.
Provider-backed adapters must use the metered gateway:

```metta
(reasonerRuntimeProvider providerCallback arguments "USD" declaredCost)
```

It reserves one provider call and the declared cost before invoking that callback;
a zero allowance prevents the call. The cost unit must match the registration.
These are conservative reservations, not measured billing. Gateways are the
supported adapter contract; trusted host code that bypasses them is outside
these guarantees. This is not an arbitrary-code or network sandbox.

Retained cycle records are bounded to twice the declared payload-node allowance
with depth 32 and existing scalar limits, in addition to the session record cap.
Oversized audit updates leave retained data unchanged. Feedback payloads also
respect the payload allowance. An unavailable or invalid adapter, exhausted
allowance, expired invocation or rejected audit update never grants execution
permission, changes native scores, or updates source reliability.

`hostReasonerCycles` exposes bounded `HostReasonerCycle` records containing the
operation context, phased invocation, checked intake result, original proposal
envelopes, retained native decision (or mode observation) and observed outcome. Repeated collection for one
context does not invoke again. Intake rejects wrong identities, undeclared sources,
kinds/candidates, duplicate proposal IDs, unknown evidence and oversized output.
Timeout/invalid output retains empty advice. Audit capacity exhaustion skips
collection and preserves native operation; no durable recovery or eviction is
introduced. Missing runtime callbacks likewise leave native operation available.

Decision notification follows retention of the exact native operation/ticket.
It reports what the native scheduler chose, not acceptance or causal attribution
of a shadow proposal. Observation notification runs only after the existing host
outcome validator accepts an immutable callback, before its slot is replaced.
Wrong-owner and conflicting callbacks do not reach the coordinator; identical
redelivery produces no additional notification. No success/failure label becomes
a numerical prediction grade or reliability update.

Offline boundary tests run the normal bridge/Core dispatch with a test adapter,
check one-time decision/outcome delivery and timeout/invalid-output fallback,
and exercise real NARS/PLN inference over the automatically supplied facts.
Disabled startup and native import/engine separation remain covered. No live
provider or external channel run is implied by these tests.

## Runtime sequence

Use the existing bridge cycle and its single published bundle:

1. Finish host bookkeeping and publish the bundle through
   `prepareTaskStateForMetaMo` as today.
2. Preserve existing signal publication, constitutional-mode evaluation,
   appraisal, native candidate generation and concrete-operation capture.
3. Once the bounded view and native availability are known, ask enabled adapters
   for proposals. Collect them before final scheduling and selection. Translate
   only data the host has admitted for that adapter and purpose.
4. Check proposal representation, invocation freshness, evidence authority and
   ownership. Record the intake result. Apply the existing candidate and concrete
   operation gates using the same bundle and captured operations.
5. Keep native admitted candidates available. Apply fixed scheduling precedence,
   then any enabled bounded advisory influence within the eligible class.
6. Retain the ordinary final host operation through `retainSelectedOperation`.
   Record which proposal, if any, actually influenced its selection. Call
   `retainReasonerProposalSelection` for that primary event before execution.
7. Dispatch the exact retained command and ticket through Core. Its final policy,
   snapshot, permission and resource checks remain authoritative.
8. In the actual dispatch-outcome callback, capture linked evidence through
   `observeReasonerProposalExecution` before another callback replaces the slot.
   Record the ungraded receipt and route eligible evidence to external assessment.

The collection and feedback hooks should resolve to empty behavior when the
extension is disabled. Native composition should not load engine libraries or
allocate reasoner audit state merely to discover that no adapter is enabled.

Reasoner calls must run outside the dispatch mutex. Engine step/queue limits do
not replace a wall-clock deadline. Provider deadlines, cancellation and stale
response disposal are host obligations. Validate freshness again when accepting
a result; Core still checks authority immediately before invocation.

If attribution fails, do not invent a link or grant reasoner credit. An ordinary
native selection may proceed only through its own still-valid host checks.

## Selection influence without replacing selection

Reuse registered candidates and existing concrete operations. Intake cannot
invent a command binding, add an unavailable native candidate, promote a lower
scheduling class, or bypass a mode restriction. Transition proposals remain
requests for the existing scheduler/host mechanisms; they do not switch frames
or modes from inside a reasoner.

Initially collect proposals in shadow mode: retain their predicted preferences
while the native selector determines the actual operation. Next, enable a bounded
advisory contribution for eligible candidates under explicit configuration. Keep
native order for ties and retain the native score, advisory contribution and
final score separately for explanation.

The existing `reasonerProposalEffectiveScore` scales a proposal's score by its
confidence and source reliability. It is not a replacement for the native
candidate score. Do not apply that scaling to every native candidate, because
missing proposals would then suppress ordinary work. Reuse its validated inputs
for an explicitly bounded overlay whose zero-influence behavior reproduces the
native selector. The overlay's cap and formula need registry declarations and
selection tests before activation.

Do not sum arbitrary numbers of agreeing proposals into unbounded influence.
Start with one eligible representative per source/candidate and a capped
aggregate; duplicates must contribute once. Keep the current selector while
evidence is collected. Bootstrap source priors are not earned performance.

## Attribution, comparison and learning

Keep three records distinct: the proposal's decision, the observed execution
receipt, and the external prediction assessment. A rejected or deferred proposal
is retained with its reason; rejection does not refute its prediction.

The current evidence adapter permits one proposal event per selected execution.
Choose and retain one primary attribution deterministically before dispatch.
Other agreeing proposals remain advisory records and receive no execution-backed
credit through that ticket. Supporting several independently assessed hypotheses
from one observation requires a separate assessment-identity design; it must not
be implemented by weakening the existing ownership checks.

In shadow mode, a prediction may be linked before dispatch when it agrees with
the operation the native selector actually chose. Record that the selection was
native; agreement does not mean the reasoner caused the choice. Predictions for
operations that did not run remain ungraded without other supporting evidence.

Reuse stable outcome identities, exact receipt matching and idempotent recording.
Execution receipts remain `Unresolved` / `Ungraded`. The external service resolves
the retained prediction and actual payload; callers cannot provide substitute
observations or a grade to the assessment entry point.

The built-in `ExpectedOperationResult` comparator tests exact observed payload
equality. It establishes only that prediction's result. Other prediction schemas
need registered comparators and trusted supporting observations. Unsupported,
blocked and unobserved cases remain ungraded. General frame claims and rejected
alternatives require additional authoritative observation adapters before they
can be assessed.

The coordinator resolves trusted comparator registrations from retained adapter
metadata and declared schemas. The legacy service still has one global comparator
setting; the coordinator port does not use or swap it. Comparison validation is
shared, and the comparator/configuration version is retained in
assessment provenance. A changed configuration does not regrade a completed
assessment; unsupported predictions can be retried because deferral reserves no
assessment identity.

The legacy `assessReasonerProposalOutcome` also updates application source
reliability. Shadow evaluation instead uses `assessHostReasonerProposalOutcome`,
which reuses comparison/validation helpers without learning. The existing atomic
assessment-and-learning path remains available for explicit legacy use;
independent coordinator learning controls and engine feedback remain separate.
Validate finite grades and learner inputs before committing. Preserve
one update per stable assessment and allow retry after a rejected attempt.

Application source reliability is an advisory weight, separate from each
reasoner's native truth revision. Deliver validated observations or assessments
to an engine only through an explicitly configured feedback adapter that
understands its semantics. An EMA source-weight update must never be translated
automatically into a NARS or PLN truth-value update.

Future appraisal-weight or mode-threshold learning should publish update
proposals externally. The host validates a whitelist of registry fields, numeric
ranges, evidence and update identity, then applies accepted values at a cycle
boundary. Keep before/after values and provenance. Never mutate the bundle or
parameters halfway through an active selection. Preemption order, authority,
permission checks and policy floors are not learnable fields.

Mode-transition prediction intake needs its own point before the transition it
predicts. The initial candidate-intake hook runs after the current mode evaluation
and must not retrofit a prediction onto a transition that already occurred.

## Composition, configuration and failure isolation

Add one optional host composition/coordinator module rather than importing
reasoners throughout Core or MetaMo. It should own trusted registration and call
the existing modules. Reuse host startup configuration; avoid separate copies of
provider credentials, policy or dispatch configuration.

Configuration should independently control collection, selection influence,
assessment and learning. Start with all disabled. Enabling a reasoner must not
silently enable provider calls, learning or an additional command surface. Declare
limits for facts, payload size, proposals per source/cycle, session audit capacity,
engine steps/queues, provider calls/cost and elapsed time. Respect the existing
128-link evidence limit; do not evict outstanding evidence to accept more work.

The current inference extension imports proposal support and loads both local
engines. Load it once, without separately reimporting its state-owning proposal
module. If selective per-engine loading becomes necessary, extend that loader
in place. Do not create parallel copies of engine definitions or audit stores.

| Condition | Required behavior |
| --- | --- |
| Disabled extension | Native runtime, with no reasoner/provider dependency. |
| No conclusion, unavailable adapter or timeout | Continue native operation under its ordinary checks; retain bounded diagnostics. |
| Invalid, stale or unauthorized evidence | Reject the proposal; leave decision/learning state unchanged apart from its rejection audit. |
| Policy-rejected proposal | Retain the rejection; neither dispatch nor assign a failure grade. |
| Missing or uncertain execution | Preserve uncertainty; do not infer completion, failure or permission to retry. |
| Invalid comparison or learner state | No assessment commit or reliability update; preserve valid receipts. |
| Duplicate/conflicting delivery | Return the retained result or reject the conflict without a second update. |

These failure paths preserve native availability, not guaranteed execution:
native work may itself be unavailable or rejected. Reasoner failure cannot enable
legacy model-generated command fallback. Bound diagnostics by references and
admitted summaries; logging does not grant another component access to raw data.

## Implementation and verification sequence

1. Add trusted optional composition, adapter registration and invocation metadata.
   Define new record types and tests. Preserve disabled-startup import isolation.
2. Connect shadow intake in the normal bridge using the existing NARS/PLN
   adapters. Exercise real derivation, negative evidence and engine separation.
3. Connect proposal decisions, primary attribution and receipt capture through
   actual selection and dispatch callbacks. Preserve native candidate availability.
4. Connect pure shadow evaluation, then independently enabled idempotent external
   assessment/learning. Test unsupported predictions and invalid grades.
5. Enable bounded advisory selection in offline experiments before live use.
   Add engine feedback and learned registry updates as separate, validated stages.

Extend the existing reasoner, concrete admission, operation-selection and boundary
tests. Test the normal runtime with disabled adapters, empty intake, timeout,
malformed output, stale invocation, another frame's evidence, policy rejection,
agreeing/duplicate proposals, missing observations and conflicting redelivery.
Show unchanged native selection at zero influence and unchanged reliability for
all ungraded cases. Keep exact-command dispatch and evidence attribution checks.

For predictive usefulness, compare native selection, shadow proposals and bounded
influence on matched offline scenarios with the same initial state, policies and
observation opportunities. Measure independently verified task outcomes,
prediction quality, graded coverage, latency/cost and policy violations. Report
ungraded coverage separately; missing observations are not incorrect predictions.
Keep calibration and evaluation episodes separate before raising influence.

Only after offline checks pass should a separately authorized, bounded live run
enable a configured provider through normal runtime intake. Retain the complete
invocation → proposal → decision → ticket → observation → assessment chain.
A helper demonstration or a driver that bypasses intake does not establish this.
Current host evidence and assessment are session-local; durable restart recovery
requires separate work and must not be inferred from successful redelivery tests.
