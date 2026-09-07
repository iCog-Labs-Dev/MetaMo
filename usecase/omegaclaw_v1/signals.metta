
(= (omegaClawObservation
        $turnId $wakeReason $timestamp
        $newMessage $messageId $messageText $channel
        $activeTask $taskStatus $autonomyPhase
        $previousAction $previousCommandResults $previousErrors
        $loopBudget $resourceSignals $semanticSignals)
    (omegaClawObservationRecord
        $turnId $wakeReason $timestamp
        $newMessage $messageId $messageText $channel
        $activeTask $taskStatus $autonomyPhase
        $previousAction $previousCommandResults $previousErrors
        $loopBudget $resourceSignals $semanticSignals))

(= (omegaClawObservationField $observation $field)
    (let (omegaClawObservationRecord
            $turnId $wakeReason $timestamp
            $newMessage $messageId $messageText $channel
            $activeTask $taskStatus $autonomyPhase
            $previousAction $previousCommandResults $previousErrors
            $loopBudget $resourceSignals $semanticSignals)
        $observation
        (case $field (
            (turn-id $turnId)
            (wake-reason $wakeReason)
            (timestamp $timestamp)
            (new-message $newMessage)
            (message-id $messageId)
            (message-text $messageText)
            (channel $channel)
            (active-task $activeTask)
            (task-status $taskStatus)
            (autonomy-phase $autonomyPhase)
            (previous-action $previousAction)
            (previous-command-results $previousCommandResults)
            (previous-errors $previousErrors)
            (loop-budget $loopBudget)
            (resource-signals $resourceSignals)
            (semantic-signals $semanticSignals)
            ($_ (empty))
        ))))

(= (omegaClawOutcome
        $sourceTurn $candidateId
        $commandsProposed $commandsAuthorized $commandsExecuted
        $successCount $failureCount $blockedCount
        $userVisibleResult $taskProgress $evidenceQuality
        $safetyEvents $resourceCost $contradictionEvidence)
    (omegaClawOutcomeRecord
        $sourceTurn $candidateId
        $commandsProposed $commandsAuthorized $commandsExecuted
        $successCount $failureCount $blockedCount
        $userVisibleResult $taskProgress $evidenceQuality
        $safetyEvents $resourceCost $contradictionEvidence
        (omegaClawNormalizeLegacyOutcome
            $candidateId
            $commandsProposed $commandsAuthorized $commandsExecuted
            $successCount $failureCount $blockedCount
            $userVisibleResult $taskProgress $evidenceQuality
            $safetyEvents $contradictionEvidence)))

(= (omegaClawOutcomeWithMeaning
        $sourceTurn $candidateId
        $commandsProposed $commandsAuthorized $commandsExecuted
        $successCount $failureCount $blockedCount
        $userVisibleResult $taskProgress $evidenceQuality
        $safetyEvents $resourceCost $contradictionEvidence
        $meaning)
    (omegaClawOutcomeRecord
        $sourceTurn $candidateId
        $commandsProposed $commandsAuthorized $commandsExecuted
        $successCount $failureCount $blockedCount
        $userVisibleResult $taskProgress $evidenceQuality
        $safetyEvents $resourceCost $contradictionEvidence
        $meaning))

;; Keep dispatch, utility, verification, and delivery independent.
(= (omegaClawOutcomeMeaning
        $proposalStatus $dispatchStatus $effectCount $effectClass
        $resultUtility $verificationStatus $deliveryStatus $failureReason
        $guidanceCandidateId $realizationId $evidenceRelevant)
    (omegaClawOutcomeMeaningWithProposal
        $proposalStatus $dispatchStatus $effectCount $effectClass
        $resultUtility $verificationStatus $deliveryStatus $failureReason
        $guidanceCandidateId $realizationId $evidenceRelevant none 0))

(= (omegaClawOutcomeMeaningWithProposal
        $proposalStatus $dispatchStatus $effectCount $effectClass
        $resultUtility $verificationStatus $deliveryStatus $failureReason
        $guidanceCandidateId $realizationId $evidenceRelevant
        $proposalFingerprint $proposalAttempt)
    (omegaClawOutcomeMeaningRecord
        $proposalStatus $dispatchStatus $effectCount $effectClass
        $resultUtility $verificationStatus $deliveryStatus $failureReason
        $guidanceCandidateId $realizationId $evidenceRelevant
        $proposalFingerprint $proposalAttempt))

(= (omegaClawOutcomeMeaningField $meaning $field)
    (let (omegaClawOutcomeMeaningRecord
            $proposalStatus $dispatchStatus $effectCount $effectClass
            $resultUtility $verificationStatus $deliveryStatus $failureReason
            $guidanceCandidateId $realizationId $evidenceRelevant
            $proposalFingerprint $proposalAttempt)
        $meaning
        (case $field (
            (proposal-status $proposalStatus)
            (dispatch-status $dispatchStatus)
            (effect-count $effectCount)
            (effect-class $effectClass)
            (result-utility $resultUtility)
            (verification-status $verificationStatus)
            (delivery-status $deliveryStatus)
            (failure-reason $failureReason)
            (guidance-candidate-id $guidanceCandidateId)
            (realization-id $realizationId)
            (evidence-relevant $evidenceRelevant)
            (proposal-fingerprint $proposalFingerprint)
            (proposal-attempt $proposalAttempt)
            ($_ (empty))
        ))))

(= (omegaClawNoEffectOutcomeCandidate $candidateId)
    (case $candidateId (
        (defer True)
        (idle True)
        ($_ False)
    )))

(= (omegaClawLegacyProposalStatus
        $candidateId $proposed $authorized $blockedCount)
    (if (omegaClawNoEffectOutcomeCandidate $candidateId)
        not-required
        (if (== $proposed ())
            empty
            (if (== $authorized ())
                invalid
                (if (> $blockedCount 0) partial valid)))))

(= (omegaClawLegacyDispatchStatus
        $executed $successCount $failureCount)
    (if (== $executed ())
        not-dispatched
        (if (> $failureCount 0)
            (if (> $successCount 0) partial failed)
            executed)))

(= (omegaClawLegacyResultUtility
        $executed $visible $taskProgress $evidenceQuality)
    (if (== $executed ())
        irrelevant
        (if (and
                (not (== $visible ()))
                (or (> $taskProgress 0.0) (> $evidenceQuality 0.0)))
            useful
            empty)))

(= (omegaClawLegacyVerificationStatus
        $candidateId $successCount $failureCount $evidenceQuality)
    (case $candidateId (
        (verify
            (if (> $failureCount 0) failed
                (if (and (> $successCount 0)
                         (>= $evidenceQuality
                             (omegaClawEvidenceSufficiencyThreshold)))
                    passed pending)))
        (verify-goal
            (if (> $failureCount 0) failed
                (if (and (> $successCount 0)
                         (>= $evidenceQuality
                             (omegaClawEvidenceSufficiencyThreshold)))
                    passed pending)))
        ($_ not-required)
    )))

(= (omegaClawLegacyDeliveryStatus
        $candidateId $successCount $failureCount)
    (case $candidateId (
        (respond
            (if (> $successCount 0) sent
                (if (> $failureCount 0) failed suppressed)))
        (ask-clarification
            (if (> $successCount 0) sent
                (if (> $failureCount 0) failed suppressed)))
        ($_ not-applicable)
    )))

(= (omegaClawOutcomeFailureReasonFromStatuses
        $proposalStatus $dispatchStatus $resultUtility
        $verificationStatus $deliveryStatus
        $safetyEvents $contradictionEvidence)
    (if (> $safetyEvents 0)
        safety-event
        (if (> $contradictionEvidence 0)
            contradiction
            (case $proposalStatus (
                (empty proposal-empty)
                (invalid proposal-invalid)
                ($_ (case $dispatchStatus (
                    (failed dispatch-failed)
                    (partial dispatch-partial-failure)
                    ($_ (case $deliveryStatus (
                        (failed delivery-failed)
                        (suppressed delivery-suppressed)
                        ($_ (case $verificationStatus (
                            (failed verification-failed)
                            ($_ (case $resultUtility (
                                (empty result-empty)
                                ($_ none)
                            )))
                        )))
                    )))
                )))
            )))))

(= (omegaClawOutcomeHasLegacyEvidence
        $proposalStatus $dispatchStatus $resultUtility
        $verificationStatus $deliveryStatus
        $safetyEvents $contradictionEvidence)
    (not (and
        (== $proposalStatus not-required)
        (and
            (== $dispatchStatus not-dispatched)
            (and
                (== $resultUtility irrelevant)
                (and
                    (== $verificationStatus not-required)
                    (and
                        (== $deliveryStatus not-applicable)
                        (and (== $safetyEvents 0)
                             (== $contradictionEvidence 0)))))))))

(= (omegaClawNormalizeLegacyOutcome
        $candidateId
        $commandsProposed $commandsAuthorized $commandsExecuted
        $successCount $failureCount $blockedCount
        $userVisibleResult $taskProgress $evidenceQuality
        $safetyEvents $contradictionEvidence)
    (let* (
        ($proposalStatus
            (omegaClawLegacyProposalStatus
                $candidateId $commandsProposed
                $commandsAuthorized $blockedCount))
        ($dispatchStatus
            (omegaClawLegacyDispatchStatus
                $commandsExecuted $successCount $failureCount))
        ($resultUtility
            (omegaClawLegacyResultUtility
                $commandsExecuted $userVisibleResult
                $taskProgress $evidenceQuality))
        ($verificationStatus
            (omegaClawLegacyVerificationStatus
                $candidateId $successCount $failureCount
                $evidenceQuality))
        ($deliveryStatus
            (omegaClawLegacyDeliveryStatus
                $candidateId $successCount $failureCount))
        ($failureReason
            (omegaClawOutcomeFailureReasonFromStatuses
                $proposalStatus $dispatchStatus $resultUtility
                $verificationStatus $deliveryStatus
                $safetyEvents $contradictionEvidence))
        ($evidenceRelevant
            (omegaClawOutcomeHasLegacyEvidence
                $proposalStatus $dispatchStatus $resultUtility
                $verificationStatus $deliveryStatus
                $safetyEvents $contradictionEvidence))
    )
        (omegaClawOutcomeMeaning
            $proposalStatus $dispatchStatus
            (size-atom $commandsExecuted) unknown
            $resultUtility $verificationStatus $deliveryStatus $failureReason
            $candidateId $candidateId $evidenceRelevant)))

(= (omegaClawOutcomeField $outcome $field)
    (let (omegaClawOutcomeRecord
            $sourceTurn $candidateId
            $commandsProposed $commandsAuthorized $commandsExecuted
            $successCount $failureCount $blockedCount
            $userVisibleResult $taskProgress $evidenceQuality
            $safetyEvents $resourceCost $contradictionEvidence $meaning)
        $outcome
        (case $field (
            (source-turn $sourceTurn)
            (candidate-id $candidateId)
            (commands-proposed $commandsProposed)
            (commands-authorized $commandsAuthorized)
            (commands-executed $commandsExecuted)
            (success-count $successCount)
            (failure-count $failureCount)
            (blocked-count $blockedCount)
            (user-visible-result $userVisibleResult)
            (task-progress $taskProgress)
            (evidence-quality $evidenceQuality)
            (safety-events $safetyEvents)
            (resource-cost $resourceCost)
            (contradiction-evidence $contradictionEvidence)
            (meaning $meaning)
            (proposal-status
                (omegaClawOutcomeMeaningField $meaning proposal-status))
            (dispatch-status
                (omegaClawOutcomeMeaningField $meaning dispatch-status))
            (effect-count
                (omegaClawOutcomeMeaningField $meaning effect-count))
            (effect-class
                (omegaClawOutcomeMeaningField $meaning effect-class))
            (result-utility
                (omegaClawOutcomeMeaningField $meaning result-utility))
            (verification-status
                (omegaClawOutcomeMeaningField $meaning verification-status))
            (delivery-status
                (omegaClawOutcomeMeaningField $meaning delivery-status))
            (failure-reason
                (omegaClawOutcomeMeaningField $meaning failure-reason))
            (guidance-candidate-id
                (omegaClawOutcomeMeaningField
                    $meaning guidance-candidate-id))
            (realization-id
                (omegaClawOutcomeMeaningField $meaning realization-id))
            (evidence-relevant
                (omegaClawOutcomeMeaningField $meaning evidence-relevant))
            (proposal-fingerprint
                (omegaClawOutcomeMeaningField $meaning proposal-fingerprint))
            (proposal-attempt
                (omegaClawOutcomeMeaningField $meaning proposal-attempt))
            ($_ (empty))
        ))))

;; Empty recall proves goal absence without creating failure learning.
(= (omegaClawOutcomeExpectedEmpty $outcome)
    (and
        (== (omegaClawOutcomeField $outcome realization-id) recall-goals)
        (and
            (> (omegaClawOutcomeField $outcome success-count) 0)
            (== (omegaClawOutcomeField $outcome result-utility) empty))))

(= (omegaClawSignal $kind $strength $source)
    (omegaClawSignalRecord $kind (clipUnit $strength) $source))

(= (omegaClawSignalField $signal $field)
    (let (omegaClawSignalRecord $kind $strength $source)
        $signal
        (case $field (
            (kind $kind)
            (strength $strength)
            (source $source)
            ($_ (empty))
        ))))

(= (omegaClawPerception $observation $outcome $signals)
    (omegaClawPerceptionRecord
        $observation $outcome $signals $signals () ()))

(= (omegaClawPerceptionFromParts
        $observation $outcome
        $structuralSignals $semanticSignals $outcomeSignals)
    (omegaClawPerceptionRecord
        $observation
        $outcome
        (listAppend
            $structuralSignals
            (listAppend $semanticSignals $outcomeSignals))
        $structuralSignals
        $semanticSignals
        $outcomeSignals))

(= (omegaClawPerceptionField $perception $field)
    (let (omegaClawPerceptionRecord
            $observation $outcome $signals
            $structuralSignals $semanticSignals $outcomeSignals)
        $perception
        (case $field (
            (observation $observation)
            (outcome $outcome)
            (signals $signals)
            (structural-signals $structuralSignals)
            (semantic-signals $semanticSignals)
            (outcome-signals $outcomeSignals)
            ($_ (empty))
        ))))

(= (omegaClawSignalsContainKind () $kind)
    False)

(= (omegaClawSignalsContainKind $signals $kind)
    (let* (
        (($head $tail) (decons $signals))
    )
        (if (== (omegaClawSignalField $head kind) $kind)
            True
            (omegaClawSignalsContainKind $tail $kind))))

(= (omegaClawSignalStrengthByKind () $kind)
    0.0)

(= (omegaClawSignalStrengthByKind $signals $kind)
    (let* (
        (($head $tail) (decons $signals))
    )
        (if (== (omegaClawSignalField $head kind) $kind)
            (omegaClawSignalField $head strength)
            (omegaClawSignalStrengthByKind $tail $kind))))

;; Omitted signal-feature weights contribute zero.
(= (omegaClawSignalFeatureWeights $kind)
    (case $kind (
        (human-message ((importance 0.55) (human_presence 1.00)))
        (user-waiting ((importance 0.60) (human_presence 1.00)))
        (autonomous-turn ((autonomy_drive 0.70)))
        (information-request ((importance 0.45) (opportunity 0.35)
                              (human_presence 0.40)))
        (goal-control-request ((importance 0.75) (goal_control 1.00)
                               (human_presence 0.60)))
        (failure ((importance 0.50) (uncertainty 0.40)
                  (progress -0.30) (failure_load 0.75)))
        (repeated-failure ((importance 0.70)
                           (uncertainty 0.60) (progress -0.50)
                           (failure_load 1.00)))
        (execution-failure ((importance 0.55)
                            (uncertainty 0.45) (progress -0.40)
                            (failure_load 0.85)))
        (proposal-empty ((uncertainty 0.35) (progress -0.20)
                         (failure_load 0.40)))
        (proposal-invalid ((uncertainty 0.45)
                           (progress -0.30) (failure_load 0.65)))
        (proposal-repeated ((uncertainty 0.55)
                            (progress -0.45) (failure_load 0.80)))
        (ambiguity ((novelty 0.30) (importance 0.40) (uncertainty 0.60)
                    (ambiguity_load 1.00)))
        (verified-success ((risk -0.30) (opportunity 0.50) (progress 0.70)
                           (evidence_strength 1.00)))
        (verification-passed ((opportunity 0.45) (progress 0.65)
                              (evidence_strength 1.00)))
        (verification-failed ((uncertainty 0.55)
                              (progress -0.35) (failure_load 0.55)))
        (progress-made ((opportunity 0.30) (progress 0.45)
                        (evidence_strength 0.35)))
        (result-useful ((opportunity 0.40) (progress 0.50)
                        (evidence_strength 0.60)))
        (result-empty ((uncertainty 0.25) (progress -0.20)
                       (failure_load 0.30)))
        (evidence-sufficient ((uncertainty -0.35) (opportunity 0.25)
                              (progress 0.30) (evidence_strength 1.00)))
        (evidence-insufficient ((uncertainty 0.45)
                                (ambiguity_load 0.45)))
        (stalled-progress ((importance 0.50) (progress -0.20)
                           (failure_load 0.30)))
        (task-drift ((novelty 0.60) (uncertainty 0.40)
                     (task_focus 0.80)))
        (user-angry ((importance 0.35) (human_presence 0.35)))
        (danger ((risk 0.80) (importance 0.70) (uncertainty 0.40)
                 (ambiguity_load 0.20)))
        (contradiction ((risk 0.35) (uncertainty 0.50)
                        (task_focus 0.55)))
        (semantic-unavailable ())
        (execution-request ((importance 0.70) (opportunity 0.90)
                            (progress 0.60)))
        (scheduled-wake ((opportunity 0.45) (importance 0.20)))
        (continuation-due ((importance 0.55) (progress 0.35)))
        (active-goal ((importance 0.50) (opportunity 0.40)
                      (progress 0.25) (task_focus 0.75)
                      (autonomy_drive 0.35)))
        (goal-missing ((novelty 0.35) (opportunity 0.45)
                       (uncertainty 0.20)))
        (verification-needed ((importance 0.60) (uncertainty 0.30)
                              (progress 0.25) (ambiguity_load 0.25)))
        (goal-complete ((opportunity 0.40) (progress 0.75)
                        (evidence_strength 0.70)))
        (budget-low ((risk 0.15) (importance 0.35)
                     (task_focus 0.40)))
        (blocked-command ((risk 0.45) (importance 0.35)
                          (uncertainty 0.30) (progress -0.25)
                          (failure_load 0.40)))
        (effect-reversible ((risk -0.15) (opportunity 0.15)))
        (effect-external ((risk 0.35) (importance 0.25)))
        (effect-destructive ((risk 0.90) (importance 0.80)
                             (uncertainty 0.30)))
        ($_ ())
    )))

(= (omegaClawSignalDefaultStrength $kind)
    (case $kind (
        (repeated-failure 0.85)
        (failure 0.80)
        (task-drift 0.45)
        (ambiguity 0.60)
        (stalled-progress 0.35)
        (progress-made 0.40)
        (verified-success 0.40)
        (human-message 1.00)
        (user-waiting 0.30)
        (user-angry 0.60)
        (danger 0.60)
        (contradiction 0.60)
        (semantic-unavailable 1.00)
        (information-request 0.75)
        (goal-control-request 0.85)
        (execution-request 0.85)
        (autonomous-turn 0.70)
        (scheduled-wake 0.55)
        (continuation-due 0.60)
        (task-execution-authorized 1.00)
        (active-goal 0.60)
        (goal-missing 0.55)
        (verification-needed 0.65)
        (goal-complete 0.70)
        (budget-low 0.70)
        (blocked-command 0.65)
        (proposal-empty 0.75)
        (proposal-invalid 0.80)
        (proposal-repeated 0.90)
        (execution-failure 0.85)
        (result-empty 0.70)
        (result-useful 0.75)
        (evidence-sufficient 0.80)
        (evidence-insufficient 0.75)
        (verification-passed 0.85)
        (verification-failed 0.85)
        (effect-reversible 0.60)
        (effect-external 0.70)
        (effect-destructive 1.00)
        ($_ 0.0)
    )))

(= (omegaClawDefaultSignal $kind $source)
    (omegaClawSignal
        $kind
        (omegaClawSignalDefaultStrength $kind)
        $source))
