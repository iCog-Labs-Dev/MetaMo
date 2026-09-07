;; Persist only committed adapter states in a versioned local envelope.

(= (omegaClawPersistenceRestoreResult $state $status $detail)
    (omegaClawPersistenceRestoreResultRecord $state $status $detail))

(= (omegaClawPersistenceRestoreResultField $result $field)
    (let (omegaClawPersistenceRestoreResultRecord $state $status $detail)
        $result
        (case $field (
            (state $state)
            (status $status)
            (detail $detail)
            ($_ (empty))
        ))))

(= (omegaClawValidatePersistedAdapterFields
        $state $engine $nextTurnId $adapterCommittedIds $stageTrace)
    (let* (
        ($motivationState
            (omegaClawEngineStateField $engine motivation-state))
        ($engineNextTurnId
            (omegaClawEngineStateField $engine next-turn-id))
        ($engineCommittedIds
            (omegaClawEngineStateField $engine committed-turn-ids))
        ($pendingAction
            (omegaClawEngineStateField $engine pending-action))
    )
        (if (!= (stateSchema $motivationState) (omegaClawSchema))
            (validationError
                persisted-schema-mismatch
                (stateSchema $motivationState))
            (if (!= $nextTurnId $engineNextTurnId)
                (validationError
                    persisted-turn-id-mismatch
                    (adapter $nextTurnId engine $engineNextTurnId))
                (if (!= $adapterCommittedIds $engineCommittedIds)
                    (validationError
                        persisted-commit-id-mismatch
                        ($adapterCommittedIds $engineCommittedIds))
                    (if (!= $pendingAction none)
                        (validationError
                            persisted-uncommitted-action
                            $pendingAction)
                        (if (not (omegaClawCollectionWithinLimit
                                    $adapterCommittedIds
                                    (omegaClawCommittedTurnIdLimit)))
                            (validationError
                                oversized-persisted-commit-ids
                                (size-atom $adapterCommittedIds))
                            (if (not (omegaClawCollectionWithinLimit
                                        $stageTrace
                                        (omegaClawAdapterStageTraceLimit)))
                                (validationError
                                    oversized-persisted-stage-trace
                                    (size-atom $stageTrace))
                                (validationOk $state)))))))))

(= (omegaClawPersistedEngineRecord $engine)
    (case $engine (
        ((omegaClawEngineStateRecord
                (motivationState $schema $goals $modulators)
                $taskState $autonomyState $goalState $pendingAction
                $recentActions $diagnosticsHistory $goalEvidence
                $nextTurnId $committedTurnIds $lastOutcome)
            True)
        ($_ False)
    )))

(= (omegaClawValidatePersistedAdapterState $state)
    (case $state (
        ((omegaClawAdapterStateRecord
                $engine $nextTurnId $adapterCommittedIds $stageTrace)
            (if (omegaClawPersistedEngineRecord $engine)
                (let $engineResult
                    (eval (omegaClawValidateEngineState $engine))
                    (if (eval (validationIsOk $engineResult))
                        (omegaClawValidatePersistedAdapterFields
                            $state $engine $nextTurnId
                            $adapterCommittedIds $stageTrace)
                        $engineResult))
                (validationError invalid-persisted-engine $engine)))
        ($_ (validationError invalid-persisted-adapter-state $state))
    )))

;; Persist durable motivation and autonomy, never an in-flight host turn.
(= (omegaClawPersistenceProjection $state)
    (let (omegaClawAdapterStateRecord
            (omegaClawEngineStateRecord
                $motivationState $taskState $autonomyState $goalState
                $pendingAction $recentActions $diagnosticsHistory $goalEvidence
                $nextTurnId $committedTurnIds $lastOutcome)
            $adapterTurnId $adapterCommittedIds $stageTrace)
        $state
        (omegaClawAdapterState
            (omegaClawEngineState
                $motivationState
                (omegaClawTaskState none inactive)
                $autonomyState
                $goalState
                none
                ()
                ()
                ()
                $nextTurnId
                $committedTurnIds
                none)
            $adapterTurnId
            $adapterCommittedIds
            ())))

(= (omegaClawPersistenceDecodeState $payload $freshState)
    (case (catch (sread $payload)) (
        ((Error $errorType $details)
            (omegaClawPersistenceRestoreResult
                $freshState invalid
                (parse-error $errorType $details)))
        ($state
            (case (catch
                    (omegaClawValidatePersistedAdapterState $state)) (
                ((Error $errorType $details)
                    (omegaClawPersistenceRestoreResult
                        $freshState invalid
                        (validation-error $errorType $details)))
                ((validationOk $validated)
                    (omegaClawPersistenceRestoreResult
                        $validated loaded none))
                ((validationError $code $details)
                    (omegaClawPersistenceRestoreResult
                        $freshState invalid ($code $details)))
                ($_
                    (omegaClawPersistenceRestoreResult
                        $freshState invalid validation-no-result))
            )))
    )))

(= (omegaClawPersistenceLoad $freshState)
    (let* (
        ($loaded
            (py-call (state_store.load_snapshot
                (omegaClawPersistenceConfig path)
                (omegaClawPersistenceConfig version))))
        ($status (py-call (state_store.snapshot_field $loaded status)))
        ($detail (py-call (state_store.snapshot_field $loaded detail)))
    )
        (case $status (
            (loaded
                (omegaClawPersistenceDecodeState
                    (py-call (state_store.snapshot_field $loaded state))
                    $freshState))
            (missing
                (omegaClawPersistenceRestoreResult
                    $freshState missing none))
            (incompatible
                (omegaClawPersistenceRestoreResult
                    $freshState incompatible $detail))
            ($_
                (omegaClawPersistenceRestoreResult
                    $freshState invalid $detail))
        ))))

(= (omegaClawPersistenceSave $state)
    (case (omegaClawValidatePersistedAdapterState $state) (
        ((validationOk $validated)
            (let $projected
                (omegaClawPersistenceProjection $validated)
                (py-call (state_store.save_snapshot
                    (omegaClawPersistenceConfig path)
                    (omegaClawPersistenceConfig version)
                    (repr $projected)))))
        ((validationError $code $details)
            save-invalid-state)
    )))

(= (omegaClawPersistenceRecoverFresh $freshState $restoreResult)
    (let* (
        ($status
            (omegaClawPersistenceRestoreResultField
                $restoreResult status))
        ($detail
            (omegaClawPersistenceRestoreResultField
                $restoreResult detail))
        ($_ (if (or (== $status invalid) (== $status incompatible))
            (py-call (state_store.quarantine_snapshot
                (omegaClawPersistenceConfig path) $detail))
            none))
        ($saveStatus (omegaClawPersistenceSave $freshState))
        ($_ (println!
            (METAMO-PERSISTENCE: initialized $status $detail $saveStatus)))
    )
        $freshState))

(= (omegaClawPersistenceInitialize $freshState)
    (let $restoreResult (omegaClawPersistenceLoad $freshState)
        (case (omegaClawPersistenceRestoreResultField
                $restoreResult status) (
            (loaded
                (prog1
                    (omegaClawPersistenceRestoreResultField
                        $restoreResult state)
                    (println!
                        (METAMO-PERSISTENCE: restored
                            (omegaClawAdapterStateField
                                (omegaClawPersistenceRestoreResultField
                                    $restoreResult state)
                                next-turn-id)))))
            ($_
                (omegaClawPersistenceRecoverFresh
                    $freshState $restoreResult))
        ))))

(= (omegaClawPersistenceCommittedAdvance $previousState $nextState)
    (case (omegaClawValidatePersistedAdapterState $nextState) (
        ((validationOk $validated)
            (let* (
                ($previousTurnId
                    (omegaClawAdapterStateField
                        $previousState next-turn-id))
                ($nextTurnId
                    (omegaClawAdapterStateField
                        $validated next-turn-id))
                ($committedTurnId (- $nextTurnId 1))
            )
                (and (> $nextTurnId $previousTurnId)
                    (listContains
                        (omegaClawAdapterStateField
                            $validated committed-turn-ids)
                        $committedTurnId))))
        ($_ False)
    )))

(= (omegaClawPersistenceSaveCommitted $previousState $nextState)
    (if (omegaClawPersistenceCommittedAdvance
            $previousState $nextState)
        (let $status (omegaClawPersistenceSave $nextState)
            (prog1
                $status
                (println!
                    (METAMO-PERSISTENCE: commit
                        (- (omegaClawAdapterStateField
                                $nextState next-turn-id) 1)
                        $status))))
        skipped))
