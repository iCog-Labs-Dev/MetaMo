
(: TransitionResult Type)
(: transitionResult (-> Expression MotivationState TransitionResult))

;; Return the action from a canonical transition result.
;; Example: (transitionAction (transitionResult action state)) -> action
(= (transitionAction (transitionResult $action $nextState))
    $action
)

;; Return the next state from a canonical transition result.
;; Example: (transitionState (transitionResult action state)) -> state
(= (transitionState (transitionResult $action $nextState))
    $nextState
)


;; Canonical bimonad with explicit policies.

(: TransitionComputation Type)
(: transitionComputation (-> Expression MotivationState Number GoalChangeFeedback TransitionComputation))

(: MetaMoPseudoBimonad Type)
(: metaMoPseudoBimonad (-> OpenPsiAppraisal MagusDecision StabilityPolicy CoherencePolicy Expression Expression MetaMoPseudoBimonad))

;; Return action from a canonical transition computation.
;; Example: (transitionComputationAction (transitionComputation action state 0.0 feedback)) -> action
(= (transitionComputationAction (transitionComputation $action $state $projectionDelta $feedback))
    $action
)

;; Return state from a canonical transition computation.
;; Example: (transitionComputationState (transitionComputation action state 0.0 feedback)) -> state
(= (transitionComputationState (transitionComputation $action $state $projectionDelta $feedback))
    $state
)

;; Return projection delta from a canonical transition computation.
;; Example: (transitionComputationProjectionDelta (transitionComputation action state 0.1 feedback)) -> 0.1
(= (transitionComputationProjectionDelta (transitionComputation $action $state $projectionDelta $feedback))
    $projectionDelta
)

;; Return feedback from a canonical transition computation.
;; Example: (transitionComputationFeedback (transitionComputation action state 0.0 feedback)) -> feedback
(= (transitionComputationFeedback (transitionComputation $action $state $projectionDelta $feedback))
    $feedback
)

;; Return the canonical appraisal object.
;; Example: (bimonadAppraisal bimonad) -> appraisal
(= (bimonadAppraisal (metaMoPseudoBimonad $appraisal $decision $stability $coherence $merge $history))
    $appraisal
)

;; Return the canonical decision object.
;; Example: (bimonadDecision bimonad) -> decision
(= (bimonadDecision (metaMoPseudoBimonad $appraisal $decision $stability $coherence $merge $history))
    $decision
)

;; Return the canonical stability policy.
;; Example: (bimonadStability bimonad) -> policy
(= (bimonadStability (metaMoPseudoBimonad $appraisal $decision $stability $coherence $merge $history))
    $stability
)

;; Return the canonical coherence policy.
;; Example: (bimonadCoherence bimonad) -> policy
(= (bimonadCoherence (metaMoPseudoBimonad $appraisal $decision $stability $coherence $merge $history))
    $coherence
)

;; Return the canonical merge policy.
;; Example: (bimonadMerge bimonad) -> merge-policy
(= (bimonadMerge (metaMoPseudoBimonad $appraisal $decision $stability $coherence $merge $history))
    $merge
)

;; Return diagnostics history data.
;; Example: (bimonadHistory bimonad) -> ()
(= (bimonadHistory (metaMoPseudoBimonad $appraisal $decision $stability $coherence $merge $history))
    $history
)

;; Compute a single feature/feedback snapshot for a stimulus.
;; Example: (bimonadFeedback bimonad state stimulus) -> (goalChangeFeedback ())
(= (bimonadFeedback $bimonad $state $stimulus)
    (openPsiGoalChangeFeedback (bimonadAppraisal $bimonad) $state $stimulus)
)

;; Build the canonical post-appraisal decision context.
;; Example: (decisionContext bimonad state stimulus) -> appraised-state
(= (decisionContext $bimonad $state $stimulus)
    (raiseBoundaryCaution
        (bimonadStability $bimonad)
        (openPsiAppraise (bimonadAppraisal $bimonad) $state $stimulus)
    )
)

;; Apply a proposed canonical Delta G and return projection telemetry.
;; Example: (stateFromDeltaComputation bimonad state delta feedback) -> transition-computation
(= (stateFromDeltaComputation $bimonad $decisionState $proposedDeltaG $feedback)
    (let* (
        ($stability (bimonadStability $bimonad))
        ($dampedDeltaG (eval (applyHomeostaticDamping $stability $decisionState $proposedDeltaG)))
        ($addedGoals (eval (vectorAdd (stateGoals $decisionState) $dampedDeltaG)))
        ($nextGoals (eval (clipVector $addedGoals 0.0 1.0)))
        ($rawNext (motivationState (stateSchema $decisionState) $nextGoals (stateModulators $decisionState)))
        ($projected (eval (projectToSafeRegion $stability $rawNext)))
        ($projectionDelta (eval (stateDistance $rawNext $projected)))
    )
        (transitionComputation none $projected $projectionDelta $feedback)
    )
)

;; Compute one canonical transition before runtime fallback checks.
;; Example: (computeTransition bimonad state stimulus candidates) -> transition-computation
(= (computeTransition $bimonad $state $stimulus $candidates)
    (let* (
        ($feedback (eval (bimonadFeedback $bimonad $state $stimulus)))
        ($decisionState (eval (decisionContext $bimonad $state $stimulus)))
        ($decisionResult (eval (magusDecide (bimonadDecision $bimonad) $decisionState $candidates $feedback)))
        ($action (eval (decisionAction $decisionResult)))
        ($deltaG (eval (decisionDeltaG $decisionResult)))
        ($stateComputation (eval (stateFromDeltaComputation $bimonad $decisionState $deltaG $feedback)))
        ($computedState (eval (transitionComputationState $stateComputation)))
        ($computedProjectionDelta (eval (transitionComputationProjectionDelta $stateComputation)))
    )
        (transitionComputation
            $action
            $computedState
            $computedProjectionDelta
            $feedback
        )
    )
)

;; Build a local canonical reference state for contractivity probing.
;; Example: (localReferenceState state next) -> nearby-state
(= (localReferenceState $state $nextState)
    (let* (
        ($goalDifference (eval (listDifference (stateGoals $nextState) (stateGoals $state))))
        ($modulatorDifference (eval (listDifference (stateModulators $nextState) (stateModulators $state))))
        ($goalProbe (eval (probeVector $goalDifference 0.01 1e-6)))
        ($modProbe (eval (probeVector $modulatorDifference 0.01 1e-6)))
        ($probeGoalsAdded (eval (vectorAdd (stateGoals $state) $goalProbe)))
        ($probeModsAdded (eval (vectorAdd (stateModulators $state) $modProbe)))
        ($probeGoals (eval (clipVector $probeGoalsAdded 0.0 1.0)))
        ($probeMods (eval (clipVector $probeModsAdded 0.0 1.0)))
    )
        (motivationState
            (stateSchema $state)
            $probeGoals
            $probeMods
        )
    )
)

;; Apply and project conservative canonical fallback.
;; Example: (applyConservativeFallback bimonad current next) -> fallback-state
(= (applyConservativeFallback $bimonad $currentState $nextState)
    (let* (
        ($averageGoals (eval (averageArrays (stateGoals $currentState) (stateGoals $nextState))))
        ($averageMods (eval (averageArrays (stateModulators $currentState) (stateModulators $nextState))))
        ($fallbackGoals (eval (clipVector $averageGoals 0.0 1.0)))
        ($fallbackMods (eval (clipVector $averageMods 0.0 1.0)))
        ($fallbackState (motivationState
            (stateSchema $currentState)
            $fallbackGoals
            $fallbackMods
        ))
    )
        (eval
            (projectToSafeRegion
                (bimonadStability $bimonad)
                $fallbackState
            )
        )
    )
)

;; Build fallback transition details after law/safety guard failure.
;; Example: (targetTransitionFallbackComputation bimonad current next computation) -> transition-computation
(= (targetTransitionFallbackComputation $bimonad $state $nextState $computation)
    (let* (
        ($fallback (eval (applyConservativeFallback $bimonad $state $nextState)))
        ($extraDelta (eval (stateDistance $nextState $fallback)))
        ($action (eval (transitionComputationAction $computation)))
        ($projectionDelta (eval (transitionComputationProjectionDelta $computation)))
        ($combinedProjectionDelta (eval (+ $projectionDelta $extraDelta)))
        ($feedback (eval (transitionComputationFeedback $computation)))
    )
        (transitionComputation
            $action
            $fallback
            $combinedProjectionDelta
            $feedback
        )
    )
)

;; Dispatch target transition result by an already-reduced guard.
;; Example: (targetTransitionFromGuard True bimonad state next computation) -> computation
(= (targetTransitionFromGuard True $bimonad $state $nextState $computation)
    $computation
)

(= (targetTransitionFromGuard False $bimonad $state $nextState $computation)
    (targetTransitionFallbackComputation $bimonad $state $nextState $computation)
)

;; Measure the canonical lax distributive law.
;; Example: (measureLaxDistributiveLaw bimonad state stimulus candidates 0.01) -> law-check
(= (measureLaxDistributiveLaw $bimonad $state $stimulus $candidates $tolerance)
    (let* (
        ($feedback (bimonadFeedback $bimonad $state $stimulus))
        ($decisionState1 (decisionContext $bimonad $state $stimulus))
        ($decisionResult1 (magusDecide (bimonadDecision $bimonad) $decisionState1 $candidates $feedback))
        ($final1 (transitionComputationState (stateFromDeltaComputation $bimonad $decisionState1 (decisionDeltaG $decisionResult1) $feedback)))
        ($decisionResult2 (magusDecide (bimonadDecision $bimonad) $state $candidates $feedback))
        ($decidedState2 (transitionComputationState (stateFromDeltaComputation $bimonad $state (decisionDeltaG $decisionResult2) $feedback)))
        ($final2 (decisionContext $bimonad $decidedState2 $stimulus))
        ($error (stateDistance $final1 $final2))
    )
        (lawCheckResult modular-appraisal-decision-interface $final1 $final2 $error $tolerance (<= $error $tolerance))
    )
)

;; Compute the stabilized target transition with fallback checks.
;; Example: (targetTransitionDetails bimonad state stimulus candidates) -> transition-computation
(= (targetTransitionDetails $bimonad $state $stimulus $candidates)
    (let* (
        ($computation (eval (computeTransition $bimonad $state $stimulus $candidates)))
        ($nextState (eval (transitionComputationState $computation)))
        ($referenceState (eval (localReferenceState $state $nextState)))
        ($lax (eval (measureLaxDistributiveLaw $bimonad $state $stimulus $candidates 0.01)))
        ($contractive (eval (checkContractiveUpdateLaw (bimonadStability $bimonad) $bimonad $state $referenceState $stimulus $candidates)))
        ($safe (eval (isInSafeRegion (bimonadStability $bimonad) $nextState)))
        ($guard (eval (and (eval (lawCheckHolds $lax)) (and $contractive $safe))))
    )
        (targetTransitionFromGuard $guard $bimonad $state $nextState $computation)
    )
)

;; Return the target-only transition result.
;; Example: (stepTargetOnly bimonad state stimulus candidates) -> transitionResult
(= (stepTargetOnly $bimonad $state $stimulus $candidates)
    (let* (
        ($target (eval (targetTransitionDetails $bimonad $state $stimulus $candidates)))
        ($action (eval (transitionComputationAction $target)))
        ($targetState (eval (transitionComputationState $target)))
    )
        (transitionResult $action $targetState)
    )
)

;; Return the embodied canonical transition result.
;; Example: (stepEmbodied bimonad state stimulus candidates) -> transitionResult
(= (stepEmbodied $bimonad $state $stimulus $candidates)
    (let* (
        ($target (eval (targetTransitionDetails $bimonad $state $stimulus $candidates)))
        ($action (eval (transitionComputationAction $target)))
        ($targetState (eval (transitionComputationState $target)))
        ($blend (eval (measureBlend (bimonadCoherence $bimonad) $state $targetState)))
        ($nextState (eval (blendResultState $blend)))
    )
        (transitionResult $action $nextState)
    )
)

;; Execute a diagnosed canonical step.
;; Example: (stepWithDiagnostics bimonad state stimulus candidates True) -> diagnosed-transition
(= (stepWithDiagnostics $bimonad $state $stimulus $candidates $embody)
    (let* (
        ($stability (bimonadStability $bimonad))
        ($target (eval (targetTransitionDetails $bimonad $state $stimulus $candidates)))
        ($action (eval (transitionComputationAction $target)))
        ($targetState (eval (transitionComputationState $target)))
        ($blend (eval (if $embody
            (eval (measureBlend (bimonadCoherence $bimonad) $state $targetState))
            (let* (
                ($driftForNoEmbodiment (eval (measureSelfModelDrift (bimonadCoherence $bimonad) $state $targetState)))
            )
                (blendResult
                    $targetState
                    1.0
                    1.0
                    $driftForNoEmbodiment
                )
            )
        )))
        ($nextState (eval (blendResultState $blend)))
        ($lax (eval (measureLaxDistributiveLaw $bimonad $state $stimulus $candidates 0.01)))
        ($referenceState (eval (localReferenceState $state $targetState)))
        ($contractive (eval (checkContractiveUpdateLaw $stability $bimonad $state $referenceState $stimulus $candidates)))
        ($drift (eval (blendResultDrift $blend)))
        ($diagnostics
            (metaMoDiagnostics
                (candidateId $action)
                (eval (lawCheckError $lax))
                (eval (lawCheckTolerance $lax))
                (eval (lawCheckHolds $lax))
                $contractive
                (eval (isInSafeRegion $stability $targetState))
                (eval (isInSafeRegion $stability $nextState))
                (eval (boundaryPressure $stability $state))
                (eval (boundaryPressure $stability $targetState))
                (eval (boundaryPressure $stability $nextState))
                (eval (transitionComputationProjectionDelta $target))
                (eval (stateDistance $state $targetState))
                (eval (selfModelStateDistance $drift))
                (eval (selfModelDistanceMeasured $drift))
                (eval (selfModelCombinedDrift $drift))
                (eval (selfModelDriftHolds $drift))
                (eval (blendResultAlpha $blend))
                (eval (blendResultBaseAlpha $blend))
            )
        )
    )
        (diagnosedTransition $action $nextState $diagnostics)
    )
)

;; Compatibility alias for the embodied canonical step.
;; Example: (step bimonad state stimulus candidates) -> transitionResult
(= (step $bimonad $state $stimulus $candidates)
    (stepEmbodied $bimonad $state $stimulus $candidates)
)
