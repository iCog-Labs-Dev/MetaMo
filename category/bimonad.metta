
(: TransitionResult Type)
(: transitionResult (-> ActionType MotivationalState TransitionResult))

(: BestCandidateResult Type)
(: bestCandidateResult (-> Number ActionType BestCandidateResult))

(: MetaMoPseudoBimonad Type)
(: metaMoPseudoBimonad
   (-> AppraisalComonad DecisionMonad Symbol Symbol Symbol Symbol Symbol MetaMoPseudoBimonad))

;; Extract the action from a TransitionResult.
;; Example: (transitionAction (transitionResult MOVE (motivation g m))) -> MOVE
(= (transitionAction (transitionResult $action $nextState))
    $action
)

;; Extract the next motivational state from a TransitionResult.
;; Example: (transitionState (transitionResult MOVE (motivation g m))) -> (motivation g m)
(= (transitionState (transitionResult $action $nextState))
    $nextState
)

;; Extract the score from a BestCandidateResult.
;; Example: (bestCandidateScore (bestCandidateResult 0.85 MOVE)) -> 0.85
(= (bestCandidateScore (bestCandidateResult $score $action))
    $score
)

;; Extract the optimal action from a BestCandidateResult.
;; Example: (bestCandidateAction (bestCandidateResult 0.85 MOVE)) -> MOVE
(= (bestCandidateAction (bestCandidateResult $score $action))
    $action
)

;; Extract the appraisal comonad from a MetaMoPseudoBimonad.
;; Example: (bimonadAppraisal myBimonad)
(= (bimonadAppraisal (metaMoPseudoBimonad $appraisal $decision $dampingFn $boundaryFn $projectFn $contractiveFn $safeFn))
    $appraisal
)

;; Extract the decision monad from a MetaMoPseudoBimonad.
;; Example: (bimonadDecision myBimonad)
(= (bimonadDecision (metaMoPseudoBimonad $appraisal $decision $dampingFn $boundaryFn $projectFn $contractiveFn $safeFn))
    $decision
)

;; Extract the damping function symbol from a MetaMoPseudoBimonad.
;; Example: (bimonadDampingSymbol myBimonad)
(= (bimonadDampingSymbol (metaMoPseudoBimonad $appraisal $decision $dampingFn $boundaryFn $projectFn $contractiveFn $safeFn))
    $dampingFn
)

;; Extract the boundary stabilization function symbol from a MetaMoPseudoBimonad.
;; Example: (bimonadBoundarySymbol myBimonad)
(= (bimonadBoundarySymbol (metaMoPseudoBimonad $appraisal $decision $dampingFn $boundaryFn $projectFn $contractiveFn $safeFn))
    $boundaryFn
)

;; Extract the projection function symbol from a MetaMoPseudoBimonad.
;; Example: (bimonadProjectSymbol myBimonad)
(= (bimonadProjectSymbol (metaMoPseudoBimonad $appraisal $decision $dampingFn $boundaryFn $projectFn $contractiveFn $safeFn))
    $projectFn
)

;; Extract the contractivity verification function symbol from a MetaMoPseudoBimonad.
;; Example: (bimonadContractiveSymbol myBimonad)
(= (bimonadContractiveSymbol (metaMoPseudoBimonad $appraisal $decision $dampingFn $boundaryFn $projectFn $contractiveFn $safeFn))
    $contractiveFn
)

;; Extract the safe region check function symbol from a MetaMoPseudoBimonad.
;; Example: (bimonadSafeRegionSymbol myBimonad)
(= (bimonadSafeRegionSymbol (metaMoPseudoBimonad $appraisal $decision $dampingFn $boundaryFn $projectFn $contractiveFn $safeFn))
    $safeFn
)

;; Build the post-appraisal state that the decision monad should score by appraising a stimulus and applying boundary stabilization.
;; Example: (decisionContext myBimonad currState stimulus)
(= (decisionContext
        (metaMoPseudoBimonad $appraisal $decision $dampingFn $boundaryFn $projectFn $contractiveFn $safeFn)
        $state
        $stimulus
   )
    (eval ($boundaryFn (appraise $appraisal $state $stimulus)))
)

;; Apply a proposed goal update (DeltaG) inside the stabilization path, including damping, clipping, and projection.
;; Example: (stateFromDelta myBimonad myDecisionState (0.05 -0.01))
(= (stateFromDelta
        (metaMoPseudoBimonad $appraisal $decision $dampingFn $boundaryFn $projectFn $contractiveFn $safeFn)
        $decisionState
        $proposedDeltaG
   )
    (let* (
        ($dampedDeltaG (eval ($dampingFn $decisionState $proposedDeltaG)))
        ($nextGoals (eval (clipVector
            (if (== $dampedDeltaG ())
                (motivationGoals $decisionState)
                (vectorAdd (motivationGoals $decisionState) $dampedDeltaG))
            0.0 1.0)))
        ($nextState (motivation $nextGoals (motivationModulators $decisionState)))
    )
        (eval ($projectFn $nextState))
    )
)

;; Compute one appraisal/decision transition (action and next state) before runtime validation.
;; Example: (computeTransition myBimonad currState stimulus (ACTION_A ACTION_B))
(= (computeTransition $bimonad $state $stimulus $candidates)
    (let* (
        ($decisionState (decisionContext $bimonad $state $stimulus))
        ($decisionResult (eval (decide (bimonadDecision $bimonad) $decisionState $candidates)))
        ($action (decisionAction $decisionResult))
        ($nextState (stateFromDelta $bimonad $decisionState (decisionDeltaG $decisionResult)))
    )
        (transitionResult $action $nextState)
    )
)

;; Build a nearby state to probe local contractivity by adding a small perturbation toward $nextState.
;; Example: (localReferenceState state1 state2)
(= (localReferenceState $state $nextState)
    (let* (
        ($goalProbe (probeVector (listDifference (motivationGoals $nextState) (motivationGoals $state)) 0.01 1e-6))
        ($modProbe (probeVector (listDifference (motivationModulators $nextState) (motivationModulators $state)) 0.01 1e-6))
        ($probeGoals (clipVector (vectorAdd (motivationGoals $state) $goalProbe) 0.0 1.0))
        ($probeMods (clipVector (vectorAdd (motivationModulators $state) $modProbe) 0.0 1.0))
    )
        (motivation $probeGoals $probeMods)
    )
)

;; Shrink the transition toward the current state by averaging when runtime checks fail.
;; Example: (applyConservativeFallback currentState proposedNextState)
(= (applyConservativeFallback $currentState $nextState)
    (motivation
        (eval (clipVector (averageArrays (motivationGoals $currentState) (motivationGoals $nextState)) 0.0 1.0))
        (eval (clipVector (averageArrays (motivationModulators $currentState) (motivationModulators $nextState)) 0.0 1.0))
    )
)

;; Calculate a consensus score from two subsystem evaluations, penalized by their difference.
;; Example: (candidateConsensusScore 0.8 0.9)
(= (candidateConsensusScore $scoreA $scoreB)
    (- (/ (+ $scoreA $scoreB) 2.0)
       (* 0.25 (absNumber (- $scoreA $scoreB))))
)

;; Compute the consensus value for a candidate given two separate decision contexts.
;; Example: (candidateConsensusValue myBimonad contextA contextB MOVE)
(= (candidateConsensusValue $bimonad $context1 $context2 $candidate)
    (candidateConsensusScore
        (eval (scoreCandidate (bimonadDecision $bimonad) $context1 $candidate))
        (eval (scoreCandidate (bimonadDecision $bimonad) $context2 $candidate))
    )
)

;; Recursive loop to find the candidate with the highest consensus score.
;; Example: (bestCandidateLoop ctx1 ctx2 MOVE 0.8 (STAY EAT) myBimonad)
(= (bestCandidateLoop $context1 $context2 $currentBest $currentScore $remaining $bimonad)
    (if (== $remaining ())
        (bestCandidateResult $currentScore $currentBest)
        (let* (
            (($head $rest) (decons $remaining))
            ($headScore (candidateConsensusValue $bimonad $context1 $context2 $head))
        )
            (if (> $headScore $currentScore)
                (bestCandidateLoop $context1 $context2 $head $headScore $rest $bimonad)
                (bestCandidateLoop $context1 $context2 $currentBest $currentScore $rest $bimonad)
            )
        )
    )
)

;; Find the best candidate based on consensus between two decision contexts.
;; Example: (bestCandidate ctx1 ctx2 (MOVE STAY) myBimonad)
(= (bestCandidate $context1 $context2 $candidates $bimonad)
    (let* (
        (($head $rest) (decons $candidates))
        ($headScore (candidateConsensusValue $bimonad $context1 $context2 $head))
    )
        (bestCandidateLoop $context1 $context2 $head $headScore $rest $bimonad)
    )
)

;; Select a shared action by combining evaluations from two states over the same candidate set.
;; Example: (consensusAction myBimonad stateA stateB stimulus (A B))
(= (consensusAction $bimonad $stateA $stateB $stimulus $candidates)
    (let* (
        ($contextA (decisionContext $bimonad $stateA $stimulus))
        ($contextB (decisionContext $bimonad $stateB $stimulus))
        ($bestResult (bestCandidate $contextA $contextB $candidates $bimonad))
    )
        (bestCandidateAction $bestResult)
    )
)


;; Compute the consensus target state by merging the results of an action applied to two different states.
;; Example: (consensusTargetState myBimonad stateA stateB stimulus MOVE 0.05)
(= (consensusTargetState $bimonad $stateA $stateB $stimulus $action $coherenceCorrection)
    (let* (
        ($contextA (decisionContext $bimonad $stateA $stimulus))
        ($contextB (decisionContext $bimonad $stateB $stimulus))
        ($targetA (stateFromDelta $bimonad $contextA (actionDeltaG $action)))
        ($targetB (stateFromDelta $bimonad $contextB (actionDeltaG $action)))
    )
        (eval (parallelMerge $targetA $targetB $coherenceCorrection))
    )
)

;; Build a coupled consensus action and consensus target state from a shared candidate set.
;; Example: (consensusTransition myBimonad stateA stateB stimulus (MOVE STAY) 0.05)
(= (consensusTransition $bimonad $stateA $stateB $stimulus $candidates $coherenceCorrection)
    (let* (
        ($action  (eval (consensusAction $bimonad $stateA $stateB $stimulus $candidates)))
        ($targetState (eval (consensusTargetState $bimonad $stateA $stateB $stimulus $action $coherenceCorrection)))
    )
        (transitionResult $action $targetState)
    )
)

;; Wrapper for consensusTransition with a default coherence correction of 0.05.
;; Example: (consensusTransitionDefault myBimonad stateA stateB stimulus candidates)
(= (consensusTransitionDefault $bimonad $stateA $stateB $stimulus $candidates)
    (consensusTransition $bimonad $stateA $stateB $stimulus $candidates 0.05)
)


;; Validates the First Principle: Modular Appraisal-Decision Interface (commutation of paths).
;; Example: (checkLaxDistributiveLaw myBimonad currState stimulus (A B))
(= (checkLaxDistributiveLaw $bimonad $state $stimulus $candidates)
    (let* (
        ;; Path 1: Appraise then Decide -> stabilized D(Psi(X))
        ($decisionState1 (decisionContext $bimonad $state $stimulus))
        ($decisionResult1 (decide (bimonadDecision $bimonad) $decisionState1 $candidates))
        ($finalState1 (stateFromDelta $bimonad $decisionState1 (decisionDeltaG $decisionResult1)))

        ;; Path 2: Decide then Appraise -> stabilized Psi(D(X))
        ($decisionResult2 (decide (bimonadDecision $bimonad) $state $candidates))
        ($decidedState2 (stateFromDelta $bimonad $state (decisionDeltaG $decisionResult2)))
        ($finalState2 (decisionContext $bimonad $decidedState2 $stimulus))
        
        ;; Calculate the controlled distortion distance
        ($distortion (motivationStateDistance $finalState1 $finalState2))
    )
        (if (<= $distortion (eval (LAX_DISTRIBUTIVE_DELTA)))
            True
            False
        )
    )
)

;; Execute one complete step of the MetaMo bimonad, including transition, validation, and fallback.
;; Example: (step myBimonad currState stimulus (MOVE STAY))
(= (step $bimonad $state $stimulus $candidates)
    (let* (
        ($transition (computeTransition $bimonad $state $stimulus $candidates))
        ($action (transitionAction $transition))
        ($nextState (transitionState $transition))
        ($referenceState (localReferenceState $state $nextState))
        
        ($laxOk (checkLaxDistributiveLaw $bimonad $state $stimulus $candidates))
        ($contractiveOk (eval ((bimonadContractiveSymbol $bimonad) $bimonad $state $referenceState $stimulus $candidates)))
        ($safeOk (eval ((bimonadSafeRegionSymbol $bimonad) $nextState)))
        ($stableState
            (if (and $laxOk (and $contractiveOk $safeOk))
                $nextState
                (applyConservativeFallback $state $nextState)
            )
        )
    )
        (transitionResult $action $stableState)
    )
)
