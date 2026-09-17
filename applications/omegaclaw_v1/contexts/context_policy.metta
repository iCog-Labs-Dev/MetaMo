;; Context and constitutional admission policy.
;;
;; This module decides whether a registered candidate is feasible for a bounded
;; FrameStateBundle. It does not construct scheduler directives.

;; context_integration imports context_accessors before this module. Leaf
;; modules do not reimport dependencies: native PeTTa would compile them twice.

!(import! &self (library MetaMo applications/omegaclaw_v1/contexts/typed_policy))

;; Concrete-operation path. Both resolved policy scopes and operation metadata
;; come from the host, never a reasoner claim or a compacted display summary.
;; The existing candidate-only gate remains a legacy preliminary check.
(= (feasibilityGateForOperation $bundle $candidate $operation $global $frame)
   ;; request_admission is loaded after the legacy context helpers below.
   (eval (feasibilityGateForRequest $bundle $bundle
      (AdmissionRequest propose-candidate current-frame $candidate)
      $operation $global $frame)))

(= (cfv2-current-frame-active)
   (or (== (get-state &cfv2-current-status) Active)
       (== (get-state &cfv2-current-status) Focused)))

(= (cfv2-current-frame-mode-compatible)
   (== (get-state &cfv2-current-frame-mode)
       (get-state &cfv2-root-mode)))

(= (cfv2-budget-open)
   (let $budget (get-state &cfv2-current-budget)
      (if (== $budget ())
          False
          (case $budget (
             ((ResourceBudget $_ $_ $_ (status Closed)) False)
             ((ResourceBudget $_ $_ $_ (status Exhausted)) False)
             ($_ True))))))

;; These candidates can cause work or side effects and therefore require an
;; admitted, active, mode-compatible frame with an open budget.
(= (candidateRequiresFrame $candidate)
   (case $candidate
      ((execute-skill True)
       (learn True)
       (self-improve True)
       (background-work True)
       (invent-goal True)
       (plan-goal True)
       (repair-failure True)
       (verify-frame-state True)
       ($_ False))))

(= (frameBundleHasCurrent $bundle)
   (not (== (frameBundleCurrentId $bundle) ())))

(= (frameBundleActive $bundle)
   (or (== (bundle-current-status $bundle) Active)
       (== (bundle-current-status $bundle) Focused)))

(= (frameBundleModeCompatible $bundle)
   (== (frameBundleCurrentMode $bundle) (frameBundleRootMode $bundle)))

(= (frameBundleBudgetOpen $bundle)
   (let $budget (bundle-current-budget-state $bundle)
      (frameBundleBudgetOpenValue $budget)))

(= (frameBundleBudgetOpenValue
      (ResourceBudget $_ $_ $_ (status $status)))
   (and (not (== $status Closed))
        (not (== $status Exhausted))))
(= (frameBundleBudgetOpenValue open-budget) True)
;; Base policy example:
   ;;   `(contextPolicyGate $bundle execute-skill)` returns either
   ;;   `(GateDecision Admitted Feasible)` or a typed rejection such as
   ;;   `(GateDecision Rejected BudgetExhausted)`.
   ;; Candidates that do not require a frame, such as `respond`, may be
   ;; admitted even when the current-frame requirement is false.
(= (contextPolicyGate $bundle $candidate)
   
   (contextPolicyGateFacts
      (candidateRequiresFrame $candidate)
      (frameBundleHasCurrent $bundle)
      (frameBundleActive $bundle)
      (frameBundleModeCompatible $bundle)
      (frameBundleBudgetOpen $bundle)))

;; Constitutional modes are a monotonic tightening layer. They may reject an
;; otherwise feasible candidate, but they never admit a candidate rejected by
;; the base action-policy gate.
; Constitutional policy is a tightening layer. Example:
;;   `(constitutionalModeGate execute-skill)` rejects operational work in
;;   Sleep mode with `SleepModeOperationalWork`; it never overrides a base
;;   policy rejection.
(= (constitutionalModeGate $candidate)
   (if (and (== (constitutionalMode) Sleep)
            (candidateRequiresFrame $candidate))
       (GateDecision Rejected SleepModeOperationalWork)
       (GateDecision Admitted Feasible)))

(= (feasibilityGate $bundle $candidate)
   ;; Use this as the complete single-candidate admission check:
   ;;   `(feasibilityGate $bundle respond)`.
   ;; The base context gate runs first; constitutional mode can then further
   ;; reject an otherwise feasible candidate.
   (let (GateDecision $baseAdmission $baseReason)
           (contextPolicyGate $bundle $candidate)
      (if (== $baseAdmission Rejected)
          (GateDecision Rejected $baseReason)
          (constitutionalModeGate $candidate))))

(= (contextPolicyGateFacts False $_ $_ $_ $_)
   (GateDecision Admitted Feasible))
(= (contextPolicyGateFacts True False $_ $_ $_)
   (GateDecision Rejected NoActiveFrame))
(= (contextPolicyGateFacts True True False $_ $_)
   (GateDecision Rejected InactiveFrame))
(= (contextPolicyGateFacts True True True False $_)
   (GateDecision Rejected FrameModeMismatch))
(= (contextPolicyGateFacts True True True True False)
   (GateDecision Rejected BudgetExhausted))
(= (contextPolicyGateFacts True True True True True)
   (GateDecision Admitted Feasible))
;; Boolean convenience form:
   ;;   `(candidateAdmitted $bundle respond)` -> `True` or `False`.
   ;; Use `feasibilityGate` instead when the rejection reason is needed.
(= (candidateAdmitted $bundle $candidate)
   
   (let (GateDecision $admission $reason) (feasibilityGate $bundle $candidate)
      (== $admission Admitted)))

;; Example with adapter actions:
   ;;   `(feasibilityGateActions $bundle (action-list))` returns `True` only
   ;;   when every action in the list is admitted. This predicate checks all
   ;;   actions; it does not remove rejected actions from the list.
(= (feasibilityGateActions $bundle ()) True)
(= (feasibilityGateActions $bundle $actions)
   (let* (
      (($head $tail) (decons-atom $actions))
      ($gate (feasibilityGate $bundle (actionId $head)))
      ((GateDecision $admission $reason) $gate))
      (and (== $admission Admitted)
           (feasibilityGateActions $bundle $tail))))

!(import! &self (library MetaMo applications/omegaclaw_v1/contexts/request_admission))
