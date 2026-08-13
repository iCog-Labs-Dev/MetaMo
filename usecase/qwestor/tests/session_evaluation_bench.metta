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

(= (qwestorBenchmarkPreviousOutcomePairs none)
  ()
)

(= (qwestorBenchmarkPreviousOutcomePairs
      (qwestorPendingOutcome $outcomeId $outcome))
  (qwestorOutcomePairs $outcome)
)

(= (qwestorRunSessionTurn $engine $sessionId $turnIndex $spec)
  (let* (
    ($caseId (index-atom $spec 0))
    ($caseGroup (index-atom $spec 1))
    ($context (makeQwestorContext (index-atom $spec 2)))
    ($query (index-atom $spec 3))
    ($expectedAction (index-atom $spec 4))
    ($acceptableActions (index-atom $spec 5))
    ($expectedStyles (index-atom $spec 6))
    ($outcomePairs (index-atom $spec 7))
    ($beforeState (qwestorEngineMotivationState $engine))
    ($previousOutcome
      (qwestorBenchmarkPreviousOutcomePairs
        (qwestorEnginePendingOutcome $engine)))
    ($pending
      (validationValue
        (qwestorPrepareTransition $engine $context $query)))
    ($prepared (qwestorPendingPreparedCycle $pending))
    ($report (qwestorPreparedDecisionReport $prepared))
    ($diagnostics (qwestorPendingDiagnostics $pending))
    ($request (qwestorPendingEffectRequest $pending))
    ($effectContext (qwestorEffectRequestContext $request))
    ($actionId (qwestorDiagnosticsActionId $diagnostics))
    ($outcome
      (makeQwestorOutcome
        (qwestor_benchmark_outcome $sessionId $turnIndex)
        $outcomePairs))
    ($effectResult
      (qwestorEffectResultRecord
        (qwestorEffectRequestId $request)
        "deterministic benchmark response"))
    ($cycle
      (validationValue
        (qwestorCommitCycle $engine $pending $effectResult $outcome)))
    ($nextEngine (qwestorCycleNextEngine $cycle))
    ($afterState (qwestorEngineMotivationState $nextEngine))
    ($recorded
      (py-call
        (eval.record_session_case
          "usecase/qwestor/metrics/artifacts/session_results.jsonl"
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
          (qwestorEffectContextStyles $effectContext)
          $expectedStyles
          $sessionId
          $turnIndex
          $caseGroup
          (stateGoals $beforeState)
          (stateModulators $beforeState)
          (stateGoals $afterState)
          (stateModulators $afterState)
          $previousOutcome
          (qwestorOutcomePairs $outcome))))
  )
    $nextEngine
  )
)

(= (qwestorRunSessionTurns $engine $sessionId $turnIndex $turns)
  (if (== $turns ())
    $engine
    (let* (
      (($head $tail) (decons $turns))
      ($nextEngine
        (qwestorRunSessionTurn $engine $sessionId $turnIndex $head))
    )
      (qwestorRunSessionTurns
        $nextEngine $sessionId (+ $turnIndex 1) $tail)
    )
  )
)

(= (qwestorRunEvaluationSessions $sessions)
  (if (== $sessions ())
    True
    (let* (
      (($head $tail) (decons $sessions))
      ($sessionId (index-atom $head 0))
      ($turns (index-atom $head 1))
      ($finalEngine
        (qwestorRunSessionTurns
          (qwestorNewEngineState) $sessionId 0 $turns))
    )
      (qwestorRunEvaluationSessions $tail)
    )
  )
)

!(py-call
  (eval.reset_results
    "usecase/qwestor/metrics/artifacts/session_results.jsonl"))

!(qwestorRunEvaluationSessions (py-call (benchmark_data.sessionCases)))

!(py-call
  (eval.generate_artifacts
    "usecase/qwestor/metrics/artifacts/session_results.jsonl"
    "usecase/qwestor/metrics/artifacts/session"))

!(py-call
  (eval.summaryTextFromFile
    "usecase/qwestor/metrics/artifacts/session_results.jsonl"))
