(: QwestorEngineState Type)
(: qwestorEngineStateRecord
    (-> MotivationState Expression Expression Expression Expression Number
        QwestorEngineState))

(: QwestorCandidateScore Type)
(: qwestorCandidateScoreRecord
    (-> ActionCandidate Number QwestorCandidateScore))

(: QwestorDecisionReport Type)
(: qwestorDecisionReportRecord
    (-> ActionCandidate Expression Number QwestorDecisionReport))

(: QwestorPreparedCycle Type)
(: qwestorPreparedCycleRecord
    (-> MotivationState QwestorPerception QwestorPerception Expression
        GoalChangeFeedback MotivationState Expression QwestorDecisionReport
        QwestorPreparedCycle))

(: QwestorEffectContext Type)
(: qwestorEffectContextRecord
    (-> Expression Expression Expression QwestorEffectContext))

(: QwestorEffectRequest Type)
(: qwestorEffectRequestRecord
    (-> Expression Symbol Symbol QwestorEffectContext QwestorEffectRequest))

(: QwestorEffectResult Type)
(: qwestorEffectResultRecord
    (-> Expression Expression QwestorEffectResult))

(: QwestorEngineDiagnostics Type)
(: qwestorEngineDiagnosticsRecord
    (-> Symbol Number Number Bool Number Bool Number Number Number Bool Bool
        QwestorEngineDiagnostics))

(: QwestorPendingTransition Type)
(: qwestorPendingTransitionRecord
    (-> Number MotivationState Expression QwestorEffectRequest
        QwestorEngineDiagnostics QwestorPreparedCycle QwestorPendingTransition))

(: QwestorCycleResult Type)
(: qwestorCycleResultRecord
    (-> QwestorEngineState QwestorEffectRequest QwestorEffectResult
        QwestorEngineDiagnostics QwestorPreparedCycle QwestorCycleResult))

(= (qwestorEngineState $engine)
    (qwestorEngineMotivationState $engine)
)

(= (qwestorEngineMotivationState
        (qwestorEngineStateRecord
            $state $pendingOutcome $history $diagnostics $completed $turn))
    $state
)

(= (qwestorEnginePendingOutcome
        (qwestorEngineStateRecord
            $state $pendingOutcome $history $diagnostics $completed $turn))
    $pendingOutcome
)

(= (qwestorEngineHistory
        (qwestorEngineStateRecord
            $state $pendingOutcome $history $diagnostics $completed $turn))
    $history
)

(= (qwestorEngineDiagnosticsHistory
        (qwestorEngineStateRecord
            $state $pendingOutcome $history $diagnostics $completed $turn))
    $diagnostics
)

(= (qwestorEngineCompletedRequestIds
        (qwestorEngineStateRecord
            $state $pendingOutcome $history $diagnostics $completed $turn))
    $completed
)

(= (qwestorEngineTurn
        (qwestorEngineStateRecord
            $state $pendingOutcome $history $diagnostics $completed $turn))
    $turn
)

(= (qwestorNewEngineState)
    (qwestorEngineStateRecord
        (qwestorDefaultState)
        none
        ()
        ()
        ()
        0
    )
)

(= (qwestorValidateEngineState $engine)
    (let* (
        ($state (qwestorEngineMotivationState $engine))
        ($stateResult (qwestorValidateState $state))
        ($outcomeResult
            (qwestorValidatePendingOutcome
                (qwestorEnginePendingOutcome $engine)))
    )
        (if (validationIsOk $stateResult)
            (if (validationIsOk $outcomeResult)
                (if (qwestorIsInSafeRegion (qwestorStabilityPolicy) $state)
                    (validationOk $engine)
                    (validationError unsafe-qwestor-engine-state $state)
                )
                $outcomeResult
            )
            $stateResult
        )
    )
)

(= (qwestorPendingOutcomeValue none)
    none
)

(= (qwestorPendingOutcomeValue
        (qwestorPendingOutcome $outcomeId $outcome))
    $outcome
)

(= (qwestorCandidateScoreCandidate
        (qwestorCandidateScoreRecord $candidate $score))
    $candidate
)

(= (qwestorCandidateScoreValue
        (qwestorCandidateScoreRecord $candidate $score))
    $score
)

(= (qwestorScoreCandidates $decision $state $candidates)
    (if (== $candidates ())
        ()
        (let* (
            (($head $tail) (decons $candidates))
        )
            (cons-atom
                (qwestorCandidateScoreRecord
                    $head
                    (magusScore $decision $state $head))
                (qwestorScoreCandidates $decision $state $tail)
            )
        )
    )
)

(= (qwestorBestCandidateScoreLoop $best $remaining)
    (if (== $remaining ())
        $best
        (let* (
            (($head $tail) (decons $remaining))
            ($nextBest
                (if (> (qwestorCandidateScoreValue $head)
                       (qwestorCandidateScoreValue $best))
                    $head
                    $best))
        )
            (qwestorBestCandidateScoreLoop $nextBest $tail)
        )
    )
)

(= (qwestorBestCandidateScore $scores)
    (let* (
        (($first $rest) (decons $scores))
    )
        (qwestorBestCandidateScoreLoop $first $rest)
    )
)

(= (qwestorRemoveCandidateScore $scores $candidateId)
    (if (== $scores ())
        ()
        (let* (
            (($head $tail) (decons $scores))
        )
            (if (==
                    (candidateId (qwestorCandidateScoreCandidate $head))
                    $candidateId)
                (qwestorRemoveCandidateScore $tail $candidateId)
                (cons-atom
                    $head
                    (qwestorRemoveCandidateScore $tail $candidateId))
            )
        )
    )
)

(= (qwestorDecisionReport $decision $state $candidates)
    (let* (
        ($scores (qwestorScoreCandidates $decision $state $candidates))
        ($best (qwestorBestCandidateScore $scores))
        ($winner (qwestorCandidateScoreCandidate $best))
        ($remaining
            (qwestorRemoveCandidateScore $scores (candidateId $winner)))
        ($margin
            (if (== $remaining ())
                0.0
                (let* (
                    ($runner (qwestorBestCandidateScore $remaining))
                )
                    (-
                        (qwestorCandidateScoreValue $best)
                        (qwestorCandidateScoreValue $runner))
                )
            ))
    )
        (qwestorDecisionReportRecord $winner $scores $margin)
    )
)

(= (qwestorDecisionWinner
        (qwestorDecisionReportRecord $winner $scores $margin))
    $winner
)

(= (qwestorDecisionScores
        (qwestorDecisionReportRecord $winner $scores $margin))
    $scores
)

(= (qwestorDecisionMargin
        (qwestorDecisionReportRecord $winner $scores $margin))
    $margin
)

(= (qwestorCandidateScorePairs $scores)
    (if (== $scores ())
        ()
        (let* (
            (($head $tail) (decons $scores))
            ($candidate (qwestorCandidateScoreCandidate $head))
        )
            (cons-atom
                ((candidateId $candidate) (qwestorCandidateScoreValue $head))
                (qwestorCandidateScorePairs $tail))
        )
    )
)

(= (qwestorPreparedCurrentState
        (qwestorPreparedCycleRecord
            $current $perception $continuing $features $feedback $decisionState
            $candidates $report))
    $current
)

(= (qwestorPreparedPerception
        (qwestorPreparedCycleRecord
            $current $perception $continuing $features $feedback $decisionState
            $candidates $report))
    $perception
)

(= (qwestorPreparedContinuingPerception
        (qwestorPreparedCycleRecord
            $current $perception $continuing $features $feedback $decisionState
            $candidates $report))
    $continuing
)

(= (qwestorPreparedFeatures
        (qwestorPreparedCycleRecord
            $current $perception $continuing $features $feedback $decisionState
            $candidates $report))
    $features
)

(= (qwestorPreparedFeedback
        (qwestorPreparedCycleRecord
            $current $perception $continuing $features $feedback $decisionState
            $candidates $report))
    $feedback
)

(= (qwestorPreparedDecisionState
        (qwestorPreparedCycleRecord
            $current $perception $continuing $features $feedback $decisionState
            $candidates $report))
    $decisionState
)

(= (qwestorPreparedCandidates
        (qwestorPreparedCycleRecord
            $current $perception $continuing $features $feedback $decisionState
            $candidates $report))
    $candidates
)

(= (qwestorPreparedDecisionReport
        (qwestorPreparedCycleRecord
            $current $perception $continuing $features $feedback $decisionState
            $candidates $report))
    $report
)

(= (qwestorPrepareCycleUnchecked $engine $context)
    (let* (
        ($bundle (qwestorBundle))
        ($bimonad (qwestorBimonad))
        ($current (qwestorEngineMotivationState $engine))
        ($previousOutcome
            (qwestorPendingOutcomeValue
                (qwestorEnginePendingOutcome $engine)))
        ($rawPerception (makeQwestorPerception $context $previousOutcome))
        ($perception (bundleAdaptStimulus $bundle $rawPerception))
        ($consumed (qwestorConsumePerceptionOutcome $perception))
        ($continuing (qwestorConsumedPerceptionValue $consumed))
        ($features (qwestorStimulusFeatureFn $current $perception))
        ($feedback (bimonadFeedback $bimonad $current $perception))
        ($decisionState (decisionContext $bimonad $current $perception))
        ($candidates
            (bundleBuildCandidates $bundle $decisionState $perception))
        ($report
            (qwestorDecisionReport
                (bimonadDecision $bimonad) $decisionState $candidates))
    )
        (qwestorPreparedCycleRecord
            $current
            $perception
            $continuing
            $features
            $feedback
            $decisionState
            $candidates
            $report
        )
    )
)

(= (qwestorPrepareCycle $engine $context)
    (let* (
        ($engineResult (qwestorValidateEngineState $engine))
        ($bundleResult (qwestorValidatedBundle))
    )
        (if (validationIsOk $engineResult)
            (if (validationIsOk $bundleResult)
                (validationOk
                    (qwestorPrepareCycleUnchecked $engine $context))
                $bundleResult
            )
            $engineResult
        )
    )
)

(= (qwestorConservativeTarget $policy $current $target)
    (qwestorProjectToSafeRegion
        $policy
        (motivationState
            (stateSchema $current)
            (averageArrays (stateGoals $current) (stateGoals $target))
            (averageArrays
                (stateModulators $current)
                (stateModulators $target)))
    )
)

(= (qwestorEffectKind $actionId)
    (case $actionId (
        (act_search search)
        (act_verify verification)
        (act_wait wait)
        ($_ llm)
    ))
)

(= (qwestorBuildEffectContext $query $state $styles)
    (qwestorEffectContextRecord
        $query
        $styles
        (qwestorStateSummary $state)
    )
)

(= (qwestorEffectContextQuery
        (qwestorEffectContextRecord $query $styles $stateValues))
    $query
)

(= (qwestorEffectContextStyles
        (qwestorEffectContextRecord $query $styles $stateValues))
    $styles
)

(= (qwestorEffectContextStateValues
        (qwestorEffectContextRecord $query $styles $stateValues))
    $stateValues
)

(= (qwestorEffectRequestId
        (qwestorEffectRequestRecord
            $requestId $actionId $kind $context))
    $requestId
)

(= (qwestorEffectRequestActionId
        (qwestorEffectRequestRecord
            $requestId $actionId $kind $context))
    $actionId
)

(= (qwestorEffectRequestKind
        (qwestorEffectRequestRecord
            $requestId $actionId $kind $context))
    $kind
)

(= (qwestorEffectRequestContext
        (qwestorEffectRequestRecord
            $requestId $actionId $kind $context))
    $context
)

(= (qwestorEffectResultRequestId
        (qwestorEffectResultRecord $requestId $payload))
    $requestId
)

(= (qwestorEffectResultPayload
        (qwestorEffectResultRecord $requestId $payload))
    $payload
)

(= (qwestorPrepareTransitionFromCycle $engine $query $prepared)
    (let* (
        ($bundle (qwestorBundle))
        ($bimonad (qwestorBimonad))
        ($policy (bundleStabilityPolicy $bundle))
        ($coherence (bundleCoherencePolicy $bundle))
        ($current (qwestorPreparedCurrentState $prepared))
        ($perception (qwestorPreparedPerception $prepared))
        ($feedback (qwestorPreparedFeedback $prepared))
        ($decisionState (qwestorPreparedDecisionState $prepared))
        ($candidates (qwestorPreparedCandidates $prepared))
        ($report (qwestorPreparedDecisionReport $prepared))
        ($winner (qwestorDecisionWinner $report))
        ($actionId (candidateId $winner))
        ($decision (bimonadDecision $bimonad))
        ($delta
            (profiledMagusProposeDeltaG
                (magusDecisionGoalChangeFn $decision)
                (magusDecisionProfile $decision)
                $decisionState
                $winner
                $feedback
                (magusDecisionLambdaInd $decision)
                (magusDecisionLambdaTrans $decision)))
        ($cautiousState (qwestorRaiseBoundaryCaution $policy $decisionState))
        ($dampedDelta
            (qwestorApplyHomeostaticDamping
                $policy $cautiousState $delta))
        ($rawTarget
            (motivationState
                (stateSchema $cautiousState)
                (clipVector
                    (vectorAdd (stateGoals $cautiousState) $dampedDelta)
                    0.0
                    1.0)
                (stateModulators $cautiousState)))
        ($projectionDiagnostics
            (qwestorDiagnoseProjection $policy $rawTarget))
        ($projected (qwestorProjectToSafeRegion $policy $rawTarget))
        ($lax
            (measureLaxDistributiveLaw
                $bimonad $current $perception $candidates 0.01))
        ($reference (localReferenceState $current $projected))
        ($contractive
            (checkContractiveUpdateLaw
                $policy $bimonad $current $reference $perception $candidates))
        ($guard
            (and
                (lawCheckHolds $lax)
                (and
                    $contractive
                    (qwestorIsInSafeRegion $policy $projected))))
        ($safeTarget
            (if $guard
                $projected
                (qwestorConservativeTarget $policy $current $projected)))
        ($blend (measureBlend $coherence $current $safeTarget))
        ($nextState
            (qwestorProjectToSafeRegion
                $policy
                (blendResultState $blend)))
        ($styles (qwestorResponseStyles $decisionState))
        ($effectContext
            (qwestorBuildEffectContext $query $nextState $styles))
        ($requestId (qwestor_request (qwestorEngineTurn $engine)))
        ($effectRequest
            (qwestorEffectRequestRecord
                $requestId
                $actionId
                (qwestorEffectKind $actionId)
                $effectContext))
        ($drift (blendResultDrift $blend))
        ($diagnostics
            (qwestorEngineDiagnosticsRecord
                $actionId
                (qwestorDecisionMargin $report)
                (qwestorDiagnosticsPressure $projectionDiagnostics)
                (qwestorDiagnosticsSafeBefore $projectionDiagnostics)
                (qwestorDiagnosticsProjectionDistance $projectionDiagnostics)
                (lawCheckHolds $lax)
                (lawCheckError $lax)
                (blendResultBaseAlpha $blend)
                (blendResultAlpha $blend)
                $contractive
                (qwestorIsInSafeRegion $policy $nextState)))
    )
        (qwestorPendingTransitionRecord
            (qwestorEngineTurn $engine)
            $nextState
            (qwestorEnginePendingOutcome $engine)
            $effectRequest
            $diagnostics
            $prepared
        )
    )
)

(= (qwestorPrepareTransition $engine $context $query)
    (let* (
        ($preparedResult (qwestorPrepareCycle $engine $context))
    )
        (case $preparedResult (
            ((validationOk $prepared)
                (validationOk
                    (qwestorPrepareTransitionFromCycle
                        $engine $query $prepared)))
            ((validationError $code $details)
                (validationError $code $details))
        ))
    )
)

(= (qwestorDiagnoseCycle $engine $context $query)
    (qwestorPrepareTransition $engine $context $query)
)

(= (qwestorPendingSourceTurn
        (qwestorPendingTransitionRecord
            $sourceTurn $nextState $consumedOutcome $request $diagnostics
            $prepared))
    $sourceTurn
)

(= (qwestorPendingNextState
        (qwestorPendingTransitionRecord
            $sourceTurn $nextState $consumedOutcome $request $diagnostics
            $prepared))
    $nextState
)

(= (qwestorPendingConsumedOutcome
        (qwestorPendingTransitionRecord
            $sourceTurn $nextState $consumedOutcome $request $diagnostics
            $prepared))
    $consumedOutcome
)

(= (qwestorPendingEffectRequest
        (qwestorPendingTransitionRecord
            $sourceTurn $nextState $consumedOutcome $request $diagnostics
            $prepared))
    $request
)

(= (qwestorPendingDiagnostics
        (qwestorPendingTransitionRecord
            $sourceTurn $nextState $consumedOutcome $request $diagnostics
            $prepared))
    $diagnostics
)

(= (qwestorPendingPreparedCycle
        (qwestorPendingTransitionRecord
            $sourceTurn $nextState $consumedOutcome $request $diagnostics
            $prepared))
    $prepared
)

(= (qwestorDiagnosticsActionId
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $actionId
)

(= (qwestorDiagnosticsWinnerMargin
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $margin
)

(= (qwestorDiagnosticsBoundaryPressure
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $pressure
)

(= (qwestorDiagnosticsSafeBefore
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $safeBefore
)

(= (qwestorDiagnosticsProjectionDistanceValue
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $projectionDistance
)

(= (qwestorDiagnosticsLaxHolds
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $laxHolds
)

(= (qwestorDiagnosticsLaxError
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $laxError
)

(= (qwestorDiagnosticsBaseAlpha
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $baseAlpha
)

(= (qwestorDiagnosticsAcceptedAlpha
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $alpha
)

(= (qwestorDiagnosticsContractive
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $contractive
)

(= (qwestorDiagnosticsSafeAfter
        (qwestorEngineDiagnosticsRecord
            $actionId $margin $pressure $safeBefore $projectionDistance
            $laxHolds $laxError $baseAlpha $alpha $contractive $safeAfter))
    $safeAfter
)

(= (qwestorDiagnosticsPairs $diagnostics)
    (
        (boundary_pressure
            (qwestorDiagnosticsBoundaryPressure $diagnostics))
        (safe_before
            (qwestorDiagnosticsSafeBefore $diagnostics))
        (projection_distance
            (qwestorDiagnosticsProjectionDistanceValue $diagnostics))
        (lax_holds
            (qwestorDiagnosticsLaxHolds $diagnostics))
        (lax_error
            (qwestorDiagnosticsLaxError $diagnostics))
        (base_alpha
            (qwestorDiagnosticsBaseAlpha $diagnostics))
        (accepted_alpha
            (qwestorDiagnosticsAcceptedAlpha $diagnostics))
        (contractive
            (qwestorDiagnosticsContractive $diagnostics))
        (safe_after
            (qwestorDiagnosticsSafeAfter $diagnostics))
    )
)

(= (qwestorCommitCycleUnchecked
        $engine $pending $effectResult $outcome)
    (let* (
        ($request (qwestorPendingEffectRequest $pending))
        ($requestId (qwestorEffectRequestId $request))
        ($diagnostics (qwestorPendingDiagnostics $pending))
        ($prepared (qwestorPendingPreparedCycle $pending))
        ($historyEntry
            (qwestorTurnRecord
                (qwestorEngineTurn $engine)
                (qwestorEffectRequestActionId $request)
                (qwestorDecisionScores
                    (qwestorPreparedDecisionReport $prepared))
                (qwestorEffectResultPayload $effectResult)))
        ($nextEngine
            (qwestorEngineStateRecord
                (qwestorPendingNextState $pending)
                (qwestorMakePendingOutcome
                    (qwestorOutcomeId $outcome) $outcome)
                (listAppend
                    (qwestorEngineHistory $engine)
                    ($historyEntry))
                (listAppend
                    (qwestorEngineDiagnosticsHistory $engine)
                    ($diagnostics))
                (listAppend
                    (qwestorEngineCompletedRequestIds $engine)
                    ($requestId))
                (+ (qwestorEngineTurn $engine) 1)))
    )
        (validationOk
            (qwestorCycleResultRecord
                $nextEngine
                $request
                $effectResult
                $diagnostics
                $prepared))
    )
)

(= (qwestorCommitCycle $engine $pending $effectResult $outcome)
    (let* (
        ($request (qwestorPendingEffectRequest $pending))
        ($requestId (qwestorEffectRequestId $request))
        ($sourceMatches
            (==
                (qwestorPendingSourceTurn $pending)
                (qwestorEngineTurn $engine)))
        ($consumedOutcomeMatches
            (==
                (qwestorPendingConsumedOutcome $pending)
                (qwestorEnginePendingOutcome $engine)))
        ($requestMatches
            (==
                $requestId
                (qwestorEffectResultRequestId $effectResult)))
        ($alreadyCommitted
            (listContains
                (qwestorEngineCompletedRequestIds $engine)
                $requestId))
        ($outcomeResult (qwestorValidateOutcome $outcome))
    )
        (if $sourceMatches
            (if $consumedOutcomeMatches
                (if $requestMatches
                    (if $alreadyCommitted
                        (validationError duplicate-qwestor-commit $requestId)
                        (if (validationIsOk $outcomeResult)
                            (qwestorCommitCycleUnchecked
                                $engine $pending $effectResult $outcome)
                            $outcomeResult
                        )
                    )
                    (validationError mismatched-qwestor-effect-result
                        ((expected $requestId)
                         (actual
                            (qwestorEffectResultRequestId $effectResult))))
                )
                (validationError mismatched-qwestor-consumed-outcome
                    ((expected (qwestorEnginePendingOutcome $engine))
                     (actual (qwestorPendingConsumedOutcome $pending))))
            )
            (validationError stale-qwestor-transition
                ((expected (qwestorEngineTurn $engine))
                 (actual (qwestorPendingSourceTurn $pending))))
        )
    )
)

(= (qwestorCycleNextEngine
        (qwestorCycleResultRecord
            $nextEngine $request $effectResult $diagnostics $prepared))
    $nextEngine
)

(= (qwestorCycleEffectRequest
        (qwestorCycleResultRecord
            $nextEngine $request $effectResult $diagnostics $prepared))
    $request
)

(= (qwestorCycleEffectResult
        (qwestorCycleResultRecord
            $nextEngine $request $effectResult $diagnostics $prepared))
    $effectResult
)

(= (qwestorCycleDiagnostics
        (qwestorCycleResultRecord
            $nextEngine $request $effectResult $diagnostics $prepared))
    $diagnostics
)

(= (qwestorCyclePrepared
        (qwestorCycleResultRecord
            $nextEngine $request $effectResult $diagnostics $prepared))
    $prepared
)
