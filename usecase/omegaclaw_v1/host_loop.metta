
(= (omegaClawHostRunResult
        $response $commands $displayResults $adapterState)
    (omegaClawHostRunResultRecord
        $response $commands $displayResults $adapterState))

(= (omegaClawHostRunResultField $result $field)
    (let* (
        ((omegaClawHostRunResultRecord
            $response $commands $displayResults $adapterState) $result)
    )
        (case $field (
            (response $response)
            (commands $commands)
            (display-results $displayResults)
            (adapter-state $adapterState)
            ($_ (empty))
        ))))

(= (omegaClawHostPrintError $stage $code $details)
    (println! (METAMO-LIFECYCLE-ERROR: $stage $code $details)))

(= (omegaClawHostOutputTokenLimit $adapterState)
    (let* (
        ($engine
            (omegaClawAdapterStateField
                $adapterState extension-state))
        ($taskStatus
            (omegaClawTaskStateField
                (omegaClawEngineStateField $engine task-state)
                status))
    )
        (if (omegaClawCandidateTaskActive $taskStatus)
            (omegaClawCoreConfig max-output-token)
            (omegaClawCoreConfig autonomy-max-output-token))))

(= (omegaClawHostProviderSetting $adapterState $field)
    (let* (
        ($engine
            (omegaClawAdapterStateField
                $adapterState extension-state))
        ($taskStatus
            (omegaClawTaskStateField
                (omegaClawEngineStateField $engine task-state)
                status))
    )
        (case $field (
            (timeout
                (if (omegaClawCandidateTaskActive $taskStatus)
                    (omegaClawCoreConfig human-provider-timeout)
                    (omegaClawCoreConfig autonomy-provider-timeout)))
            (operation
                (if (omegaClawCandidateTaskActive $taskStatus)
                    human-realization
                    autonomy-realization))
            ($_ (empty))
        ))))

(= (omegaClawHostCommandsAfterPolicyCheck
        $pending $parsedCommands $authorizedCommands)
    (case (omegaClawFilterCommands
            $pending $parsedCommands $authorizedCommands) (
        ((validationOk $boundary)
            (case (omegaClawCommandBoundaryField
                    $boundary proposal-validation) (
                ((validationOk $_)
                    (omegaClawCommandBoundaryField
                        $boundary executable-commands))
                ((validationError $code $details)
                    (progn
                        (println!
                            (METAMO-PROPOSAL-REJECTED:
                                $code $details))
                        ()))
            )))
        ((validationError $code $details)
            (progn
                (println!
                    (METAMO-PROPOSAL-REJECTED: $code $details))
                ()))
    )))

(= (omegaClawHostAutonomousTurn $turn)
    (not (omegaClawHostTurnField $turn new-message)))

(= (omegaClawHostShouldRequestDirective $directive)
    (let* (
        ($capabilityEnvelope
            (omegaClawMotivationDirectiveField
                $directive capability-envelope))
        ($realizationId
            (omegaClawMotivationDirectiveField
                $directive realization-id))
    )
        (and
            (omegaClawHostShouldRequestCommands $capabilityEnvelope)
            (and
                (not (== $realizationId defer))
                (not (== $realizationId idle))))))

(= (omegaClawHostYieldCandidate $candidateId)
    (case $candidateId (
        (defer True)
        (idle True)
        ($_ False)
    )))

(= (omegaClawHostYieldScoreTraces ())
    ())

(= (omegaClawHostYieldScoreTraces $traces)
    (let* (
        (($head $tail) (decons $traces))
        ($remaining (omegaClawHostYieldScoreTraces $tail))
    )
        (if (omegaClawHostYieldCandidate
                (omegaClawCandidateScoreTraceField
                    $head candidate-id))
            (cons-atom $head $remaining)
            $remaining)))

(= (omegaClawHostBestYieldScoreTrace $decisionEvidence)
    (omegaClawBestCandidateScoreTrace
        (omegaClawHostYieldScoreTraces
            (omegaClawDecisionEvidenceField
                $decisionEvidence score-traces))))

(= (omegaClawHostWinnerYieldMargin $decisionEvidence)
    (case (omegaClawHostBestYieldScoreTrace $decisionEvidence) (
        (none none)
        ($yieldTrace
            (- (omegaClawDecisionEvidenceField
                    $decisionEvidence winner-score)
               (omegaClawCandidateScoreTraceField
                    $yieldTrace score)))
    )))

(= (omegaClawHostMotivationYieldReason
        $autonomous $requestCommands $decisionEvidence)
    (if (not (and $autonomous $requestCommands))
        none
        (case $decisionEvidence (
            (none none)
            ($_
                (let* (
                    ($winnerScore
                        (omegaClawDecisionEvidenceField
                            $decisionEvidence winner-score))
                    ($yieldMargin
                        (omegaClawHostWinnerYieldMargin
                            $decisionEvidence))
                )
                    (if (< $winnerScore
                            (omegaClawCoreConfig
                                autonomy-action-score-threshold))
                        motivation-action-threshold
                        (case $yieldMargin (
                            (none none)
                            ($_
                                (if (< $yieldMargin
                                        (omegaClawCoreConfig
                                            autonomy-yield-margin-threshold))
                                    motivation-yield-threshold
                                    none))
                        ))))
        )))))

(= (omegaClawHostRequestGateResult $requestCommands $disposition)
    (omegaClawHostRequestGateResultRecord
        $requestCommands $disposition))

(= (omegaClawHostRequestGateResultField $result $field)
    (let (omegaClawHostRequestGateResultRecord
            $requestCommands $disposition)
        $result
        (case $field (
            (request-commands $requestCommands)
            (disposition $disposition)
            ($_ (empty))
        ))))

;; Poll for human input before spending an autonomous provider call.
(= (omegaClawHostRequestGate $turn $directive $decisionEvidence)
    (if (not (omegaClawHostShouldRequestDirective $directive))
        (omegaClawHostRequestGateResult False none)
        (if (not (omegaClawHostAutonomousTurn $turn))
            (omegaClawHostRequestGateResult True none)
            (let* (
                ($motivationReason
                    (omegaClawHostMotivationYieldReason
                        True True $decisionEvidence))
            )
                (if (not (== $motivationReason none))
                    (progn
                        (println!
                            (METAMO-MOTIVATION-GATE:
                                yield $motivationReason
                                (winner-score
                                    (omegaClawDecisionEvidenceField
                                        $decisionEvidence winner-score))
                                (action-threshold
                                    (omegaClawCoreConfig
                                        autonomy-action-score-threshold))
                                (yield-margin
                                    (omegaClawHostWinnerYieldMargin
                                        $decisionEvidence))
                                (margin-threshold
                                    (omegaClawCoreConfig
                                        autonomy-yield-margin-threshold))))
                        (omegaClawCoreEndAutonomyBurst)
                        (omegaClawHostRequestGateResult
                            False $motivationReason))
                    (progn
                        (omegaClawCoreStartAutonomyBudgetAt (get_time))
                        (if (not (omegaClawCoreAutonomyBudgetAvailable))
                        (progn
                            (println!
                                (METAMO-AUTONOMY-YIELD:
                                    (omegaClawCoreAutonomyBudgetExhaustionReason)))
                            (omegaClawCoreEndAutonomyBurst)
                            (omegaClawHostRequestGateResult
                                False autonomy-budget-exhausted))
                        (if (omegaClawCorePollHumanInput)
                            (progn
                                (println!
                                    (METAMO-AUTONOMY-PREEMPTED:
                                        before-provider))
                                (omegaClawHostRequestGateResult
                                    False preempted-by-human))
                            (progn
                                (omegaClawCoreRecordAutonomyBudget
                                    main-llm-calls 1)
                                (omegaClawHostRequestGateResult
                                    True none))))))))))

(= (omegaClawHostEffectiveDisposition
        $requestDisposition $dispatchDisposition)
    (omegaClawHostEffectiveDisposition
        $requestDisposition none $dispatchDisposition))

(= (omegaClawHostEffectiveDisposition
        $requestDisposition $providerFailure $dispatchDisposition)
    (if (== $requestDisposition none)
        (if (== $dispatchDisposition none)
            $providerFailure
            $dispatchDisposition)
        $requestDisposition))

(= (omegaClawHostRequestProposal
        $requestCommands $fragment $turn $preparedState)
    (case $requestCommands (
        (True
            (let* (
                ($promptStartedAt
                    (py-call (workspace_policy.monotonic_seconds)))
                ($prompt
                    (omegaClawAdapterAppendContext
                        (omegaClawCoreBaseContext) $fragment))
                ($promptFinishedAt
                    (py-call (workspace_policy.monotonic_seconds)))
                ($promptElapsed
                    (eval (- $promptFinishedAt $promptStartedAt)))
                ($_ (println!
                    (METAMO-TIMING: prompt-build $promptElapsed)))
            )
                (omegaClawCoreRequestCommands
                    $prompt $turn
                    (omegaClawHostOutputTokenLimit $preparedState)
                    (omegaClawHostProviderSetting
                        $preparedState timeout)
                    (omegaClawHostProviderSetting
                        $preparedState operation))))
        ($_ (omegaClawCoreProposal () () ()))
    )))

(= (omegaClawHostDispatchPlan
        $authorizedCommands $dispatchCommands $disposition)
    (omegaClawHostDispatchPlanRecord
        $authorizedCommands $dispatchCommands $disposition))

(= (omegaClawHostDispatchPlanField $plan $field)
    (let (omegaClawHostDispatchPlanRecord
            $authorizedCommands $dispatchCommands $disposition)
        $plan
        (case $field (
            (authorized-commands $authorizedCommands)
            (dispatch-commands $dispatchCommands)
            (disposition $disposition)
            ($_ (empty))
        ))))

(= (omegaClawHostDispatchPlanAfterHumanCheck
        $autonomous $requestCommands $humanArrived $policyCommands)
    (if (and $autonomous
            (and $requestCommands
                (and $humanArrived
                    (not (== $policyCommands ())))))
        (omegaClawHostDispatchPlan
            $policyCommands () preempted-by-human)
        (omegaClawHostDispatchPlan
            $policyCommands $policyCommands none)))

;; Drop stale autonomous proposals when human input arrives before dispatch.
(= (omegaClawHostDispatchPlanBeforeDispatch
        $turn $requestCommands $pending
        $parsedCommands $authorizedCommands)
    (omegaClawHostDispatchPlanBeforeDispatch
        $turn $requestCommands $pending
        $parsedCommands $authorizedCommands none))

(= (omegaClawHostDispatchPlanBeforeDispatch
        $turn $requestCommands $pending
        $parsedCommands $authorizedCommands $providerFailure)
    (let* (
        ($policyCommands
            (if (and
                    $requestCommands
                    (== $providerFailure none))
                (omegaClawHostCommandsAfterPolicyCheck
                    $pending $parsedCommands $authorizedCommands)
                ()))
        ($autonomous (omegaClawHostAutonomousTurn $turn))
        ($humanArrived
            (if (and $autonomous $requestCommands)
                (omegaClawCorePollHumanInput)
                False))
        ($_ (if $humanArrived
            (println!
                (METAMO-AUTONOMY-PREEMPTED:
                    before-dispatch stale-proposal))
            True))
    )
        (omegaClawHostDispatchPlanAfterHumanCheck
            $autonomous $requestCommands
            $humanArrived $policyCommands)))

(= (omegaClawHostPrintAutonomyTransition $filteredState $committed)
    (let* (
        ($beforeEngine
            (omegaClawAdapterStateField
                $filteredState extension-state))
        ($afterState
            (omegaClawCommitResultField $committed state))
        ($afterEngine
            (omegaClawAdapterStateField
                $afterState extension-state))
        ($extensionResult
            (omegaClawCommitResultField
                $committed extension-result))
        ($outcome
            (omegaClawCommittedEngineTurnField
                $extensionResult outcome))
        ($candidateId
            (omegaClawOutcomeField $outcome candidate-id))
        ($phaseBefore
            (omegaClawAutonomyStateField
                (omegaClawEngineStateField
                    $beforeEngine autonomy-state)
                phase))
        ($phaseAfter
            (omegaClawAutonomyStateField
                (omegaClawEngineStateField
                    $afterEngine autonomy-state)
                phase))
        ($goalBefore
            (omegaClawEngineStateField $beforeEngine goal-state))
        ($goalAfter
            (omegaClawEngineStateField $afterEngine goal-state))
    )
        (if (omegaClawAutonomyCandidate $candidateId)
            (println!
                (METAMO-AUTONOMY-TRANSITION:
                    (candidate $candidateId)
                    (phase $phaseBefore $phaseAfter)
                    (goal-status
                        (omegaClawGoalStateField $goalBefore status)
                        (omegaClawGoalStateField $goalAfter status))
                    (verdict
                        (omegaClawGoalStateField
                            $goalAfter last-verdict))))
            True)))


(= (omegaClawHostFinishCommit
        $response $executedCommands $displayResults
        $filteredState $commitResult)
    (case $commitResult (
        ((validationOk $committed)
            (let* (
                ($evidence
                    (omegaClawMetaMoCommitEvidenceFromResult $committed))
                ($_ (println! (METAMO-COMMIT: $evidence)))
                ($_ (omegaClawHostPrintAutonomyTransition
                        $filteredState $committed))
            )
                (omegaClawHostRunResult
                    $response
                    $executedCommands
                    $displayResults
                    (omegaClawCommitResultField $committed state))))
        ((validationError $code $details)
            (let* (
                ($_ (omegaClawHostPrintError commit $code $details))
            )
                (omegaClawHostRunResult
                    $response $executedCommands $displayResults
                    $filteredState)))
    )))

(= (omegaClawHostRunFilteredTurn
        $response $parsedCommands $filteredResult $dispatchDisposition)
    (let* (
        ($filteredState
            (omegaClawFilterResultField $filteredResult state))
        ($filteredTurn
            (omegaClawFilterResultField
                $filteredResult filtered-turn))
        ($filteredCommands
            (omegaClawFilteredTurnField
                $filteredTurn filtered-commands))
        ($executedCommands
            (if (== $dispatchDisposition preempted-by-human)
                ()
                $filteredCommands))
        ($filterEvidence
            (omegaClawMetaMoFilterEvidenceFromResult
                $parsedCommands $filteredResult))
        ($_ (println! (METAMO-FILTER: $filterEvidence)))
        ($dispatchStartedAt
            (py-call (workspace_policy.monotonic_seconds)))
        ($dispatch (omegaClawCoreDispatchCommands $executedCommands))
        ($dispatchFinishedAt
            (py-call (workspace_policy.monotonic_seconds)))
        ($dispatchElapsed
            (eval (- $dispatchFinishedAt $dispatchStartedAt)))
        ($_ (println! (METAMO-TIMING: dispatch $dispatchElapsed)))
        ($commandResults
            (omegaClawCoreDispatchBatchField
                $dispatch command-results))
        ($displayResults
            (RESULTS:
                (omegaClawCoreDispatchBatchField
                    $dispatch display-results)))
        ($_ (println! $displayResults))
        ($commitResult
            (omegaClawAdapterCommitTurnWithDisposition
                (omegaClawMetaMoAdapter)
                $filteredState
                $filteredTurn
                $commandResults
                $dispatchDisposition))
    )
        (omegaClawHostFinishCommit
            $response $executedCommands $displayResults
            $filteredState $commitResult)))

(= (omegaClawHostFinishFilter
        $response $parsedCommands $preparedState
        $filterResult $dispatchDisposition)
    (case $filterResult (
        ((validationOk $filteredResult)
            (omegaClawHostRunFilteredTurn
                $response $parsedCommands
                $filteredResult $dispatchDisposition))
        ((validationError $code $details)
            (let* (
                ($_ (omegaClawHostPrintError filter $code $details))
                ($displayResults (RESULTS: ()))
                ($_ (println! $displayResults))
            )
                (omegaClawHostRunResult
                    $response () $displayResults $preparedState)))
    )))

(= (omegaClawHostRunPreparedTurn
        $previousAdapterState $preparedResult $turn)
    (let* (
        ($preparedState
            (omegaClawPrepareResultField $preparedResult state))
        ($preparedTurn
            (omegaClawPrepareResultField
                $preparedResult prepared-turn))
        ($prepareEvidence
            (omegaClawMetaMoPrepareEvidenceFromResult
                $previousAdapterState
                $preparedResult))
        ($_ (println! (METAMO-PREPARE: $prepareEvidence)))
        ($_ (println! (METAMO-DECISION:
            (omegaClawMetaMoDecisionTraceFromResult
                $previousAdapterState $preparedResult))))
        ($pending
            (omegaClawPreparedTurnField
                $preparedTurn extension-cycle))
        ($directive
            (omegaClawPendingTransitionField
                $pending directive))
        ($fragment
            (omegaClawPreparedTurnField
                $preparedTurn context-fragment))
        ($requestGate
            (omegaClawHostRequestGate
                $turn $directive
                (omegaClawPendingTransitionField
                    $pending decision-evidence)))
        ($requestCommands
            (omegaClawHostRequestGateResultField
                $requestGate request-commands))
        ($requestDisposition
            (omegaClawHostRequestGateResultField
                $requestGate disposition))
        ($proposal
            (omegaClawHostRequestProposal
                $requestCommands $fragment $turn $preparedState))
        ($response
            (omegaClawCoreProposalField $proposal response))
        ($parsedCommands
            (omegaClawCoreProposalField $proposal parsed-commands))
        ($authorizedCommands
            (omegaClawCoreProposalField $proposal authorized-commands))
        ($providerFailure
            (omegaClawCoreProposalField $proposal provider-failure))
        ($_ (if (== $providerFailure none)
            True
            (println!
                (METAMO-PROVIDER-FAILURE: $providerFailure))))
        ($dispatchPlan
            (omegaClawHostDispatchPlanBeforeDispatch
                $turn $requestCommands $pending
                $parsedCommands $authorizedCommands
                $providerFailure))
        ($shapeAuthorizedCommands
            (omegaClawHostDispatchPlanField
                $dispatchPlan authorized-commands))
        ($dispatchDisposition
            (omegaClawHostEffectiveDisposition
                $requestDisposition
                $providerFailure
                (omegaClawHostDispatchPlanField
                    $dispatchPlan disposition)))
        ($_ (println! (RESPONSE: $parsedCommands)))
        ($filterStartedAt
            (py-call (workspace_policy.monotonic_seconds)))
        ($filterResult
            (omegaClawAdapterFilterCommands
                (omegaClawMetaMoAdapter)
                $preparedState
                $preparedTurn
                $parsedCommands
                $shapeAuthorizedCommands))
        ($filterFinishedAt
            (py-call (workspace_policy.monotonic_seconds)))
        ($filterElapsed
            (eval (- $filterFinishedAt $filterStartedAt)))
        ($_ (println!
            (METAMO-TIMING: filter $filterElapsed)))
    )
        (omegaClawHostFinishFilter
            $response $parsedCommands $preparedState
            $filterResult $dispatchDisposition)
    ))

(= (omegaClawHostFinishPrepare
        $turn $adapterState $prepareResult)
    (case $prepareResult (
        ((validationOk $preparedResult)
            (omegaClawHostRunPreparedTurn
                $adapterState $preparedResult $turn))
        ((validationError $code $details)
            (let* (
                ($_ (omegaClawHostPrintError prepare $code $details))
            )
                (omegaClawHostRunResult
                    () () (RESULTS: ()) $adapterState)))
    ))
)

(= (omegaClawHostShouldRequestCommands $capabilityEnvelope)
    (case $capabilityEnvelope (
        (no-effect False)
        ($_ True)
    )))

(= (omegaClawHostHistoryPayload $commands)
    (case $commands (
        (() ())
        ($_ $commands)
    )))

(= (omegaClawHostOutcomeHistoryWorthy $outcome)
    (case $outcome (
        (none False)
        ($_
            (or
                (== (omegaClawOutcomeField
                        $outcome result-utility) useful)
                (== (omegaClawOutcomeField
                        $outcome delivery-status) sent)))
    )))

(= (omegaClawHostHistoryPayloadForState $commands $adapterState)
    (case $adapterState (
        ((omegaClawAdapterStateRecord
                $extensionState $nextTurnId $committedTurnIds $stageTrace)
            (if (omegaClawHostOutcomeHistoryWorthy
                    (omegaClawEngineStateField
                        $extensionState last-outcome))
                $commands
                ()))
        ($_ ())
    )))

(= (omegaClawHostPrintHumanReceipt $turn)
    (case (omegaClawHostTurnField $turn new-message) (
        (True
            (println!
                (METAMO-HUMAN-RECEIVED:
                    (get_time_as_string)
                    (omegaClawHostTurnField $turn message-id))))
        ($_ True)
    )))

(= (omegaClawHostRunTurn $turn $adapterState)
    (omegaClawHostFinishPrepare
        $turn
        $adapterState
        (omegaClawAdapterPrepareTurn
            (omegaClawMetaMoAdapter)
            $adapterState
            $turn)
    )
)

(= (omegaClawHostEngineWorkingOn $engine)
    (case $engine (
        ((omegaClawEngineStateRecord
                $motivationState $taskState $autonomyState $goalState
                $pendingAction $recentActions $diagnosticsHistory $goalEvidence
                $nextTurnId $committedTurnIds $lastOutcome)
            (case $taskState (
                ((omegaClawTaskStateRecord
                        none $status $authorization $evidence)
                    (case $autonomyState (
                        ((omegaClawAutonomyStateRecord $phase $actionCount)
                            (autonomy $phase))
                        ($_ none)
                    )))
                ((omegaClawTaskStateRecord
                        $activeTask $status $authorization $evidence)
                    (task $activeTask $status))
                ($_ none)
            )))
        ($_ none)
    )))

(= (omegaClawHostCandidatePhase $candidateId)
    (case $candidateId (
        (recall-goals recall)
        (invent-goal invent)
        (plan-goal plan)
        (background-work act)
        (assess-progress assess)
        (verify-goal verify)
        (learn integrate)
        (self-improve repair)
        (repair-failure repair)
        (repair-autonomy repair)
        ($_ none)
    )))

(= (omegaClawHostEngineExecutedWork $engine)
    (let* (
        ($taskState (omegaClawEngineStateField $engine task-state))
        ($lastOutcome (omegaClawEngineStateField $engine last-outcome))
    )
        (case $lastOutcome (
            (none (omegaClawHostEngineWorkingOn $engine))
            ($_
                (let* (
                    ($candidateId
                        (omegaClawOutcomeField
                            $lastOutcome candidate-id))
                    ($phase
                        (omegaClawHostCandidatePhase $candidateId))
                )
                    (case $phase (
                        (none
                            (case $taskState (
                                ((omegaClawTaskStateRecord
                                        none $status $authorization $evidence)
                                    none)
                                ((omegaClawTaskStateRecord
                                        $activeTask $status
                                        $authorization $evidence)
                                    (task $activeTask $status))
                                ($_ none)
                            )))
                        ($_ (autonomy $phase))
                    ))))
        ))))

(= (omegaClawHostWorkingOn $adapterState)
    (case $adapterState (
        ((omegaClawAdapterStateRecord
                $extensionState $nextTurnId $committedTurnIds $stageTrace)
            (omegaClawHostEngineExecutedWork $extensionState))
        ($_ none)
    )))

(= (omegaClawHostAutonomyContinuationNeeded
        $taskState $autonomyState $outcome)
    (case $outcome (
        (none False)
        ($_
            (let* (
                ($taskStatus
                    (omegaClawTaskStateField $taskState status))
                ($phase
                    (omegaClawAutonomyStateField
                        $autonomyState phase))
                ($candidateId
                    (omegaClawOutcomeField $outcome candidate-id))
                ($successCount
                    (omegaClawOutcomeField $outcome success-count))
                ($failureReason
                    (omegaClawOutcomeField $outcome failure-reason))
                ($attemptObserved
                    (or
                        (> $successCount 0)
                        (not (== $failureReason none))))
            )
                (or
                    (and
                        (case $taskStatus (
                            (active True)
                            (ready True)
                            (verifying True)
                            (verified True)
                            ($_ False)
                        ))
                        $attemptObserved)
                    (and
                        (not (omegaClawCandidateTaskActive $taskStatus))
                        (and
                            (not (== $phase idle))
                            (and
                                (omegaClawAutonomyCandidate $candidateId)
                                $attemptObserved))))))
    )))

(= (omegaClawHostContinuationYieldReason
        $taskStatus $failureReason $continuationNeeded $budgetReason)
    (if (== $taskStatus awaiting-human)
        awaiting-human
        (if (== $failureReason preempted-by-human)
            preempted-by-human
            (case $failureReason (
                (motivation-action-threshold
                    motivation-action-threshold)
                (motivation-yield-threshold
                    motivation-yield-threshold)
                ($_ (if $continuationNeeded $budgetReason none))
            )))))

(= (omegaClawHostYield $reason)
    (progn
        (println! (METAMO-AUTONOMY-YIELD: $reason))
        (omegaClawCoreEndAutonomyBurst)))

(= (omegaClawHostFailureReasonCharges $failureReason)
    (case $failureReason (
        (none False)
        (preempted-by-human False)
        (autonomy-budget-exhausted False)
        (motivation-action-threshold False)
        (motivation-yield-threshold False)
        ($_ True)
    )))

;; Continue only recoverable outcomes within the autonomous failure budget.
(= (omegaClawHostOutcomeChargesFailure $outcome)
    (if (omegaClawOutcomeExpectedEmpty $outcome)
        False
        (omegaClawHostFailureReasonCharges
            (omegaClawOutcomeField $outcome failure-reason))))

(= (omegaClawHostEnsureContinuation $adapterState)
    (case $adapterState (
        ((omegaClawAdapterStateRecord
                (omegaClawEngineStateRecord
                    $motivationState $taskState $autonomyState $goalState
                    $pendingAction $recentActions $diagnosticsHistory $goalEvidence
                    $nextTurnId $committedTurnIds $lastOutcome)
                $adapterTurnId $adapterCommittedIds $stageTrace)
            (let* (
                ($taskStatus
                    (omegaClawTaskStateField $taskState status))
                ($failureReason
                    (case $lastOutcome (
                        (none none)
                        ($_ (omegaClawOutcomeField
                                $lastOutcome failure-reason))
                    )))
                ($continuationNeeded
                    (omegaClawHostAutonomyContinuationNeeded
                        $taskState $autonomyState $lastOutcome))
                ($budgetReason
                    (omegaClawCoreAutonomyBudgetExhaustionReason))
                ($yieldReason
                    (omegaClawHostContinuationYieldReason
                        $taskStatus $failureReason
                        $continuationNeeded $budgetReason))
            )
                (if (not (== $yieldReason none))
                    (omegaClawHostYield $yieldReason)
                    (if $continuationNeeded
                        (omegaClawCoreEnsureLoopBudget 2)
                        True))))
        ($_ True)
    )))

(= (omegaClawHostRecordAutonomyOutcome $turn $adapterState)
    (if (not (omegaClawHostAutonomousTurn $turn))
        True
        (case $adapterState (
            ((omegaClawAdapterStateRecord
                    (omegaClawEngineStateRecord
                        $motivationState $taskState $autonomyState $goalState
                        $pendingAction $recentActions $diagnosticsHistory
                        $goalEvidence $nextTurnId $committedTurnIds $outcome)
                    $adapterTurnId $adapterCommittedIds $stageTrace)
                (case $outcome (
                    (none True)
                    ($_
                        (let* (
                            ($effectCount
                                (omegaClawOutcomeField
                                    $outcome effect-count))
                            ($effectClass
                                (omegaClawOutcomeField
                                    $outcome effect-class))
                            ($chargedEffects
                                (if (== $effectClass no-effect)
                                    0
                                    $effectCount))
                            ($_ (if (> $chargedEffects 0)
                                (omegaClawCoreRecordAutonomyBudget
                                    effect-count $chargedEffects)
                                True))
                            ($_ (if (omegaClawHostOutcomeChargesFailure
                                        $outcome)
                                (omegaClawCoreRecordAutonomyBudget
                                    failure-count 1)
                                True))
                        ) True))
                )))
            ($_ True)
        ))))

(= (omegaClawHostRecordTurn $turn $result)
    (let (omegaClawHostRunResultRecord
            $response $commands $displayResults $adapterState)
        $result
        (let* (
            ($historyStartedAt
                (py-call (workspace_policy.monotonic_seconds)))
            ($historyPayload
                (omegaClawHostHistoryPayloadForState
                    $commands $adapterState))
            ($_
            (omegaClawCoreRecordTurn
                $turn
                $historyPayload
                $historyPayload $displayResults
                (omegaClawHostWorkingOn $adapterState)))
            ($historyFinishedAt
                (py-call (workspace_policy.monotonic_seconds)))
            ($historyElapsed
                (eval (- $historyFinishedAt $historyStartedAt)))
            ($_ (println!
                (METAMO-TIMING: history $historyElapsed)))
        )
            (progn
            (omegaClawHostRecordAutonomyOutcome $turn $adapterState)
            (omegaClawHostEnsureContinuation $adapterState)
            $adapterState))))

(= (omegaClawHostTaskStatus $adapterState)
    (omegaClawTaskStateField
        (omegaClawEngineStateField
            (omegaClawAdapterStateField
                $adapterState extension-state)
            task-state)
        status))

;; Suspend an unanswered human task while preserving it as future context.
(= (omegaClawHostSuspendAwaitingHuman $adapterState)
    (let* (
        ($engine
            (omegaClawAdapterStateField
                $adapterState extension-state))
        ($taskState
            (omegaClawEngineStateField $engine task-state))
        ($suspendedTask
            (omegaClawTaskStateWithContext
                (omegaClawTaskStateField $taskState active-task)
                suspended
                no-effect
                (omegaClawTaskStateField $taskState evidence)))
    )
        (omegaClawAdapterState
            (omegaClawEngineState
                (omegaClawEngineStateField $engine motivation-state)
                $suspendedTask
                (omegaClawEngineStateField $engine autonomy-state)
                (omegaClawEngineStateField $engine goal-state)
                (omegaClawEngineStateField $engine pending-action)
                (omegaClawEngineStateField $engine recent-actions)
                (omegaClawEngineStateField $engine diagnostics-history)
                (omegaClawEngineStateField $engine goal-evidence)
                (omegaClawEngineStateField $engine next-turn-id)
                (omegaClawEngineStateField $engine committed-turn-ids)
                (omegaClawEngineStateField $engine last-outcome))
            (omegaClawAdapterStateField $adapterState next-turn-id)
            (omegaClawAdapterStateField $adapterState committed-turn-ids)
            (omegaClawAdapterStateField $adapterState stage-trace))))

(= (omegaClawHostIdleState $adapterState)
    (if (== (omegaClawHostTaskStatus $adapterState) awaiting-human)
        (let $waited
            (eval (+
                (omegaClawCoreRuntimeState human-wait-iterations)
                1))
            (if (>= $waited
                    (omegaClawCoreConfig human-response-wait-iterations))
                (omegaClawHostSuspendAwaitingHuman $adapterState)
                $adapterState))
        $adapterState))

(= (omegaClawHostRuntimeEffect $effect)
    (prog1 True $effect))

;; Apply wait bookkeeping only after the next adapter state is determined.
(= (omegaClawHostFinishHumanWait $previousState $nextState)
    (let* (
        ($previousStatus (omegaClawHostTaskStatus $previousState))
        ($nextStatus (omegaClawHostTaskStatus $nextState))
    )
        (if (== $previousStatus awaiting-human)
            (if (== $nextStatus suspended)
                (let* (
                    ($_ (println! (METAMO-HUMAN-WAIT-EXPIRED:
                        (omegaClawCoreConfig
                            human-response-wait-iterations))))
                    ($_ (omegaClawHostRuntimeEffect
                        (omegaClawCoreResetHumanWaitIterations)))
                    ($_ (omegaClawHostRuntimeEffect
                        (omegaClawCoreResetAutonomyBudget)))
                    ($_ (omegaClawHostRuntimeEffect
                        (omegaClawCoreEnsureLoopBudget
                            (eval (+ 1 (omegaClawCoreConfig
                                max-wake-loops))))))
                ) True)
                (omegaClawHostRuntimeEffect
                    (omegaClawCoreIncrementHumanWaitIterations)))
            (omegaClawHostRuntimeEffect
                (omegaClawCoreResetHumanWaitIterations)))))

(= (omegaClawHostFinishIdle $previousState $nextState)
    (let* (
        ($_ (omegaClawHostRuntimeEffect (omegaClawCoreIdle)))
    )
        (omegaClawHostFinishHumanWait $previousState $nextState)))


(= (omegaClawIntegratedLoopInitialTurnId $adapterState)
    (omegaClawAdapterStateField $adapterState next-turn-id))

(= (omegaClawIntegratedLoopInitialIteration)
    1)

(= (omegaClawIntegratedLoop $adapterState)
    (omegaClawIntegratedLoop
        $adapterState
        (omegaClawIntegratedLoopInitialTurnId $adapterState)
        (omegaClawIntegratedLoopInitialIteration)))

;; Run with a persistent turn ID and a session-local display iteration.
(= (omegaClawIntegratedLoop $adapterState $turnId $iteration)
    (let* (
        ($iterationStartedAt
            (py-call (workspace_policy.monotonic_seconds)))
        ($_ (omegaClawCoreBeginIteration $iteration))
        ($_ (println!
            (---------iteration $iteration)))
        ($turn (omegaClawCoreReceiveTurn $turnId $iteration))
        ($_ (omegaClawHostPrintHumanReceipt $turn))
        ($_ (println!
            (METAMO-Can-Run: (omegaClawCoreCanRun))))
        ($canRun (omegaClawCoreCanRun))
        ($nextState
            (if $canRun
                (omegaClawHostRecordTurn
                    $turn
                    (omegaClawHostRunTurn $turn $adapterState))
                (omegaClawHostIdleState $adapterState)))
        ($_ (if $canRun
            True
            (omegaClawHostFinishIdle $adapterState $nextState)))
        ($_ (omegaClawPersistenceSaveCommitted
                $adapterState $nextState))
        ($nextTurnId
            (omegaClawAdapterStateField
                $nextState next-turn-id))
        ($_ (println!
            (METAMO-NEXT-TURN: $nextTurnId)))
        ($iterationFinishedAt
            (py-call (workspace_policy.monotonic_seconds)))
        ($iterationElapsed
            (eval (- $iterationFinishedAt $iterationStartedAt)))
        ($_ (println!
            (METAMO-TIMING: total-turn $iterationElapsed)))
        ($_ (omegaClawCoreFinishIteration))
        ($_ (cut))
    )
        (omegaClawIntegratedLoop
            $nextState $nextTurnId (+ 1 $iteration))
    ))

(= (runMetaMoOmegaClaw)
    (case (omegaClawAdapterInitialize
            (omegaClawMetaMoAdapter) default) (
        ((validationOk $adapterState)
            (let* (
                ($persistentState
                    (omegaClawPersistenceInitialize $adapterState))
                ($_ (omegaClawCoreInitialize))
                ($_ (println! (METAMO-LIFECYCLE: initialized)))
            )
                (omegaClawIntegratedLoop $persistentState)))
        ((validationError $code $details)
            (println! (METAMO-INITIALIZATION-ERROR: $code $details)))
    )))

(= (omegaClawIntegrationReady)
    True)
