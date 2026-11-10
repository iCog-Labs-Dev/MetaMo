# Loosely coupled reasoner integration

Status: proposed runtime design

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

The normal runtime does not yet collect proposals or connect these evidence and
assessment calls automatically. An optional extension working in a test does not
establish that connection.

Existing relationships are documented in [COMPOSITION.md](COMPOSITION.md),
[CONTRACTS.md](CONTRACTS.md), [SCHEDULING.md](SCHEDULING.md) and
[DISPATCH.md](DISPATCH.md). Existing reasoner APIs and assessment semantics are
described in [README.md](README.md#nars--pln-proposal-integration).

## Implemented local adapter records

`reasoners/host_reasoner_contracts.metta` now defines pure MeTTa, opt-in representation
contracts using the existing factual, typed-policy and proposal-data helpers. They allocate no state, load no engine, register
no adapter and install no runtime hook. The coordinator and automatic runtime
sequence below remain proposed. Import `lib_import` before the contract module
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
admit a proposal against current host ownership and policy. Automatic intake
and retaining these records in the runtime remain separate coordinator work.

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
retains one adapter. No provider, automatic intake, grading or learning is enabled.
Automatic collection and feedback routing remain later runtime work.

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
automatic cycle intake, proposal selection and feedback remain coordinator work.
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

Resolve comparator registration from retained adapter metadata and its declared
prediction schema. The existing service has one global comparator setting;
extend its entry point with a trusted resolved comparator, or add a routing
adapter, while reusing its validation and commit logic. Do not swap the global
setting around individual calls. Retain the comparator/configuration version in
assessment provenance. A changed configuration does not regrade a completed
assessment; unsupported predictions can be retried because deferral reserves no
assessment identity.

The current `assessReasonerProposalOutcome` also updates application source
reliability. Therefore shadow evaluation must not call it as a supposedly pure
preview. Introduce a pure evaluation port reusing the comparison/validation
helpers, and retain the existing atomic assessment-and-learning path for enabled
updates. Validate finite grades and learner inputs before committing. Preserve
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
