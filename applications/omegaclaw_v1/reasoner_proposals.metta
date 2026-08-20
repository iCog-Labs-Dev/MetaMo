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

(: ReasonerMotivationalProposalType Type)
(: ReasonerMotivationalProposal
   (-> Symbol Symbol Symbol Expression Symbol Expression Expression
       Number Expression Expression ReasonerMotivationalProposalType))

(= (reasonerProposalSources) (nars pln llm rule-engine human-adapter))
(= (reasonerInferenceSources) (nars pln))
(= (reasonerOptionalProposalSources) (llm))
(= (reasonerProposalKinds)
   (propose-candidate request-frame-switch request-mode-change request-attention))

(= (reasonerProposalSourceValid nars) True)
(= (reasonerProposalSourceValid pln) True)
(= (reasonerProposalSourceValid llm) True)
(= (reasonerProposalSourceValid rule-engine) True)
(= (reasonerProposalSourceValid human-adapter) True)
(= (reasonerProposalSourceValid $_) False)

(= (reasonerProposalKindValid propose-candidate) True)
(= (reasonerProposalKindValid request-frame-switch) True)
(= (reasonerProposalKindValid request-mode-change) True)
(= (reasonerProposalKindValid request-attention) True)
(= (reasonerProposalKindValid $_) False)

(= (reasonerProposalConfidenceValid $confidence)
   (and (>= $confidence 0.0) (<= $confidence 1.0)))

;; Candidate names are registry-owned. This prevents a reasoner from smuggling
;; an arbitrary executable operation through the proposal boundary.
(= (reasonerProposalCandidateValid respond) True)
(= (reasonerProposalCandidateValid retrieve-memory) True)
(= (reasonerProposalCandidateValid search-knowledge) True)
(= (reasonerProposalCandidateValid execute-skill) True)
(= (reasonerProposalCandidateValid learn) True)
(= (reasonerProposalCandidateValid self-improve) True)
(= (reasonerProposalCandidateValid background-work) True)
(= (reasonerProposalCandidateValid recall-goals) True)
(= (reasonerProposalCandidateValid invent-goal) True)
(= (reasonerProposalCandidateValid plan-goal) True)
(= (reasonerProposalCandidateValid repair-failure) True)
(= (reasonerProposalCandidateValid defer) True)
(= (reasonerProposalCandidateValid ask-clarification) True)
(= (reasonerProposalCandidateValid $_) False)

(= (reasonerProposalIdValid $id)
   (not (== $id ())))

;; A proposal may ask the scheduler to consider a frame/mode transition. The
;; target is deliberately data-shaped and is never passed to a ContextFrames
;; mutation function by MetaMo.
(= (reasonerProposalTargetValid propose-candidate $target)
   (not (== $target ())))
(= (reasonerProposalTargetValid request-attention $target)
   (not (== $target ())))
(= (reasonerProposalTargetValid request-frame-switch (FrameTarget $frame))
   (not (== $frame ())))
(= (reasonerProposalTargetValid request-mode-change (ModeTarget Fast)) True)
(= (reasonerProposalTargetValid request-mode-change (ModeTarget Slow)) True)
(= (reasonerProposalTargetValid $_ $_) False)

;; ---------------------------------------------------------------------------
;; Inference adapters
;; ---------------------------------------------------------------------------
;; NARS and PLN are first-class inference sources. Their engines only need to
;; provide a conclusion, normalized confidence, evidence references, the
;; registered candidate they recommend, and an expected outcome. The adapter
;; adds provenance without exposing engine-specific terms to MetaMo.

(= (narsInferenceToProposal
      $id $conclusion $confidence $evidence $candidate $prediction)
   (ReasonerMotivationalProposal
      $id nars propose-candidate current-frame $candidate
      (NARSConclusion $conclusion) (NARSSupport $conclusion)
      $confidence $evidence $prediction))

(= (plnInferenceToProposal
      $id $conclusion $confidence $evidence $candidate $prediction)
   (ReasonerMotivationalProposal
      $id pln propose-candidate current-frame $candidate
      (PLNConclusion $conclusion) (PLNSupport $conclusion)
      $confidence $evidence $prediction))

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
   ;; Keep the public predicate single-arity and read the positional fields
   ;; only after checking the constructor tag. Unknown shapes fail closed.
   (if (== (car-atom $proposal) ReasonerMotivationalProposal)
       (let* (
          ($id (index-atom $proposal 1))
          ($source (index-atom $proposal 2))
          ($kind (index-atom $proposal 3))
          ($target (index-atom $proposal 4))
          ($candidate (index-atom $proposal 5))
          ($claim (index-atom $proposal 6))
          ($confidence (index-atom $proposal 8))
          ($prediction (index-atom $proposal 10)))
          (and (reasonerProposalIdValid $id)
               (reasonerProposalSourceValid $source)
               (reasonerProposalKindValid $kind)
               (reasonerProposalTargetValid $kind $target)
               (reasonerProposalCandidateValid $candidate)
               (reasonerProposalConfidenceValid $confidence)
               (not (== $claim ()))
               (not (== $prediction ()))))
       False)))

(= (reasonerProposalAdmission $bundle $proposal)
   (if (not (reasonerProposalValid $proposal))
       (ReasonerMotivationalDecision Malformed InvalidProposal $proposal none)
       (let* (
          ($candidate (index-atom $proposal 5))
          ((GateDecision $admission $reason) (feasibilityGate $bundle $candidate)))
          (if (== $admission Admitted)
              (ReasonerMotivationalDecision Accepted Feasible $proposal $candidate 0.0)
              (ReasonerMotivationalDecision Rejected $reason $proposal $candidate 0.0)))))

;; Score an accepted proposal as the corresponding registered MetaMo action.
;; This is the only proposal-to-action conversion performed by MetaMo; the
;; returned action is data for the scheduler and is never executed here.
(= (reasonerProposalDecision $bundle $state $proposal)
   (let ((ReasonerMotivationalDecision $status $reason $_proposal $candidate $_score)
            (reasonerProposalAdmission $bundle $proposal))
      (if (== $status Accepted)
          (let* (
             ($action (candidateToAction $candidate))
             ($score (omegaclawScoreForBundle $bundle $state $action)))
             (ReasonerMotivationalDecision Accepted Feasible $proposal $candidate $score))
          (ReasonerMotivationalDecision $status $reason $proposal $candidate 0.0))))

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
      ($status (index-atom $decision 1))
      ($reason (index-atom $decision 2))
      ($candidate (index-atom $decision 4))
      ($score (index-atom $decision 5))
      ($kind (index-atom $proposal 3))
      ($target (index-atom $proposal 4)))
      (ReasonerMotivationalDirective
         (proposal $proposal)
         (status $status)
         (reason $reason)
         (operation $kind)
         (target $target)
         (candidate $candidate)
         (score $score)
         (source MetaMo))))
