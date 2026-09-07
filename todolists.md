# ContextFrames × MetaMo Remaining Tasks

This checklist tracks the work remaining against the 22 July 2026 integration specification.

## Highest priority

- [x] Implement the finite mode regulator.
- [x] Add the constitutional mode set: `Engaged`, `Threat`, `Rumination`, and `Sleep` for the MVP.
  - [x] Add the preemption order: Threat-remediation > Recovery > Interactive > Orienting > Engaged > Rumination > Sleep.
  - [x] Consume existing signals rather than introducing a parallel salience substrate.
  - [x] Enforce mode monotonicity: modes may tighten gates but never relax the policy floor.
  - [x] Keep trigger thresholds registry-resident and mark them as seed values.
  - [x] Add transition tests for collisions, preemption, and default Engaged behavior.

- [x] Add the reasoner proposal channel (R3/S3 migration seam).
  - [x] Define a source-neutral typed `reasoner-motivational-proposal` boundary.
  - [x] Accept proposals derived by NARS/PLN inference, with LLM-supported reasoning treated as an optional proposal source.
  - [x] Keep reasoner proposals advisory: MetaMo validates and scores them, while ContextFrames or the scheduler performs approved state changes.
  - [x] Support proposals such as switching frame or entering Slow mode without obeying them automatically.
  - [x] Convert validated proposals into the existing typed candidate/action representation without exposing arbitrary executable commands.
  - [x] Score proposals with the same candidate-scoring path as other candidates.
  - [x] Record each accepted, rejected, deferred, or malformed proposal as a prediction or decision event.
  - [x] Record and grade the resulting outcome using observed execution and frame-state evidence.
  - [x] Increase or decrease proposal influence from graded performance and source reliability.
  - [x] Add an explicit NARS/PLN-to-proposal adapter for typed facts, inferred conclusions, support, confidence, and evidence references.
  - [x] Define the retirement criteria for the interim operation-class dispatcher.

### Interim operation-class dispatcher retirement criteria

The dispatcher may be retired only when every condition below is demonstrated
in the integration test suite and in one end-to-end OmegaClaw run:

- Every dispatcher operation class has a typed proposal representation and a
  scheduler-owned handler; no class depends on a free-form command string.
- NARS/PLN proposals can reach the same candidate/action conversion,
  feasibility gates, and scoring path as native candidates.
- Frame-switch and mode-change proposals are emitted as advisory directives;
  MetaMo or a reasoner cannot call a ContextFrames mutator directly.
- Accepted, rejected, deferred, and malformed proposals produce decision
  events, and post-execution outcomes are recorded with execution and
  frame-state evidence.
- Proposal source reliability and influence are updated from graded outcomes,
  with an auditable source/proposal identifier on every update.
- Safety-parity tests prove that proposal-originated actions cannot bypass
  frame, mode, budget, permission, skill, or egress constraints.
- The scheduler consumes proposal directives for a complete vertical slice,
  including transition proposals, and the dispatcher fallback remains unused
  for that slice.
- A rollback path exists for rejected or unavailable proposals, so retiring the
  dispatcher does not turn a missing reasoner proposal into an implicit action.

- [ ] Complete relation evidence lifecycle (R7).
  - [x] Route same-frame judgments to an explicit `verify-frame-state` operation or suspension state.
  - [x] Capture verification outcomes as confirmed or refuted evidence.
  - [ ] Write verification outcomes back to the originating relation.
  - [ ] Treat model-declared confidence as a prior after evidence exists.
  - [ ] Replace hard confidence bands with a continuous scheduling influence function.
  - [ ] Add tests for confirmed, refuted, and unresolved relation outcomes.

## Safety and policy

- [ ] Complete hard-feasibility pruning (R1).
  - [ ] Enforce frame constraints before scoring candidates.
  - [ ] Enforce skill restrictions before dispatch.
  - [ ] Enforce egress and permission restrictions before dispatch.
  - [ ] Verify that no safety rule exists only as an appraisal weight.
  - [ ] Add tests proving unsafe candidates are absent, rather than merely lower-scored.

- [ ] Audit commitment lifecycle behavior (R4).
  - [ ] Define explicit `completed`, `abandoned-with-reason`, and `superseded` events.
  - [ ] Ensure urgency decay/recharge cannot terminate a live commitment.
  - [ ] Ensure blocked frames are periodically resurfaced.
  - [ ] Ensure no frame is silently deleted or permanently descheduled.
  - [ ] Add lifecycle tests around decay, failure, blocking, and recovery.

## Signal, appraisal, and state model

- [ ] Purify signals (R2).
  - [ ] Represent signals as typed facts rather than evaluations with embedded intensity constants.
  - [ ] Attach provenance references to every signal.
  - [ ] Move all evaluative weights and intensity values into the appraisal registry.
  - [ ] Add provenance and weighting tests.

- [ ] Complete self-model fencing (R5).
  - [ ] Keep the MetaMo self-model limited to motivational and physiological quantities.
  - [ ] Define the adjudicated store interface for capability and knowledge claims.
  - [ ] Permit MetaMo to read those claims only through a typed boundary.
  - [ ] Prevent MetaMo from writing capability, knowledge, or belief claims.
  - [ ] Add schema and write-denial tests.

- [ ] Declare homeostasis completely (R6).
  - [ ] Enumerate every regulated variable in registry data.
  - [ ] Declare each variable’s set-point, bound, or recharge target.
  - [ ] Ensure `runHomeostasis` consumes the registry rather than hidden constants.
  - [ ] Add tests for every declared correction path.

- [ ] Convert persisted numeric state to integer scale (R8).
  - [ ] Choose and document a scale, such as `0–1000`.
  - [ ] Convert persisted goals, modulators, priorities, and confidence values.
  - [ ] Keep floating-point values limited to volatile calculations.
  - [ ] Add serialization and round-trip tests.

## Interim mechanisms and expiry tracking

- [ ] Mark S1 signal/appraisal constants explicitly as seed data.
  - [ ] Add seed metadata to registry entries.
  - [ ] Add outcome-grading hooks.
  - [ ] Define when boot values are replaced by learned values.

- [ ] Mark S2 model-declared relation confidence as interim.
  - [ ] Add expiry metadata and documentation.
  - [ ] Remove threshold-band behavior when R7 write-back is live.

- [ ] Mark S3 candidate scoring as interim.
  - [ ] Document the migration seam to reasoner proposals.
  - [ ] Track residual duties after concrete action selection moves to the reasoner.

- [ ] Document S4 floating-point scope.
  - [ ] Identify all persisted numeric fields.
  - [ ] Confirm that only volatile motivational calculations remain floating-point.

## Testing and verification

- [ ] Add complete mode-layer integration tests.
- [ ] Add reasoner-proposal acceptance, rejection, prediction, and grading tests.
  - [ ] Add NARS/PLN inference-to-proposal adapter tests.
  - [ ] Add tests proving proposals cannot bypass feasibility, budget, mode, permission, or frame constraints.
- [ ] Add relation verification write-back tests.
- [ ] Add safety-pruning tests for constraints, permissions, egress, and skills.
- [ ] Add commitment lifecycle and starvation-prevention tests.
- [ ] Add signal provenance and registry-weight tests.
- [ ] Add self-model schema-fence tests.
- [ ] Add integer persistence round-trip tests.
- [ ] Install or provide a test double for the optional ChromaDB relation composer.
- [ ] Run the full frame-ingestion path in CI, including user message ingestion and frame composition.
- [ ] Preserve the source guard proving MetaMo does not access `getHistory` or raw `&prevmsg` state.
- [ ] Add a full motivational-cycle test using only `FrameStateBundle` and typed runtime projections.

## Completion criteria

- [ ] MetaMo selects regime/mode and applies hard feasibility, but does not select concrete intra-frame actions.
- [ ] The reasoner proposal channel is active and outcome-graded.
- [ ] Relations remain advisory, and verification outcomes update relation evidence.
- [ ] All safety constraints prune candidates before scoring.
- [ ] Signals are typed and provenance-bearing.
- [ ] Persisted numeric state uses the declared integer scale.
- [ ] Live commitments cannot be silently terminated by motivational decay.
- [ ] The full motivational cycle works with raw history and raw `prevmsg` access removed from MetaMo modules.
