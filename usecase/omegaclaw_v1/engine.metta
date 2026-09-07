
(= (omegaClawTaskState $activeTask $status)
    (omegaClawTaskStateRecord $activeTask $status no-effect ()))

(= (omegaClawTaskStateWithContext
        $activeTask $status $authorization $evidence)
    (omegaClawTaskStateRecord
        $activeTask $status $authorization $evidence))

(= (omegaClawTaskStateField $taskState $field)
    (let (omegaClawTaskStateRecord
            $activeTask $status $authorization $evidence)
        $taskState
        (case $field (
            (active-task $activeTask)
            (status $status)
            (authorization $authorization)
            (evidence $evidence)
            ($_ (empty))
        ))))

(= (omegaClawAutonomyState $phase $actionCount)
    (omegaClawAutonomyStateRecord $phase $actionCount))

(= (omegaClawAutonomyStateField $autonomyState $field)
    (let (omegaClawAutonomyStateRecord $phase $actionCount)
        $autonomyState
        (case $field (
            (phase $phase)
            (action-count $actionCount)
            ($_ (empty))
        ))))

(= (omegaClawGoalState
        $goalId $description $acceptanceCriteria $status
        $currentStep $attemptCount $lastVerdict)
    (omegaClawGoalStateRecord
        $goalId $description $acceptanceCriteria $status
        $currentStep $attemptCount $lastVerdict))

(= (omegaClawGoalStateField $goalState $field)
    (case $goalState (
        (none none)
        ((omegaClawGoalStateRecord
                $goalId $description $acceptanceCriteria $status
                $currentStep $attemptCount $lastVerdict)
            (case $field (
                (goal-id $goalId)
                (description $description)
                (acceptance-criteria $acceptanceCriteria)
                (status $status)
                (current-step $currentStep)
                (attempt-count $attemptCount)
                (last-verdict $lastVerdict)
                ($_ (empty))
            )))
        ($_ (empty))
    )))

(= (omegaClawGoalStatuses)
    (active planned assessing verifying blocked complete))

(= (omegaClawGoalEvidence
        $sourceTurn $candidateId $commands $results)
    (omegaClawGoalEvidenceRecord
        $sourceTurn $candidateId $commands $results))

(= (omegaClawGoalEvidenceField $evidence $field)
    (let (omegaClawGoalEvidenceRecord
            $sourceTurn $candidateId $commands $results)
        $evidence
        (case $field (
            (source-turn $sourceTurn)
            (candidate-id $candidateId)
            (commands $commands)
            (results $results)
            ($_ (empty))
        ))))

(= (omegaClawValidateGoalState $goalState)
    (case $goalState (
        (none (validationOk none))
        ((omegaClawGoalStateRecord
                $goalId $description $acceptanceCriteria $status
                $currentStep $attemptCount $lastVerdict)
            (if (listContains (omegaClawGoalStatuses) $status)
                (if (>= $attemptCount 0)
                    (validationOk $goalState)
                    (validationError
                        invalid-omegaclaw-goal-attempt-count
                        $attemptCount))
                (validationError
                    invalid-omegaclaw-goal-status $status)))
        ($_
            (validationError
                invalid-omegaclaw-goal-state $goalState))
    )))

(= (omegaClawPendingAction $turnId $candidateId $capabilityEnvelope)
    (omegaClawPendingActionRecord
        $turnId $candidateId $capabilityEnvelope))

(= (omegaClawValidatePendingAction $pendingAction)
    (case $pendingAction (
        (none (validationOk none))
        ((omegaClawPendingActionRecord
                $turnId $candidateId $capabilityEnvelope)
            (let* (
                ($candidateIds (eval (omegaClawCandidateIds)))
                ($capabilityEnvelopes
                    (eval (omegaClawCapabilityEnvelopes)))
            )
                (if (eval (listContains
                        $candidateIds $candidateId))
                    (if (eval (listContains
                            $capabilityEnvelopes
                            $capabilityEnvelope))
                        (validationOk
                            (omegaClawPendingActionRecord
                                $turnId
                                $candidateId
                                $capabilityEnvelope))
                        (validationError
                            unknown-omegaclaw-capability-envelope
                            $capabilityEnvelope))
                    (validationError
                        unknown-omegaclaw-candidate
                        $candidateId))))
        ($_
            (validationError
                invalid-omegaclaw-pending-action
                $pendingAction))
    )))


(= (omegaClawEngineState
        $motivationState $taskState $autonomyState $goalState $pendingAction
        $recentActions $diagnosticsHistory $goalEvidence $nextTurnId
        $committedTurnIds $lastOutcome)
    (omegaClawEngineStateRecord
        $motivationState $taskState $autonomyState $goalState $pendingAction
        $recentActions $diagnosticsHistory $goalEvidence $nextTurnId
        $committedTurnIds $lastOutcome))

(= (omegaClawEngineStateField $engine $field)
    (let (omegaClawEngineStateRecord
            $motivationState $taskState $autonomyState $goalState $pendingAction
            $recentActions $diagnosticsHistory $goalEvidence $nextTurnId
            $committedTurnIds $lastOutcome)
        $engine
        (case $field (
            (motivation-state $motivationState)
            (task-state $taskState)
            (autonomy-state $autonomyState)
            (goal-state $goalState)
            (pending-action $pendingAction)
            (recent-actions $recentActions)
            (diagnostics-history $diagnosticsHistory)
            (goal-evidence $goalEvidence)
            (next-turn-id $nextTurnId)
            (committed-turn-ids $committedTurnIds)
            (last-outcome $lastOutcome)
            ($_ (empty))
        ))))

(= (omegaClawNewEngineState)
    (omegaClawEngineState
        (omegaClawDefaultState)
        (omegaClawTaskState none inactive)
        (omegaClawAutonomyState recall 0)
        none
        none
        ()
        ()
        ()
        1
        ()
        none))

(= (omegaClawEngineCollectionsWithinLimits $engine)
    (and
        (omegaClawCollectionWithinLimit
            (omegaClawEngineStateField $engine recent-actions)
            (omegaClawRecentActionLimit))
        (and
            (omegaClawCollectionWithinLimit
                (omegaClawEngineStateField
                    $engine diagnostics-history)
                (omegaClawDiagnosticsHistoryLimit))
            (and
                (omegaClawCollectionWithinLimit
                    (omegaClawEngineStateField $engine goal-evidence)
                    (omegaClawGoalEvidenceLimit))
                (and
                    (omegaClawCollectionWithinLimit
                        (omegaClawTaskStateField
                            (omegaClawEngineStateField $engine task-state)
                            evidence)
                        (omegaClawGoalEvidenceLimit))
                    (omegaClawCollectionWithinLimit
                        (omegaClawEngineStateField
                            $engine committed-turn-ids)
                        (omegaClawCommittedTurnIdLimit)))))))

(= (omegaClawValidateEngineState $engine)
    (let* (
        ($motivationState
            (omegaClawEngineStateField
                $engine motivation-state))
        ($pendingAction
            (omegaClawEngineStateField
                $engine pending-action))
        ($goalState
            (omegaClawEngineStateField $engine goal-state))
        ($nextTurnId
            (omegaClawEngineStateField
                $engine next-turn-id))
        ($stateResult
            (eval (validateMotivationState $motivationState)))
        ($pendingResult
            (eval (omegaClawValidatePendingAction $pendingAction)))
        ($goalResult
            (eval (omegaClawValidateGoalState $goalState)))
    )
        (if (eval (validationIsOk $stateResult))
            (if (eval (validationIsOk $pendingResult))
                (if (eval (validationIsOk $goalResult))
                    (if (eval
                            (omegaClawEngineCollectionsWithinLimits
                                $engine))
                        (if (eval (> $nextTurnId 0))
                            (validationOk $engine)
                            (validationError
                                invalid-omegaclaw-next-turn-id
                                $nextTurnId))
                        (validationError
                            oversized-omegaclaw-engine-collection
                            ((recent-actions
                                (size-atom
                                    (omegaClawEngineStateField
                                        $engine recent-actions)))
                             (diagnostics-history
                                (size-atom
                                    (omegaClawEngineStateField
                                        $engine diagnostics-history)))
                             (goal-evidence
                                (size-atom
                                    (omegaClawEngineStateField
                                        $engine goal-evidence)))
                             (committed-turn-ids
                                (size-atom
                                    (omegaClawEngineStateField
                                        $engine committed-turn-ids))))))
                    $goalResult)
                $pendingResult)
            $stateResult)))


(= (omegaClawPendingTransition
        $turnId $observation $perception $nextState $directive
        $pendingAction $diagnostics $contextFragment)
    (omegaClawPendingTransition
        $turnId $observation $perception $nextState $directive
        $pendingAction $diagnostics none () $contextFragment))

(= (omegaClawPendingTransition
        $turnId $observation $perception $nextState $directive
        $pendingAction $diagnostics $decisionEvidence $contextFragment)
    (omegaClawPendingTransition
        $turnId $observation $perception $nextState $directive
        $pendingAction $diagnostics $decisionEvidence () $contextFragment))

(= (omegaClawPendingTransition
        $turnId $observation $perception $nextState $directive
        $pendingAction $diagnostics $decisionEvidence
        $evidenceLedger $contextFragment)
    (omegaClawPendingTransitionRecord
        $turnId $observation $perception $nextState $directive
        $pendingAction $diagnostics $decisionEvidence
        $evidenceLedger $contextFragment))

(= (omegaClawPendingTransitionField $pending $field)
    (let (omegaClawPendingTransitionRecord
            $turnId $observation $perception $nextState $directive
            $pendingAction $diagnostics $decisionEvidence
            $evidenceLedger $contextFragment)
        $pending
        (case $field (
            (turn-id $turnId)
            (observation $observation)
            (perception $perception)
            (next-state $nextState)
            (directive $directive)
            (pending-action $pendingAction)
            (diagnostics $diagnostics)
            (decision-evidence $decisionEvidence)
            (evidence-ledger $evidenceLedger)
            (context-fragment $contextFragment)
            ($_ (empty))
        ))))

(= (omegaClawPreparedEngineTurn $engine $pending)
    (omegaClawPreparedEngineTurnRecord $engine $pending))

(= (omegaClawPreparedEngineTurnField $prepared $field)
    (let (omegaClawPreparedEngineTurnRecord $engine $pending)
        $prepared
        (case $field (
            (engine $engine)
            (pending $pending)
            ($_ (empty))
        ))))

(= (omegaClawCommittedEngineTurn
        $engine $outcome $directive $boundary $results)
    (omegaClawCommittedEngineTurnRecord
        $engine $outcome $directive $boundary $results))

(= (omegaClawCommittedEngineTurnField $committed $field)
    (let (omegaClawCommittedEngineTurnRecord
            $engine $outcome $directive $boundary $results)
        $committed
        (case $field (
            (engine $engine)
            (outcome $outcome)
            (directive $directive)
            (boundary $boundary)
            (results $results)
            ($_ (empty))
        ))))


(= (omegaClawTaskAuthorizationForObservation $observation)
    (let $semanticSignals
        (omegaClawObservationField $observation semantic-signals)
        (if (>= (omegaClawSignalStrengthByKind
                    $semanticSignals goal-control-request)
                (omegaClawSemanticSignalThresholdFor
                    goal-control-request))
            send-only
            (if (>= (omegaClawSignalStrengthByKind
                        $semanticSignals execution-request)
                    (omegaClawSemanticSignalThresholdFor
                        execution-request))
                requested-effect
                send-only))))

(= (omegaClawTaskStateForObservation $taskState $observation)
    (case (eval (omegaClawObservationField
                    $observation new-message)) (
        (True
            (let* (
                ($message
                    (eval (omegaClawObservationField
                        $observation message-text)))
            )
                (eval (omegaClawTaskStateWithContext
                    $message
                    active
                    (omegaClawTaskAuthorizationForObservation
                        $observation)
                    ()))))
        ($_ $taskState)
    )))

(= (omegaClawPerceptionForEngine $engine $observation)
    (if (omegaClawObservationField $observation new-message)
        (omegaClawPerceptionFromObservation $observation)
        (case (omegaClawEngineStateField
                        $engine last-outcome) (
            (none (omegaClawPerceptionFromObservation $observation))
            ($outcome
                (omegaClawPerceptionFromObservationAndOutcome
                    $observation $outcome))
        ))))

(= (omegaClawDirectiveFromDiagnosed
        $turnId $diagnosed $decisionEvidence)
    (let* (
        ($candidate (eval (diagnosedAction $diagnosed)))
        ($candidateId (eval (candidateId $candidate)))
        ($realizationId
            (eval (omegaClawCandidatePolicyField
                $candidate realization-id)))
        ($cognitiveMode
            (eval (omegaClawCandidatePolicyField
                $candidate cognitive-mode)))
        ($promptGuidance
            (eval (omegaClawCandidatePolicyField
                $candidate prompt-guidance)))
        ($capabilityEnvelope
            (eval (omegaClawCandidatePolicyField
                $candidate capability-envelope)))
        ($decisionScore
            (eval (omegaClawDecisionEvidenceField
                $decisionEvidence winner-score)))
        ($diagnostics (eval (diagnosedDiagnostics $diagnosed)))
        ($actionId (eval (diagnosticsActionId $diagnostics)))
        ($diagnosticsId
            (eval (omegaClawDiagnosticsId $turnId $actionId)))
    )
        (eval (omegaClawMotivationDirective
            $turnId
            $candidateId
            $realizationId
            $cognitiveMode
            $promptGuidance
            $capabilityEnvelope
            $decisionScore
            $diagnosticsId))))

(= (omegaClawPrepareTurnUnchecked $engine $observation)
    (let* (
        ($turnId
            (omegaClawEngineStateField $engine next-turn-id))
        ($perception
            (omegaClawPerceptionForEngine $engine $observation))
        ($motivationState
            (omegaClawEngineStateField
                $engine motivation-state))
        ($candidates
            (eval (omegaClawCandidateBuilderFn
                $motivationState $perception)))
        ($diagnosed
            (eval (stepWithDiagnostics
                (omegaClawBimonad)
                $motivationState
                $perception
                $candidates
                True)))
        ($nextState (eval (diagnosedState $diagnosed)))
        ($diagnostics (eval (diagnosedDiagnostics $diagnosed)))
        ($winner (eval (diagnosedAction $diagnosed)))
        ($decisionState
            (eval (decisionContext
                (omegaClawBimonad)
                $motivationState
                $perception)))
        ($scoreTraces
            (eval (omegaClawCandidateScoreTraces
                (omegaClawDecisionProfile)
                $decisionState
                $candidates)))
        ($bestScoreTrace
            (eval (omegaClawBestCandidateScoreTrace
                $scoreTraces)))
        ($decisionEvidence
            (eval (omegaClawDecisionEvidenceFromBest
                $motivationState
                $perception
                (omegaClawAvailableCandidateIds
                    $motivationState $perception)
                $scoreTraces
                (candidateId $winner)
                $bestScoreTrace)))
        ($directive
            (eval (omegaClawDirectiveFromDiagnosed
                $turnId $diagnosed $decisionEvidence)))
        ($candidateId
            (eval (omegaClawMotivationDirectiveField
                $directive candidate-id)))
        ($capabilityEnvelope
            (eval (omegaClawMotivationDirectiveField
                $directive capability-envelope)))
        ($currentTask
            (omegaClawEngineStateField $engine task-state))
        ($nextTask
            (eval (omegaClawTaskStateForObservation
                $currentTask $observation)))
        ($evidenceLedger
            (if (omegaClawCandidateTaskActive
                    (omegaClawTaskStateField $nextTask status))
                (omegaClawTaskStateField $nextTask evidence)
                (omegaClawEngineStateField $engine goal-evidence)))
        ($pendingAction
            (eval (omegaClawPendingAction
                $turnId $candidateId $capabilityEnvelope)))
        ($contextFragment
            (eval (omegaClawPromptFragment $directive)))
        ($pending
            (eval (omegaClawPendingTransition
                $turnId
                $observation
                $perception
                $nextState
                $directive
                $pendingAction
                $diagnostics
                $decisionEvidence
                $evidenceLedger
                $contextFragment)))
        ($autonomyState
            (omegaClawEngineStateField $engine autonomy-state))
        ($goalState
            (omegaClawEngineStateField $engine goal-state))
        ($recentActions
            (omegaClawEngineStateField $engine recent-actions))
        ($nextRecentActions
            (eval (omegaClawBoundedAppend
                $recentActions
                $pendingAction
                (omegaClawRecentActionLimit))))
        ($diagnosticsHistory
            (omegaClawEngineStateField
                $engine diagnostics-history))
        ($nextDiagnosticsHistory
            (eval (omegaClawBoundedAppend
                $diagnosticsHistory
                $diagnostics
                (omegaClawDiagnosticsHistoryLimit))))
        ($nextTurnId (eval (+ $turnId 1)))
        ($committedTurnIds
            (omegaClawEngineStateField
                $engine committed-turn-ids))
        ($preparedEngine
            (omegaClawEngineState
                $nextState
                $nextTask
                $autonomyState
                $goalState
                $pendingAction
                $nextRecentActions
                $nextDiagnosticsHistory
                (omegaClawEngineStateField $engine goal-evidence)
                $nextTurnId
                $committedTurnIds
                none))
    )
        (if (omegaClawDecisionEvidenceField
                $decisionEvidence exact-argmax)
            (validationOk
                (omegaClawPreparedEngineTurn
                    $preparedEngine $pending))
            (validationError
                omegaclaw-non-maximal-candidate
                $decisionEvidence))
    ))

(= (omegaClawPrepareTurn $engine $observation)
    (let* (
        ($engineResult
            (omegaClawValidateEngineState $engine))
        ($bundleResult (eval (omegaClawValidatedBundle)))
    )
        (if (eval (validationIsOk $engineResult))
            (if (eval (validationIsOk $bundleResult))
                (case (omegaClawEngineStateField
                            $engine pending-action) (
                    (none
                        (omegaClawPrepareTurnUnchecked
                            $engine $observation))
                    ($pendingAction
                        (validationError
                            omegaclaw-pending-action-not-committed
                            $pendingAction))
                ))
                $bundleResult)
            $engineResult)
        ))

(= (omegaClawFilterCommands
        $pending $parsedCommands $hostAuthorizedCommands)
    (let* (
        ($turnId
            (eval (omegaClawPendingTransitionField
                $pending turn-id)))
        ($directive
            (eval (omegaClawPendingTransitionField
                $pending directive)))
        ($evidenceAuthorizedCommands
            (omegaClawCommandsAllowedByPendingEvidence
                $pending $hostAuthorizedCommands))
        ($previousOutcome
            (omegaClawPerceptionField
                (omegaClawPendingTransitionField $pending perception)
                outcome))
    )
        (omegaClawBuildCommandBoundary
            $turnId $directive
            $parsedCommands $evidenceAuthorizedCommands
            $previousOutcome)))
;; Persist inert command metadata so state inspection cannot repeat effects.
(= (omegaClawCommandSnapshot $name $first $second $representation)
    (omegaClawCommandSnapshotRecord
        $name $first $second $representation))

(= (omegaClawCommandSnapshotField $snapshot $field)
    (let (omegaClawCommandSnapshotRecord
            $name $first $second $representation)
        $snapshot
        (case $field (
            (name $name)
            (first $first)
            (second $second)
            (representation $representation)
            ($_ (empty))
        ))))

(= (omegaClawCommandSnapshotFromCommand $command)
    (case $command (
        ((omegaClawCommandSnapshotRecord
                $name $first $second $representation)
            $command)
        ($_
            (let* (
                ($name (omegaClawCommandName (quote $command)))
                ($representation (repr (quote $command)))
            )
                (case $name (
                    (define-goal
                        (omegaClawCommandSnapshot
                            $name
                            (index-atom (quote $command) 1)
                            (index-atom (quote $command) 2)
                            $representation))
                    (goal-verdict
                        (omegaClawCommandSnapshot
                            $name
                            (index-atom (quote $command) 1)
                            (index-atom (quote $command) 2)
                            $representation))
                    (goal-progress
                        (omegaClawCommandSnapshot
                            $name
                            (index-atom (quote $command) 1)
                            none
                            $representation))
                    (pin
                        (omegaClawCommandSnapshot
                            $name
                            (index-atom (quote $command) 1)
                            none
                            $representation))
                    (shell
                        (omegaClawCommandSnapshot
                            $name
                            (index-atom (quote $command) 1)
                            none
                            $representation))
                    (read-file
                        (omegaClawCommandSnapshot
                            $name
                            (index-atom (quote $command) 1)
                            none
                            $representation))
                    ($_
                        (omegaClawCommandSnapshot
                            $name none none $representation))
                ))))
    )))

(= (omegaClawCommandSnapshots ())
    ())

(= (omegaClawCommandSnapshots $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
    )
        (cons-atom
            (omegaClawCommandSnapshotFromCommand (quote $head))
            (omegaClawCommandSnapshots $tail))))

(= (omegaClawCommandSnapshotCapability $snapshot)
    (let* (
        ($name (omegaClawCommandSnapshotField $snapshot name))
        ($first (omegaClawCommandSnapshotField $snapshot first))
    )
        (case $name (
            (read-file
                (if (== (py-call
                            (workspace_policy.safe_workspace_path $first))
                        true)
                    external-read
                    requested-effect))
            (shell
                (if (== (py-call
                            (workspace_policy.safe_workspace_shell $first))
                        true)
                    external-read
                    requested-effect))
            ($_ (omegaClawCommandCapabilityFromName $name))
        ))))

(= (omegaClawSnapshotsContainReadEvidence ())
    False)

(= (omegaClawSnapshotsContainReadEvidence $snapshots)
    (let* (
        ($head (car-atom (quote $snapshots)))
        ($tail (cdr-atom (quote $snapshots)))
        ($capability (omegaClawCommandSnapshotCapability $head))
    )
        (or
            (== $capability memory-read)
            (or
                (== $capability external-read)
                (omegaClawSnapshotsContainReadEvidence $tail)))))

;; Verify from cumulative independent evidence before requesting another read.
(= (omegaClawGoalEvidenceEntryIndependent $entry)
    (and
        (not (== (omegaClawGoalEvidenceField $entry results) ()))
        (omegaClawSnapshotsContainReadEvidence
            (omegaClawGoalEvidenceField $entry commands))))

(= (omegaClawGoalEvidenceLedgerIndependentCount ())
    0)

(= (omegaClawGoalEvidenceLedgerIndependentCount $ledger)
    (let* (
        ($head (car-atom (quote $ledger)))
        ($tail (cdr-atom (quote $ledger)))
    )
        (+
            (if (omegaClawGoalEvidenceEntryIndependent $head) 1 0)
            (omegaClawGoalEvidenceLedgerIndependentCount $tail))))

(= (omegaClawPreviousOutcomeHasIndependentEvidence $pending)
    (let* (
        ($perception
            (omegaClawPendingTransitionField $pending perception))
        ($outcome
            (omegaClawPerceptionField $perception outcome))
    )
        (case $outcome (
            (none False)
            ($_
                (and
                    (== (omegaClawOutcomeField
                            $outcome candidate-id)
                        verify-goal)
                    (and
                        (> (omegaClawOutcomeField
                                $outcome success-count) 0)
                        (and
                            (not (== (omegaClawOutcomeField
                                        $outcome user-visible-result)
                                    ()))
                            (omegaClawSnapshotsContainReadEvidence
                                (omegaClawOutcomeField
                                    $outcome commands-executed))))))
        ))))

(= (omegaClawPendingIndependentEvidenceCount $pending)
    (let $ledgerCount
        (omegaClawGoalEvidenceLedgerIndependentCount
            (omegaClawPendingTransitionField $pending evidence-ledger))
        (if (> $ledgerCount 0)
            $ledgerCount
            (if (omegaClawPreviousOutcomeHasIndependentEvidence $pending)
                1
                0))))

(= (omegaClawPendingHasIndependentEvidence $pending)
    (>= (omegaClawPendingIndependentEvidenceCount $pending)
        (omegaClawMinimumIndependentEvidenceEntries)))

(= (omegaClawPendingEvidenceLedgerStatus $pending)
    (if (omegaClawPendingHasIndependentEvidence $pending)
        evidence-ready
        evidence-missing))

(= (omegaClawCommandAllowedByPendingEvidence $pending $command)
    (case (omegaClawCommandName (quote $command)) (
        (goal-verdict
            (if (== (index-atom (quote $command) 1) complete)
                (omegaClawPendingHasIndependentEvidence $pending)
                True))
        ($_ True)
    )))

(= (omegaClawCommandsAllowedByPendingEvidence $pending ())
    ())

(= (omegaClawCommandsAllowedByPendingEvidence $pending $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
        ($remaining
            (omegaClawCommandsAllowedByPendingEvidence
                $pending $tail))
    )
        (if (omegaClawCommandAllowedByPendingEvidence
                $pending $head)
            (cons-atom $head $remaining)
            $remaining)))


(= (omegaClawCommandResult $command $status $payloadSummary)
    (let* (
        ($snapshot
            (omegaClawCommandSnapshotFromCommand (quote $command)))
    )
        (omegaClawCommandResultFromSnapshot
            $snapshot $status $payloadSummary)))

;; Reuse dispatch snapshots when recording results.
(= (omegaClawCommandResultFromSnapshot
        $snapshot $status $payloadSummary)
    (omegaClawCommandResultRecord
        $snapshot
        (omegaClawCommandSnapshotCapability $snapshot)
        $status
        $payloadSummary))

(= (omegaClawCommandResultField $result $field)
    (let (omegaClawCommandResultRecord
            $command $capability $status $payloadSummary)
        $result
        (case $field (
            (command $command)
            (capability $capability)
            (status $status)
            (payload-summary $payloadSummary)
            ($_ (empty))
        ))))

(= (omegaClawCommandResultStatuses)
    (success failure safety-event contradiction))

(= (omegaClawCommandResultsMatch () $executableSnapshots)
    True)

(= (omegaClawCommandResultsMatch $results $executableSnapshots)
    (let* (
        ($head (car-atom (quote $results)))
        ($tail (cdr-atom (quote $results)))
        ($command
            (omegaClawCommandResultField $head command))
        ($capability
            (omegaClawCommandResultField $head capability))
        ($expectedCapability
            (omegaClawCommandSnapshotCapability $command))
        ($status
            (omegaClawCommandResultField $head status))
        ($statuses (eval (omegaClawCommandResultStatuses)))
        ($statusAllowed
            (eval (listContains $statuses $status)))
        ($restValid
            (omegaClawCommandResultsMatch
                $tail $executableSnapshots))
        ($commandAuthorized
            (validationIsOk
                (omegaClawRemoveFirst
                    $executableSnapshots $command)))
    )
        (and
            $commandAuthorized
            (and
                (eval (== $capability $expectedCapability))
                (and $statusAllowed $restValid)))))

(= (omegaClawCommandResultsValid $results $executableCommands)
    (omegaClawCommandResultsMatch
        $results
        (omegaClawCommandSnapshots (quote $executableCommands))))

(= (omegaClawCommandResultCommands ())
    ())

(= (omegaClawCommandResultCommands $results)
    (let* (
        ($head (car-atom (quote $results)))
        ($tail (cdr-atom (quote $results)))
        ($command
            (omegaClawCommandResultField $head command))
        ($remaining
            (omegaClawCommandResultCommands $tail))
    )
        (cons-atom $command $remaining)))

(= (omegaClawCommandResultCount () $status)
    0)

(= (omegaClawCommandResultCount $results $status)
    (let* (
        ($head (car-atom (quote $results)))
        ($tail (cdr-atom (quote $results)))
        ($resultStatus
            (omegaClawCommandResultField $head status))
        ($increment
            (if (eval (== $resultStatus $status)) 1 0))
        ($remaining
            (omegaClawCommandResultCount $tail $status))
    )
        (eval (+ $increment $remaining))))

(= (omegaClawCommandResultPayloads ())
    ())

(= (omegaClawCommandResultPayloads $results)
    (let* (
        ($head (car-atom (quote $results)))
        ($tail (cdr-atom (quote $results)))
        ($payload
            (omegaClawCommandResultField
                $head payload-summary))
        ($remaining
            (omegaClawCommandResultPayloads $tail))
    )
        (cons-atom $payload $remaining)))

(= (omegaClawPayloadHasUtility $payload)
    (case $payload (
        (() False)
        ([] False)
        (None False)
        ((Error $errorType $details) False)
        ($_ True)
    )))

(= (omegaClawCapabilityHasIntrinsicResult $capability)
    (case $capability (
        (channel-send True)
        (working-memory-write True)
        (memory-write True)
        (goal-control True)
        ($_ False)
    )))

(= (omegaClawCommandResultHasUtility $result)
    (and
        (== (omegaClawCommandResultField $result status) success)
        (or
            (omegaClawCapabilityHasIntrinsicResult
                (omegaClawCommandResultField $result capability))
            (omegaClawPayloadHasUtility
                (omegaClawCommandResultField
                    $result payload-summary)))))

(= (omegaClawUsefulCommandResultCount ())
    0)

(= (omegaClawUsefulCommandResultCount $results)
    (let* (
        ($head (car-atom (quote $results)))
        ($tail (cdr-atom (quote $results)))
        ($increment
            (if (omegaClawCommandResultHasUtility $head) 1 0))
    )
        (+ $increment
            (omegaClawUsefulCommandResultCount $tail))))

;; Keep operational utility, task progress, and verification independent.
(= (omegaClawCapabilityProducesEvidence $capability)
    (case $capability (
        (memory-read True)
        (external-read True)
        ($_ False)
    )))

(= (omegaClawCommandResultHasEvidence $result)
    (and
        (== (omegaClawCommandResultField $result status) success)
        (and
            (omegaClawCapabilityProducesEvidence
                (omegaClawCommandResultField $result capability))
            (omegaClawPayloadHasUtility
                (omegaClawCommandResultField
                    $result payload-summary)))))

(= (omegaClawEvidenceCommandResultCount ())
    0)

(= (omegaClawEvidenceCommandResultCount $results)
    (let* (
        ($head (car-atom (quote $results)))
        ($tail (cdr-atom (quote $results)))
        ($increment
            (if (omegaClawCommandResultHasEvidence $head) 1 0))
    )
        (+ $increment
            (omegaClawEvidenceCommandResultCount $tail))))

(= (omegaClawCapabilityHasIntrinsicTaskValue $capability)
    (case $capability (
        (requested-effect True)
        ($_ False)
    )))

(= (omegaClawCommandResultHasTaskValue $result)
    (and
        (== (omegaClawCommandResultField $result status) success)
        (or
            (omegaClawCommandResultHasEvidence $result)
            (omegaClawCapabilityHasIntrinsicTaskValue
                (omegaClawCommandResultField $result capability)))))

(= (omegaClawTaskValueCommandResultCount ())
    0)

(= (omegaClawTaskValueCommandResultCount $results)
    (let* (
        ($head (car-atom (quote $results)))
        ($tail (cdr-atom (quote $results)))
        ($increment
            (if (omegaClawCommandResultHasTaskValue $head) 1 0))
    )
        (+ $increment
            (omegaClawTaskValueCommandResultCount $tail))))

(= (omegaClawOutcomeEvidenceQuality $results $executionBase)
    (eval
        (clipUnit
            (/ (omegaClawEvidenceCommandResultCount $results)
               $executionBase))))

(= (omegaClawCommandResultCapabilityCount
        () $capability $status)
    0)

(= (omegaClawCommandResultCapabilityCount
        $results $capability $status)
    (let* (
        ($head (car-atom (quote $results)))
        ($tail (cdr-atom (quote $results)))
        ($matches
            (and
                (== (omegaClawCommandResultField
                        $head capability) $capability)
                (== (omegaClawCommandResultField
                        $head status) $status)))
    )
        (+ (if $matches 1 0)
           (omegaClawCommandResultCapabilityCount
                $tail $capability $status))))

(= (omegaClawCapabilityEffectClass $capability)
    (case $capability (
        (memory-read read-effect)
        (external-read read-effect)
        (working-memory-write write-effect)
        (memory-write write-effect)
        (goal-control write-effect)
        (channel-send external-effect)
        (requested-effect external-effect)
        ($_ unknown)
    )))

(= (omegaClawCombineEffectClass $current $next)
    (case $current (
        (no-effect $next)
        ($_ (if (== $next no-effect)
            $current
            (if (== $current $next) $current mixed)))
    )))

(= (omegaClawCommandResultsEffectClass ())
    no-effect)

(= (omegaClawCommandResultsEffectClass $results)
    (let* (
        ($head (car-atom (quote $results)))
        ($tail (cdr-atom (quote $results)))
    )
        (omegaClawCombineEffectClass
            (omegaClawCapabilityEffectClass
                (omegaClawCommandResultField $head capability))
            (omegaClawCommandResultsEffectClass $tail))))

(= (omegaClawOutcomeProposalStatus
        $guidanceCandidateId $parsed $authorized $blockedCount)
    (if (omegaClawNoEffectOutcomeCandidate $guidanceCandidateId)
        not-required
        (if (== $parsed ())
            empty
            (if (== $authorized ())
                invalid
                (if (> $blockedCount 0) partial valid)))))

(= (omegaClawOutcomeDispatchStatus
        $executedCount $successCount $failureCount)
    (if (== $executedCount 0)
        not-dispatched
        (if (> $failureCount 0)
            (if (> $successCount 0) partial failed)
            executed)))

(= (omegaClawOutcomeResultUtility
        $executedCount $usefulResultCount)
    (if (== $executedCount 0)
        irrelevant
        (if (> $usefulResultCount 0) useful empty)))

(= (omegaClawOutcomeVerificationStatus
        $guidanceCandidateId $realizationId $executed
        $successCount $failureCount $evidenceQuality)
    (if (or (== $guidanceCandidateId verify)
            (== $realizationId verify-goal))
        (case (omegaClawGoalVerdictField
                    (omegaClawGoalVerdictFromCommands $executed)
                    status) (
            (complete passed)
            (blocked failed)
            (incomplete failed)
            (none
                (if (> $failureCount 0)
                    failed
                    (if (and (> $successCount 0)
                             (>= $evidenceQuality
                                 (omegaClawEvidenceSufficiencyThreshold)))
                        pending pending)))
            ($_ pending)
        ))
        (if (omegaClawSnapshotsNeedTaskVerification $executed)
            pending
            not-required)))

(= (omegaClawOutcomeDeliveryStatus
        $guidanceCandidateId $results)
    (let* (
        ($sent
            (omegaClawCommandResultCapabilityCount
                $results channel-send success))
        ($failed
            (omegaClawCommandResultCapabilityCount
                $results channel-send failure))
    )
        (if (> $sent 0)
            sent
            (if (> $failed 0)
                failed
                (case $guidanceCandidateId (
                    (respond suppressed)
                    (clarify suppressed)
                    ($_ not-applicable)
                ))))))

(= (omegaClawOutcomeEvidenceRelevant
        $proposalStatus $dispatchStatus $resultUtility
        $verificationStatus $deliveryStatus
        $safetyEvents $contradictions)
    (omegaClawOutcomeHasLegacyEvidence
        $proposalStatus $dispatchStatus $resultUtility
        $verificationStatus $deliveryStatus
        $safetyEvents $contradictions))

(= (omegaClawSuppressedProposalStatus $parsed)
    (if (== $parsed ()) not-requested valid))

(= (omegaClawSuppressedOutcomeFromCommandResults
        $pending $boundary $disposition)
    (let* (
        ($parsed
            (omegaClawCommandBoundaryField
                $boundary parsed-commands))
        ($authorized
            (omegaClawCommandBoundaryField
                $boundary host-authorized-commands))
        ($directive
            (eval (omegaClawPendingTransitionField
                $pending directive)))
        ($turnId
            (eval (omegaClawPendingTransitionField $pending turn-id)))
        ($realizationId
            (eval (omegaClawMotivationDirectiveField
                $directive realization-id)))
        ($candidateId
            (eval (omegaClawMotivationDirectiveField
                $directive candidate-id)))
        ($meaning
            (omegaClawOutcomeMeaningWithProposal
                (omegaClawSuppressedProposalStatus $parsed)
                not-dispatched 0 no-effect irrelevant
                not-required not-applicable $disposition
                $candidateId $realizationId False
                (omegaClawCommandBoundaryField
                    $boundary proposal-fingerprint)
                (omegaClawCommandBoundaryField
                    $boundary proposal-attempt)))
    )
        (omegaClawOutcomeWithMeaning
            $turnId
            $realizationId
            (omegaClawCommandSnapshots (quote $parsed))
            (omegaClawCommandSnapshots (quote $authorized))
            ()
            0 0 0 ()
            0.0 0.0 0.0 0.0 0.0
            $meaning)))

(= (omegaClawOutcomeFromCommandResults $pending $boundary $results)
    (omegaClawOutcomeFromCommandResultsWithDisposition
        $pending $boundary $results none))

(= (omegaClawOutcomeFromCommandResultsWithDisposition
        $pending $boundary $results $disposition)
    (case $disposition (
        (preempted-by-human
            (omegaClawSuppressedOutcomeFromCommandResults
                $pending $boundary $disposition))
        (autonomy-budget-exhausted
            (omegaClawSuppressedOutcomeFromCommandResults
                $pending $boundary $disposition))
        (motivation-action-threshold
            (omegaClawSuppressedOutcomeFromCommandResults
                $pending $boundary $disposition))
        (motivation-yield-threshold
            (omegaClawSuppressedOutcomeFromCommandResults
                $pending $boundary $disposition))
        (provider-timeout
            (omegaClawSuppressedOutcomeFromCommandResults
                $pending $boundary $disposition))
        (provider-unavailable
            (omegaClawSuppressedOutcomeFromCommandResults
                $pending $boundary $disposition))
        (provider-error
            (omegaClawSuppressedOutcomeFromCommandResults
                $pending $boundary $disposition))
        (provider-empty-response
            (omegaClawSuppressedOutcomeFromCommandResults
                $pending $boundary $disposition))
        (provider-output-limit
            (omegaClawSuppressedOutcomeFromCommandResults
                $pending $boundary $disposition))
        (provider-reasoning-only
            (omegaClawSuppressedOutcomeFromCommandResults
                $pending $boundary $disposition))
        ($_
            (omegaClawOutcomeFromCommandResultsNormally
                $pending $boundary $results))
    )))

(= (omegaClawOutcomeFromCommandResultsNormally
        $pending $boundary $results)
    (let* (
        ($parsed
            (omegaClawCommandBoundaryField
                $boundary parsed-commands))
        ($authorized
            (omegaClawCommandBoundaryField
                $boundary host-authorized-commands))
        ($parsedSnapshots
            (omegaClawCommandSnapshots (quote $parsed)))
        ($authorizedSnapshots
            (omegaClawCommandSnapshots (quote $authorized)))
        ($executed
            (omegaClawCommandResultCommands $results))
        ($successCount
            (omegaClawCommandResultCount $results success))
        ($failureCount
            (omegaClawCommandResultCount $results failure))
        ($parsedCount (size-atom (quote $parsed)))
        ($executedCount (size-atom (quote $executed)))
        ($resultCount (size-atom (quote $results)))
        ($blockedCount
            (eval (maxNumber 0
                (- $parsedCount $executedCount))))
        ($executionBase (eval (maxNumber 1 $executedCount)))
        ($proposalBase (eval (maxNumber 1 $parsedCount)))
        ($directive
            (eval (omegaClawPendingTransitionField
                $pending directive)))
        ($turnId
            (eval (omegaClawPendingTransitionField $pending turn-id)))
        ($candidateId
            (eval (omegaClawMotivationDirectiveField
                $directive realization-id)))
        ($guidanceCandidateId
            (eval (omegaClawMotivationDirectiveField
                $directive candidate-id)))
        ($payloads
            (omegaClawCommandResultPayloads $results))
        ($usefulResultCount
            (omegaClawUsefulCommandResultCount $results))
        ($taskValueResultCount
            (omegaClawTaskValueCommandResultCount $results))
        ($progress
            (eval (clipUnit (/ $taskValueResultCount $proposalBase))))
        ($evidence
            (omegaClawOutcomeEvidenceQuality
                $results $executionBase))
        ($safetyEvents
            (omegaClawCommandResultCount
                $results safety-event))
        ($autonomyUsage
            (eval (clipUnit (/ $executedCount $proposalBase))))
        ($contradictions
            (omegaClawCommandResultCount
                $results contradiction))
        ($uncertainty (eval (clipUnit $contradictions)))
        ($derivedProposalStatus
            (omegaClawOutcomeProposalStatus
                $guidanceCandidateId $parsed $authorized $blockedCount))
        ($proposalValidation
            (omegaClawCommandBoundaryField
                $boundary proposal-validation))
        ($proposalStatus
            (case $proposalValidation (
                ((validationError empty-required-output $_) empty)
                ((validationError $_ $_) invalid)
                ($_ $derivedProposalStatus)
            )))
        ($dispatchStatus
            (omegaClawOutcomeDispatchStatus
                $executedCount $successCount $failureCount))
        ($resultUtility
            (omegaClawOutcomeResultUtility
                $executedCount $usefulResultCount))
        ($verificationStatus
            (omegaClawOutcomeVerificationStatus
                $guidanceCandidateId $candidateId $executed
                $successCount $failureCount $evidence))
        ($deliveryStatus
            (omegaClawOutcomeDeliveryStatus
                $guidanceCandidateId $results))
        ($derivedFailureReason
            (omegaClawOutcomeFailureReasonFromStatuses
                $proposalStatus $dispatchStatus $resultUtility
                $verificationStatus $deliveryStatus
                $safetyEvents $contradictions))
        ($failureReason
            (case $proposalValidation (
                ((validationError $code $_) $code)
                ($_ $derivedFailureReason)
            )))
        ($meaning
            (omegaClawOutcomeMeaningWithProposal
                $proposalStatus $dispatchStatus $executedCount
                (omegaClawCommandResultsEffectClass $results)
                $resultUtility $verificationStatus $deliveryStatus
                $failureReason $guidanceCandidateId $candidateId
                (omegaClawOutcomeEvidenceRelevant
                    $proposalStatus $dispatchStatus $resultUtility
                    $verificationStatus $deliveryStatus
                    $safetyEvents $contradictions)
                (omegaClawCommandBoundaryField
                    $boundary proposal-fingerprint)
                (omegaClawCommandBoundaryField
                    $boundary proposal-attempt)))
    )
        (omegaClawOutcomeWithMeaning
            $turnId
            $candidateId
            $parsedSnapshots
            $authorizedSnapshots
            $executed
            $successCount
            $failureCount
            $blockedCount
            $payloads
            $progress
            $evidence
            $safetyEvents
            $autonomyUsage
            $uncertainty
            $meaning)))

(= (omegaClawGoalDefinition $description $acceptanceCriteria)
    (omegaClawGoalDefinitionRecord $description $acceptanceCriteria))

(= (omegaClawGoalDefinitionFromCommands ())
    none)

(= (omegaClawGoalDefinitionFromCommands $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
    )
        (case (omegaClawCommandSnapshotField $head name) (
            (define-goal
                (omegaClawGoalDefinition
                    (omegaClawCommandSnapshotField $head first)
                    (omegaClawCommandSnapshotField $head second)))
            ($_ (omegaClawGoalDefinitionFromCommands $tail))
        ))))

(= (omegaClawGoalStepFromCommands ())
    none)

(= (omegaClawGoalStepFromCommands $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
    )
        (case (omegaClawCommandSnapshotField $head name) (
            (pin (omegaClawCommandSnapshotField $head first))
            ($_ (omegaClawGoalStepFromCommands $tail))
        ))))

(= (omegaClawGoalVerdict $status $evidence)
    (omegaClawGoalVerdictRecord $status $evidence))

(= (omegaClawGoalVerdictField $verdict $field)
    (case $verdict (
        (none none)
        ((omegaClawGoalVerdictRecord $status $evidence)
            (case $field (
                (status $status)
                (evidence $evidence)
                ($_ (empty))
            )))
        ($_ (empty))
    )))

(= (omegaClawGoalVerdictFromCommands ())
    none)

(= (omegaClawGoalVerdictFromCommands $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
    )
        (case (omegaClawCommandSnapshotField $head name) (
            (goal-verdict
                (omegaClawGoalVerdict
                    (omegaClawCommandSnapshotField $head first)
                    (omegaClawCommandSnapshotField $head second)))
            ($_ (omegaClawGoalVerdictFromCommands $tail))
        ))))

(= (omegaClawGoalProgressFromCommands ())
    none)

(= (omegaClawGoalProgressFromCommands $commands)
    (let* (
        ($head (car-atom (quote $commands)))
        ($tail (cdr-atom (quote $commands)))
    )
        (case (omegaClawCommandSnapshotField $head name) (
            (goal-progress
                (omegaClawCommandSnapshotField $head first))
            ($_ (omegaClawGoalProgressFromCommands $tail))
        ))))

(= (omegaClawOutcomeCommandSucceeded $outcome)
    (> (omegaClawOutcomeField $outcome success-count) 0))

(= (omegaClawOutcomeUsefulSuccess $outcome)
    (and
        (omegaClawOutcomeCommandSucceeded $outcome)
        (== (omegaClawOutcomeField $outcome result-utility) useful)))

(= (omegaClawOutcomeAdvancesAutonomy $outcome)
    (case (omegaClawOutcomeField $outcome candidate-id) (
        (recall-goals (omegaClawOutcomeCommandSucceeded $outcome))
        ($_ (omegaClawOutcomeUsefulSuccess $outcome))
    )))

(= (omegaClawOutcomeGoalVerdict $outcome)
    (omegaClawGoalVerdictFromCommands
        (omegaClawOutcomeField $outcome commands-executed)))

(= (omegaClawCapabilityNeedsTaskVerification $capability)
    (case $capability (
        (requested-effect True)
        (memory-write True)
        (goal-control False)
        (unknown True)
        ($_ False)
    )))

(= (omegaClawSnapshotsNeedTaskVerification ())
    False)

(= (omegaClawSnapshotsNeedTaskVerification $snapshots)
    (let* (
        ($head (car-atom (quote $snapshots)))
        ($tail (cdr-atom (quote $snapshots)))
    )
        (or
            (omegaClawCapabilityNeedsTaskVerification
                (omegaClawCommandSnapshotCapability $head))
            (omegaClawSnapshotsNeedTaskVerification $tail))))

(= (omegaClawSnapshotsOnlyChannelSends ())
    False)

(= (omegaClawSnapshotsOnlyChannelSends $snapshots)
    (let* (
        ($head (car-atom (quote $snapshots)))
        ($tail (cdr-atom (quote $snapshots)))
    )
        (and
            (== (omegaClawCommandSnapshotCapability $head) channel-send)
            (case $tail (
                (() True)
                ($_ (omegaClawSnapshotsOnlyChannelSends $tail))
            )))))

(= (omegaClawOutcomeNeedsTaskVerification $outcome)
    (or
        (> (omegaClawOutcomeField $outcome safety-events) 0)
        (or
            (> (omegaClawOutcomeField
                    $outcome contradiction-evidence) 0)
            (or
                (> (omegaClawOutcomeField $outcome blocked-count) 0)
                (omegaClawSnapshotsNeedTaskVerification
                    (omegaClawOutcomeField
                        $outcome commands-executed))))))

(= (omegaClawGoalEvidenceAppend $items $evidence)
    (omegaClawBoundedAppend
        $items $evidence (omegaClawGoalEvidenceLimit)))

(= (omegaClawOutcomeCarriesTaskEvidence $taskState $outcome)
    (and
        (omegaClawCandidateTaskActive
            (omegaClawTaskStateField $taskState status))
        (and
            (omegaClawSnapshotsContainReadEvidence
                (omegaClawOutcomeField $outcome commands-executed))
            (== (omegaClawOutcomeField
                    $outcome result-utility) useful))))

(= (omegaClawTaskEvidenceAfterOutcome $taskState $outcome)
    (let $evidence
        (omegaClawTaskStateField $taskState evidence)
        (if (omegaClawOutcomeCarriesTaskEvidence $taskState $outcome)
            (omegaClawGoalEvidenceAppend
                $evidence
                (omegaClawGoalEvidence
                    (omegaClawOutcomeField $outcome source-turn)
                    (omegaClawOutcomeField $outcome candidate-id)
                    (omegaClawOutcomeField $outcome commands-executed)
                    (omegaClawOutcomeField $outcome user-visible-result)))
            $evidence)))

(= (omegaClawTaskStateAtStatus $taskState $status $evidence)
    (omegaClawTaskStateWithContext
        (omegaClawTaskStateField $taskState active-task)
        $status
        (omegaClawTaskStateField $taskState authorization)
        $evidence))

(= (omegaClawTaskStateAfterOutcome $taskState $outcome)
    (let* (
        ($activeTask
            (omegaClawTaskStateField $taskState active-task))
        ($taskEvidence
            (omegaClawTaskEvidenceAfterOutcome $taskState $outcome))
        ($candidateId
            (omegaClawOutcomeField $outcome candidate-id))
        ($taskActive
            (omegaClawCandidateTaskActive
                (omegaClawTaskStateField $taskState status)))
        ($taskEffectCommitted
            (and
                (omegaClawOutcomeUsefulSuccess $outcome)
                $taskActive))
        ($verdictStatus
            (omegaClawGoalVerdictField
                (omegaClawOutcomeGoalVerdict $outcome) status))
    )
        (case $candidateId (
            (respond
                (if $taskEffectCommitted
                    (omegaClawTaskState none completed)
                    $taskState))
            (ask-clarification
                (if $taskEffectCommitted
                    (omegaClawTaskStateAtStatus
                        $taskState awaiting-human $taskEvidence)
                    $taskState))
            (execute-skill
                (if $taskEffectCommitted
                    (if (omegaClawSnapshotsOnlyChannelSends
                            (omegaClawOutcomeField
                                $outcome commands-executed))
                        (omegaClawTaskState none completed)
                        (if (omegaClawOutcomeNeedsTaskVerification $outcome)
                            (omegaClawTaskStateAtStatus
                                $taskState verifying $taskEvidence)
                            (omegaClawTaskStateAtStatus
                                $taskState ready $taskEvidence)))
                    $taskState))
            (repair-failure
                (if $taskEffectCommitted
                    (if (omegaClawOutcomeNeedsTaskVerification $outcome)
                        (omegaClawTaskStateAtStatus
                            $taskState verifying $taskEvidence)
                        (omegaClawTaskStateAtStatus
                            $taskState ready $taskEvidence))
                    $taskState))
            (verify-goal
                (if $taskEffectCommitted
                    (case $verdictStatus (
                        (complete
                            (omegaClawTaskStateAtStatus
                                $taskState verified $taskEvidence))
                        (blocked
                            (omegaClawTaskStateAtStatus
                                $taskState blocked $taskEvidence))
                        (none
                            (omegaClawTaskStateAtStatus
                                $taskState
                                (omegaClawTaskStateField
                                    $taskState status)
                                $taskEvidence))
                        ($_
                            (omegaClawTaskStateAtStatus
                                $taskState active $taskEvidence))
                    ))
                    $taskState))
            ($_ $taskState)
        ))))

(= (omegaClawOutcomeCarriesGoalEvidence $taskState $outcome)
    (and
        (not (omegaClawCandidateTaskActive
            (omegaClawTaskStateField $taskState status)))
        (and
            (omegaClawSnapshotsContainReadEvidence
                (omegaClawOutcomeField $outcome commands-executed))
            (== (omegaClawOutcomeField
                    $outcome result-utility) useful))))

(= (omegaClawGoalEvidenceAfterOutcome
        $goalEvidence $taskState $outcome)
    (let $candidateId
        (omegaClawOutcomeField $outcome candidate-id)
        (case $candidateId (
            (invent-goal ())
            ($_
                (if (omegaClawOutcomeCarriesGoalEvidence
                        $taskState $outcome)
                    (omegaClawGoalEvidenceAppend
                        $goalEvidence
                        (omegaClawGoalEvidence
                            (omegaClawOutcomeField
                                $outcome source-turn)
                            $candidateId
                            (omegaClawOutcomeField
                                $outcome commands-executed)
                            (omegaClawOutcomeField
                                $outcome user-visible-result)))
                    $goalEvidence))
        ))))

(= (omegaClawGoalStateAfterOutcome $goalState $taskState $outcome)
    (let* (
        ($candidateId
            (omegaClawOutcomeField $outcome candidate-id))
        ($commands
            (omegaClawOutcomeField $outcome commands-executed))
        ($succeeded (omegaClawOutcomeUsefulSuccess $outcome))
        ($autonomyTurn
            (not (omegaClawCandidateTaskActive
                (omegaClawTaskStateField $taskState status))))
    )
        (if (and $succeeded $autonomyTurn)
            (case $candidateId (
                (invent-goal
                    (case (omegaClawGoalDefinitionFromCommands $commands) (
                        ((omegaClawGoalDefinitionRecord
                                $description $acceptanceCriteria)
                            (omegaClawGoalState
                                (omegaClawGoalId
                                    (omegaClawOutcomeField
                                        $outcome source-turn))
                                $description
                                $acceptanceCriteria
                                active none 0 none))
                        ($_ $goalState)
                    )))
                (plan-goal
                    (case $goalState (
                        ((omegaClawGoalStateRecord
                                $goalId $description $acceptanceCriteria
                                $status $currentStep $attemptCount
                                $lastVerdict)
                            (case (omegaClawGoalStepFromCommands $commands) (
                                (none $goalState)
                                ($step
                                    (omegaClawGoalState
                                        $goalId $description
                                        $acceptanceCriteria planned
                                        $step $attemptCount $lastVerdict))
                            )))
                        ($_ $goalState)
                    )))
                (background-work
                    (case $goalState (
                        ((omegaClawGoalStateRecord
                                $goalId $description $acceptanceCriteria
                                $status $currentStep $attemptCount
                                $lastVerdict)
                            (omegaClawGoalState
                                $goalId $description $acceptanceCriteria
                                assessing $currentStep
                                (+ $attemptCount 1) none))
                        ($_ $goalState)
                    )))
                (repair-autonomy
                    (case $goalState (
                        ((omegaClawGoalStateRecord
                                $goalId $description $acceptanceCriteria
                                $status $currentStep $attemptCount
                                $lastVerdict)
                            (omegaClawGoalState
                                $goalId $description $acceptanceCriteria
                                assessing $currentStep
                                (+ $attemptCount 1) none))
                        ($_ $goalState)
                    )))
                (assess-progress
                    (case $goalState (
                        ((omegaClawGoalStateRecord
                                $goalId $description $acceptanceCriteria
                                $status $currentStep $attemptCount
                                $lastVerdict)
                            (case (omegaClawGoalProgressFromCommands
                                    $commands) (
                                (continue
                                    (omegaClawGoalState
                                        $goalId $description
                                        $acceptanceCriteria active none
                                        $attemptCount $lastVerdict))
                                (ready
                                    (omegaClawGoalState
                                        $goalId $description
                                        $acceptanceCriteria verifying
                                        $currentStep $attemptCount
                                        $lastVerdict))
                                (blocked
                                    (omegaClawGoalState
                                        $goalId $description
                                        $acceptanceCriteria blocked
                                        $currentStep $attemptCount
                                        $lastVerdict))
                                ($_ $goalState)
                            )))
                        ($_ $goalState)
                    )))
                (verify-goal
                    (case $goalState (
                        ((omegaClawGoalStateRecord
                                $goalId $description $acceptanceCriteria
                                $status $currentStep $attemptCount
                                $lastVerdict)
                            (let $verdict
                                (omegaClawGoalVerdictFromCommands $commands)
                                (case (omegaClawGoalVerdictField
                                            $verdict status) (
                                    (complete
                                        (omegaClawGoalState
                                            $goalId $description
                                            $acceptanceCriteria complete
                                            $currentStep $attemptCount
                                            $verdict))
                                    (incomplete
                                        (omegaClawGoalState
                                            $goalId $description
                                            $acceptanceCriteria active
                                            $currentStep $attemptCount
                                            $verdict))
                                    (blocked
                                        (omegaClawGoalState
                                            $goalId $description
                                            $acceptanceCriteria blocked
                                            $currentStep $attemptCount
                                            $verdict))
                                    ($_ $goalState)
                                ))))
                        ($_ $goalState)
                    )))
                ($_ $goalState)
            ))
            $goalState)))

(= (omegaClawAutonomyCandidate $candidateId)
    (case $candidateId (
        (recall-goals True)
        (invent-goal True)
        (plan-goal True)
        (background-work True)
        (assess-progress True)
        (verify-goal True)
        (learn True)
        (self-improve True)
        (repair-failure True)
        (repair-autonomy True)
        ($_ False)
    )))

(= (omegaClawGoalResumePhase $goalState)
    (case $goalState (
        (none invent)
        ((omegaClawGoalStateRecord
                $goalId $description $acceptanceCriteria $status
                $currentStep $attemptCount $lastVerdict)
            (case $status (
                (active
                    (case $currentStep (
                        (none plan)
                        ($_ act)
                    )))
                (planned act)
                (assessing assess)
                (verifying verify)
                (blocked plan)
                (complete invent)
                ($_ invent)
            )))
        ($_ invent)
    )))

(= (omegaClawAutonomyNextPhase
        $currentPhase $candidateId $goalBefore $goalAfter)
    (case $candidateId (
        (recall-goals (omegaClawGoalResumePhase $goalAfter))
        (invent-goal
            (case (omegaClawGoalStateField $goalAfter status) (
                (active plan)
                ($_ $currentPhase)
            )))
        (plan-goal
            (case (omegaClawGoalStateField $goalAfter status) (
                (planned act)
                ($_ $currentPhase)
            )))
        (background-work
            (case (omegaClawGoalStateField $goalAfter status) (
                (assessing assess)
                ($_ $currentPhase)
            )))
        (assess-progress
            (case (omegaClawGoalStateField $goalAfter status) (
                (active plan)
                (verifying verify)
                (blocked idle)
                ($_ $currentPhase)
            )))
        (verify-goal
            (case (omegaClawGoalVerdictField
                        (omegaClawGoalStateField
                            $goalAfter last-verdict) status) (
                (complete integrate)
                (incomplete act)
                (blocked idle)
                ($_ $currentPhase)
            )))
        (learn
            (case (omegaClawGoalStateField $goalBefore status) (
                (complete recall)
                ($_ $currentPhase)
            )))
        (self-improve recall)
        (repair-failure verify)
        (repair-autonomy
            (case (omegaClawGoalStateField $goalAfter status) (
                (assessing assess)
                ($_ $currentPhase)
            )))
        ($_ $currentPhase)
    )))

(= (omegaClawAutonomyStateAfterOutcome
        $autonomyState $taskState $goalBefore $goalAfter $outcome)
    (let* (
        ($candidateId
            (omegaClawOutcomeField $outcome candidate-id))
        ($successCount
            (omegaClawOutcomeField $outcome success-count))
        ($taskStatus
            (omegaClawTaskStateField $taskState status))
        ($canAttempt
            (and
                (omegaClawOutcomeAdvancesAutonomy $outcome)
                (and
                    (not (omegaClawCandidateTaskActive $taskStatus))
                    (omegaClawAutonomyCandidate $candidateId))))
        ($currentPhase
            (omegaClawAutonomyStateField $autonomyState phase))
        ($actionCount
            (omegaClawAutonomyStateField
                $autonomyState action-count))
        ($nextActionCount
            (if (and
                    (== $currentPhase idle)
                    (== $candidateId recall-goals))
                1
                (+ $actionCount 1)))
        ($nextPhase
            (omegaClawAutonomyNextPhase
                $currentPhase $candidateId $goalBefore $goalAfter))
        ($boundedPhase
            (if (and
                    (>= $nextActionCount
                        (omegaClawAutonomyStepLimit))
                    (not (== $nextPhase idle)))
                idle
                $nextPhase))
    )
        (if $canAttempt
            (omegaClawAutonomyState
                $boundedPhase $nextActionCount)
            $autonomyState)))

(= (omegaClawCommitTurnUncheckedWithDisposition
        $engine $pending $boundary $results $disposition)
    (let* (
        ($outcome
            (omegaClawOutcomeFromCommandResultsWithDisposition
                $pending $boundary $results $disposition))
        ($motivationState
            (omegaClawEngineStateField
                $engine motivation-state))
        ($taskState
            (omegaClawEngineStateField $engine task-state))
        ($nextTaskState
            (omegaClawTaskStateAfterOutcome
                $taskState $outcome))
        ($autonomyState
            (omegaClawEngineStateField $engine autonomy-state))
        ($goalState
            (omegaClawEngineStateField $engine goal-state))
        ($nextGoalState
            (omegaClawGoalStateAfterOutcome
                $goalState $taskState $outcome))
        ($nextAutonomyState
            (omegaClawAutonomyStateAfterOutcome
                $autonomyState $taskState
                $goalState $nextGoalState $outcome))
        ($recentActions
            (omegaClawEngineStateField $engine recent-actions))
        ($diagnosticsHistory
            (omegaClawEngineStateField
                $engine diagnostics-history))
        ($goalEvidence
            (omegaClawEngineStateField $engine goal-evidence))
        ($nextGoalEvidence
            (omegaClawGoalEvidenceAfterOutcome
                $goalEvidence $taskState $outcome))
        ($nextTurnId
            (omegaClawEngineStateField $engine next-turn-id))
        ($committedTurnIds
            (omegaClawEngineStateField
                $engine committed-turn-ids))
        ($turnId
            (eval (omegaClawPendingTransitionField $pending turn-id)))
        ($nextCommittedTurnIds
            (eval (omegaClawBoundedAppend
                $committedTurnIds
                $turnId
                (omegaClawCommittedTurnIdLimit))))
        ($nextEngine
            (omegaClawEngineState
                $motivationState
                $nextTaskState
                $nextAutonomyState
                $nextGoalState
                none
                $recentActions
                $diagnosticsHistory
                $nextGoalEvidence
                $nextTurnId
                $nextCommittedTurnIds
                $outcome))
        ($directive
            (eval (omegaClawPendingTransitionField
                $pending directive)))
        ($committed
            (omegaClawCommittedEngineTurn
                $nextEngine
                $outcome
                $directive
                $boundary
                $results))
    )
        (validationOk $committed)))

(= (omegaClawCommitTurn $engine $pending $boundary $results)
    (omegaClawCommitTurnWithDisposition
        $engine $pending $boundary $results none))

(= (omegaClawCommitTurnWithDisposition
        $engine $pending $boundary $results $disposition)
    (let* (
        ($turnId
            (eval (omegaClawPendingTransitionField $pending turn-id)))
        ($committedTurnIds
            (omegaClawEngineStateField
                $engine committed-turn-ids))
        ($alreadyCommitted
            (eval (listContains $committedTurnIds $turnId)))
        ($nextTurnId
            (omegaClawEngineStateField
                $engine next-turn-id))
        ($expectedTurnId
            (eval (- $nextTurnId 1)))
        ($enginePending
            (omegaClawEngineStateField
                $engine pending-action))
        ($pendingAction
            (eval (omegaClawPendingTransitionField
                $pending pending-action)))
        ($boundaryTurnId
            (omegaClawCommandBoundaryField
                $boundary turn-id))
        ($executable
            (omegaClawCommandBoundaryField
                $boundary executable-commands))
        ($executableSnapshots
            (omegaClawCommandSnapshots (quote $executable)))
        ($resultCommands
            (omegaClawCommandResultCommands $results))
    )
        (if $alreadyCommitted
            (validationError duplicate-omegaclaw-engine-commit $turnId)
            (if (eval (!= $turnId $expectedTurnId))
                (validationError stale-omegaclaw-engine-transition
                    ((expected $expectedTurnId) (actual $turnId)))
                (if (eval (not (== $enginePending $pendingAction)))
                    (validationError
                        mismatched-omegaclaw-pending-action
                        (($enginePending) ($pendingAction)))
                    (if (eval (!= $turnId $boundaryTurnId))
                        (validationError
                            mismatched-omegaclaw-command-boundary
                            $boundary)
                        (if (not
                                (omegaClawCommandMultisetSubset
                                    $resultCommands $executableSnapshots))
                            (validationError
                                omegaclaw-result-command-not-executable
                                ($resultCommands $executable))
                            (if (omegaClawCommandResultsValid
                                    $results $executable)
                                (omegaClawCommitTurnUncheckedWithDisposition
                                    $engine $pending $boundary
                                    $results $disposition)
                                (validationError
                                    invalid-omegaclaw-command-results
                                    $results)))))))))
