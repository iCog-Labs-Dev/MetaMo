(= (tradingDefaultState)
    (motivationState
        (tradingSchema)
        (tradingDefaultGoals)
        (tradingDefaultModulators)
    )
)

(= (tradingStateFromVectors $goals $modulators)
    (motivationState (tradingSchema) $goals $modulators)
)

(= (tradingPrudenceState)
    (tradingStateFromVectors
        (0.85 0.30 0.90 0.35 0.90 0.25 0.70 0.85 0.25 0.15 0.15 0.15 0.10 0.10)
        (0.50 0.35 0.30 0.65 0.75 0.80 0.40 0.25 0.15 0.55 0.35 0.20)
    )
)

(= (tradingAmbitionState)
    (tradingStateFromVectors
        (0.45 0.88 0.45 0.88 0.55 0.85 0.45 0.45 0.32 0.32 0.34 0.20 0.35 0.28)
        (0.50 0.75 0.75 0.45 0.35 0.30 0.25 0.10 0.35 0.70 0.25 0.15)
    )
)

(= (tradingStateSnapshot $state)
    (tradingStateSnapshotRecord
        (motivationSchemaId (stateSchema $state))
        (stateGoals $state)
        (stateModulators $state)
    )
)

(= (tradingStateFromSnapshot (tradingStateSnapshotRecord $schemaId $goals $modulators))
    (if (== $schemaId trading_agent)
        (motivationState (tradingSchema) $goals $modulators)
        (validationError wrong-trading-schema $schemaId)
    )
)
