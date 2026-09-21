;; Policy is a hard admission boundary; modes may only tighten it.
;; These tests use real gates and the real numeric scorer, without services.
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
;; This test explicitly exercises optional proposal admission; no inference.
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_proposals))
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/typed_policy))

(= (monotonicBundle $status $mode $budget)
   (FrameStateBundle
      (root (FrameStateRoot root "policy-frame" (mode Fast) () ()))
      (current (FrameStateCurrent (id "policy-frame") (parent ()) UserDirective
         (status $status) (frame-mode $mode) (priority 1.0)
         (goal-summary "task") (history-summary "") (deliverable-summary "")
         (results-summary "") (budget (ResourceBudget 10 10 units (status $budget)))
         (constraints ()) (certified-method ())))
      (index (active ()) (completed ())) (relations ()) (runtime ())))
(= (monotonicOpenBundle) (monotonicBundle Active Fast Open))
(= (monotonicScope $skills $permissions $egress $constraints $budgets)
   (typedPolicyFixture Global $skills $permissions $egress $constraints $budgets))
(= (monotonicGate $global)
   (candidateAdmissionForOperation (monotonicOpenBundle) execute-skill
      (typedOperationFixture) $global (typedScopeFixture (FrameTarget "policy-frame"))))
(= (monotonicDeniedScope)
   (monotonicScope ("read-file") ("files.read") () ((DenySkill "read-file")) (typedBudgetFixture)))
(= (monotonicProposal)
   (ReasonerMotivationalProposal monotonic-p nars propose-candidate current-frame
      execute-skill claim support 1.0 (EvidenceReferences (e1)) prediction))

;; Engaged: preserve the original rejection, including when Sleep also rejects.
!(setConstitutionalMode Engaged)
!(test (feasibilityGate (monotonicBundle Blocked Fast Open) execute-skill)
   (GateDecision Rejected InactiveFrame))
!(test (feasibilityGate (monotonicBundle Active Slow Open) execute-skill)
   (GateDecision Rejected FrameModeMismatch))
!(test (feasibilityGate (monotonicBundle Active Fast Exhausted) execute-skill)
   (GateDecision Rejected BudgetExhausted))
!(test (monotonicGate ()) (GateDecision Rejected InvalidGlobalPolicy))
!(test (monotonicGate (monotonicScope () ("files.read") () () (typedBudgetFixture))) (GateDecision Rejected SkillNotAllowed))
!(test (monotonicGate (monotonicScope ("read-file") () () () (typedBudgetFixture))) (GateDecision Rejected PermissionDenied))
!(test (monotonicGate (monotonicDeniedScope)) (GateDecision Rejected ConstraintDenied))
!(test (monotonicGate (monotonicScope ("read-file") ("files.read") () () ((ResourceBudget "commands" "units" 0 Open)))) (GateDecision Rejected BudgetExhausted))
!(test (feasibilityGateForOperation (monotonicOpenBundle) execute-skill
   (PolicyOperation (candidate execute-skill) (target "policy-frame")
      (skill "read-file") (permissions ("files.read")) (egress ("unapproved")) (costs ()))
   (typedScopeFixture Global) (typedScopeFixture (FrameTarget "policy-frame")))
   (GateDecision Rejected EgressDenied))
;; Denied maximum-confidence proposals never evaluate even an invalid scorer state.
!(test (reasonerProposalScoreForOperation (monotonicOpenBundle) (monotonicOpenBundle)
   invalid-scorer-state (monotonicProposal) (typedOperationFixture)
   (monotonicDeniedScope) (typedScopeFixture (FrameTarget "policy-frame"))) 0.0)
!(test (getCandidate (reasonerProposalToActionForOperation
   (monotonicOpenBundle) (monotonicOpenBundle) (monotonicProposal)
   (typedOperationFixture) (monotonicDeniedScope)
   (typedScopeFixture (FrameTarget "policy-frame")))) none)
!(test (monotonicGate (typedScopeFixture Global)) (GateDecision Admitted Feasible))

;; Threat: preserve the original rejection, including when Sleep also rejects.
!(setConstitutionalMode Threat)
!(test (feasibilityGate (monotonicBundle Blocked Fast Open) execute-skill)
   (GateDecision Rejected InactiveFrame))
!(test (feasibilityGate (monotonicBundle Active Slow Open) execute-skill)
   (GateDecision Rejected FrameModeMismatch))
!(test (feasibilityGate (monotonicBundle Active Fast Exhausted) execute-skill)
   (GateDecision Rejected BudgetExhausted))
!(test (monotonicGate ()) (GateDecision Rejected InvalidGlobalPolicy))
!(test (monotonicGate (monotonicScope () ("files.read") () () (typedBudgetFixture))) (GateDecision Rejected SkillNotAllowed))
!(test (monotonicGate (monotonicScope ("read-file") () () () (typedBudgetFixture))) (GateDecision Rejected PermissionDenied))
!(test (monotonicGate (monotonicDeniedScope)) (GateDecision Rejected ConstraintDenied))
!(test (monotonicGate (monotonicScope ("read-file") ("files.read") () () ((ResourceBudget "commands" "units" 0 Open)))) (GateDecision Rejected BudgetExhausted))
!(test (feasibilityGateForOperation (monotonicOpenBundle) execute-skill
   (PolicyOperation (candidate execute-skill) (target "policy-frame")
      (skill "read-file") (permissions ("files.read")) (egress ("unapproved")) (costs ()))
   (typedScopeFixture Global) (typedScopeFixture (FrameTarget "policy-frame")))
   (GateDecision Rejected EgressDenied))
;; Denied maximum-confidence proposals never evaluate even an invalid scorer state.
!(test (reasonerProposalScoreForOperation (monotonicOpenBundle) (monotonicOpenBundle)
   invalid-scorer-state (monotonicProposal) (typedOperationFixture)
   (monotonicDeniedScope) (typedScopeFixture (FrameTarget "policy-frame"))) 0.0)
!(test (getCandidate (reasonerProposalToActionForOperation
   (monotonicOpenBundle) (monotonicOpenBundle) (monotonicProposal)
   (typedOperationFixture) (monotonicDeniedScope)
   (typedScopeFixture (FrameTarget "policy-frame")))) none)
!(test (monotonicGate (typedScopeFixture Global)) (GateDecision Admitted Feasible))

;; Rumination: preserve the original rejection, including when Sleep also rejects.
!(setConstitutionalMode Rumination)
!(test (feasibilityGate (monotonicBundle Blocked Fast Open) execute-skill)
   (GateDecision Rejected InactiveFrame))
!(test (feasibilityGate (monotonicBundle Active Slow Open) execute-skill)
   (GateDecision Rejected FrameModeMismatch))
!(test (feasibilityGate (monotonicBundle Active Fast Exhausted) execute-skill)
   (GateDecision Rejected BudgetExhausted))
!(test (monotonicGate ()) (GateDecision Rejected InvalidGlobalPolicy))
!(test (monotonicGate (monotonicScope () ("files.read") () () (typedBudgetFixture))) (GateDecision Rejected SkillNotAllowed))
!(test (monotonicGate (monotonicScope ("read-file") () () () (typedBudgetFixture))) (GateDecision Rejected PermissionDenied))
!(test (monotonicGate (monotonicDeniedScope)) (GateDecision Rejected ConstraintDenied))
!(test (monotonicGate (monotonicScope ("read-file") ("files.read") () () ((ResourceBudget "commands" "units" 0 Open)))) (GateDecision Rejected BudgetExhausted))
!(test (feasibilityGateForOperation (monotonicOpenBundle) execute-skill
   (PolicyOperation (candidate execute-skill) (target "policy-frame")
      (skill "read-file") (permissions ("files.read")) (egress ("unapproved")) (costs ()))
   (typedScopeFixture Global) (typedScopeFixture (FrameTarget "policy-frame")))
   (GateDecision Rejected EgressDenied))
;; Denied maximum-confidence proposals never evaluate even an invalid scorer state.
!(test (reasonerProposalScoreForOperation (monotonicOpenBundle) (monotonicOpenBundle)
   invalid-scorer-state (monotonicProposal) (typedOperationFixture)
   (monotonicDeniedScope) (typedScopeFixture (FrameTarget "policy-frame"))) 0.0)
!(test (getCandidate (reasonerProposalToActionForOperation
   (monotonicOpenBundle) (monotonicOpenBundle) (monotonicProposal)
   (typedOperationFixture) (monotonicDeniedScope)
   (typedScopeFixture (FrameTarget "policy-frame")))) none)
!(test (monotonicGate (typedScopeFixture Global)) (GateDecision Admitted Feasible))

;; Sleep: preserve the original rejection, including when Sleep also rejects.
!(setConstitutionalMode Sleep)
!(test (feasibilityGate (monotonicBundle Blocked Fast Open) execute-skill)
   (GateDecision Rejected InactiveFrame))
!(test (feasibilityGate (monotonicBundle Active Slow Open) execute-skill)
   (GateDecision Rejected FrameModeMismatch))
!(test (feasibilityGate (monotonicBundle Active Fast Exhausted) execute-skill)
   (GateDecision Rejected BudgetExhausted))
!(test (monotonicGate ()) (GateDecision Rejected InvalidGlobalPolicy))
!(test (monotonicGate (monotonicScope () ("files.read") () () (typedBudgetFixture))) (GateDecision Rejected SkillNotAllowed))
!(test (monotonicGate (monotonicScope ("read-file") () () () (typedBudgetFixture))) (GateDecision Rejected PermissionDenied))
!(test (monotonicGate (monotonicDeniedScope)) (GateDecision Rejected ConstraintDenied))
!(test (monotonicGate (monotonicScope ("read-file") ("files.read") () () ((ResourceBudget "commands" "units" 0 Open)))) (GateDecision Rejected BudgetExhausted))
!(test (feasibilityGateForOperation (monotonicOpenBundle) execute-skill
   (PolicyOperation (candidate execute-skill) (target "policy-frame")
      (skill "read-file") (permissions ("files.read")) (egress ("unapproved")) (costs ()))
   (typedScopeFixture Global) (typedScopeFixture (FrameTarget "policy-frame")))
   (GateDecision Rejected EgressDenied))
;; Denied maximum-confidence proposals never evaluate even an invalid scorer state.
!(test (reasonerProposalScoreForOperation (monotonicOpenBundle) (monotonicOpenBundle)
   invalid-scorer-state (monotonicProposal) (typedOperationFixture)
   (monotonicDeniedScope) (typedScopeFixture (FrameTarget "policy-frame"))) 0.0)
!(test (getCandidate (reasonerProposalToActionForOperation
   (monotonicOpenBundle) (monotonicOpenBundle) (monotonicProposal)
   (typedOperationFixture) (monotonicDeniedScope)
   (typedScopeFixture (FrameTarget "policy-frame")))) none)
!(test (monotonicGate (typedScopeFixture Global)) (GateDecision Rejected SleepModeOperationalWork))

;; Leaving Sleep removes only its extra restriction, never a host denial.
!(setConstitutionalMode Threat)
!(test (monotonicGate (typedScopeFixture Global)) (GateDecision Admitted Feasible))
!(test (monotonicGate (monotonicDeniedScope)) (GateDecision Rejected ConstraintDenied))

;; Risk is a preference among admitted actions, not a policy authorization.
;; Identical actions differ only in risk; neutral low goals avoid saturation.
(= (monotonicState)
   (motivation (0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1)
      (0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5)))
(= (monotonicRiskAction $risk)
   (action execute-skill (0.2 0.2 0.2 0.2 0.2 0.2 0.2 0.2 0.2 0.2 0.2)
      $risk (0 0 0 0 0 0 0 0 0 0 0)))
!(test (> (omegaclawScore (monotonicState) (monotonicRiskAction 0.0))
          (omegaclawScore (monotonicState) (monotonicRiskAction 0.2))) True)
!(test (monotonicGate (typedScopeFixture Global)) (GateDecision Admitted Feasible))
;; Even a positive raw preference score cannot override the separate hard gate.
!(test (> (omegaclawScore (monotonicState) (monotonicRiskAction 0.0)) 0.0) True)
!(test (monotonicGate (monotonicDeniedScope)) (GateDecision Rejected ConstraintDenied))
!(setConstitutionalMode Engaged)
