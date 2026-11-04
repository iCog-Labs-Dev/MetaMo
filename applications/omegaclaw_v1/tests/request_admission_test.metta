!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
;; This test explicitly exercises optional proposal admission; no inference.
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_proposals))
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/typed_policy))

(= (requestBundle $id $status $mode)
   (FrameStateBundle
      (root (FrameStateRoot root "origin" (mode Fast) () ()))
      (current (FrameStateCurrent (id $id) (parent ()) UserDirective
         (status $status) (frame-mode $mode) (priority 0.5)
         (goal-summary "task") (history-summary "") (deliverable-summary "")
         (results-summary "") (budget (ResourceBudget 10 10 units (status Open)))
         (constraints ()) (certified-method ())))
      (index (active ()) (completed ())) (relations ())
      (runtime (FrameStateRuntime (new-message False) (message-present False)
         (message-summary "") (task-open True) (task-execution-observed "")
         (active-task-summary "task") (last-results-summary "") (error "")
         (wake-loops 0) (next-wake-at 0) (budget-state ())))))
(= (originBundle) (requestBundle "origin" Active Fast))
(= (destinationBundle) (requestBundle "destination" Active Fast))
(= (requestScope $target)
   (typedPolicyFixture $target ("read-file" "switch-frame" "switch-mode")
      ("files.read" "frames.switch-frame" "frames.switch-mode") () () (typedBudgetFixture)))
(= (requestOp $candidate $target $skill $permissions)
   (PolicyOperation (candidate $candidate) (target $target) (skill $skill)
      (permissions $permissions) (egress ()) (costs ((ResourceCost "commands" "units" 1)))))
(= (readOp $candidate $target) (requestOp $candidate $target "read-file" ("files.read")))
(= (proposalFixture $kind $target $candidate)
   (ReasonerMotivationalProposal p1 nars $kind $target $candidate claim support 1.0 (EvidenceReferences (e1)) prediction))
(= (requestCheck $target $request $operation)
   (feasibilityGateForRequest (originBundle) $target $request $operation
      (requestScope Global) (requestScope (FrameTarget (frameBundleCurrentId $target)))))

!(test (candidateAdmissionForOperation (originBundle) execute-skill (readOp execute-skill "origin")
   (requestScope Global) (requestScope (FrameTarget "origin"))) (GateDecision Admitted Feasible))
!(test (candidateAdmissionForOperation (originBundle) execute-skill (readOp execute-skill "destination")
   (requestScope Global) (requestScope (FrameTarget "origin"))) (GateDecision Rejected TargetMismatch))
!(test (requestCheck (destinationBundle) (AdmissionRequest propose-candidate current-frame execute-skill)
   (readOp execute-skill "destination")) (GateDecision Rejected TargetMismatch))
!(test (requestCheck (destinationBundle) (AdmissionRequest request-attention (FrameTarget "destination") execute-skill)
   (readOp execute-skill "destination")) (GateDecision Admitted Feasible))
!(test (requestCheck (requestBundle "destination" Blocked Fast)
   (AdmissionRequest request-attention (FrameTarget "destination") respond) (readOp respond "destination"))
   (GateDecision Rejected InactiveFrame))
!(test (requestCheck (requestBundle "destination" Active Slow)
   (AdmissionRequest request-attention (FrameTarget "destination") respond) (readOp respond "destination"))
   (GateDecision Rejected FrameModeMismatch))

;; Frame switch cannot use defer's name or an unrelated operation to bypass checks.
!(test (requestCheck (destinationBundle) (AdmissionRequest request-frame-switch (FrameTarget "destination") defer)
   (requestOp defer "destination" "switch-frame" ("frames.switch-frame"))) (GateDecision Admitted Feasible))
!(test (requestCheck (destinationBundle) (AdmissionRequest request-frame-switch (FrameTarget "other") defer)
   (requestOp defer "destination" "switch-frame" ("frames.switch-frame"))) (GateDecision Rejected TargetMismatch))
!(test (requestCheck (destinationBundle) (AdmissionRequest request-frame-switch (FrameTarget "destination") defer)
   (readOp defer "destination")) (GateDecision Rejected OperationMismatch))
!(test (requestCheck (destinationBundle) (AdmissionRequest request-frame-switch (FrameTarget "destination") defer)
   (requestOp defer "destination" "switch-frame" ())) (GateDecision Rejected PermissionDenied))
!(test (requestCheck (destinationBundle) (AdmissionRequest propose-candidate (FrameTarget "destination") defer)
   (requestOp defer "destination" "switch-frame" ("frames.switch-frame"))) (GateDecision Rejected OperationMismatch))

(= (slowOperation $mode)
   (ModeOperation $mode (requestOp defer "destination" "switch-mode" ("frames.switch-mode"))))
!(test (requestCheck (requestBundle "destination" Active Slow)
   (AdmissionRequest request-mode-change (ModeTarget Slow) defer) (slowOperation Slow)) (GateDecision Admitted Feasible))
!(test (requestCheck (requestBundle "destination" Active Slow)
   (AdmissionRequest request-mode-change (ModeTarget Slow) defer) (slowOperation Fast)) (GateDecision Rejected ModeMismatch))
!(test (requestCheck (destinationBundle)
   (AdmissionRequest request-mode-change (ModeTarget Slow) defer) (slowOperation Slow)) (GateDecision Rejected FrameModeMismatch))
!(test (requestCheck (destinationBundle)
   (AdmissionRequest request-mode-change (ModeTarget Slow) defer) (readOp defer "destination")) (GateDecision Rejected MissingModeOperation))

!(test (getStatus (reasonerProposalAdmissionForOperation (originBundle) (destinationBundle)
   (proposalFixture request-attention (FrameTarget "destination") execute-skill)
   (readOp execute-skill "destination") (requestScope Global) (requestScope (FrameTarget "destination")))) Accepted)
!(test (getReason (reasonerProposalAdmissionForOperation (originBundle) (destinationBundle)
   (proposalFixture request-frame-switch (FrameTarget "destination") defer)
   (readOp defer "destination") (requestScope Global) (requestScope (FrameTarget "destination")))) OperationMismatch)
!(test (getCandidate (reasonerProposalToActionForOperation (originBundle) (destinationBundle)
   (proposalFixture propose-candidate current-frame execute-skill)
   (readOp execute-skill "destination") (requestScope Global) (requestScope (FrameTarget "destination")))) none)
!(test (attentionDirectiveForRequest (originBundle) (destinationBundle)
   (AdmissionRequest request-attention (FrameTarget "other") execute-skill)
   (readOp execute-skill "destination") (requestScope Global) (requestScope (FrameTarget "destination")) 1.0)
   (AttentionDirective (target ()) (slice None) (task none) (admission Rejected)
      (reason TargetMismatch) (priority 0) (source MetaMo)))

!(setConstitutionalMode Sleep)
!(test (requestCheck (destinationBundle) (AdmissionRequest request-frame-switch (FrameTarget "destination") defer)
   (requestOp defer "destination" "switch-frame" ("frames.switch-frame"))) (GateDecision Rejected SleepModeOperationalWork))
!(test (requestCheck (requestBundle "destination" Active Slow)
   (AdmissionRequest request-mode-change (ModeTarget Slow) defer) (slowOperation Slow)) (GateDecision Rejected SleepModeOperationalWork))
!(setConstitutionalMode Engaged)
!(test (requestCheck (originBundle) (AdmissionRequest propose-candidate current-frame arbitrary)
   (readOp arbitrary "origin")) (GateDecision Rejected InvalidCandidate))
!(test (candidateAdmissionForOperation (originBundle) execute-skill (readOp execute-skill "origin")
   () (requestScope (FrameTarget "origin"))) (GateDecision Rejected InvalidGlobalPolicy))

;; Native generation uses normal availability and individually applies the
;; common gate. Denied rows cannot become scored actions.
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/factual_signals))
!(fixturePutSignal user-waiting (quote (BooleanFact True)))
!(generateCandidatesForOperations (originBundle)
   ((CandidateOperation respond (readOp respond "origin") (requestScope Global) (requestScope (FrameTarget "origin")))
    (CandidateOperation execute-skill (readOp execute-skill "origin") () (requestScope (FrameTarget "origin")))))
!(test (collapse (match &candidateSpace (candidate $name) $name)) (respond))
!(generateCandidatesForOperations (originBundle) ())
!(test (collapse (match &candidateSpace (candidate $name) $name)) ())
;; Deliberately invalid scorer state: a rejected proposal must never evaluate it.
!(test (reasonerProposalScoreForOperation (originBundle) (destinationBundle) no-scoring-state
   (proposalFixture propose-candidate current-frame execute-skill)
   (readOp execute-skill "destination") (requestScope Global) (requestScope (FrameTarget "destination"))) 0.0)
!(test (attentionDirectiveForRequest (originBundle) (destinationBundle)
   (AdmissionRequest request-attention (FrameTarget "destination") execute-skill)
   (readOp execute-skill "destination") () (requestScope (FrameTarget "destination")) 1.0)
   (AttentionDirective (target ()) (slice None) (task none) (admission Rejected)
      (reason InvalidGlobalPolicy) (priority 0) (source MetaMo)))
!(test (feasibilityGateForRequest (originBundle) ()
   (AdmissionRequest request-attention (FrameTarget "destination") execute-skill)
   (readOp execute-skill "destination") (requestScope Global) (requestScope (FrameTarget "destination")))
   (GateDecision Rejected InvalidTargetSnapshot))
!(test (requestCheck (destinationBundle) (AdmissionRequest request-frame-switch (FrameTarget "destination") defer)
   (ModeOperation Slow (requestOp defer "destination" "switch-frame" ("frames.switch-frame"))))
   (GateDecision Rejected OperationMismatch))
!(test (getReason (reasonerProposalAdmission (originBundle)
   (proposalFixture request-frame-switch (FrameTarget "destination") defer))) MissingOperationContext)
!(test (getReason (reasonerProposalAdmission (originBundle)
   (proposalFixture request-mode-change (ModeTarget Slow) defer))) MissingOperationContext)
!(test (getReason (reasonerProposalAdmission (originBundle)
   (proposalFixture request-attention current-frame execute-skill))) MissingOperationContext)

;; The real Core frame ID may be symbolic; never coerce a text target to it.
(= (nativeRequestCheck $frameId $operationId)
   (feasibilityGateForRequest
      (requestBundle $frameId Active Fast) (requestBundle $frameId Active Fast)
      (AdmissionRequest propose-candidate current-frame execute-skill)
      (readOp execute-skill $operationId)
      (requestScope Global) (requestScope (FrameTarget $frameId))))
!(test (nativeRequestCheck Frame-native Frame-native) (GateDecision Admitted Feasible))
!(test (nativeRequestCheck Frame-native "Frame-native") (GateDecision Rejected TargetMismatch))
!(test (requestBundleShapeValid (requestBundle 42 Active Fast)) False)
!(test (requestBundleShapeValid (requestBundle (Frame-native) Active Fast)) False)

;; Representation errors are rejected before concrete policy or scoring.
!(test (getStatus (reasonerProposalAdmissionForOperation (originBundle) (originBundle)
   (quote (ReasonerMotivationalProposal "" nars propose-candidate current-frame
      execute-skill claim support 0.9 (EvidenceReferences (e1)) prediction))
   (readOp execute-skill "origin") (requestScope Global) (requestScope (FrameTarget "origin")))) Malformed)

!(test (reasonerProposalScoreForOperation (originBundle) (originBundle) invalid-scoring-state
   (quote (ReasonerMotivationalProposal p nars propose-candidate current-frame
      execute-skill claim support "0.9" (EvidenceReferences (e1)) prediction))
   (readOp execute-skill "origin") (requestScope Global) (requestScope (FrameTarget "origin"))) 0.0)

;; A shaped reference is not resolved/authenticated by these pure policy helpers.
!(test (getStatus (reasonerProposalAdmissionForOperation (originBundle) (originBundle)
   (quote (ReasonerMotivationalProposal p nars propose-candidate current-frame
      execute-skill claim support 0.9 (EvidenceReferences (unresolved-stamp)) prediction))
   (readOp execute-skill "origin") (requestScope Global) (requestScope (FrameTarget "origin")))) Accepted)

;; Exercise the concrete gate with invalid records, rather than accessor tests alone.
;; Example: (requestInvalidReasonerProposals) contains no admissible proposal.
(= (requestInvalidReasonerProposals)
    (let $valid (proposalFixture propose-candidate current-frame execute-skill)
        (
            (cons-atom WrongProposal (cdr-atom $valid))
            (map-atom (0 1 2 3 4 5 6 7 8 9) $index (index-atom $valid $index))
            (concat $valid (extra))
            (ReasonerMotivationalProposal p nars propose-candidate current-frame
                execute-skill claim () 0.9 (EvidenceReferences (e1)) prediction)
            (ReasonerMotivationalProposal p pln propose-candidate current-frame
                execute-skill claim () 0.9 (EvidenceReferences (e1)) prediction)
            (ReasonerMotivationalProposal p nars propose-candidate current-frame
                execute-skill claim support 0.9 (EvidenceReferences ()) prediction)
            (ReasonerMotivationalProposal p pln propose-candidate current-frame
                execute-skill claim support 0.9 (EvidenceReferences ()) prediction)
            (ReasonerMotivationalProposal p nars propose-candidate current-frame
                execute-skill claim support 0.9 (EvidenceReferences (e1)) ())
            (ReasonerMotivationalProposal p pln propose-candidate current-frame
                execute-skill claim support 0.9 (EvidenceReferences (e1)) ())
        )
    )
)

!(bind! &request-reasoner-events-before (new-state (reasonerProposalEvents)))
!(bind! &request-reasoner-outcomes-before (new-state (reasonerProposalOutcomes)))
!(bind! &request-reasoner-reliability-before (new-state
    (collapse (match &reasoner-source-reliability $row $row))))
!(test (map-atom (requestInvalidReasonerProposals) $proposal
    (reasonerProposalAdmissionForOperation (originBundle) (originBundle) $proposal
        (readOp execute-skill "origin") (requestScope Global) (requestScope (FrameTarget "origin"))))
    (map-atom (requestInvalidReasonerProposals) $proposal
        (ReasonerMotivationalDecision Malformed InvalidProposal $proposal none 0.0)))

;; Invalid policy and scorer values must never be inspected for malformed proposals.
!(test (map-atom (requestInvalidReasonerProposals) $proposal
    (reasonerProposalScoreForOperation (originBundle) (originBundle) invalid-scoring-state
        $proposal invalid-operation invalid-global-policy invalid-frame-policy))
    (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0))

!(test (map-atom (requestInvalidReasonerProposals) $proposal
    (reasonerProposalToActionForOperation (originBundle) (originBundle) $proposal
        (readOp execute-skill "origin") (requestScope Global) (requestScope (FrameTarget "origin"))))
    (map-atom (requestInvalidReasonerProposals) $proposal
        (ReasonerProposalActionResult Malformed InvalidProposal none (action none () 0.0 ()))))

!(test (reasonerProposalEvents) (get-state &request-reasoner-events-before))
!(test (reasonerProposalOutcomes) (get-state &request-reasoner-outcomes-before))
!(test (collapse (match &reasoner-source-reliability $row $row))
    (get-state &request-reasoner-reliability-before))
