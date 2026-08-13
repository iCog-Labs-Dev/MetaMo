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

(= (qwestorRunPerceptionEvaluationCase $artifactPath $spec)
  (let* (
    ($caseId (index-atom $spec 0))
    ($caseGroup (index-atom $spec 1))
    ($query (index-atom $spec 2))
    ($expectedAction (index-atom $spec 3))
    ($acceptableActions (index-atom $spec 4))
    ($expectedStyles (index-atom $spec 5))
    ($conversation (index-atom $spec 6))
    ($sessionId (index-atom $spec 7))
    ($turnIndex (index-atom $spec 8))
    ($benchmarkVersion (index-atom $spec 9))
    ($labelRationale (index-atom $spec 10))
    ($benchmarkSuite (index-atom $spec 11))
    ($benchmarkLabelDigest (index-atom $spec 12))
    ($started
      (py-call
        (benchmark_data.liveProgress
          $sessionId $turnIndex $caseId perception)))
    ($traceReset (py-call (llm_adapter.resetRuntimeTrace)))
    ($context
      (makeQwestorContext
        (py-call
          (llm_adapter.perceiveQueryPairs $query $conversation))))
    ($pending
      (validationValue
        (qwestorPrepareTransition
          (qwestorNewEngineState) $context $query)))
    ($prepared (qwestorPendingPreparedCycle $pending))
    ($report (qwestorPreparedDecisionReport $prepared))
    ($diagnostics (qwestorPendingDiagnostics $pending))
    ($request (qwestorPendingEffectRequest $pending))
    ($effectContext (qwestorEffectRequestContext $request))
    ($actionId (qwestorDiagnosticsActionId $diagnostics))
    ($recorded
      (py-call
        (eval.record_policy_case
          $artifactPath
          qwestor
          $caseId
          $caseGroup
          $actionId
          (qwestorDecisionMargin $report)
          (featureMapPairs (qwestorPreparedFeatures $prepared))
          (qwestorStateSummary (qwestorPendingNextState $pending))
          (qwestorCandidateScorePairs (qwestorDecisionScores $report))
          (qwestorDiagnosticsPairs $diagnostics)
          $expectedAction
          $acceptableActions
          (qwestorEffectContextStyles $effectContext)
          $expectedStyles
          $sessionId
          $turnIndex
          $benchmarkVersion
          $labelRationale
          (py-call (llm_adapter.runtimeSummaryPairs))
          (py-call (llm_adapter.perceptionTracePairs))
          $benchmarkSuite
          $benchmarkLabelDigest)))
    ($completed
      (py-call
        (benchmark_data.liveProgress
          $sessionId $turnIndex $caseId complete)))
  )
    True
  )
)

(= (qwestorRunPerceptionEvaluationCases $artifactPath $cases)
  (if (== $cases ())
    True
    (let* (
      (($head $tail) (decons $cases))
      ($recorded
        (qwestorRunPerceptionEvaluationCase $artifactPath $head))
    )
      (qwestorRunPerceptionEvaluationCases $artifactPath $tail)
    )
  )
)
