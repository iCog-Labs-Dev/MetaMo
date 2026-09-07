(= (omegaClawHostAdapter
        $initFn $observeFn $contextFn $filterFn $afterDispatchFn)
    (omegaClawHostAdapterRecord
        $initFn $observeFn $contextFn $filterFn $afterDispatchFn))

(= (omegaClawHostAdapterField $adapter $field)
    (let (omegaClawHostAdapterRecord
            $initFn $observeFn $contextFn $filterFn $afterDispatchFn)
        $adapter
        (case $field (
            (init $initFn)
            (observe $observeFn)
            (context $contextFn)
            (filter $filterFn)
            (after-dispatch $afterDispatchFn)
            ($_ (empty))
        ))))


(= (omegaClawAdapterState
        $extensionState $nextTurnId $committedTurnIds $stageTrace)
    (omegaClawAdapterStateRecord
        $extensionState $nextTurnId $committedTurnIds $stageTrace))

(= (omegaClawAdapterStateField $state $field)
    (let (omegaClawAdapterStateRecord
            $extensionState $nextTurnId $committedTurnIds $stageTrace)
        $state
        (case $field (
            (extension-state $extensionState)
            (next-turn-id $nextTurnId)
            (committed-turn-ids $committedTurnIds)
            (stage-trace $stageTrace)
            ($_ (empty))
        ))))

(= (omegaClawAdapterStateWithTrace $state $stage)
    (omegaClawAdapterState
        (omegaClawAdapterStateField $state extension-state)
        (omegaClawAdapterStateField $state next-turn-id)
        (omegaClawAdapterStateField $state committed-turn-ids)
        (omegaClawBoundedAppend
            (omegaClawAdapterStateField $state stage-trace)
            $stage
            (omegaClawAdapterStageTraceLimit))))


(= (omegaClawAdapterObservation
        $extensionState $observation $extensionCycle)
    (omegaClawAdapterObservationRecord
        $extensionState $observation $extensionCycle))


(= (omegaClawPreparedHostTurn
        $turnId $observation $extensionCycle $contextFragment)
    (omegaClawPreparedHostTurnRecord
        $turnId $observation $extensionCycle $contextFragment))

(= (omegaClawPreparedTurnField $prepared $field)
    (let (omegaClawPreparedHostTurnRecord
            $turnId $observation $extensionCycle $contextFragment)
        $prepared
        (case $field (
            (turn-id $turnId)
            (observation $observation)
            (extension-cycle $extensionCycle)
            (context-fragment $contextFragment)
            ($_ (empty))
        ))))

(= (omegaClawAdapterPrepareResult $state $prepared)
    (omegaClawAdapterPrepareResultRecord $state $prepared))

(= (omegaClawPrepareResultField $result $field)
    (let (omegaClawAdapterPrepareResultRecord $state $prepared)
        $result
        (case $field (
            (state $state)
            (prepared-turn $prepared)
            ($_ (empty))
        ))))


(= (omegaClawFilteredHostTurn
        $prepared $parsedCommands $hostAuthorizedCommands $filteredCommands)
    (omegaClawFilteredHostTurnRecord
        $prepared $parsedCommands $hostAuthorizedCommands $filteredCommands))

(= (omegaClawFilteredTurnField $filtered $field)
    (let (omegaClawFilteredHostTurnRecord
            $prepared $parsedCommands $hostAuthorizedCommands $filteredCommands)
        $filtered
        (case $field (
            (prepared-turn $prepared)
            (parsed-commands $parsedCommands)
            (host-authorized-commands $hostAuthorizedCommands)
            (filtered-commands $filteredCommands)
            ($_ (empty))
        ))))

(= (omegaClawAdapterFilterResult $state $filtered)
    (omegaClawAdapterFilterResultRecord $state $filtered))

(= (omegaClawFilterResultField $result $field)
    (let (omegaClawAdapterFilterResultRecord $state $filtered)
        $result
        (case $field (
            (state $state)
            (filtered-turn $filtered)
            ($_ (empty))
        ))))


(= (omegaClawDispatchOutcome
        $turnId $parsedCommands $hostAuthorizedCommands
        $executedCommands $dispatchResults)
    (omegaClawDispatchOutcome
        $turnId $parsedCommands $hostAuthorizedCommands
        $executedCommands $dispatchResults none))

(= (omegaClawDispatchOutcome
        $turnId $parsedCommands $hostAuthorizedCommands
        $executedCommands $dispatchResults $disposition)
    (omegaClawDispatchOutcomeRecord
        $turnId $parsedCommands $hostAuthorizedCommands
        $executedCommands $dispatchResults $disposition))

(= (omegaClawDispatchOutcomeField $outcome $field)
    (let (omegaClawDispatchOutcomeRecord
            $turnId $parsedCommands $hostAuthorizedCommands
            $executedCommands $dispatchResults $disposition)
        $outcome
        (case $field (
            (turn-id $turnId)
            (parsed-commands $parsedCommands)
            (host-authorized-commands $hostAuthorizedCommands)
            (executed-commands $executedCommands)
            (dispatch-results $dispatchResults)
            (disposition $disposition)
            ($_ (empty))
        ))))

(= (omegaClawAdapterAfterDispatchResult $extensionState $extensionResult)
    (omegaClawAdapterAfterDispatchResultRecord
        $extensionState $extensionResult))

(= (omegaClawAdapterCommitResult $state $outcome $extensionResult)
    (omegaClawAdapterCommitResultRecord $state $outcome $extensionResult))

(= (omegaClawCommitResultField $result $field)
    (let (omegaClawAdapterCommitResultRecord
            $state $outcome $extensionResult)
        $result
        (case $field (
            (state $state)
            (outcome $outcome)
            (extension-result $extensionResult)
            ($_ (empty))
        ))))


;; Remove one item when validating command multisets.
(= (omegaClawRemoveFirst $items $needle)
    (if (== $items ())
        (validationError missing-command $needle)
        (let* (
            ($head (car-atom (quote $items)))
            ($tail (cdr-atom (quote $items)))
        )
            (if (== $head $needle)
                (validationOk $tail)
                (case (omegaClawRemoveFirst $tail $needle) (
                    ((validationOk $remaining)
                        (validationOk (cons-atom $head $remaining)))
                    ((validationError $code $details)
                        (validationError $code $details))
                ))
            )
        )
    ))

(= (omegaClawCommandMultisetSubset $subset $superset)
    (if (== $subset ())
        True
        (let* (
            ($head (car-atom (quote $subset)))
            ($tail (cdr-atom (quote $subset)))
        )
            (case (omegaClawRemoveFirst $superset $head) (
                ((validationOk $remaining)
                    (omegaClawCommandMultisetSubset $tail $remaining))
                ((validationError $code $details) False)
            ))
        )
    ))


;; Append adapter guidance without replacing OmegaClaw context.
(= (omegaClawAdapterAppendContext $baseContext $contextFragment)
    (case $contextFragment (
        (() $baseContext)
        ($_
            (let* (
                ($baseWithSpace
                    (string_concat $baseContext " "))
            )
                (string_concat $baseWithSpace $contextFragment)
            ))
    )))


(= (omegaClawNoOpInitialize $config)
    $config)

(= (omegaClawNoOpObserve $extensionState $hostSnapshot)
    (omegaClawAdapterObservation
        $extensionState
        $hostSnapshot
        $hostSnapshot))

(= (omegaClawNoOpContext $extensionState $extensionCycle)
    ())

(= (omegaClawNoOpFilter $extensionCycle $hostAuthorizedCommands)
    $hostAuthorizedCommands)

(= (omegaClawNoOpAfterDispatch
        $extensionState $extensionCycle $outcome)
    (omegaClawAdapterAfterDispatchResult
        $extensionState
        $outcome))

(= (omegaClawNoOpHostAdapter)
    (omegaClawHostAdapter
        omegaClawNoOpInitialize
        omegaClawNoOpObserve
        omegaClawNoOpContext
        omegaClawNoOpFilter
        omegaClawNoOpAfterDispatch))


;; Initialize the adapter before the host loop starts.
(= (omegaClawAdapterInitialize $adapter $config)
    (let* (
        ($initFn (omegaClawHostAdapterField $adapter init))
        ($extensionState (eval ($initFn $config)))
    )
        (validationOk
            (omegaClawAdapterState
                $extensionState
                1
                ()
                (initialize)))))


;; Prepare one observed turn and append its prompt fragment.
(= (omegaClawAdapterPrepareTurn $adapter $state $hostSnapshot)
    (let* (
        ($observeFn (omegaClawHostAdapterField $adapter observe))
        ($contextFn (omegaClawHostAdapterField $adapter context))
        ($turnId (omegaClawAdapterStateField $state next-turn-id))
        ($extensionState
            (omegaClawAdapterStateField $state extension-state))
        ($observed
            (eval
                ($observeFn
                    (quote $extensionState)
                    (quote $hostSnapshot))))
        )
        (case $observed (
            ((omegaClawAdapterObservationRecord
                    $nextExtensionState $observation $extensionCycle)
                (let* (
                    ($contextFragment
                        (eval
                            ($contextFn
                                (quote $nextExtensionState)
                                (quote $extensionCycle))))
                    ($nextState
                        (omegaClawAdapterState
                            $nextExtensionState
                            (+ $turnId 1)
                            (omegaClawAdapterStateField
                                $state committed-turn-ids)
                            (omegaClawTrimToLimit
                                (listAppend
                                (omegaClawAdapterStateField
                                    $state stage-trace)
                                (observe context))
                                (omegaClawAdapterStageTraceLimit))))
                    ($prepared
                        (omegaClawPreparedHostTurn
                            $turnId
                            $observation
                            $extensionCycle
                            $contextFragment))
                )
                    (validationOk
                        (omegaClawAdapterPrepareResult
                            $nextState
                            $prepared))))
            ($_ (validationError
                    invalid-omegaclaw-observation-result
                    $observed))
        ))
    ))


;; Motivation may remove but never add host-authorized commands.
(= (omegaClawAdapterFilterAuthorized
        $adapter $state $prepared
        $parsedCommands $hostAuthorizedCommands False)
    (validationError
        invalid-host-authorization-expansion
        ($parsedCommands $hostAuthorizedCommands)))

(= (omegaClawAdapterFilterAuthorized
        $adapter $state $prepared
        $parsedCommands $hostAuthorizedCommands True)
    (let* (
        ($filterFn (omegaClawHostAdapterField $adapter filter))
        ($extensionCycle
            (omegaClawPreparedTurnField
                $prepared extension-cycle))
        ($filteredCommands
            (eval
                ($filterFn
                    (quote $extensionCycle)
                    (quote $hostAuthorizedCommands))))
        ($isNarrowing
            (omegaClawCommandMultisetSubset
                $filteredCommands
                $hostAuthorizedCommands))
    )
        (omegaClawAdapterFilterNarrowed
            $state
            $prepared
            $parsedCommands
            $hostAuthorizedCommands
            $filteredCommands
            $isNarrowing)))

(= (omegaClawAdapterFilterNarrowed
        $state $prepared $parsedCommands
        $hostAuthorizedCommands $filteredCommands False)
    (validationError
        motivation-command-expansion
        ($hostAuthorizedCommands $filteredCommands)))

(= (omegaClawAdapterFilterNarrowed
        $state $prepared $parsedCommands
        $hostAuthorizedCommands $filteredCommands True)
    (let* (
        ($nextState
            (omegaClawAdapterStateWithTrace $state filter))
        ($filtered
            (omegaClawFilteredHostTurn
                $prepared
                $parsedCommands
                $hostAuthorizedCommands
                $filteredCommands))
    )
        (validationOk
            (omegaClawAdapterFilterResult
                $nextState
                $filtered))))

(= (omegaClawAdapterFilterCommands
        $adapter $state $prepared $parsedCommands $hostAuthorizedCommands)
    (let* (
        ($turnId (omegaClawPreparedTurnField $prepared turn-id))
        ($expectedTurnId
            (- (omegaClawAdapterStateField $state next-turn-id) 1))
    )
        (if (!= $turnId $expectedTurnId)
            (validationError
                stale-omegaclaw-prepared-turn
                (expected $expectedTurnId actual $turnId))
            (omegaClawAdapterFilterAuthorized
                $adapter
                $state
                $prepared
                $parsedCommands
                $hostAuthorizedCommands
                (omegaClawCommandMultisetSubset
                    $hostAuthorizedCommands
                    $parsedCommands)))))


;; Commit dispatch results against the latest adapter state.
(= (omegaClawAdapterCommitTurn
        $adapter $state $filteredTurn $dispatchResults)
    (omegaClawAdapterCommitTurnWithDisposition
        $adapter $state $filteredTurn $dispatchResults none))

(= (omegaClawAdapterCommitTurnWithDisposition
        $adapter $state $filteredTurn $dispatchResults $disposition)
    (let* (
        ($prepared
            (omegaClawFilteredTurnField $filteredTurn prepared-turn))
        ($turnId (omegaClawPreparedTurnField $prepared turn-id))
        ($expectedTurnId
            (- (omegaClawAdapterStateField $state next-turn-id) 1))
        ($committed
            (omegaClawAdapterStateField $state committed-turn-ids))
    )
        (if (listContains $committed $turnId)
            (validationError
                duplicate-omegaclaw-adapter-commit
                $turnId)
            (if (!= $turnId $expectedTurnId)
                (validationError
                    stale-omegaclaw-adapter-commit
                    (expected $expectedTurnId actual $turnId))
                (let* (
                    ($outcome
                        (omegaClawDispatchOutcome
                            $turnId
                            (omegaClawFilteredTurnField
                                $filteredTurn parsed-commands)
                            (omegaClawFilteredTurnField
                                $filteredTurn host-authorized-commands)
                            (omegaClawFilteredTurnField
                                $filteredTurn filtered-commands)
                            $dispatchResults
                            $disposition))
                    ($afterFn
                        (omegaClawHostAdapterField
                            $adapter after-dispatch))
                    ($extensionState
                        (omegaClawAdapterStateField
                            $state extension-state))
                    ($extensionCycle
                        (omegaClawPreparedTurnField
                            $prepared extension-cycle))
                    ($afterResult
                        (eval
                            ($afterFn
                                (quote $extensionState)
                                (quote $extensionCycle)
                                (quote $outcome))))
                )
                    (case $afterResult (
                        ((omegaClawAdapterAfterDispatchResultRecord
                                $nextExtensionState $extensionResult)
                            (let* (
                                ($nextState
                                    (omegaClawAdapterState
                                        $nextExtensionState
                                        (omegaClawAdapterStateField
                                            $state next-turn-id)
                                        (omegaClawBoundedAppend
                                            $committed
                                            $turnId
                                            (omegaClawCommittedTurnIdLimit))
                                        (omegaClawBoundedAppend
                                            (omegaClawAdapterStateField
                                                $state stage-trace)
                                            commit
                                            (omegaClawAdapterStageTraceLimit))))
                            )
                                (validationOk
                                    (omegaClawAdapterCommitResult
                                        $nextState
                                        $outcome
                                        $extensionResult))))
                        ($_ (validationError
                                invalid-omegaclaw-after-dispatch-result
                                $afterResult))
                    ))
                )
            )
        )
    ))
