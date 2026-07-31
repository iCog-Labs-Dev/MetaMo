(: ResearchAssistantEngineState Type)
(: researchAssistantEngineState (-> MotivationState MotivationState Expression Expression Expression ResearchAssistantEngineState))

(: ResearchAssistantPreparedCycle Type)
(: researchAssistantPreparedCycle (-> ResearchAssistantPerception ResearchAssistantCalibrationResult ResearchAssistantPerception MotivationState Expression Expression ResearchAssistantPreparedCycle))

(: ResearchAssistantCycleResult Type)
(: researchAssistantCycleResult (-> ResearchAssistantEngineState AssistantResponse Expression ResearchAssistantPreparedCycle ResearchAssistantCycleResult))

;; Return the operation order frozen from the Python engine.
(= (researchAssistantEngineOperationOrder)
    (
        perceive_once
        calibrate_once
        merge_current_states
        build_shared_candidates_once
        run_curiosity_diagnosed_step
        run_ethics_diagnosed_step
        simulate_reciprocal_translation
        calculate_consensus_target
        request_final_response
        commit_next_states
        assemble_diagnostics
    )
)

;; Return curiosity perspective state.
(= (researchAssistantEngineCuriosityState (researchAssistantEngineState $curiosityState $ethicsState $history $diagnostics $paperContext))
    $curiosityState
)

;; Return ethics perspective state.
(= (researchAssistantEngineEthicsState (researchAssistantEngineState $curiosityState $ethicsState $history $diagnostics $paperContext))
    $ethicsState
)

;; Return conversation history.
(= (researchAssistantEngineHistory (researchAssistantEngineState $curiosityState $ethicsState $history $diagnostics $paperContext))
    $history
)

;; Return diagnostics history.
(= (researchAssistantEngineDiagnosticsHistory (researchAssistantEngineState $curiosityState $ethicsState $history $diagnostics $paperContext))
    $diagnostics
)

;; Return active paper context.
(= (researchAssistantEnginePaperContext (researchAssistantEngineState $curiosityState $ethicsState $history $diagnostics $paperContext))
    $paperContext
)

;; Build the initial two-perspective engine state.
(= (researchAssistantInitialEngineState)
    (researchAssistantEngineState
        (researchAssistantCuriosityState)
        (researchAssistantEthicsState)
        ()
        ()
        no_paper_context
    )
)

;; Replace paper context without mutating motivational state.
(= (researchAssistantSetPaperContext $engineState $paperContext)
    (researchAssistantEngineState
        (researchAssistantEngineCuriosityState $engineState)
        (researchAssistantEngineEthicsState $engineState)
        (researchAssistantEngineHistory $engineState)
        (researchAssistantEngineDiagnosticsHistory $engineState)
        $paperContext
    )
)

;; Merge the current curiosity and ethics states through the application bimonad policy.
(= (researchAssistantMergePerspectiveStates $curiosityState $ethicsState)
    (let* (
        ($bimonad (eval (researchAssistantBimonad)))
    )
        (eval
            (parallelMerge
                (bimonadMerge $bimonad)
                (bimonadDecision $bimonad)
                $curiosityState
                $ethicsState
            )
        )
    )
)

;; Build the current mood map from the merged state.
(= (researchAssistantCurrentMoodFromMerged $mergedState)
    (
        (arousal (stateModulator $mergedState arousal))
        (caution (stateModulator $mergedState securing))
    )
)

;; Prepare a full cycle exactly once per raw perception.
(= (researchAssistantPrepareCycle $engineState $rawPerception)
    (let* (
        ($calibration (eval (calibrateResearchAssistantPerception $rawPerception)))
        ($perception (eval (researchAssistantCalibrationPerception $calibration)))
        ($mergedCurrent (eval (researchAssistantMergePerspectiveStates
            (researchAssistantEngineCuriosityState $engineState)
            (researchAssistantEngineEthicsState $engineState)
        )))
        ($mood (eval (researchAssistantCurrentMoodFromMerged $mergedCurrent)))
        ($candidates (eval (researchAssistantBuildCandidates $perception $mood)))
    )
        (researchAssistantPreparedCycle
            $rawPerception
            $calibration
            $perception
            $mergedCurrent
            $mood
            $candidates
        )
    )
)

;; Return calibrated perception from prepared cycle.
(= (researchAssistantPreparedPerception (researchAssistantPreparedCycle $raw $calibration $perception $mergedCurrent $mood $candidates))
    $perception
)

;; Return candidates from prepared cycle.
(= (researchAssistantPreparedCandidates (researchAssistantPreparedCycle $raw $calibration $perception $mergedCurrent $mood $candidates))
    $candidates
)

;; Return calibration from prepared cycle.
(= (researchAssistantPreparedCalibration (researchAssistantPreparedCycle $raw $calibration $perception $mergedCurrent $mood $candidates))
    $calibration
)

;; Return raw perception from prepared cycle.
(= (researchAssistantPreparedRawPerception (researchAssistantPreparedCycle $raw $calibration $perception $mergedCurrent $mood $candidates))
    $raw
)

;; Run a diagnosed local step for one perspective.
(= (researchAssistantDiagnosedStep $state $perception $candidates)
    (let* (
        ($bimonad (eval (researchAssistantBimonad)))
    )
        (eval (stepWithDiagnostics
            $bimonad
            $state
            $perception
            $candidates
            True
        ))
    )
)

;; Target-only step used by diagnostics that intentionally inspect stabilized targets.
(= (researchAssistantTargetStepFn $state $perception $candidates)
    (let* (
        ($bimonad (eval (researchAssistantBimonad)))
    )
        (eval (stepTargetOnly
            $bimonad
            $state
            $perception
            $candidates
        ))
    )
)

;; Embodied step used by Python-equivalent reciprocal simulation.
(= (researchAssistantEmbodiedStepFn $state $perception $candidates)
    (let* (
        ($bimonad (eval (researchAssistantBimonad)))
    )
        (eval (stepEmbodied
            $bimonad
            $state
            $perception
            $candidates
        ))
    )
)

;; Score a candidate by two contexts with a disagreement penalty.
(= (researchAssistantConsensusScore $decision $contextA $contextB $candidate)
    (let* (
        ($scoreA (eval (magusScore $decision $contextA $candidate)))
        ($scoreB (eval (magusScore $decision $contextB $candidate)))
        ($mean (eval (/ (+ $scoreA $scoreB) 2.0)))
        ($disagreement (eval (absNumber (- $scoreA $scoreB))))
    )
        (eval (- $mean (* 0.25 $disagreement)))
    )
)

;; Recursive consensus candidate selection that preserves first candidate on ties.
(= (researchAssistantConsensusBestLoop $decision $contextA $contextB $currentBest $currentScore $remaining)
    (if (== $remaining ())
        $currentBest
        (let* (
            (($head $rest) (decons $remaining))
            ($headScore (eval (researchAssistantConsensusScore $decision $contextA $contextB $head)))
        )
            (if (eval (> $headScore $currentScore))
                (researchAssistantConsensusBestLoop $decision $contextA $contextB $head $headScore $rest)
                (researchAssistantConsensusBestLoop $decision $contextA $contextB $currentBest $currentScore $rest)
            )
        )
    )
)

;; Select the consensus action candidate.
(= (researchAssistantConsensusAction $decision $contextA $contextB $candidates)
    (let* (
        (($first $rest) (decons $candidates))
        ($firstScore (eval (researchAssistantConsensusScore $decision $contextA $contextB $first)))
    )
        (researchAssistantConsensusBestLoop $decision $contextA $contextB $first $firstScore $rest)
    )
)

;; Propose profile-derived Delta G for a selected action.
(= (researchAssistantDecisionDeltaForAction (magusDecision $profile $goalChangeFn $lambdaInd $lambdaTrans) $state $action $feedback)
    (profiledMagusProposeDeltaG $goalChangeFn $profile $state $action $feedback $lambdaInd $lambdaTrans)
)

;; Build the consensus action and merged target state.
(= (researchAssistantConsensusTransition $curiosityState $ethicsState $perception $candidates)
    (let* (
        ($bimonad (eval (researchAssistantBimonad)))
        ($decision (eval (bimonadDecision $bimonad)))
        ($contextC (eval (decisionContext $bimonad $curiosityState $perception)))
        ($contextE (eval (decisionContext $bimonad $ethicsState $perception)))
        ($action (eval (researchAssistantConsensusAction $decision $contextC $contextE $candidates)))
        ($feedbackC (eval (bimonadFeedback $bimonad $curiosityState $perception)))
        ($feedbackE (eval (bimonadFeedback $bimonad $ethicsState $perception)))
        ($deltaC (eval (researchAssistantDecisionDeltaForAction $decision $contextC $action $feedbackC)))
        ($deltaE (eval (researchAssistantDecisionDeltaForAction $decision $contextE $action $feedbackE)))
        ($targetCComputation (eval (stateFromDeltaComputation $bimonad $contextC $deltaC $feedbackC)))
        ($targetEComputation (eval (stateFromDeltaComputation $bimonad $contextE $deltaE $feedbackE)))
        ($targetC (eval (transitionComputationState $targetCComputation)))
        ($targetE (eval (transitionComputationState $targetEComputation)))
        ($mergedTarget (eval (parallelMerge
            (bimonadMerge $bimonad)
            $decision
            $targetC
            $targetE
        )))
    )
        (transitionResult $action $mergedTarget)
    )
)

;; Extract reciprocal simulation target state.
(= (researchAssistantReciprocalTargetState
        (reciprocalSimulationResult $sourceAction $targetAction $translatedAfterSource $targetAfterTranslation $error $tolerance $holds)
    )
    $targetAfterTranslation
)

;; Estimate simulated caution from the reciprocal target state.
(= (researchAssistantSimulatedCaution $simulation)
    (let* (
        ($targetState (researchAssistantReciprocalTargetState $simulation))
    )
        (/ (+ (stateModulator $targetState threshold) (stateModulator $targetState securing)) 2.0)
    )
)

;; Return lax error from diagnostics.
(= (researchAssistantDiagnosticsLaxError
        (metaMoDiagnostics $actionId $laxError $laxTolerance $laxHolds $contractiveHolds $targetSafe $finalSafe $pressureBefore $pressureTarget $pressureFinal $projectionDelta $targetDistance $stateDrift $selfDrift $combinedDrift $selfDriftHolds $blendAlpha $baseBlendAlpha)
    )
    $laxError
)

;; Return self-model drift from diagnostics.
(= (researchAssistantDiagnosticsSelfModelDrift
        (metaMoDiagnostics $actionId $laxError $laxTolerance $laxHolds $contractiveHolds $targetSafe $finalSafe $pressureBefore $pressureTarget $pressureFinal $projectionDelta $targetDistance $stateDrift $selfDrift $combinedDrift $selfDriftHolds $blendAlpha $baseBlendAlpha)
    )
    $selfDrift
)

;; Commit the two next states, conversation turn, and diagnostics history.
(= (researchAssistantCommitCycle $engineState $userText $response $curiosityStep $ethicsStep)
    (researchAssistantEngineState
        (diagnosedState $curiosityStep)
        (diagnosedState $ethicsStep)
        (researchAssistantAppendTurn
            (researchAssistantEngineHistory $engineState)
            $userText
            (researchAssistantResponseText $response)
        )
        (listAppend
            (researchAssistantEngineDiagnosticsHistory $engineState)
            ((diagnosedDiagnostics $curiosityStep) (diagnosedDiagnostics $ethicsStep))
        )
        (researchAssistantEnginePaperContext $engineState)
    )
)

;; Run a complete pure cycle using already-adapted perception and provider output.
(= (researchAssistantRunCycle $engineState $userText $rawPerception $providerResult)
    (let* (
        ($prepared (eval (researchAssistantPrepareCycle $engineState $rawPerception)))
        ($perception (eval (researchAssistantPreparedPerception $prepared)))
        ($candidates (eval (researchAssistantPreparedCandidates $prepared)))
        ($curiosityStep (eval (researchAssistantDiagnosedStep
            (researchAssistantEngineCuriosityState $engineState)
            $perception
            $candidates
        )))
        ($ethicsStep (eval (researchAssistantDiagnosedStep
            (researchAssistantEngineEthicsState $engineState)
            $perception
            $candidates
        )))
        ($adapter (agentFrameAdapter
            (researchAssistantCuriosityToEthicsTranslation)
            none
            none
            none
        ))
        ($simulation (eval (checkReciprocalSimulation
            $adapter
            researchAssistantEmbodiedStepFn
            researchAssistantEmbodiedStepFn
            (researchAssistantEngineCuriosityState $engineState)
            $perception
            $candidates
            0.05
        )))
        ($consensus (eval (researchAssistantConsensusTransition
            (researchAssistantEngineCuriosityState $engineState)
            (researchAssistantEngineEthicsState $engineState)
            $perception
            $candidates
        )))
        ($chosenAction (eval (transitionAction $consensus)))
        ($mergedTarget (eval (transitionState $consensus)))
        ($diagnosticsC (eval (diagnosedDiagnostics $curiosityStep)))
        ($diagnosticsE (eval (diagnosedDiagnostics $ethicsStep)))
        ($response (eval (researchAssistantBuildResponse
            $userText
            (researchAssistantEnginePaperContext $engineState)
            $chosenAction
            $mergedTarget
            (candidateId (diagnosedAction $curiosityStep))
            (candidateId (diagnosedAction $ethicsStep))
            (researchAssistantSimulatedCaution $simulation)
            (reciprocalSimulationError $simulation)
            (maxNumber
                (researchAssistantDiagnosticsLaxError $diagnosticsC)
                (researchAssistantDiagnosticsLaxError $diagnosticsE)
            )
            (maxNumber
                (researchAssistantDiagnosticsSelfModelDrift $diagnosticsC)
                (researchAssistantDiagnosticsSelfModelDrift $diagnosticsE)
            )
            (researchAssistantPreparedCalibration $prepared)
            (researchAssistantPreparedRawPerception $prepared)
            $perception
            $providerResult
        )))
        ($nextEngineState (eval (researchAssistantCommitCycle
            $engineState
            $userText
            $response
            $curiosityStep
            $ethicsStep
        )))
        ($cycleDiagnostics
            (researchAssistantCycleDiagnostics
                (eval (candidateId (diagnosedAction $curiosityStep)))
                (eval (candidateId (diagnosedAction $ethicsStep)))
                (eval (candidateId $chosenAction))
                $simulation
                (eval (researchAssistantResponseProviderRequest
                    $userText
                    (researchAssistantEnginePaperContext $engineState)
                    $chosenAction
                    $mergedTarget
                ))
                (researchAssistantEngineOperationOrder)
            )
        )
    )
        (researchAssistantCycleResult
            $nextEngineState
            $response
            $cycleDiagnostics
            $prepared
        )
    )
)

;; Return next engine state from a cycle result.
(= (researchAssistantCycleNextEngine (researchAssistantCycleResult $nextEngine $response $diagnostics $prepared))
    $nextEngine
)

;; Return response from a cycle result.
(= (researchAssistantCycleResponse (researchAssistantCycleResult $nextEngine $response $diagnostics $prepared))
    $response
)
