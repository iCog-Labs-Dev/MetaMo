!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/features)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../../openpsi/profile)
!(import! &self ../../openpsi/appraisal)
!(import! &self ../../applications/common/openpsi_conventions)
!(import! &self ../../magus/correlation)
!(import! &self ../../magus/profile)
!(import! &self ../../magus/goal_change)
!(import! &self ../../magus/decision)
!(import! &self ../../dynamics/stability)
!(import! &self ../../dynamics/coherence)
!(import! &self ../../category/merge)
!(import! &self ../../category/diagnostics)
!(import! &self ../../category/functors)
!(import! &self ../../category/bimonad)
!(import! &self ../../core/runtime)
!(import! &self config)
!(import! &self schema)
!(import! &self state)
!(import! &self stimulus)
!(import! &self appraisal_profile)
!(import! &self actions)
!(import! &self planning)
!(import! &self decision_profile)
!(import! &self goal_change)
!(import! &self "policy_helpers.py")
!(import! &self stability)
!(import! &self bundle)
!(import! &self engine)
!(import! &self "context_parser.py")
!(import! &self "session_store.py")
!(import! &self "adapters/llm_adapter.py")
!(import! &self session_helpers)

(: QwestorRunCommand Type)
(: qwestorRunCommandRecord
    (-> QwestorContext Expression Expression QwestorOutcome QwestorRunCommand))

(: QwestorSessionResult Type)
(: qwestorSessionResultRecord
    (-> QwestorEngineState Expression QwestorSessionResult))

(= (qwestorBeginTurn $engine $context $query)
    (qwestorPrepareTransition $engine $context $query)
)

(= (qwestorContextFromPayload $payload)
    (makeQwestorContext
        (py-call (context_parser.parseContextPairs $payload)))
)

(= (qwestorBeginParsedTurn $engine $contextPayload $query)
    (qwestorBeginTurn
        $engine
        (qwestorContextFromPayload $contextPayload)
        $query)
)

(= (runQwestor $engine $pending $effectResult $outcome)
    (qwestorCommitCycle $engine $pending $effectResult $outcome)
)

(= (qwestorRunSingleTurn $engine $context $query $effectPayload $outcome)
    (let* (
        ($pendingResult (qwestorBeginTurn $engine $context $query))
    )
        (case $pendingResult (
            ((validationOk $pending)
                (let* (
                    ($request (qwestorPendingEffectRequest $pending))
                    ($effectResult
                        (qwestorEffectResultRecord
                            (qwestorEffectRequestId $request)
                            $effectPayload))
                )
                    (runQwestor $engine $pending $effectResult $outcome)
                ))
            ((validationError $code $details)
                (validationError $code $details))
        ))
    )
)

(= (qwestorInteractiveStep $engine $context $query $effectPayload $outcome)
    (qwestorRunSingleTurn
        $engine $context $query $effectPayload $outcome)
)

(= (qwestorExecuteLivePending $engine $pending)
    (let* (
        ($request (qwestorPendingEffectRequest $pending))
        ($effectContext (qwestorEffectRequestContext $request))
        ($actionId (qwestorEffectRequestActionId $request))
        ($effectKind (qwestorEffectRequestKind $request))
        ($answer
            (py-call
                (llm_adapter.executeEffectText
                    (qwestorEffectContextQuery $effectContext)
                    $actionId
                    $effectKind
                    (qwestorEffectContextStyles $effectContext)
                    (qwestorEffectContextStateValues $effectContext))))
        ($outcomePairs
            (py-call
                (llm_adapter.assessOutcomePairs
                    (qwestorEffectContextQuery $effectContext)
                    $answer
                    $actionId
                    $effectKind)))
        ($outcome
            (makeQwestorOutcome
                (qwestor_outcome (qwestorPendingSourceTurn $pending))
                $outcomePairs))
        ($effectResult
            (qwestorEffectResultRecord
                (qwestorEffectRequestId $request)
                $answer))
    )
        (runQwestor $engine $pending $effectResult $outcome)
    )
)

(= (qwestorRunLiveTurn $engine $query)
    (let* (
        ($context
            (makeQwestorContext
                (py-call (llm_adapter.perceiveQueryPairs $query))))
        ($pendingResult (qwestorBeginTurn $engine $context $query))
    )
        (case $pendingResult (
            ((validationOk $pending)
                (qwestorExecuteLivePending $engine $pending))
            ((validationError $code $details)
                (validationError $code $details))
        ))
    )
)

(= (qwestorRunCommandContext
        (qwestorRunCommandRecord $context $query $effectPayload $outcome))
    $context
)

(= (qwestorRunCommandQuery
        (qwestorRunCommandRecord $context $query $effectPayload $outcome))
    $query
)

(= (qwestorRunCommandEffectPayload
        (qwestorRunCommandRecord $context $query $effectPayload $outcome))
    $effectPayload
)

(= (qwestorRunCommandOutcome
        (qwestorRunCommandRecord $context $query $effectPayload $outcome))
    $outcome
)

(= (qwestorRunCannedSessionLoop $engine $commands $results)
    (if (== $commands ())
        (validationOk (qwestorSessionResultRecord $engine $results))
        (let* (
            (($head $tail) (decons $commands))
            ($cycleResult
                (qwestorRunSingleTurn
                    $engine
                    (qwestorRunCommandContext $head)
                    (qwestorRunCommandQuery $head)
                    (qwestorRunCommandEffectPayload $head)
                    (qwestorRunCommandOutcome $head)))
        )
            (case $cycleResult (
                ((validationOk $cycle)
                    (qwestorRunCannedSessionLoop
                        (qwestorCycleNextEngine $cycle)
                        $tail
                        (listAppend $results ($cycle))))
                ((validationError $code $details)
                    (validationError $code $details))
            ))
        )
    )
)

(= (qwestorRunCannedSession $engine $commands)
    (qwestorRunCannedSessionLoop $engine $commands ())
)

(= (qwestorSessionResultEngine
        (qwestorSessionResultRecord $engine $results))
    $engine
)

(= (qwestorSessionResultCycles
        (qwestorSessionResultRecord $engine $results))
    $results
)
