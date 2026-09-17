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

(: ReasonerMotivationalProposalType Type)
(: ReasonerMotivationalProposal
   (-> Symbol Symbol Symbol Expression Symbol Expression Expression
       Number Expression Expression ReasonerMotivationalProposalType))

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

(= (reasonerProposalSources) (nars pln llm rule-engine human-adapter))
(= (reasonerInferenceSources) (nars pln))
(= (reasonerOptionalProposalSources) (llm))
(= (reasonerProposalKinds)
   (propose-candidate request-frame-switch request-mode-change request-attention))

(= (reasonerProposalSourceValid $value)
   (case $value ((nars True)
      (pln True)
      (llm True)
      (rule-engine True)
      (human-adapter True)
      ($_ False))))

(= (reasonerProposalKindValid $value)
   (case $value ((propose-candidate True)
      (request-frame-switch True)
      (request-mode-change True)
      (request-attention True)
      ($_ False))))

(= (reasonerProposalConfidenceValid $confidence)
   (and (>= $confidence 0.0) (<= $confidence 1.0)))

;; Candidate names are registry-owned. This prevents a reasoner from smuggling
;; an arbitrary executable operation through the proposal boundary.
(= (reasonerProposalCandidateValid $value)
   (case $value ((respond True)
      (retrieve-memory True)
      (search-knowledge True)
      (execute-skill True)
      (learn True)
      (self-improve True)
      (background-work True)
      (recall-goals True)
      (invent-goal True)
      (plan-goal True)
      (repair-failure True)
      (defer True)
      (verify-frame-state True)
      (ask-clarification True)
      ($_ False))))

(= (reasonerProposalIdValid $id)
   (not (== $id ())))

;; A proposal may ask the scheduler to consider a frame/mode transition. The
;; target is deliberately data-shaped and is never passed to a ContextFrames
;; mutation function by MetaMo.
(= (reasonerProposalTargetValid $kind $target)
   (case $kind (
      (propose-candidate (not (== $target ())))
      (request-attention (not (== $target ())))
      (request-frame-switch (case $target (
         ((FrameTarget $frame) (not (== $frame ()))) ($_ False))))
      (request-mode-change (case $target (
         ((ModeTarget Fast) True) ((ModeTarget Slow) True) ($_ False))))
      ($_ False))))

;; ---------------------------------------------------------------------------
;; Inference adapters
;; ---------------------------------------------------------------------------
;; NARS and PLN are first-class inference sources. Their engines only need to
;; provide typed facts, an inferred conclusion, typed support, normalized
;; confidence, evidence references, the registered candidate they recommend,
;; and an expected outcome. The adapter adds provenance without exposing
;; engine-specific execution terms to MetaMo.

(= (narsFactsToProposal
      $id $facts $conclusion $support $confidence $evidence
      $candidate $prediction)
   (ReasonerMotivationalProposal
      $id nars propose-candidate current-frame $candidate
      (InferredConclusion nars $conclusion)
      (InferenceSupport nars $facts $support)
      $confidence
      (EvidenceReferences $evidence)
      $prediction))

(= (plnFactsToProposal
      $id $facts $conclusion $support $confidence $evidence
      $candidate $prediction)
   (ReasonerMotivationalProposal
      $id pln propose-candidate current-frame $candidate
      (InferredConclusion pln $conclusion)
      (InferenceSupport pln $facts $support)
      $confidence
      (EvidenceReferences $evidence)
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
(= (llmReasoningToProposal
      $id $claim $confidence $evidence $candidate $prediction)
   (ReasonerMotivationalProposal
      $id llm propose-candidate current-frame $candidate
      (LLMClaim $claim) (LLMSupport $claim)
      $confidence $evidence $prediction))

(= (requestFrameSwitchProposal
      $id $frame-id $confidence $evidence $prediction)
   (ReasonerMotivationalProposal
      $id nars request-frame-switch (FrameTarget $frame-id) defer
      (SwitchFrameClaim $frame-id) (SwitchFrameSupport $frame-id)
      $confidence $evidence $prediction))

(= (requestSlowModeProposal
      $id $confidence $evidence $prediction)
   (ReasonerMotivationalProposal
      $id pln request-mode-change (ModeTarget Slow) defer
      request-slow-mode (ModeChangeSupport Slow)
      $confidence $evidence $prediction))

(= (reasonerProposalValid $proposal)
   (case $proposal (
      ((ReasonerMotivationalProposal $id $source $kind $target $candidate
         $claim $support $confidence $evidence $prediction)
       (and (reasonerProposalIdValid $id)
         (and (reasonerProposalSourceValid $source)
           (and (reasonerProposalKindValid $kind)
             (and (reasonerProposalTargetValid $kind $target)
               (and (reasonerProposalCandidateValid $candidate)
                 (and (reasonerProposalConfidenceValid $confidence)
                   (and (not (== $claim ()))
                        (not (== $prediction ()))))))))))
      ($_ False))))

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

;; The learned reliability uses a 20% update step so one noisy outcome cannot
;; dominate the source prior. Grades come only from observed outcomes.
(= (reasonerSourceReliabilityAfterGrade $source $grade)
   (clampValue (+ (* 0.80 (reasonerSourceReliability $source))
                  (* 0.20 $grade))))

(= (updateReasonerSourceReliability $source $grade)
   (let* (
      ($oldRows (collapse (match &reasoner-source-reliability
         (ReasonerSourceReliability $source $old)
         (ReasonerSourceReliability $source $old))))
      ($new (reasonerSourceReliabilityAfterGrade $source $grade))
      ($_ (if (== $oldRows ())
              True
              (let $oldRow (car-atom $oldRows)
                 (remove-atom &reasoner-source-reliability $oldRow))))
      ($_ (add-atom &reasoner-source-reliability
             (ReasonerSourceReliability $source $new))))
      $new))

;; Influence is bounded by both source reliability and the proposal's own
;; confidence. It never bypasses feasibility and never creates an action.
(= (reasonerProposalInfluence $proposal)
   (let* (
      ($source (getProposalSource $proposal))
      ($confidence (getProposalConfidence $proposal)))
      (clampValue (* $confidence (reasonerSourceReliability $source)))))

(= (reasonerProposalEffectiveScore $bundle $state $proposal)
   (* (reasonerProposalScore $bundle $state $proposal)
      (reasonerProposalInfluence $proposal)))

;; A transition proposal can be valid, feasible, and scored while still being
;; deferred until the scheduler performs its own authorization/availability
;; check. This is distinct from rejection and malformed input.
(= (reasonerProposalDisposition $proposal $status)
   (if (== $status Accepted)
       (let $kind (getProposalKind $proposal)
          (if (or (== $kind request-frame-switch)
                  (== $kind request-mode-change)) Deferred Accepted))
       $status))

(= (recordReasonerProposalEvent $proposal $decision)
   (let* (
      ($status (getStatus $decision))
      ($disposition (reasonerProposalDisposition $proposal $status))
      ($event (ReasonerProposalEvent
         (proposal $proposal)
         (decision $decision)
         (disposition $disposition)))
      ($_ (add-atom &reasoner-proposal-events $event)))
      $event))

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

(= (reasonerProposalOutcomeGrade Completed Confirmed) 1.0)
(= (reasonerProposalOutcomeGrade Completed Unresolved) 0.75)
(= (reasonerProposalOutcomeGrade Completed Refuted) 0.0)
(= (reasonerProposalOutcomeGrade Failed Confirmed) 0.25)
(= (reasonerProposalOutcomeGrade Failed Unresolved) 0.0)
(= (reasonerProposalOutcomeGrade Failed Refuted) 0.0)
(= (reasonerProposalOutcomeGrade Blocked Confirmed) 0.25)
(= (reasonerProposalOutcomeGrade Blocked Unresolved) 0.25)
(= (reasonerProposalOutcomeGrade Blocked Refuted) 0.0)
(= (reasonerProposalOutcomeGrade Unobserved Confirmed) 0.5)
(= (reasonerProposalOutcomeGrade Unobserved Unresolved) 0.5)
(= (reasonerProposalOutcomeGrade Unobserved Refuted) 0.0)

(= (reasonerProposalOutcomeClass Completed Confirmed) Confirmed)
(= (reasonerProposalOutcomeClass Completed Unresolved) Unresolved)
(= (reasonerProposalOutcomeClass Completed Refuted) Refuted)
(= (reasonerProposalOutcomeClass Failed $_) Refuted)
(= (reasonerProposalOutcomeClass Blocked $_) Unresolved)
(= (reasonerProposalOutcomeClass Unobserved $_) Unresolved)

;; `execution-evidence` and `frame-state-evidence` are bounded observations
;; supplied by the host. They are retained verbatim for audit/grading and are
;; not treated as executable instructions.
(= (recordReasonerProposalOutcome
      $proposal-event $execution-status $execution-evidence
      $frame-evidence-status $frame-state-evidence)
   (let* (
      ($grade (reasonerProposalOutcomeGrade
         $execution-status $frame-evidence-status))
      ($outcome (reasonerProposalOutcomeClass
         $execution-status $frame-evidence-status))
      ($event (ReasonerProposalOutcomeEvent
         (proposal-event $proposal-event)
         (execution-status $execution-status)
         (execution-evidence $execution-evidence)
         (frame-evidence-status $frame-evidence-status)
         (frame-state-evidence $frame-state-evidence)
         (outcome $outcome)
         (grade $grade)))
      ($_ (add-atom &reasoner-proposal-outcomes $event))
      ($proposal (getProposalEventProposal $proposal-event))
      ($source (getProposalSource $proposal))
      ($_ (updateReasonerSourceReliability $source $grade)))
      $event))

(= (reasonerProposalOutcomes)
   (collapse (match &reasoner-proposal-outcomes
      (ReasonerProposalOutcomeEvent
         (proposal-event $proposal-event)
         (execution-status $execution-status)
         (execution-evidence $execution-evidence)
         (frame-evidence-status $frame-evidence-status)
         (frame-state-evidence $frame-state-evidence)
         (outcome $outcome) (grade $grade))
      (ReasonerProposalOutcomeEvent
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
      ($_ (recordReasonerProposalEvent $proposal $decision)))
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
