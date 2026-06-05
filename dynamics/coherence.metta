;; Coherence dynamics helpers
;;
;; These functions operate on MotivationalState values:
;;   (motivation $goals $modulators)
;;
;; Required definitions are provided by the core/OpenPSI modules used by tests:
;;   ../../core/helper
;;   ../../core/state
;;   ../../core/state_accessors
;;   ../../core/config
;;   ../../openpsi/config
;;
;; Typical usage:
;;   (blendStates currentState targetState 1.0 0.25 0.5)

;; calculateBlendFactor
;;
;; Compute the base blend factor for a motivational state from the OpenPSI
;; individuation and transcendence goals.
;;
;; Formula:
;;   alpha = ALPHA_0 * (1.0 - gInd) + BETA_0 * gTrans
;;
;; The result is clipped to [0.0, 1.0].
;;
;; Parameters:
;;   $state - a motivation state with GoalIndex atoms for gInd and gTrans.
;;
;; Returns:
;;   Number in [0.0, 1.0].
;;
;; Example:
;;   (calculateBlendFactor
;;     (motivation (0.2 0.8 0.5 0.5 0.5 0.5 0.5 0.5)
;;                 (0.1 0.2 0.3 0.4 0.5 0.6)))
;;   => 0.2
(= (calculateBlendFactor $state)
    (let* (
      ($gInd (getGoal $state gInd))
      ($gTrans (getGoal $state gTrans))
      ($alpha (+ (* (ALPHA_0) (- 1.0 $gInd)) (* (BETA_0) $gTrans)))
    )
     (npClip $alpha 0.0 1.0) 
    )
)


;; checkSelfModelDrift
;;
;; Estimate whether the transition from one motivational state to another
;; stays within an allowed self-model drift bound.
;;
;; The drift approximation is:
;;   lipschitzConstant * motivationStateDistance(currentState, nextState)
;;
;; Parameters:
;;   $currentState       - current motivation state.
;;   $nextState          - candidate next motivation state.
;;   $lipschitzConstant  - multiplier used to approximate model drift.
;;   $maxAllowedDrift    - maximum allowed approximated drift.
;;
;; Returns:
;;   True when approximated drift is <= maxAllowedDrift, otherwise False.
;;
;; Example:
;;   (checkSelfModelDrift
;;     (motivation (0.0 0.0) (0.0 0.0))
;;     (motivation (0.3 0.4) (0.0 0.0))
;;     2.0
;;     1.0)
;;   => True
(= (checkSelfModelDrift $currentState $nextState $lipschitzConstant $maxAllowedDrift)
    (let* (
       ($distanceMoved (motivationStateDistance $currentState $nextState))
       ($approximatedDrift (* $lipschitzConstant $distanceMoved))
    )
      (<= $approximatedDrift $maxAllowedDrift)
    )
)

;; nextStateCalculator
;;
;; Build an alpha-weighted next-state candidate from currentState toward
;; targetState.
;;
;; Parameters:
;;   $currentState - current motivation state.
;;   $targetState  - desired target motivation state.
;;   $alpha        - blend factor used to move toward the target.
;;
;; Returns:
;;   A motivation state.
;;
;; Example:
;;   (nextStateCalculator
;;     (motivation (0.2 0.8) (0.1 0.2))
;;     (motivation (0.4 0.6) (0.2 0.3))
;;     0.2)
;;   => (motivation (0.24 0.76) (0.12 0.22))
(= (nextStateCalculator $currentState $targetState $alpha)
    (stateTowardTarget $currentState $targetState $alpha)
)

;; stateTowardTarget
;;
;; Build an alpha-weighted transition candidate from currentState toward
;; targetState.
(= (stateTowardTarget $currentState $targetState $alpha)
    (if (== $currentState $targetState)
        $currentState
        (motivation
            (blendArrays (motivationGoals $currentState) (motivationGoals $targetState) $alpha)
            (blendArrays (motivationModulators $currentState) (motivationModulators $targetState) $alpha)
        )
    )
)


;; blendStatesHelper
;;
;; Recursive worker for blendStates. It checks whether the target transition
;; respects the drift bound, or whether alpha has reached the minimum allowed
;; alpha. If either condition is met, it returns the current candidate next
;; state. Otherwise, it computes a smaller partial transition and recurses.
;;
;; Parameters:
;;   $currentState       - original state used for drift checking.
;;   $nextState          - current candidate state.
;;   $targetState        - desired target state.
;;   $alpha              - current blend factor.
;;   $minAlpha           - minimum alpha threshold.
;;   $lipschitzConstant  - multiplier used by checkSelfModelDrift.
;;   $maxAllowedDrift    - maximum allowed approximated drift.
;;
;; Returns:
;;   A motivation state accepted by the drift/min-alpha criteria.
;;
;; Example:
;;   (blendStatesHelper currentState nextState targetState 0.2 0.02 1.0 10.0)
(= (blendStatesHelper $currentState $nextState $targetState $alpha $minAlpha $lipschitzConstant $maxAllowedDrift)
    (let* (
        ($selfModelDrift (checkSelfModelDrift $currentState $nextState $lipschitzConstant $maxAllowedDrift))
        ($nextAlpha (* 0.5 $alpha))
        ($nextState' (stateTowardTarget $currentState $targetState $nextAlpha))
    )
        (if (or $selfModelDrift (<= $alpha $minAlpha))
            $nextState
            (blendStatesHelper $currentState $nextState' $targetState $nextAlpha $minAlpha $lipschitzConstant $maxAllowedDrift)
        )  
    )
    
)


;; blendStates
;;
;; Public entry point for coherence-preserving state blending. It calculates
;; a base alpha from the current state, derives a minimum alpha threshold, and
;; delegates the bounded transition logic to blendStatesHelper.
;;
;; Parameters:
;;   $currentState       - current motivation state.
;;   $targetState        - desired target motivation state.
;;   $lipschitzConstant  - multiplier used by checkSelfModelDrift.
;;   $maxAllowedDrift    - maximum allowed approximated drift.
;;   $minAlphaScale      - scale applied to base alpha to derive minAlpha.
;;
;; Returns:
;;   A motivation state accepted by the coherence checks.
;;
;; Example:
;;   (blendStates currentState targetState 1.0 0.25 0.5)
(= (blendStates $currentState $targetState $lipschitzConstant $maxAllowedDrift $minAlphaScale)
    (let* (
        ($baseAlpha (calculateBlendFactor $currentState))
        ($alpha $baseAlpha)
        ($minAlpha (* $minAlphaScale $baseAlpha))
        ($nextState (stateTowardTarget $currentState $targetState $alpha))
    )
        (blendStatesHelper $currentState $nextState $targetState $alpha $minAlpha $lipschitzConstant $maxAllowedDrift)
    )
)
