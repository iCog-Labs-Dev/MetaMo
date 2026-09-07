
(= (omegaClawMetaMoPrepareEvidence
        $turnId $signals $directive $decisionEvidence
        $goalNames $goalsBefore $goalsAfter
        $modulatorNames $modulatorsBefore $modulatorsAfter)
    (omegaClawMetaMoPrepareEvidenceRecord
        $turnId $signals $directive $decisionEvidence
        $goalNames $goalsBefore $goalsAfter
        $modulatorNames $modulatorsBefore $modulatorsAfter))

(= (omegaClawMetaMoPrepareEvidenceField $evidence $field)
    (let (omegaClawMetaMoPrepareEvidenceRecord
            $turnId $signals $directive $decisionEvidence
            $goalNames $goalsBefore $goalsAfter
            $modulatorNames $modulatorsBefore $modulatorsAfter)
        $evidence
        (case $field (
            (turn-id $turnId)
            (signals $signals)
            (directive $directive)
            (decision-evidence $decisionEvidence)
            (goal-names $goalNames)
            (goals-before $goalsBefore)
            (goals-after $goalsAfter)
            (modulator-names $modulatorNames)
            (modulators-before $modulatorsBefore)
            (modulators-after $modulatorsAfter)
            ($_ (empty))
        ))))

(= (omegaClawMetaMoFilterEvidence
        $turnId $capabilityEnvelope
        $parsedCommands $executableCommands $blockedCommands)
    (omegaClawMetaMoFilterEvidenceRecord
        $turnId $capabilityEnvelope
        $parsedCommands $executableCommands $blockedCommands))

(= (omegaClawMetaMoFilterEvidenceField $evidence $field)
    (let (omegaClawMetaMoFilterEvidenceRecord
            $turnId $capabilityEnvelope
            $parsedCommands $executableCommands $blockedCommands)
        $evidence
        (case $field (
            (turn-id $turnId)
            (capability-envelope $capabilityEnvelope)
            (parsed-commands $parsedCommands)
            (executable-commands $executableCommands)
            (blocked-commands $blockedCommands)
            ($_ (empty))
        ))))

(= (omegaClawMetaMoCommitEvidence
        $turnId $outcome $goals $modulators)
    (omegaClawMetaMoCommitEvidenceRecord
        $turnId $outcome $goals $modulators))

(= (omegaClawMetaMoSignalsFromSemanticList ())
    ())

(= (omegaClawMetaMoSignalsFromSemanticList $items)
    (let* (
        (($head $tail) (decons $items))
        ($remaining
            (omegaClawMetaMoSignalsFromSemanticList $tail))
    )
        (case $head (
            ((signal $kind $strength)
                (if (and
                        (listContains
                            (omegaClawSemanticSignalKinds) $kind)
                        (>= $strength
                            (omegaClawSemanticSignalThresholdFor
                                $kind)))
                    (cons-atom
                        (omegaClawSignal $kind $strength semantic-llm)
                        $remaining)
                    $remaining))
            ($_ $remaining)
        ))))

(= (omegaClawMetaMoSemanticListValid ())
    False)

(= (omegaClawMetaMoSemanticListValid $items)
    (let* (
        (($head $tail) (decons $items))
    )
        (case $head (
            ((signal $kind $strength)
                (and
                    (listContains
                        (omegaClawSemanticSignalKinds) $kind)
                    (and
                        (>= $strength 0.0)
                        (and
                            (<= $strength 1.0)
                            (if (== $tail ())
                                True
                                (omegaClawMetaMoSemanticListValid
                                    $tail))))))
            ($_ False)
        ))))

(= (omegaClawMetaMoRawSemanticContainsKind () $kind)
    False)

(= (omegaClawMetaMoRawSemanticContainsKind $items $kind)
    (let* (
        (($head $tail) (decons $items))
    )
        (case $head (
            ((signal $headKind $strength)
                (if (== $headKind $kind)
                    True
                    (omegaClawMetaMoRawSemanticContainsKind
                        $tail $kind)))
            ($_ False)
        ))))

(= (omegaClawMetaMoRawSemanticContainsKinds $items ())
    True)

(= (omegaClawMetaMoRawSemanticContainsKinds $items $kinds)
    (let* (
        (($head $tail) (decons $kinds))
    )
        (and
            (omegaClawMetaMoRawSemanticContainsKind $items $head)
            (omegaClawMetaMoRawSemanticContainsKinds
                $items $tail))))

(= (omegaClawMetaMoSemanticListComplete $items)
    (if (omegaClawMetaMoRawSemanticContainsKind
            $items semantic-unavailable)
        (== (size-atom $items) 1)
        (and
            (== (size-atom $items)
                (size-atom
                    (omegaClawSemanticClassificationKinds)))
            (omegaClawMetaMoRawSemanticContainsKinds
                $items
                (omegaClawSemanticClassificationKinds)))))

(= (omegaClawMetaMoSignalsFromSemanticText $text)
    (case (catch (sread $text)) (
        ((Error $errorType $details)
            ((omegaClawSignal
                semantic-unavailable 1.0 semantic-provider)))
        ($items
            (if (and
                    (omegaClawMetaMoSemanticListValid $items)
                    (omegaClawMetaMoSemanticListComplete $items))
                (omegaClawMetaMoSignalsFromSemanticList $items)
                ((omegaClawSignal
                    semantic-unavailable 1.0 semantic-provider))))
    )))

(= (omegaClawMetaMoSemanticSignals
        $newMessage $message $activeTask $taskStatus)
    (if $newMessage
        (let* (
            ($startedAt
                (py-call (workspace_policy.monotonic_seconds)))
            ($semanticText
                (py-call
                    (stimulus_adapter.semantic_signal_text
                        (omegaClawSemanticProviderName)
                        $message
                        $activeTask
                        $taskStatus
                        (omegaClawSemanticTimeoutSeconds)
                        (omegaClawSemanticMaxOutputTokens)
                        (omegaClawSemanticReasoningMode)
                        (omegaClawSemanticApiKeyVariable)
                        (omegaClawSemanticModelName)
                        (omegaClawSemanticBaseUrl))))
            ($finishedAt
                (py-call (workspace_policy.monotonic_seconds)))
            ($elapsed (eval (- $finishedAt $startedAt)))
            ($_ (println!
                (METAMO-TIMING: semantic-perception $elapsed)))
        )
            (omegaClawMetaMoSignalsFromSemanticText $semanticText))
        ()))

(= (omegaClawMetaMoPreviousAction $engine)
    (case (omegaClawEngineStateField $engine last-outcome) (
        (none none)
        ($outcome (omegaClawOutcomeField $outcome candidate-id))
    )))

(= (omegaClawMetaMoPreviousResults $engine)
    (case (omegaClawEngineStateField $engine last-outcome) (
        (none ())
        ($outcome (omegaClawOutcomeField $outcome user-visible-result))
    )))

;; Do not attribute the preceding outcome to a newly received human request.
(= (omegaClawMetaMoPriorValueForTurn $newMessage $value $freshValue)
    (if $newMessage $freshValue $value))

(= (omegaClawMetaMoTaskResourceSignals $taskState)
    (case (omegaClawTaskStateField $taskState authorization) (
        (requested-effect ((task-execution-authorized 1.0)))
        ($_ ())
    )))

(= (omegaClawMetaMoTaskResourceSignalsForTurn $taskState $newMessage)
    (if $newMessage
        ()
        (omegaClawMetaMoTaskResourceSignals $taskState)))

(= (omegaClawMetaMoObservationFromHostTurn
        $engine
        (omegaClawHostTurnRecord
            $turnId $wakeReason $timestamp $newMessage
            $messageId $messageText $channel
            $previousResults $previousErrors $loopBudget))
    (let* (
        ($taskState (omegaClawEngineStateField $engine task-state))
        ($autonomyState
            (omegaClawEngineStateField $engine autonomy-state))
        ($goalState
            (omegaClawEngineStateField $engine goal-state))
    )
        (omegaClawObservation
            $turnId
            $wakeReason
            $timestamp
            $newMessage
            $messageId
            $messageText
            $channel
            (omegaClawTaskStateField $taskState active-task)
            (omegaClawTaskStateField $taskState status)
            (omegaClawAutonomyStateField $autonomyState phase)
            (omegaClawMetaMoPriorValueForTurn
                $newMessage
                (omegaClawMetaMoPreviousAction $engine)
                none)
            (omegaClawMetaMoPriorValueForTurn
                $newMessage
                (omegaClawMetaMoPreviousResults $engine)
                ())
            (omegaClawMetaMoPriorValueForTurn
                $newMessage $previousErrors ())
            $loopBudget
            (omegaClawMetaMoTaskResourceSignalsForTurn
                $taskState $newMessage)
            (omegaClawMetaMoSemanticSignals
                $newMessage
                $messageText
                (omegaClawTaskStateField $taskState active-task)
                (omegaClawTaskStateField $taskState status)))))

(= (omegaClawMetaMoObservationForInput $engine $input)
    (case $input (
        ((omegaClawObservationRecord
                $turnId $wakeReason $timestamp
                $newMessage $messageId $messageText $channel
                $activeTask $taskStatus $autonomyPhase
                $previousAction $previousCommandResults $previousErrors
                $loopBudget $resourceSignals $semanticSignals)
            $input)
        ((omegaClawHostTurnRecord
                $turnId $wakeReason $timestamp $newMessage
                $messageId $messageText $channel
                $previousResults $previousErrors $loopBudget)
            (omegaClawMetaMoObservationFromHostTurn $engine $input))
        ($_ (empty))
    )))


(= (omegaClawMetaMoInitialize $config)
    (eval (omegaClawNewEngineState)))

(= (omegaClawMetaMoObserve $engine $hostTurn)
    (let* (
        ($observation
            (omegaClawMetaMoObservationForInput
                $engine $hostTurn))
        ($res (eval (omegaClawPrepareTurn
                (quote $engine) (quote $observation))))
    )
        (case $res (
            ((validationOk $prepared)
                (let* (
                    ($preparedEngine
                        (eval (omegaClawPreparedEngineTurnField
                            $prepared engine)))
                    ($pending
                        (eval (omegaClawPreparedEngineTurnField
                            $prepared pending)))
                )
                    (omegaClawAdapterObservation
                        $preparedEngine $observation $pending)))
            ((validationError $code $details)
                (validationError $code $details))
        ))
    ))

(= (omegaClawContextPreviousOutcomeField $outcome $field)
    (case $outcome (
        (none none)
        ($_ (omegaClawOutcomeField $outcome $field))
    )))

(= (omegaClawMetaMoContext $engine $pending)
    (let* (
        ($directive
            (eval (omegaClawPendingTransitionField
                (quote $pending) directive)))
        ($promptFragment
            (omegaClawPendingTransitionField $pending context-fragment))
        ($contract
            (omegaClawPromptFragmentField $promptFragment contract))
        ($instruction
            (omegaClawRealizationContractField $contract instruction))
        ($observation
            (omegaClawPendingTransitionField $pending observation))
        ($perception
            (omegaClawPendingTransitionField $pending perception))
        ($previousOutcome
            (omegaClawPerceptionField $perception outcome))
        ($taskState
            (omegaClawEngineStateField $engine task-state))
        ($autonomyState
            (omegaClawEngineStateField $engine autonomy-state))
        ($goalState
            (omegaClawEngineStateField $engine goal-state))
        ($goalEvidence
            (omegaClawEngineStateField $engine goal-evidence))
    )
        (eval (string-safe
            (eval (py-str (
                "METAMO_DIRECTIVE: "
                (eval (string-safe (repr $directive)))
                " METAMO_INSTRUCTION: " $instruction
                " REALIZATION_CONTRACT: "
                (eval (string-safe (repr $contract)))
                " ACTIVE_TASK: "
                (eval (string-safe (repr
                    (omegaClawTaskStateField $taskState active-task))))
                " TASK_STATUS: "
                (eval (string-safe (repr
                    (omegaClawTaskStateField $taskState status))))
                " TASK_AUTHORIZATION: "
                (eval (string-safe (repr
                    (omegaClawTaskStateField
                        $taskState authorization))))
                " TASK_EVIDENCE: "
                (eval (string-safe (repr
                    (omegaClawTaskStateField $taskState evidence))))
                " AUTONOMY_PHASE: "
                (eval (string-safe (repr
                    (omegaClawAutonomyStateField $autonomyState phase))))
                " AUTONOMY_GOAL: "
                (eval (string-safe (repr $goalState)))
                " AUTONOMY_EVIDENCE: "
                (eval (string-safe (repr $goalEvidence)))
                " EVIDENCE_LEDGER_STATUS: "
                (eval (string-safe (repr
                    (omegaClawPendingEvidenceLedgerStatus $pending))))
                " WAKE_REASON: "
                (eval (string-safe (repr
                    (omegaClawObservationField $observation wake-reason))))
                " PREVIOUS_ACTION: "
                (eval (string-safe (repr
                    (omegaClawObservationField $observation previous-action))))
                " PREVIOUS_RESULTS: "
                (eval (string-safe (repr
                    (omegaClawObservationField
                        $observation previous-command-results))))
                " PREVIOUS_PROPOSAL_FAILURE: "
                (omegaClawContextPreviousOutcomeField
                    $previousOutcome failure-reason)
                " PREVIOUS_PROPOSAL_FINGERPRINT: "
                (omegaClawContextPreviousOutcomeField
                    $previousOutcome proposal-fingerprint))))))))

(= (omegaClawMetaMoDecisionTraceFromResult
        $previousAdapterState $preparedResult)
    (let* (
        ($preparedTurn
            (omegaClawPrepareResultField
                $preparedResult prepared-turn))
        ($pending
            (omegaClawPreparedTurnField
                $preparedTurn extension-cycle))
        ($decisionEvidence
            (omegaClawPendingTransitionField
                $pending decision-evidence))
    )
        $decisionEvidence))

(= (omegaClawMetaMoDecisionTraceField $trace $field)
    (case $field (
        (policy-class hard-eligibility)
        (candidate-ids
            (omegaClawDecisionEvidenceField
                $trace eligible-ids))
        (candidate-scores
            (omegaClawDecisionEvidenceField
                $trace score-traces))
        (selected-candidate
            (omegaClawDecisionEvidenceField
                $trace winner-id))
        ($_
            (omegaClawDecisionEvidenceField
                $trace $field))
    )))

(= (omegaClawMetaMoFilter $pending $hostAuthorizedCommands)
    (let* (
        ($directive
            (eval (omegaClawPendingTransitionField
                $pending directive)))
        ($evidenceAuthorized
            (eval (omegaClawCommandsAllowedByPendingEvidence
                (quote $pending)
                (quote $hostAuthorizedCommands))))
    )
        (eval (omegaClawFilterAuthorizedByDirective
            $directive
            (quote $evidenceAuthorized)))))

(= (omegaClawMetaMoAfterDispatch $engine $pending $dispatchOutcome)
    (let* (
        ($parsed
            (omegaClawDispatchOutcomeField
                $dispatchOutcome parsed-commands))
        ($authorized
            (omegaClawDispatchOutcomeField
                $dispatchOutcome host-authorized-commands))
        ($executed
            (omegaClawDispatchOutcomeField
                $dispatchOutcome executed-commands))
        ($turnId
            (omegaClawDispatchOutcomeField
                $dispatchOutcome turn-id))
        ($disposition
            (omegaClawDispatchOutcomeField
                $dispatchOutcome disposition))
        ($boundaryResult
            (eval (omegaClawFilterCommands
                (quote $pending)
                (quote $parsed)
                (quote $authorized))))
        ($results
            (omegaClawDispatchOutcomeField
                $dispatchOutcome dispatch-results))
    )
        (case $boundaryResult (
            ((validationOk $boundary)
                (case (eval (omegaClawCommitTurnWithDisposition
                        (quote $engine)
                        (quote $pending)
                        (quote $boundary)
                        (quote $results)
                        $disposition)) (
                    ((validationOk $committed)
                        (let* (
                            ($nextEngine
                                (eval (omegaClawCommittedEngineTurnField
                                    (quote $committed) engine)))
                        )
                            (eval (omegaClawAdapterAfterDispatchResult
                                (quote $nextEngine) (quote $committed)))))
                    ((validationError $code $details)
                        (validationError $code $details))
                )))
            ((validationError $code $details)
                (validationError $code $details))
        ))))

(= (omegaClawMetaMoAdapter)
    (omegaClawHostAdapter
        omegaClawMetaMoInitialize
        omegaClawMetaMoObserve
        omegaClawMetaMoContext
        omegaClawMetaMoFilter
        omegaClawMetaMoAfterDispatch))


(= (omegaClawMetaMoPrepareEvidenceFromResult
        $previousAdapterState $preparedResult)
    (let* (
        ($nextAdapterState
            (omegaClawPrepareResultField $preparedResult state))
        ($preparedTurn
            (omegaClawPrepareResultField
                $preparedResult prepared-turn))
        ($pending
            (omegaClawPreparedTurnField
                $preparedTurn extension-cycle))
        ($perception
            (omegaClawPendingTransitionField $pending perception))
        ($directive
            (omegaClawPendingTransitionField $pending directive))
        ($decisionEvidence
            (omegaClawPendingTransitionField
                $pending decision-evidence))
        ($previousEngine
            (omegaClawAdapterStateField
                $previousAdapterState extension-state))
        ($nextEngine
            (omegaClawAdapterStateField
                $nextAdapterState extension-state))
        ($beforeState
            (omegaClawEngineStateField
                $previousEngine motivation-state))
        ($afterState
            (omegaClawEngineStateField
                $nextEngine motivation-state))
    )
        (omegaClawMetaMoPrepareEvidence
            (omegaClawPreparedTurnField $preparedTurn turn-id)
            (omegaClawPerceptionField $perception signals)
            $directive
            $decisionEvidence
            (omegaClawGoalNames)
            (stateGoals $beforeState)
            (stateGoals $afterState)
            (omegaClawModulatorNames)
            (stateModulators $beforeState)
            (stateModulators $afterState))))

(= (omegaClawMetaMoFilterEvidenceFromResult
        $parsedCommands $filteredResult)
    (let* (
        ($filteredTurn
            (omegaClawFilterResultField
                $filteredResult filtered-turn))
        ($preparedTurn
            (omegaClawFilteredTurnField
                $filteredTurn prepared-turn))
        ($pending
            (omegaClawPreparedTurnField
                $preparedTurn extension-cycle))
        ($directive
            (omegaClawPendingTransitionField $pending directive))
        ($executed
            (omegaClawFilteredTurnField
                $filteredTurn filtered-commands))
    )
        (omegaClawMetaMoFilterEvidence
            (omegaClawPreparedTurnField $preparedTurn turn-id)
            (omegaClawMotivationDirectiveField
                $directive capability-envelope)
            $parsedCommands
            $executed
            (omegaClawCommandsDifference
                $parsedCommands $executed))))

(= (omegaClawMetaMoCommitEvidenceFromResult $commitResult)
    (let* (
        ($adapterState
            (omegaClawCommitResultField $commitResult state))
        ($engine
            (omegaClawAdapterStateField
                $adapterState extension-state))
        ($motivationState
            (omegaClawEngineStateField $engine motivation-state))
        ($committed
            (omegaClawCommitResultField
                $commitResult extension-result))
        ($outcome
            (omegaClawCommittedEngineTurnField
                $committed outcome))
    )
        (omegaClawMetaMoCommitEvidence
            (omegaClawOutcomeField $outcome source-turn)
            $outcome
            (stateGoals $motivationState)
            (stateModulators $motivationState))))
