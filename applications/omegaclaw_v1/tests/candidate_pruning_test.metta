;; Mixed-list regressions: policy rejection must never erase feasible choices.
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/typed_policy))

(= (pruningBundle)
   (FrameStateBundle
      (root (FrameStateRoot root "policy-frame" (mode Fast) () ()))
      (current (FrameStateCurrent (id "policy-frame") (parent ()) UserDirective
         (status Active) (frame-mode Fast) (priority 1.0)
         (goal-summary "task") (history-summary "") (deliverable-summary "")
         (results-summary "") (budget (ResourceBudget 10 10 units (status Open)))
         (constraints ()) (certified-method ())))
      (index (active ()) (completed ())) (relations ())
      (runtime (FrameStateRuntime (new-message False) (message-present False)
         (message-summary "") (task-open True) (task-execution-observed "")
         (active-task-summary "task") (last-results-summary "") (error "")
         (wake-loops 0) (next-wake-at 0) (budget-state ())))))
(= (pruningState)
   (motivation (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
      (0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5)))
(= (pruningAction $name $alignment)
   (action $name ($alignment $alignment $alignment $alignment $alignment
      $alignment $alignment $alignment $alignment $alignment $alignment)
      0.0 (0 0 0 0 0 0 0 0 0 0 0)))
(= (pruningWinner $actions)
   (actionId (decisionAction (omegaclawDecideForBundle
      (pruningBundle) (pruningState) $actions))))

!(setConstitutionalMode Sleep)
;; The denied action has the maximal raw score and cannot win in either order.
!(test (pruningWinner ((pruningAction execute-skill 1.0) (pruningAction respond 0.1))) respond)
!(test (pruningWinner ((pruningAction respond 0.1) (pruningAction execute-skill 1.0))) respond)
;; Zero-scoring feasible candidates remain eligible; rejection is not score zero.
!(test (pruningWinner ((pruningAction execute-skill 1.0) (pruningAction respond 0.0))) respond)
;; Poison scoring data proves rejected candidates never reach numeric scoring.
!(test (pruningWinner ((action execute-skill invalid-correlations invalid-risk ())
   (pruningAction respond 0.1))) respond)
!(test (decisionAction (omegaclawDecideForBundle (pruningBundle) invalid-state
   ((action execute-skill invalid-correlations invalid-risk ())))) (action none () 0.0 ()))
!(test (pruningWinner ()) none)
!(setActiveFrameBundle (pruningBundle))
!(test (actionId (decisionAction (omegaclawDecideBound (pruningState)
   ((pruningAction execute-skill 1.0) (pruningAction respond 0.1))))) respond)
!(setActiveFrameBundle ())

;; Partition results retain order, complete actions, and typed per-candidate reasons.
!(test (pruneActionsForBundle (pruningBundle)
   ((pruningAction execute-skill 1.0) (pruningAction respond 0.1)
    (pruningAction learn 1.0) (pruningAction retrieve-memory 0.1)))
   (CandidatePruning
      (admitted ((pruningAction respond 0.1) (pruningAction retrieve-memory 0.1)))
      (rejected ((CandidateRejection execute-skill SleepModeOperationalWork)
                 (CandidateRejection learn SleepModeOperationalWork)))))
!(test (pruneActionsForBundle (pruningBundle) ())
   (CandidatePruning (admitted ()) (rejected ())))
;; Existing tie behavior keeps the first surviving action.
!(test (pruningWinner ((pruningAction execute-skill 1.0)
   (pruningAction respond 0.1) (pruningAction retrieve-memory 0.1))) respond)

!(setConstitutionalMode Engaged)
;; Interactive work now preempts Engaged work, regardless of its score.
!(test (pruningWinner ((pruningAction execute-skill 1.0) (pruningAction respond 0.1))) respond)
!(test (pruneActionsForBundle (pruningBundle) ((pruningAction respond 0.1)))
   (CandidatePruning (admitted ((pruningAction respond 0.1))) (rejected ())))

;; Concrete generation preserves the valid response and exposes the host denial.
(= (pruningReadOp $candidate)
   (PolicyOperation (candidate $candidate) (target "policy-frame")
      (skill "read-file") (permissions ("files.read")) (egress ()) (costs ())))
!(addSignal user-waiting 0.3)
!(generateCandidatesForOperations (pruningBundle)
   ((CandidateOperation execute-skill (pruningReadOp execute-skill) ()
      (typedScopeFixture (FrameTarget "policy-frame")))
    (CandidateOperation respond (pruningReadOp respond) (typedScopeFixture Global)
      (typedScopeFixture (FrameTarget "policy-frame")))))
!(test (collapse (match &candidateSpace (candidate $name) $name)) (respond))
!(test (candidateRejections) ((CandidateRejection execute-skill InvalidGlobalPolicy)))
;; The survivors reach the real selector; rejection diagnostics remain available.
!(test (pruningWinner (candidatesToActions)) respond)
!(generateCandidatesForOperations (pruningBundle)
   ((CandidateOperation execute-skill (pruningReadOp execute-skill) ()
      (typedScopeFixture (FrameTarget "policy-frame")))
    (CandidateOperation learn (pruningReadOp learn)
      (typedPolicyFixture Global () ("files.read") () () ())
      (typedScopeFixture (FrameTarget "policy-frame")))
    (CandidateOperation respond (pruningReadOp respond) (typedScopeFixture Global)
      (typedScopeFixture (FrameTarget "policy-frame")))))
!(test (candidateRejections)
   ((CandidateRejection execute-skill InvalidGlobalPolicy)
    (CandidateRejection learn SkillNotAllowed)))
!(test (pruningWinner (candidatesToActions)) respond)
!(generateCandidatesForOperations (pruningBundle) ())
!(test (candidateRejections) ())
!(test (collapse (match &candidateSpace (candidate $name) $name)) ())
