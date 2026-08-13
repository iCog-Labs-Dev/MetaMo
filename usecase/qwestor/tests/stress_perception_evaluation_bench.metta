!(import! &self ./perception_evaluation_runner)

!(py-call (benchmark_data.requireStressBenchmarkConfiguration))
!(py-call (llm_adapter.validateConfiguredProviders))

!(py-call
  (eval.reset_results
    "usecase/qwestor/metrics/artifacts/stress_results.jsonl"))

!(qwestorRunPerceptionEvaluationCases
  "usecase/qwestor/metrics/artifacts/stress_results.jsonl"
  (py-call (benchmark_data.stressPerceptionCases)))

!(py-call
  (eval.generate_artifacts
    "usecase/qwestor/metrics/artifacts/stress_results.jsonl"
    "usecase/qwestor/metrics/artifacts/stress"))

!(py-call
  (eval.summaryTextFromFile
    "usecase/qwestor/metrics/artifacts/stress_results.jsonl"))
