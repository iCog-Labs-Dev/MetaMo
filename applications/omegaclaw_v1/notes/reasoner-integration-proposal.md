# Reasoner integration with ContextFrames and MetaMo

Date: 19 October 2026  
Status: Proposed integration design

The reasoner should produce evidence-backed recommendations and concrete task plans from admitted ContextFrames state. MetaMo should regulate mode, enforce feasibility, and surface motivational state. OmegaClaw-Core should retain authority over dispatch, external effects, and frame bookkeeping. This separation supports the reasoner proposal channel required by R3 while preserving the role boundaries in the integration specification.

The initial deliverable is one complete, bounded cycle: an admitted task produces a supported recommendation, an authorized operation executes, and its observed outcome is correlated with the original prediction. Connecting this cycle is separate from implementing a general planner or retiring the interim candidate scorer.

## Existing implementation

The application already contains the following components:

| Component | Existing responsibility | Integration work remaining |
| --- | --- | --- |
| `reasoner_integration.metta` | Bounded NARS and PLN inference; conversion of supported conclusions into proposals | Production fact extraction and invocation |
| `reasoner_proposals.metta` | Proposal validation, admission, scoring, audit records, and grading helpers | Collection in the live cycle, outcome correlation, and replay protection |
| `bridge.metta` | One frame snapshot through signal extraction, mode evaluation, candidate admission, scoring, and selection | Incorporation of reasoner proposals into the same admission path |
| `host_operations.py` and `dispatch.pl` | Trusted operation construction, capture, ownership checks, and dispatch integration | Validation and binding of reasoner-owned concrete plans |
| `operation_selection.metta` | Selected decisions and correlated execution outcomes | Retention of the originating proposal reference |

The production composition currently excludes the optional reasoner extension. Importing the extension alone would not connect inference, selection, execution, and grading. This proposal does not activate that extension or change the existing deferral of live reasoner integration.

## Ownership requirements

The following requirements describe the proposed integration:

1. **ContextFrames and Core shall own task state and effects.** Frame identities, revisions, commitments, execution results, and lifecycle mutations shall remain host-controlled.
2. **The reasoner shall own concrete planning.** It may propose operations, ordered dependencies, expected outcomes, and recovery alternatives. A proposal shall not constitute permission to execute.
3. **MetaMo shall retain its regulatory responsibilities.** These comprise regime selection, hard feasibility, homeostasis, fairness, and state surfacing. Concrete intra-frame planning shall not be added to MetaMo's motivational rules.
4. **The host shall validate executable bindings.** Proposed arguments shall be resolved through the supported operation catalog and configured policy before Core dispatch.
5. **Outcome-driven learning shall remain outside MetaMo's durable role.** Grading results may inform proposal influence during the interim phase, but learning and belief revision belong to the reasoner and its supporting machinery.

The candidate-scoring dispatcher may remain as the interim selector permitted by S3. Its eventual retirement requires demonstrated reasoner performance and the specification's migration criteria; adding proposals does not itself satisfy those criteria.

## Proposed runtime sequence

1. **Publish the authoritative snapshot.** Complete host bookkeeping and capture the bounded frame-state bundle used by the current cycle.
2. **Extract admitted facts.** Convert the authorized frame slice into typed facts with stable evidence references. Include relevant task requirements, dependencies, and observed outcomes. Exclude raw history and unadmitted frame data. Keep observations distinct from inference rules and derived claims.
3. **Run bounded inference.** Invoke one configured engine with explicit inference, time, and resource limits. Preserve evidence stamps and distinguish unsupported conclusions from engine failure.
4. **Validate and record proposals.** Check source, identity, target, candidate, supporting evidence, confidence, and prediction. Record admission or rejection without treating explanatory text as executable code.
5. **Arbitrate through the existing gates.** Combine supported proposals with native candidates before the shared pruning and arbitration stages. A proposal shall not acquire an execution path around ordinary policy checks. Define deterministic handling of ties and conflicting recommendations.
6. **Validate concrete work.** Resolve the selected recommendation's plan or arguments into supported host operations. Preserve the exact task, revision, evidence references, and originating proposal. Capture a fresh dispatch ticket before execution.
7. **Execute through Core.** Revalidate the applicable snapshot, ownership, route, and policy before invoking the exact selected operation.
8. **Observe and grade.** Correlate actual results with the proposal's prediction. Apply each accepted observation and grade at most once. Feed the resulting evidence back to the reasoning process.

Any state change during inference shall trigger rejection or explicit revalidation before the proposal becomes executable. Missing premises, unavailable engines, malformed output, and rejected proposals shall not generate substitute work implicitly. Native candidates may remain eligible only through their ordinary admission path.

## Proposal and outcome contracts

The existing motivational proposal carries an identifier, source, kind, target, candidate, claim, support, confidence, evidence references, and prediction. It can recommend an operation class; it does not provide a complete concrete planning interface.

The integration shall retain this correlation chain:

```text
proposal identity
  → session, frame, commitment and revision
  → admitted decision and concrete operation
  → dispatch ticket
  → observed outcome
  → prediction grade
```

Concrete plans require a separate validated host-facing contract. That contract should reuse existing continuation steps where applicable and carry bounded arguments, ordering, and dependencies. Neither model confidence nor inference truth shall waive permissions, outstanding requirements, or task-completion criteria.

Grading shall distinguish prediction accuracy, operation success, and task completion. A successful read establishes a read result; it does not establish that the user's task is complete. An unexecuted proposal shall not receive a fabricated execution grade. Rejected proposals should retain their rejection reason, with predictive claims graded only when suitable evidence becomes available. Uncertain effects shall remain uncertain.

Existing grading helpers require correlation and idempotency enforcement before automatic production use. Session-local replay protection should be established first; restart-safe grading additionally requires durable identity and outcome records.

## Implementation sequence

### First supported operation

Begin with one engine, one admitted task, and one authorized file-read operation. Extract the relevant facts, obtain a supported recommendation, admit and execute the exact read, and grade a prediction against the returned observation. The test must establish the full correlation chain without directly injecting a successful outcome.

### Bounded planning for increment 3

Extend the reasoner-owned planning interface to ordered reads of explicitly permitted files. Reuse host continuation records and outcome-driven advancement. Once all required reads succeed, use their actual contents in the existing answer preparation and delivery path. Completion must continue to satisfy the task's explicit requirements.

### Recovery and additional proposals

Add recovery and correction handling in increment 4. Introduce frame-switch and mode-change proposals only with supported host handlers, clear target semantics, and ownership checks. ContextFrames Fast/Slow requests and MetaMo constitutional modes are distinct concepts and shall not be treated as interchangeable.

### Broader integration

Connect and validate the second inference engine, then extend outcome learning, durable recovery, and reasoner influence. Preserve engine namespace isolation. Retire the interim selector only after the specification's acceptance conditions are demonstrated.

## Acceptance criteria

The first integration milestone is accepted when existing test infrastructure demonstrates:

- Supported inference reaches authorized dispatch and produces an observed result tied to its proposal.
- Missing premises and negative conclusions produce no unsupported recommendation.
- Denied operations remain denied regardless of proposal confidence or score.
- Changes to the task, revision, session, or relevant policy invalidate stale work.
- Engine failure and malformed proposals cause no fabricated progress or automatic unauthorized fallback.
- Conflicting proposals have deterministic arbitration and recorded dispositions.
- Replayed outcomes do not repeat execution, advance a continuation twice, or apply a grade twice.
- Observations from a predecessor cannot complete or influence its successor as though they belonged to that successor.
- Native operation behavior remains valid while the optional reasoner path is disabled.

Full Phase 5 acceptance additionally requires both engines to traverse inference, validation, dispatch, outcome grading, and influence update, including supported transition handlers. Offline acceptance and live-service validation shall be recorded separately.

## References

- [ContextFrames x MetaMo Integration Specification](../../../../ContextFrames_MetaMo_Integration_Spec_2026-07-22.md), particularly sections 4–7 and requirements R1–R4.
- [Integration plan](../omega_docs/INTEGRATION_PLAN.md), Phase 5 and functional increments 3–4.
- [Reasoner inference adapter](../reasoner_integration.metta).
- [Proposal admission and grading helpers](../reasoner_proposals.metta).
- [Production bridge](../bridge.metta).
- [Existing reasoner integration tests](../tests/reasoner_integration_test.metta).
