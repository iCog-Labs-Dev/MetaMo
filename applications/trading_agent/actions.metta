(= (tradingActionOrder)
    (buy sell reduce hold)
)

(= (tradingNormalizeActionId $actionId)
    (if (listContains (tradingActionOrder) $actionId)
        $actionId
        (validationError unknown-trading-action-id $actionId)
    )
)

(= (tradingPlanningInstruction $actionId)
    (symbolMapGet
        (
            (buy enter)
            (sell exit)
            (reduce trim)
            (hold wait)
        )
        $actionId
        unknown
    )
)

(= (tradingExecutionInstruction $actionId)
    (symbolMapGet
        (
            (buy allocate)
            (sell liquidate)
            (reduce halve)
            (hold keep)
        )
        $actionId
        unknown
    )
)

(= (tradingActionSpec $actionId)
    (let* (
        ($canonical (tradingNormalizeActionId $actionId))
    )
        (case $canonical (
            ((validationError $code $details) $canonical)
            ($_ (tradingActionSpecRecord
                    $canonical
                    (tradingPlanningInstruction $canonical)
                    (tradingExecutionInstruction $canonical)
                )
            )
        ))
    )
)
