
(= (omegaClawSemanticClassificationKinds)
    (information-request execution-request goal-control-request ambiguity
     danger contradiction task-drift user-angry))

(= (omegaClawSemanticSignalKinds)
    (information-request execution-request goal-control-request ambiguity
     danger contradiction task-drift user-angry semantic-unavailable))

(= (omegaClawCapabilityEnvelopes)
    (send-only memory-read working-memory-write memory-write memory-update
     external-read goal-definition goal-assessment autonomy-work verification
     requested-effect no-effect))

(= (omegaClawApplicationScale) 1.0)
(= (omegaClawExecutionRiskLimit) 0.45)
(= (omegaClawExecutionUncertaintyLimit) 0.65)
(= (omegaClawSemanticSignalThreshold) 0.50)

;; Require stronger evidence for intent signals that authorize effects.
(= (omegaClawSemanticSignalThresholdFor $kind)
    (case $kind (
        (execution-request 0.65)
        (goal-control-request 0.65)
        ($_ (omegaClawSemanticSignalThreshold))
    )))
;; Keep semantic classification independent from main command realization.
(= (omegaClawSemanticProviderName) ASICloudSemantic)
(= (omegaClawSemanticApiKeyVariable) ASI_API_KEY2)
(= (omegaClawSemanticModelName) google/gemma-4-31b-it)
(= (omegaClawSemanticBaseUrl)
    "https://llm.c.singularitynet.io/v1")
(= (omegaClawSemanticTimeoutSeconds) 10.0)

(= (omegaClawSemanticMaxOutputTokens) 256)

(= (omegaClawSemanticReasoningMode) low)
(= (omegaClawEvidenceSufficiencyThreshold) 0.70)
(= (omegaClawMinimumIndependentEvidenceEntries) 2)
(= (omegaClawAutonomyStepLimit) 50)

;; Bound each autonomous burst by calls, effects, failures, and elapsed time.
(= (omegaClawAutonomyMainLlmCallLimit) 8)
(= (omegaClawAutonomyEffectLimit) 12)
(= (omegaClawAutonomyFailureLimit) 2)
(= (omegaClawAutonomyTimeBudgetSeconds) 300)

;; Resume internal work after a bounded wait for clarification.
(= (omegaClawHumanResponseWaitIterationLimit) 30)

;; Gate autonomous effects after MAGUS selects the exact maximum.
(= (omegaClawAutonomyActionScoreThreshold) 0.45)
(= (omegaClawAutonomyYieldMarginThreshold) 0.10)

;; Bound human and autonomous realization separately.
(= (omegaClawHumanProviderTimeoutSeconds) 60.0)
(= (omegaClawAutonomyProviderTimeoutSeconds) 40.0)

;; Keep outcome learning below the canonical hard delta bound.
(= (omegaClawOutcomeLearningRate) 0.08)
(= (omegaClawOutcomeMaxGoalDelta) 0.08)
(= (omegaClawProposalRetryLimit) 2)

(= (omegaClawGoalEvidenceLimit) 8)
(= (omegaClawRecentActionLimit) 16)
(= (omegaClawDiagnosticsHistoryLimit) 16)
(= (omegaClawCommittedTurnIdLimit) 64)
(= (omegaClawAdapterStageTraceLimit) 24)

;; Increment the persistence version after incompatible state-schema changes.
(= (omegaClawPersistenceConfig $field)
    (case $field (
        (version 2)
        (path MetaMo/usecase/omegaclaw_v1/runtime/metamo_state.json)
        ($_ (empty))
    )))
