;; Source-neutral reasoning boundary for OmegaClaw/MetaMo.
;;
;; A reasoner may publish a proposal, but it may not publish an executable
;; command or mutate ContextFrames. MetaMo validates the proposal and applies
;; the ordinary candidate feasibility/scoring path before publishing a
;; ReasonerMotivationalDecision for the scheduler.
;;
;; Canonical shape:
;;
;; (ReasonerMotivationalProposal
;;    <id> <source> <kind> <target> <candidate> <claim> <support>
;;    <confidence> <evidence-refs> <prediction>)
;;
;; `candidate` is the only field that can enter MetaMo's scoring path. The
;; other fields are explanatory/provenance data or scheduler intents; they
;; never become commands inside MetaMo.

!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_proposal_helpers))

;; Eight tagged fields: outcome-id, proposal-event, execution-status,
;; execution-evidence, frame-evidence-status, frame-state-evidence, outcome, grade.
;; Each argument is an expression, including (grade Ungraded) or (grade NUMBER).
;; Value and causal validation remain at the existing recording boundary.
(: ReasonerProposalOutcomeEventType Type)
(: ReasonerProposalOutcomeEvent
   (-> Expression Expression Expression Expression
       Expression Expression Expression Expression ReasonerProposalOutcomeEventType))

;; Typed inference payloads accepted by the NARS/PLN adapters. These are
;; provenance records, not executable terms.
(: ReasonerInferenceFactType Type)
(: NARSFact (-> Expression Expression Expression ReasonerInferenceFactType))
(: PLNFact (-> Expression Expression Expression ReasonerInferenceFactType))
(: InferredConclusion (-> Symbol Expression ReasonerInferenceFactType))
(: InferenceSupport (-> Symbol Expression Expression ReasonerInferenceFactType))
(: EvidenceReferences (-> Expression ReasonerInferenceFactType))

;; Append-only local audit substrate. The scheduler/ContextFrames integration
;; may additionally persist these records in its durable event log.
!(bind! &reasoner-proposal-events (new-space))
!(bind! &reasoner-proposal-outcomes (new-space))
!(bind! &reasoner-source-reliability (new-space))
;; Retained origin data is advisory provenance, never dispatch authority.
!(bind! &reasoner-proposal-origins (new-space))
;; A trusted optional host adapter installs evidence validation explicitly.
!(bind! &reasoner-evidence-validator (new-state ()))
!(bind! &reasoner-outcome-identity-provider (new-state ()))
!(bind! &reasoner-prediction-observer (new-state ()))

;; ---------------------------------------------------------------------------
;; Inference adapters
;; ---------------------------------------------------------------------------
;; NARS and PLN are first-class inference sources. Their engines only need to
;; provide typed facts, an inferred conclusion, typed support, normalized
;; confidence, evidence references, the registered candidate they recommend,
;; and an expected outcome. The adapter adds provenance without exposing
;; engine-specific execution terms to MetaMo.

;; Wrap NARS output as data, accepting raw or already wrapped evidence references.
;; Example: (narsFactsToProposal p () claim support 0.9 (quote (e1)) respond prediction).
(= (narsFactsToProposal
      $id $facts $conclusion $support $confidence $evidence
      $candidate $prediction)
   (ReasonerMotivationalProposal
      $id nars propose-candidate current-frame $candidate
      (InferredConclusion nars $conclusion)
      (InferenceSupport nars $facts $support)
      $confidence
      (reasonerProposalEvidenceRecord $evidence)
      $prediction))

;; Wrap PLN output without resolving its supporting observations.
;; Example: (plnFactsToProposal p () claim support 0.9 (quote (e1)) respond prediction).
(= (plnFactsToProposal
      $id $facts $conclusion $support $confidence $evidence
      $candidate $prediction)
   (ReasonerMotivationalProposal
      $id pln propose-candidate current-frame $candidate
      (InferredConclusion pln $conclusion)
      (InferenceSupport pln $facts $support)
      $confidence
      (reasonerProposalEvidenceRecord $evidence)
      $prediction))

(= (narsInferenceToProposal
      $id $conclusion $confidence $evidence $candidate $prediction)
   (narsFactsToProposal
      $id () $conclusion (NARSSupport $conclusion) $confidence $evidence
      $candidate $prediction))

(= (plnInferenceToProposal
      $id $conclusion $confidence $evidence $candidate $prediction)
   (plnFactsToProposal
      $id () $conclusion (PLNSupport $conclusion) $confidence $evidence
      $candidate $prediction))

;; LLM reasoning is deliberately an optional adapter. If it is not wired by
;; the host, no proposals are produced; if wired, its output is still subject
;; to the identical source, schema, candidate, and feasibility checks.
;; Example: (llmReasoningToProposal p claim 0.8 () respond prediction).
(= (llmReasoningToProposal
      $id $claim $confidence $evidence $candidate $prediction)
   (ReasonerMotivationalProposal
      $id llm propose-candidate current-frame $candidate
      (LLMClaim $claim) (LLMSupport $claim)
      $confidence (reasonerProposalEvidenceRecord $evidence) $prediction))

;; Build an advisory frame request while preserving the native target type.
;; Example: (requestFrameSwitchProposal p Frame-A 0.9 (quote (e1)) prediction).
(= (requestFrameSwitchProposal
      $id $frame-id $confidence $evidence $prediction)
   (ReasonerMotivationalProposal
      $id nars request-frame-switch (FrameTarget $frame-id) defer
      (SwitchFrameClaim $frame-id) (SwitchFrameSupport $frame-id)
      $confidence (reasonerProposalEvidenceRecord $evidence) $prediction))

;; Build a Slow-mode request with canonical evidence data, without changing mode.
;; Example: (requestSlowModeProposal p 0.9 (quote (e1)) prediction).
(= (requestSlowModeProposal
      $id $confidence $evidence $prediction)
   (ReasonerMotivationalProposal
      $id pln request-mode-change (ModeTarget Slow) defer
      request-slow-mode (ModeChangeSupport Slow)
      $confidence (reasonerProposalEvidenceRecord $evidence) $prediction))

(= (legacyReasonerProposalGate $bundle $proposal)
   ;; Legacy inference smoke tests can appraise current-frame suggestions only.
   ;; Attention, cross-frame work and transitions require concrete host context.
   (if (!= (getProposalKind $proposal) propose-candidate)
       (GateDecision Rejected MissingOperationContext)
       (if (!= (requestFrameReason $bundle $bundle (getProposalTarget $proposal)) Feasible)
           (GateDecision Rejected MissingOperationContext)
           (feasibilityGate $bundle (getProposalCandidate $proposal)))))

(= (reasonerProposalAdmission $bundle $proposal)
   (if (not (reasonerProposalValid $proposal))
       (ReasonerMotivationalDecision Malformed InvalidProposal $proposal none 0.0)
       (let* (
          ($candidate (getProposalCandidate $proposal))
          ((GateDecision $admission $reason) (legacyReasonerProposalGate $bundle $proposal)))
          (if (== $admission Admitted)
              (ReasonerMotivationalDecision Accepted Feasible $proposal $candidate 0.0)
              (ReasonerMotivationalDecision Rejected $reason $proposal $candidate 0.0)))))

;; The concrete path validates the request kind/target, not merely its candidate.
;; A transition cannot gain admission through the legacy defer candidate gate.
(= (reasonerProposalAdmissionForOperation $origin $target $proposal $operation $global $frame)
   (if (not (reasonerProposalValid $proposal))
       (ReasonerMotivationalDecision Malformed InvalidProposal $proposal none 0.0)
       (let* (
          ($candidate (getProposalCandidate $proposal))
          ((GateDecision $admission $reason)
             (feasibilityGateForRequest $origin $target
                (AdmissionRequest (getProposalKind $proposal)
                   (getProposalTarget $proposal) $candidate)
                $operation $global $frame)))
          (ReasonerMotivationalDecision
             (if (== $admission Admitted) Accepted Rejected)
             $reason $proposal $candidate 0.0))))

(= (reasonerProposalToActionForOperation $origin $target $proposal $operation $global $frame)
   (let* (
      ($decision (reasonerProposalAdmissionForOperation $origin $target $proposal $operation $global $frame))
      ($status (getStatus $decision))
      ($candidate (getCandidate $decision)))
      (if (== $status Accepted)
          (ReasonerProposalActionResult Accepted Feasible $candidate (candidateToAction $candidate))
          (ReasonerProposalActionResult $status (getReason $decision) none (action none () 0.0 ())))))

(= (reasonerProposalScoreForOperation $origin $target $state $proposal $operation $global $frame)
   (let $conversion
           (reasonerProposalToActionForOperation $origin $target $proposal $operation $global $frame)
      (if (== (getStatus $conversion) Accepted)
          (omegaclawScoreForBundle $target $state (getAction $conversion))
          0.0)))

;; Convert only an admitted, registered candidate into MetaMo's existing
;; typed `action` representation. The proposal's claim, support, evidence,
;; target, and prediction are never interpreted as executable instructions.
;; A rejected/malformed proposal produces a typed no-op action.
(= (reasonerProposalToAction $bundle $proposal)
   (let* (
      ($admission (reasonerProposalAdmission $bundle $proposal))
      ($status (getStatus $admission))
      ($reason (getReason $admission))
      ($candidate (getCandidate $admission)))
      (if (== $status Accepted)
          (ReasonerProposalActionResult Accepted Feasible $candidate
             (candidateToAction $candidate))
          (ReasonerProposalActionResult $status $reason none
             (action none () 0.0 ())))))

;; Proposal scoring deliberately delegates to the same bundle-aware scorer used
;; by ordinary candidates. No separate reasoner-specific weighting path is
;; applied here; provenance and confidence remain proposal metadata.
(= (reasonerProposalScore $bundle $state $proposal)
   (let* (
      ($conversion (reasonerProposalToAction $bundle $proposal))
      ($status (getStatus $conversion))
      ($action (getAction $conversion)))
      (if (== $status Accepted)
          (omegaclawScoreForBundle $bundle $state $action)
          0.0)))

;; Reliability priors are deliberately conservative and source-specific. They
;; are not MetaMo candidate scores; they only influence how much a proposal
;; source's recommendation affects the final proposal score.
(= (reasonerSourceReliabilityPrior $value)
   (case $value ((nars 0.80)
      (pln 0.80)
      (llm 0.50)
      (rule-engine 0.75)
      (human-adapter 0.70)
      ($_ 0.0))))

(= (reasonerSourceReliability $source)
   (let $rows (collapse (match &reasoner-source-reliability
      (ReasonerSourceReliability $source $value)
      (ReasonerSourceReliability $source $value)))
      (if (== $rows ())
          (reasonerSourceReliabilityPrior $source)
          (index-atom (car-atom $rows) 2))))

;; Influence is bounded by both source reliability and the proposal's own
;; confidence. It never bypasses feasibility and never creates an action.
(= (reasonerProposalInfluence $proposal)
   (let* (
      ($source (getProposalSource $proposal))
      ($confidence (getProposalConfidence $proposal)))
      (clampValue (* $confidence (reasonerSourceReliability $source)))))

;; Malformed values must not reach influence arithmetic or the native scorer.
;; Example: an invalid confidence returns 0.0 even with an unusable scoring state.
(= (reasonerProposalEffectiveScore $bundle $state $proposal)
    (if (reasonerProposalValid $proposal)
        (* (reasonerProposalScore $bundle $state $proposal)
            (reasonerProposalInfluence $proposal))
        0.0
    )
)

;; A transition proposal can be valid, feasible, and scored while still being
;; deferred until the scheduler performs its own authorization/availability
;; check. This is distinct from rejection and malformed input.
(= (reasonerProposalDisposition $proposal $status)
   (if (== $status Accepted)
       (let $kind (getProposalKind $proposal)
          (if (or (== $kind request-frame-switch)
                  (== $kind request-mode-change)) Deferred Accepted))
       $status))

;; Compatibility entry point captures the currently published bundle explicitly.
;; Example: trusted callers can retain an event without invoking a handler.
(= (recordReasonerProposalEvent $proposal $decision)
    (recordReasonerProposalEvent $proposal $decision (activeFrameBundle))
)

;; Retain the exact cycle, supplied snapshot and host owner beside the audit event.
;; Example: a later host selection must match this origin before linking a ticket.
(= (recordReasonerProposalEvent $proposal $decision $bundle)
   (let* (
      ($status (getStatus $decision))
      ($disposition (reasonerProposalDisposition $proposal $status))
      ($event (ReasonerProposalEvent
         (proposal $proposal)
         (decision $decision)
         (disposition $disposition)))
      ($origin (ReasonerProposalOrigin $event (get-state &operation-context)
          $bundle (commitmentSnapshot)))
      ($_ (add-atom &reasoner-proposal-events $event))
      ($_ (add-atom &reasoner-proposal-origins $origin)))
      $event))

;; Read retained origin data without recapturing or relabelling a proposal.
;; Example: (reasonerProposalOrigins) returns session-local publication records.
(= (reasonerProposalOrigins)
    (collapse (match &reasoner-proposal-origins
        (ReasonerProposalOrigin $event $context $bundle $owner)
        (ReasonerProposalOrigin $event $context $bundle $owner)))
)

(= (reasonerProposalEvents)
   (collapse (match &reasoner-proposal-events
      (ReasonerProposalEvent
         (proposal $proposal) (decision $decision) (disposition $disposition))
      (ReasonerProposalEvent
         (proposal $proposal) (decision $decision) (disposition $disposition)))))

;; ---------------------------------------------------------------------------
;; Outcome grading
;; ---------------------------------------------------------------------------
;; Outcome evidence is supplied after the scheduler/ContextFrames layer has
;; observed execution. MetaMo never infers execution from the proposal itself.
;;
;; Execution status: Completed | Failed | Blocked | Unobserved
;; Frame evidence:   Confirmed | Refuted | Unresolved

;; Compatibility readers report uncertainty; motivational code never grades.
;; Example: (reasonerProposalOutcomeGrade Completed Confirmed) -> Ungraded.
(= (reasonerProposalOutcomeGrade $execution $verification) Ungraded)

;; Execution status cannot classify the correctness of a retained prediction.
;; Example: (reasonerProposalOutcomeClass Failed Refuted) -> Unresolved.
(= (reasonerProposalOutcomeClass $execution $verification) Unresolved)

;; Invoke only a trusted installed reader, passing every input as quoted data.
;; Example: absent host wiring returns (ReasonerOutcomeRejected MissingHostEvidence).
(= (reasonerOutcomeEvidenceCheck $event $status $execution $frame-status $frame-evidence)
    (if (is-ground ($event $status $execution $frame-status $frame-evidence))
        (case (get-state &reasoner-evidence-validator)
            (
                (() (ReasonerOutcomeRejected MissingHostEvidence))
                ($validator
                    (eval ($validator (quote $event) (quote $status) (quote $execution)
                        (quote $frame-status) (quote $frame-evidence))))
            )
        )
        (ReasonerOutcomeRejected MalformedEvidence)
    )
)

;; Resolve a stable host identity without allocating one from model-supplied text.
;; Example: absent host wiring returns (ReasonerOutcomeRejected MissingHostEvidence).
(= (reasonerOutcomeIdentityCheck $event $execution)
    (case (get-state &reasoner-outcome-identity-provider)
        (
            (() (ReasonerOutcomeRejected MissingHostEvidence))
            ($provider (eval ($provider (quote $event) (quote $execution))))
        )
    )
)

;; Read the exact submitted report as data, excluding the derived grade/class.
;; Example: report equality distinguishes a redelivery from changed evidence.
(= (reasonerOutcomeReport $record)
    (case $record
        (
            ((ReasonerProposalOutcomeEvent (outcome-id $id) (proposal-event $event)
                (execution-status $status) (execution-evidence $execution)
                (frame-evidence-status $frame-status) (frame-state-evidence $frame-evidence)
                (outcome $outcome) (grade $grade))
                (quote (ReasonerOutcomeReport $event $status $execution $frame-status $frame-evidence)))
            ($_ (ReasonerOutcomeRejected MalformedOutcome))
        )
    )
)

;; Exact ID lookup uses the retained outcome itself as the replay record.
;; Example: a new execution identity has no matching outcome rows.
(= (reasonerOutcomesForId $id)
    (collapse (match &reasoner-proposal-outcomes
        (ReasonerProposalOutcomeEvent (outcome-id $id) (proposal-event $event)
            (execution-status $status) (execution-evidence $execution)
            (frame-evidence-status $frame-status) (frame-state-evidence $frame-evidence)
            (outcome $outcome) (grade $grade))
        (ReasonerProposalOutcomeEvent (outcome-id $id) (proposal-event $event)
            (execution-status $status) (execution-evidence $execution)
            (frame-evidence-status $frame-status) (frame-state-evidence $frame-evidence)
            (outcome $outcome) (grade $grade))))
)

;; Roll back a failed receipt write; do not memoize a failed commit.
;; Example: a failed audit insertion yields OutcomeCommitFailed with no outcome.
(= (commitReasonerOutcome $id $event $status $execution $frame-status $frame-evidence)
    (case (catch (transaction (recordValidatedReasonerProposalOutcome $id $event $status
            $execution $frame-status $frame-evidence)))
        (
            ((Error $reason $context) (ReasonerOutcomeRejected OutcomeCommitFailed))
            ((Error $reason) (ReasonerOutcomeRejected OutcomeCommitFailed))
            ($record $record)
        )
    )
)

;; Validate new evidence before atomically storing the ungraded receipt.
;; Example: failure during the write leaves no retained outcome.
(= (recordFreshReasonerOutcome $id $event $status $execution $frame-status $frame-evidence)
    (case (reasonerOutcomeEvidenceCheck $event $status $execution $frame-status $frame-evidence)
        (
            (ReasonerExecutionEvidenceValid
                (commitReasonerOutcome $id $event $status $execution $frame-status $frame-evidence))
            ((ReasonerOutcomeRejected $reason) (ReasonerOutcomeRejected $reason))
            ($_ (ReasonerOutcomeRejected InvalidHostEvidence))
        )
    )
)

;; Preserve the original record on redelivery; changed contents never overwrite it.
;; Example: the same identity with a changed execution status returns ConflictingReplay.
(= (recordReasonerOutcomeById $id $event $status $execution $frame-status $frame-evidence)
    (case (reasonerOutcomesForId $id)
        (
            (() (recordFreshReasonerOutcome $id $event $status $execution $frame-status $frame-evidence))
            (($existing)
                (if (== (reasonerOutcomeReport $existing)
                        (quote (ReasonerOutcomeReport $event $status $execution $frame-status $frame-evidence)))
                    $existing
                    (ReasonerOutcomeRejected ConflictingReplay)
                )
            )
            ($_ (ReasonerOutcomeRejected ConflictingReplay))
        )
    )
)

;; Serialize lookup and commit with the host; data is never interpreted as code.
;; Example: an identical valid redelivery returns its original outcome unchanged.
(= (recordReasonerOutcomeOnce $event $status $execution $frame-status $frame-evidence)
    (with_mutex omegaclaw_dispatch
        (case (reasonerOutcomeIdentityCheck $event $execution)
            (
                ((ReasonerOutcomeIdentity $id)
                    (recordReasonerOutcomeById $id $event $status $execution $frame-status $frame-evidence))
                ((ReasonerOutcomeRejected $reason) (ReasonerOutcomeRejected $reason))
                ($_ (ReasonerOutcomeRejected InvalidHostEvidence))
            )
        )
    )
)

;; Execution-backed grades require host identity and observed causal evidence.
;; Example: non-ground or caller-invented evidence cannot allocate an outcome.
(= (recordReasonerProposalOutcome
      $proposal-event $execution-status $execution-evidence
      $frame-evidence-status $frame-state-evidence)
    (if (is-ground ($proposal-event $execution-status $execution-evidence
            $frame-evidence-status $frame-state-evidence))
        (recordReasonerOutcomeOnce $proposal-event $execution-status $execution-evidence
            $frame-evidence-status $frame-state-evidence)
        (ReasonerOutcomeRejected MalformedEvidence)
    )
)

;; Internal writer used only after the host evidence check; it executes no data.
;; Example: a validated read result can be recorded with frame status Unresolved.
(= (recordValidatedReasonerProposalOutcome
      $id $proposal-event $execution-status $execution-evidence
      $frame-evidence-status $frame-state-evidence)
   (let* (
      ($event (ReasonerProposalOutcomeEvent
         (outcome-id $id)
         (proposal-event $proposal-event)
         (execution-status $execution-status)
         (execution-evidence $execution-evidence)
         (frame-evidence-status $frame-evidence-status)
         (frame-state-evidence $frame-state-evidence)
         (outcome Unresolved)
         (grade Ungraded)))
      ($_ (add-atom &reasoner-proposal-outcomes $event)))
      $event))

(= (reasonerProposalOutcomes)
   (collapse (match &reasoner-proposal-outcomes
      (ReasonerProposalOutcomeEvent
         (outcome-id $id)
         (proposal-event $proposal-event)
         (execution-status $execution-status)
         (execution-evidence $execution-evidence)
         (frame-evidence-status $frame-evidence-status)
         (frame-state-evidence $frame-state-evidence)
         (outcome $outcome) (grade $grade))
      (ReasonerProposalOutcomeEvent
         (outcome-id $id)
         (proposal-event $proposal-event)
         (execution-status $execution-status)
         (execution-evidence $execution-evidence)
         (frame-evidence-status $frame-evidence-status)
         (frame-state-evidence $frame-state-evidence)
         (outcome $outcome) (grade $grade)))))

;; Score an accepted proposal as the corresponding registered MetaMo action.
;; This is the only proposal-to-action conversion performed by MetaMo; the
;; returned action is data for the scheduler and is never executed here.
(= (reasonerProposalDecision $bundle $state $proposal)
   (let* (
      ($conversion (reasonerProposalToAction $bundle $proposal))
      ($status (getStatus $conversion))
      ($reason (getReason $conversion))
      ($candidate (getCandidate $conversion))
      ($action (getAction $conversion))
      ($decision
         (if (== $status Accepted)
             (ReasonerMotivationalDecision Accepted Feasible $proposal $candidate
                (reasonerProposalEffectiveScore $bundle $state $proposal))
             (ReasonerMotivationalDecision $status $reason $proposal none 0.0)))
      ($_ (recordReasonerProposalEvent $proposal $decision $bundle)))
      $decision))

;; The proposal remains available to the scheduler as data. Only the approved
;; candidate is converted to the existing directive path by the caller.
(= (reasonerProposalToDirective $bundle $proposal $score)
   (let (ReasonerMotivationalDecision $status $reason $_proposal $candidate $_score)
          (reasonerProposalAdmission $bundle $proposal)
      (if (== $status Accepted)
          (attentionDirectiveForDecision $bundle $candidate $score)
          (AttentionDirective
             (target (frameBundleCurrentId $bundle))
             (slice None)
             (task none)
             (admission Rejected)
             (reason $reason)
             (priority 0)
             (source MetaMo)))))

;; Scheduler-facing result. `operation` and `target` are explicit advisory
;; fields, so a scheduler can require its own authorization/availability check
;; before applying a frame switch or mode change. This function does not call
;; switch-frame, switch-mode, change-state!, or any other mutator.
(= (reasonerProposalToSchedulerDirective $bundle $state $proposal)
   (let* (
      ($decision (reasonerProposalDecision $bundle $state $proposal))
      ($status (getStatus $decision))
      ($reason (getReason $decision))
      ($candidate (getCandidate $decision))
      ($score (getScore $decision))
      ($kind (getProposalKind $proposal))
      ($target (getProposalTarget $proposal)))
      (ReasonerMotivationalDirective
         (proposal $proposal)
         (status $status)
         (reason $reason)
         (operation $kind)
         (target $target)
         (candidate $candidate)
         (score $score)
         (source MetaMo))))
