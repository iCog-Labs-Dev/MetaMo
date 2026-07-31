(: ReciprocalSimulationResult Type)
(: reciprocalSimulationResult (-> Expression Expression MotivationState MotivationState Number Number Bool ReciprocalSimulationResult))

;; Return reciprocal simulation error.
;; Example: (reciprocalSimulationError result) -> 0.0
(= (reciprocalSimulationError (reciprocalSimulationResult $sourceAction $targetAction $translatedAfterSource $targetAfterTranslation $error $tolerance $holds))
    $error
)

;; Return reciprocal simulation hold flag.
;; Example: (reciprocalSimulationHolds result) -> True
(= (reciprocalSimulationHolds (reciprocalSimulationResult $sourceAction $targetAction $translatedAfterSource $targetAfterTranslation $error $tolerance $holds))
    $holds
)

;; Check reciprocal simulation for two update functions.
;; Example: (checkReciprocalSimulation adapter sourceUpdate targetUpdate sourceState stimulus candidates 0.05) -> result
(= (checkReciprocalSimulation $adapter $sourceUpdateFn $targetUpdateFn $sourceState $stimulus $candidates $tolerance)
    (let* (
        ($sourceResult (eval ($sourceUpdateFn $sourceState $stimulus $candidates)))
        ($sourceAction (eval (transitionAction $sourceResult)))
        ($sourceNext (eval (transitionState $sourceResult)))
        ($translatedAfterSource (eval (adapterNaturalTransform $adapter (eval (adapterTranslateState $adapter $sourceNext)))))
        ($translatedSource (eval (adapterTranslateState $adapter $sourceState)))
        ($targetStimulus (eval (adapterTranslateStimulus $adapter $stimulus)))
        ($targetCandidates (eval (adapterTranslateCandidates $adapter $candidates)))
        ($targetResult (eval ($targetUpdateFn $translatedSource $targetStimulus $targetCandidates)))
        ($targetAction (eval (transitionAction $targetResult)))
        ($targetNext (eval (transitionState $targetResult)))
        ($error (eval (stateDistance $translatedAfterSource $targetNext)))
        ($holds (eval (<= $error $tolerance)))
    )
        (reciprocalSimulationResult $sourceAction $targetAction $translatedAfterSource $targetNext $error $tolerance $holds)
    )
)

;; Measure canonical parallel compositionality for a bimonad.
;; Example: (measureParallelCompositionality bimonad stateA stateB stimulus candidates 0.01) -> law-check
(= (measureParallelCompositionality $bimonad $stateA $stateB $stimulus $candidates $tolerance)
    (let* (
        ($transitionA (computeTransition $bimonad $stateA $stimulus $candidates))
        ($transitionB (computeTransition $bimonad $stateB $stimulus $candidates))
        ($leftState (parallelMerge
            (bimonadMerge $bimonad)
            (bimonadDecision $bimonad)
            (transitionComputationState $transitionA)
            (transitionComputationState $transitionB)
        ))
        ($mergedState (parallelMerge (bimonadMerge $bimonad) (bimonadDecision $bimonad) $stateA $stateB))
        ($rightTransition (computeTransition $bimonad $mergedState $stimulus $candidates))
        ($rightState (transitionComputationState $rightTransition))
        ($error (stateDistance $leftState $rightState))
    )
        (lawCheckResult parallel-motivational-compositionality $leftState $rightState $error $tolerance (<= $error $tolerance))
    )
)
