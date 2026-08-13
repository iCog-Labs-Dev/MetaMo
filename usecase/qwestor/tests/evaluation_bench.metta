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
!(import! &self "../metrics/eval.py")
!(import! &self "../metrics/benchmark_data.py")

(= (qwestorEvaluationPath)
  "usecase/qwestor/metrics/artifacts/golden_results.jsonl"
)

(= (qwestorEvaluationOutputPath)
  "usecase/qwestor/metrics/artifacts"
)

(= (qwestorEmitEvaluationCase $spec)
  (let* (
    ($caseId (index-atom $spec 0))
    ($caseGroup (index-atom $spec 1))
    ($context (makeQwestorContext (index-atom $spec 2)))
    ($query (index-atom $spec 3))
    ($expectedAction (index-atom $spec 4))
    ($acceptableActions (index-atom $spec 5))
    ($expectedStyles (index-atom $spec 6))
    ($pending
      (validationValue
        (qwestorPrepareTransition
          (qwestorNewEngineState) $context $query)))
    ($prepared (qwestorPendingPreparedCycle $pending))
    ($report (qwestorPreparedDecisionReport $prepared))
    ($diagnostics (qwestorPendingDiagnostics $pending))
    ($actionId (qwestorDiagnosticsActionId $diagnostics))
    ($request (qwestorPendingEffectRequest $pending))
    ($effectContext (qwestorEffectRequestContext $request))
  )
    (py-call
      (eval.record_policy_case
        (qwestorEvaluationPath)
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
        $expectedStyles))
  )
)

(= (qwestorEmitEvaluationCases $cases)
  (if (== $cases ())
    True
    (let* (
      (($head $tail) (decons $cases))
      ($recorded (qwestorEmitEvaluationCase $head))
    )
      (qwestorEmitEvaluationCases $tail)
    )
  )
)

!(py-call
  (eval.reset_results
    (qwestorEvaluationPath)))

!(qwestorEmitEvaluationCases (py-call (benchmark_data.policyCases)))

!(py-call
  (eval.generate_artifacts
    (qwestorEvaluationPath)
    (qwestorEvaluationOutputPath)))

!(py-call
  (eval.summaryTextFromFile
    (qwestorEvaluationPath)))
