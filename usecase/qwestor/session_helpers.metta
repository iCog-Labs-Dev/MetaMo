(= (qwestorOutcomeStorageValues $outcome)
    (
        (qwestorOutcomeValue $outcome short_help 0.50)
        (qwestorOutcomeValue $outcome long_help 0.50)
        (qwestorOutcomeValue $outcome grounding 0.50)
        (qwestorOutcomeValue $outcome safety 0.50)
        (qwestorOutcomeValue $outcome progress 0.50)
        (qwestorOutcomeValue $outcome novel_yield 0.50)
        (qwestorOutcomeValue $outcome original_yield 0.50)
        (qwestorOutcomeValue $outcome breakthrough_yield 0.50)
        (qwestorOutcomeValue $outcome coherence 0.50)
        (qwestorOutcomeValue $outcome social_quality 0.50)
        (qwestorOutcomeValue $outcome efficiency 0.50)
        (qwestorOutcomeValue $outcome accuracy 0.50)
    )
)

(= (qwestorPendingStorageFields none)
    (none ())
)

(= (qwestorPendingStorageFields
        (qwestorPendingOutcome $outcomeId $outcome))
    ($outcomeId (qwestorOutcomeStorageValues $outcome))
)

(= (qwestorSnapshotEngine $engine)
    (qwestorStateSnapshot
        (qwestorEngineMotivationState $engine)
        (qwestorEnginePendingOutcome $engine))
)

(= (qwestorEncodeSnapshotRecord
        (qwestorStateSnapshotRecord
            $schemaId $goals $modulators $pendingOutcome))
    (let* (
        (($outcomeId $outcomeValues)
            (qwestorPendingStorageFields $pendingOutcome))
    )
        (py-call
            (session_store.encode_snapshot
                $schemaId
                $goals
                $modulators
                $outcomeId
                $outcomeValues))
    )
)

(= (qwestorEncodeEngineSnapshot $engine)
    (let* (
        ($snapshotResult (qwestorSnapshotEngine $engine))
    )
        (case $snapshotResult (
            ((validationOk $snapshot)
                (validationOk (qwestorEncodeSnapshotRecord $snapshot)))
            ((validationError $code $details)
                (validationError $code $details))
        ))
    )
)

(= (qwestorSaveSnapshotRecord
        $path
        (qwestorStateSnapshotRecord
            $schemaId $goals $modulators $pendingOutcome))
    (let* (
        (($outcomeId $outcomeValues)
            (qwestorPendingStorageFields $pendingOutcome))
    )
        (py-call
            (session_store.save_snapshot
                $path
                $schemaId
                $goals
                $modulators
                $outcomeId
                $outcomeValues))
    )
)

(= (qwestorSaveEngineSnapshot $path $engine)
    (let* (
        ($snapshotResult (qwestorSnapshotEngine $engine))
    )
        (case $snapshotResult (
            ((validationOk $snapshot)
                (qwestorSaveSnapshotRecord $path $snapshot))
            ((validationError $code $details)
                (validationError $code $details))
        ))
    )
)

(= (qwestorOutcomeFromStorage $outcomeId $values)
    (makeQwestorOutcome
        $outcomeId
        (
            (short_help (index-atom $values 0))
            (long_help (index-atom $values 1))
            (grounding (index-atom $values 2))
            (safety (index-atom $values 3))
            (progress (index-atom $values 4))
            (novel_yield (index-atom $values 5))
            (original_yield (index-atom $values 6))
            (breakthrough_yield (index-atom $values 7))
            (coherence (index-atom $values 8))
            (social_quality (index-atom $values 9))
            (efficiency (index-atom $values 10))
            (accuracy (index-atom $values 11))
        ))
)

(= (qwestorPendingFromStorage $outcomeId $values)
    (if (or (== $outcomeId none) (== $outcomeId "none"))
        none
        (let* (
            ($outcome (qwestorOutcomeFromStorage $outcomeId $values))
        )
            (qwestorMakePendingOutcome $outcomeId $outcome)
        )
    )
)

(= (qwestorSchemaIdFromStorage qwestor)
    qwestor
)

(= (qwestorSchemaIdFromStorage "qwestor")
    qwestor
)

(= (qwestorSnapshotFromStorageFields
        $schemaId $goals $modulators $outcomeId $outcomeValues)
    (if (and
            (== (size-atom $goals) 20)
            (== (size-atom $modulators) 13))
        (if (or
                (== $outcomeId none)
                (or
                    (== $outcomeId "none")
                    (== (size-atom $outcomeValues) 12)))
            (validationOk
                (qwestorStateSnapshotRecord
                    (qwestorSchemaIdFromStorage $schemaId)
                    $goals
                    $modulators
                    (qwestorPendingFromStorage
                        $outcomeId $outcomeValues)))
            (validationError invalid-qwestor-stored-outcome $outcomeValues)
        )
        (validationError invalid-qwestor-stored-dimensions
            ((goals (size-atom $goals))
             (modulators (size-atom $modulators))))
    )
)

(= (qwestorRestoreEngineFromSnapshot $snapshot)
    (let* (
        ($restoredResult (qwestorStateFromSnapshot $snapshot))
    )
        (case $restoredResult (
            ((validationOk $restored)
                (let* (
                    ($engine
                        (qwestorEngineStateRecord
                            (qwestorRestoredMotivationState $restored)
                            (qwestorRestoredPendingOutcome $restored)
                            ()
                            ()
                            ()
                            0))
                    ($engineResult (qwestorValidateEngineState $engine))
                )
                    $engineResult
                ))
            ((validationError $code $details)
                (validationError $code $details))
        ))
    )
)

(= (qwestorDecodeEngineSnapshot $payload)
    (let* (
        (($schemaId $goals $modulators $outcomeId $outcomeValues)
            (py-call (session_store.decode_snapshot $payload)))
        ($snapshotResult
            (qwestorSnapshotFromStorageFields
                $schemaId $goals $modulators $outcomeId $outcomeValues))
    )
        (case $snapshotResult (
            ((validationOk $snapshot)
                (qwestorRestoreEngineFromSnapshot $snapshot))
            ((validationError $code $details)
                (validationError $code $details))
        ))
    )
)

(= (qwestorLoadEngineSnapshot $path)
    (let* (
        (($schemaId $goals $modulators $outcomeId $outcomeValues)
            (py-call (session_store.load_snapshot $path)))
        ($snapshotResult
            (qwestorSnapshotFromStorageFields
                $schemaId $goals $modulators $outcomeId $outcomeValues))
    )
        (case $snapshotResult (
            ((validationOk $snapshot)
                (qwestorRestoreEngineFromSnapshot $snapshot))
            ((validationError $code $details)
                (validationError $code $details))
        ))
    )
)
