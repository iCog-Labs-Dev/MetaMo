!(import! &self ./perception_evaluation_runner)

!(py-call (benchmark_data.requirePerceptionBenchmarkConfiguration))
!(py-call (llm_adapter.validateConfiguredProviders))

!(py-call
  (eval.reset_results
    "usecase/qwestor/metrics/artifacts/perception_results.jsonl"))

!(qwestorRunPerceptionEvaluationCases
  "usecase/qwestor/metrics/artifacts/perception_results.jsonl"
  (py-call (benchmark_data.perceptionCases)))

!(py-call
  (eval.generate_artifacts
    "usecase/qwestor/metrics/artifacts/perception_results.jsonl"
    "usecase/qwestor/metrics/artifacts/perception"))

!(py-call
  (eval.summaryTextFromFile
    "usecase/qwestor/metrics/artifacts/perception_results.jsonl"))
