!(import! &self ../../../core/validation)
!(import! &self ../../../core/schema)
!(import! &self ../../../core/features)
!(import! &self ../../../core/state)
!(import! &self ../../../core/helper)
!(import! &self "../../../core/helpers.py")
!(import! &self ../../../openpsi/profile)
!(import! &self ../../../openpsi/appraisal)
!(import! &self ../../../applications/common/openpsi_conventions)
!(import! &self ../../../magus/correlation)
!(import! &self ../../../magus/profile)
!(import! &self ../../../magus/goal_change)
!(import! &self ../../../magus/decision)
!(import! &self ../../../dynamics/stability)
!(import! &self ../../../dynamics/coherence)
!(import! &self ../../../category/merge)
!(import! &self ../../../category/diagnostics)
!(import! &self ../../../category/functors)
!(import! &self ../../../category/bimonad)
!(import! &self ../../../core/runtime)
!(import! &self ../config)
!(import! &self ../schema)
!(import! &self ../state)
!(import! &self ../stimulus)
!(import! &self ../appraisal_profile)
!(import! &self ../actions)
!(import! &self ../planning)
!(import! &self ../decision_profile)
!(import! &self ../goal_change)
!(import! &self "../policy_helpers.py")
!(import! &self ../stability)
!(import! &self ../bundle)
!(import! &self ../engine)
!(import! &self "../context_parser.py")
!(import! &self "../adapters/provider_transport.py")
!(import! &self "../adapters/prompt_builder.py")
!(import! &self "../adapters/llm_adapter.py")
!(import! &self "../metrics/eval.py")
!(import! &self "../metrics/benchmark_data.py")

(= (qwestorLivePreviousOutcomePairs none)
  ()
)

(= (qwestorLivePreviousOutcomePairs
      (qwestorPendingOutcome $outcomeId $outcome))
  (qwestorOutcomePairs $outcome)
)

(= (qwestorRunLiveEvaluationTurn $engine $sessionId $turnIndex $spec)
  (let* (
    ($caseId (index-atom $spec 0))
    ($caseGroup (index-atom $spec 1))
    ($query (index-atom $spec 2))
    ($expectedAction (index-atom $spec 3))
    ($acceptableActions (index-atom $spec 4))
    ($expectedStyles (index-atom $spec 5))
    ($evidence (index-atom $spec 6))
    ($benchmarkVersion (index-atom $spec 7))
    ($labelRationale (index-atom $spec 8))
    ($conversation
      (py-call (benchmark_data.liveConversation $sessionId)))
    ($perceptionStarted
      (py-call
        (benchmark_data.liveProgress
          $sessionId $turnIndex $caseId perception)))
    ($traceReset (py-call (llm_adapter.resetRuntimeTrace)))
    ($evidenceSet
      (py-call (llm_adapter.setControlledEvidenceText $evidence)))
    ($context
      (makeQwestorContext
        (py-call
          (llm_adapter.perceiveQueryPairs $query $conversation))))
    ($beforeState (qwestorEngineMotivationState $engine))
    ($previousOutcome
      (qwestorLivePreviousOutcomePairs
        (qwestorEnginePendingOutcome $engine)))
    ($pending
      (validationValue
        (qwestorPrepareTransition $engine $context $query)))
    ($prepared (qwestorPendingPreparedCycle $pending))
    ($report (qwestorPreparedDecisionReport $prepared))
    ($diagnostics (qwestorPendingDiagnostics $pending))
    ($request (qwestorPendingEffectRequest $pending))
    ($effectContext (qwestorEffectRequestContext $request))
    ($actionId (qwestorEffectRequestActionId $request))
    ($effectKind (qwestorEffectRequestKind $request))
    ($selectedStyles (qwestorEffectContextStyles $effectContext))
    ($effectStarted
      (py-call
        (benchmark_data.liveProgress
          $sessionId $turnIndex $caseId $actionId)))
    ($answer
      (py-call
        (llm_adapter.executeEffectText
          $query
          $actionId
          $effectKind
          $selectedStyles
          (qwestorEffectContextStateValues $effectContext)
          $conversation)))
    ($outcomeStarted
      (py-call
        (benchmark_data.liveProgress
          $sessionId $turnIndex $caseId outcome_assessment)))
    ($outcomePairs
      (py-call
        (llm_adapter.assessOutcomePairs
          $query $answer $actionId $effectKind $conversation)))
    ($evaluationStarted
      (py-call
        (benchmark_data.liveProgress
          $sessionId $turnIndex $caseId response_evaluation)))
    ($responseMetrics
      (py-call
        (llm_adapter.evaluateResponsePairsSafe
          $query
          $answer
          $actionId
          $selectedStyles
          (py-call (llm_adapter.lastEvidenceText))
          $conversation)))
    ($runtime (py-call (llm_adapter.runtimeSummaryPairs)))
    ($outcome
      (makeQwestorOutcome
        (qwestor_live_outcome $sessionId $turnIndex)
        $outcomePairs))
    ($effectResult
      (qwestorEffectResultRecord
        (qwestorEffectRequestId $request)
        $answer))
    ($cycle
      (validationValue
        (qwestorCommitCycle $engine $pending $effectResult $outcome)))
    ($nextEngine (qwestorCycleNextEngine $cycle))
    ($afterState (qwestorEngineMotivationState $nextEngine))
    ($recorded
      (py-call
        (eval.record_session_case
          "usecase/qwestor/metrics/artifacts/live_results.jsonl"
          qwestor
          $caseId
          $actionId
          (qwestorDecisionMargin $report)
          (featureMapPairs (qwestorPreparedFeatures $prepared))
          (qwestorStateSummary $afterState)
          (qwestorCandidateScorePairs (qwestorDecisionScores $report))
          (qwestorDiagnosticsPairs $diagnostics)
          $expectedAction
          $acceptableActions
          $selectedStyles
          $expectedStyles
          $sessionId
          $turnIndex
          $caseGroup
          (stateGoals $beforeState)
          (stateModulators $beforeState)
          (stateGoals $afterState)
          (stateModulators $afterState)
          $previousOutcome
          (qwestorOutcomePairs $outcome)
          $answer
          $responseMetrics
          $runtime
          $benchmarkVersion
          $labelRationale)))
    ($conversationRecorded
      (py-call
        (benchmark_data.appendLiveConversation
          $sessionId
          $query
          $answer
          $actionId
          $effectKind
          (py-call (llm_adapter.lastEvidenceText)))))
    ($turnCompleted
      (py-call
        (benchmark_data.liveProgress
          $sessionId $turnIndex $caseId complete)))
  )
    $nextEngine
  )
)

(= (qwestorRunLiveEvaluationTurns $engine $sessionId $turnIndex $turns)
  (if (== $turns ())
    $engine
    (let* (
      (($head $tail) (decons $turns))
      ($nextEngine
        (qwestorRunLiveEvaluationTurn
          $engine $sessionId $turnIndex $head))
    )
      (qwestorRunLiveEvaluationTurns
        $nextEngine $sessionId (+ $turnIndex 1) $tail)
    )
  )
)

(= (qwestorRunLiveEvaluationSessions $sessions)
  (if (== $sessions ())
    True
    (let* (
      (($head $tail) (decons $sessions))
      ($sessionId (index-atom $head 0))
      ($turns (index-atom $head 1))
      ($conversationReset
        (py-call (benchmark_data.resetLiveConversation $sessionId)))
      ($finalEngine
        (qwestorRunLiveEvaluationTurns
          (qwestorNewEngineState) $sessionId 0 $turns))
    )
      (qwestorRunLiveEvaluationSessions $tail)
    )
  )
)

!(py-call (benchmark_data.requireLiveBenchmarkConfiguration))
!(py-call (llm_adapter.requireIndependentOutcomeProvider))
!(py-call (llm_adapter.validateConfiguredProviders))

!(py-call
  (eval.reset_results
    "usecase/qwestor/metrics/artifacts/live_results.jsonl"))

!(qwestorRunLiveEvaluationSessions
  (py-call (benchmark_data.liveSessionCases)))

!(py-call
  (eval.generate_artifacts
    "usecase/qwestor/metrics/artifacts/live_results.jsonl"
    "usecase/qwestor/metrics/artifacts/live"))

!(py-call
  (eval.summaryTextFromFile
    "usecase/qwestor/metrics/artifacts/live_results.jsonl"))
