;; Define contextual guidance candidates for canonical MetaMo scoring.

(= (omegaClawCandidateIds)
    (respond clarify orient advance verify learn repair defer idle))

(= (omegaClawCandidateBaseCorrelationPairs $candidateId)
    (case $candidateId (
        (respond
            ((help_user 0.90) (responsiveness 0.85) (cooperate 0.55)
             (clarity 0.45) (coherence 0.30) (reliability 0.25)
             (progress 0.15) (risk 0.06) (contradiction 0.04)
             (unsafe 0.01)))
        (clarify
            ((help_user 0.58) (cooperate 0.62) (responsiveness 0.42)
             (clarity 0.92) (coherence 0.68) (reliability 0.62)
             (adaptivity 0.30) (risk 0.01) (contradiction 0.01)))
        (orient
            ((help_user 0.32) (learn 0.72) (clarity 0.78)
             (coherence 0.70) (reliability 0.58) (progress 0.30)
             (adaptivity 0.48) (risk 0.04) (contradiction 0.02)
             (unsafe 0.01)))
        (advance
            ((help_user 0.72) (cooperate 0.35) (responsiveness 0.52)
             (coherence 0.42) (reliability 0.38) (progress 0.95)
             (adaptivity 0.38) (risk 0.18) (contradiction 0.06)
             (unsafe 0.12)))
        (verify
            ((help_user 0.38) (learn 0.28) (clarity 0.74)
             (coherence 0.78) (reliability 0.96) (progress 0.44)
             (adaptivity 0.28) (risk 0.02) (contradiction 0.01)))
        (learn
            ((help_user 0.22) (learn 0.94) (coherence 0.62)
             (reliability 0.52) (progress 0.30) (adaptivity 0.72)
             (risk 0.05) (contradiction 0.02) (unsafe 0.01)))
        (repair
            ((help_user 0.48) (learn 0.32) (clarity 0.54)
             (coherence 0.64) (reliability 0.88) (progress 0.52)
             (adaptivity 0.92) (risk 0.06) (contradiction 0.02)
             (unsafe 0.04)))
        (defer
            ((gInd_over 0.75) (cooperate 0.18) (clarity 0.28)
             (coherence 0.42) (reliability 0.68)
             (risk 0.01) (contradiction 0.01)))
        (idle
            ((gInd_over 0.20) (coherence 0.15) (reliability 0.18)
             (risk 0.00) (contradiction 0.00) (unsafe 0.00)))
        ($_ (validationError unknown-omegaclaw-candidate $candidateId))
    )))

(= (omegaClawCandidateBaseCorrelations $candidateId)
    (case (omegaClawCandidateBaseCorrelationPairs $candidateId) (
        ((validationError $code $details)
            (validationError $code $details))
        ($pairs (omegaClawCorrelationVector $pairs))
    )))

(= (omegaClawCandidateTaskActive $status)
    (case $status (
        (active True)
        (open True)
        (blocked True)
        (ready True)
        (verifying True)
        (verified True)
        (awaiting-human True)
        ($_ False)
    )))

(= (omegaClawCandidateAwaitingHuman $status)
    (== $status awaiting-human))

(= (omegaClawCandidateTaskMayExecute $status)
    (case $status (
        (active True)
        (open True)
        ($_ False)
    )))

(= (omegaClawCandidateGateField $state $perception $field)
    (let* (
        ($signals (omegaClawPerceptionField $perception signals))
        ($observation
            (omegaClawPerceptionField $perception observation))
        ($features (omegaClawStimulusFeatures $perception))
        ($risk (featureMapNumericUnit $features risk 0.0))
        ($uncertainty
            (featureMapNumericUnit $features uncertainty 0.0))
        ($newMessage
            (omegaClawObservationField $observation new-message))
        ($observedTaskStatus
            (omegaClawObservationField $observation task-status))
        ($taskStatus
            (if $newMessage active $observedTaskStatus))
        ($taskActive (omegaClawCandidateTaskActive $taskStatus))
        ($awaitingHuman
            (omegaClawCandidateAwaitingHuman $taskStatus))
        ($autonomyPhase
            (omegaClawObservationField $observation autonomy-phase))
        ($wakeReason
            (omegaClawObservationField $observation wake-reason))
        ($previousAction
            (omegaClawObservationField $observation previous-action))
        ($orientationComplete
            (and
                (== $previousAction recall-goals)
                (omegaClawSignalsContainKind $signals result-empty)))
        ($replanReady
            (and
                (== $autonomyPhase plan)
                (and
                    (== $previousAction assess-progress)
                    (omegaClawSignalsContainKind
                        $signals active-goal))))
        ($autonomousGoalActive
            (omegaClawSignalsContainKind
                $signals active-goal))
        ($emptyObjectiveResult
            (and
                (omegaClawSignalsContainKind $signals result-empty)
                (or $taskActive $autonomousGoalActive)))
        ($failurePresent
            (or
                $emptyObjectiveResult
                (or
                    (omegaClawSignalsContainKind $signals failure)
                    (or
                        (omegaClawSignalsContainKind
                            $signals repeated-failure)
                        (or
                            (omegaClawSignalsContainKind
                                $signals proposal-empty)
                            (or
                                (omegaClawSignalsContainKind
                                    $signals proposal-invalid)
                                (or
                                    (omegaClawSignalsContainKind
                                        $signals proposal-repeated)
                                    (or
                                        (omegaClawSignalsContainKind
                                            $signals execution-failure)
                                        (omegaClawSignalsContainKind
                                            $signals verification-failed)))))))))
        ($goalControlRequested
            (>= (omegaClawSignalStrengthByKind
                    $signals goal-control-request)
                (omegaClawSemanticSignalThresholdFor
                    goal-control-request)))
        ($semanticUnavailable
            (omegaClawSignalsContainKind
                $signals semantic-unavailable))
        ($persistedExecutionRequested
            (and
                (omegaClawCandidateTaskMayExecute $taskStatus)
                (omegaClawSignalsContainKind
                    $signals task-execution-authorized)))
        ($executionRequested
            (or
                (and
                    (not $goalControlRequested)
                    (>= (omegaClawSignalStrengthByKind
                            $signals execution-request)
                        (omegaClawSemanticSignalThresholdFor
                            execution-request)))
                $persistedExecutionRequested))
        ($communicationFailure
            (and
                $taskActive
                (and
                    $failurePresent
                    (or
                        (== $previousAction respond)
                        (== $previousAction ask-clarification)))))
        ($knowledgeNeeded
            (or
                (omegaClawSignalsContainKind $signals ambiguity)
                (or
                    (omegaClawSignalsContainKind $signals task-drift)
                    (or
                        (omegaClawSignalsContainKind
                            $signals evidence-insufficient)
                        (> $uncertainty
                           (omegaClawExecutionUncertaintyLimit))))))
        ($verificationNeeded
            (or
                (omegaClawSignalsContainKind
                    $signals verification-needed)
                (or
                    (== $taskStatus verifying)
                    (or
                        (== $taskStatus ready)
                        (or
                            (== $autonomyPhase assess)
                            (== $autonomyPhase verify))))))
        ($verifiedEvidence
            (or
                (omegaClawSignalsContainKind
                    $signals verified-success)
                (or
                    (omegaClawSignalsContainKind
                        $signals verification-passed)
                    (or
                        (omegaClawSignalsContainKind
                            $signals evidence-sufficient)
                        (or
                            (omegaClawSignalsContainKind
                                $signals goal-complete)
                            (== $taskStatus verified))))))
        ($responseReady
            (or
                $communicationFailure
                (or
                    (and
                        $taskActive
                        (or
                            (== $taskStatus blocked)
                            $verifiedEvidence))
                    (and
                        $newMessage
                        (not $executionRequested)))))
        ($safetyRequired
            (or
                (omegaClawSignalsContainKind $signals danger)
                (or
                    (>= $risk (omegaClawExecutionRiskLimit))
                    (>= (stateAntiGoal $state unsafe)
                        (omegaClawExecutionRiskLimit)))))
        ($executionAllowed
            (and
                $executionRequested
                (and
                    (not $safetyRequired)
                    (<= $uncertainty
                        (omegaClawExecutionUncertaintyLimit)))))
        ($autonomyActive
            (not (== $autonomyPhase idle)))
        ($humanWaiting
            (and
                (not $awaitingHuman)
                (or
                    $newMessage
                    (or
                        $taskActive
                        (omegaClawSignalsContainKind
                            $signals user-waiting)))))
    )
        (case $field (
            (signals $signals)
            (features $features)
            (risk $risk)
            (uncertainty $uncertainty)
            (task-status $taskStatus)
            (task-active $taskActive)
            (awaiting-human $awaitingHuman)
            (new-message $newMessage)
            (human-waiting $humanWaiting)
            (autonomy-phase $autonomyPhase)
            (autonomy-active $autonomyActive)
            (wake-reason $wakeReason)
            (previous-action $previousAction)
            (orientation-complete $orientationComplete)
            (replan-ready $replanReady)
            (failure-present $failurePresent)
            (communication-failure $communicationFailure)
            (goal-control-requested $goalControlRequested)
            (semantic-unavailable $semanticUnavailable)
            (autonomous-goal-active $autonomousGoalActive)
            (execution-requested $executionRequested)
            (persisted-execution-requested
                $persistedExecutionRequested)
            (execution-allowed $executionAllowed)
            (knowledge-needed $knowledgeNeeded)
            (verification-needed $verificationNeeded)
            (verified-evidence $verifiedEvidence)
            (response-ready $responseReady)
            (safety-required $safetyRequired)
            ($_ (empty))
        ))))

(= (omegaClawBoolContribution $condition $value)
    (if $condition $value 0.0))

(= (omegaClawCandidateContextAdjustment
        $candidateId $goalName $state $perception)
    (let* (
        ($humanWaiting
            (omegaClawCandidateGateField
                $state $perception human-waiting))
        ($taskActive
            (omegaClawCandidateGateField
                $state $perception task-active))
        ($executionRequested
            (omegaClawCandidateGateField
                $state $perception execution-requested))
        ($orientationComplete
            (omegaClawCandidateGateField
                $state $perception orientation-complete))
        ($replanReady
            (omegaClawCandidateGateField
                $state $perception replan-ready))
        ($knowledgeNeeded
            (omegaClawCandidateGateField
                $state $perception knowledge-needed))
        ($verificationNeeded
            (omegaClawCandidateGateField
                $state $perception verification-needed))
        ($verifiedEvidence
            (omegaClawCandidateGateField
                $state $perception verified-evidence))
        ($failurePresent
            (omegaClawCandidateGateField
                $state $perception failure-present))
        ($communicationFailure
            (omegaClawCandidateGateField
                $state $perception communication-failure))
        ($safetyRequired
            (omegaClawCandidateGateField
                $state $perception safety-required))
        ($risk
            (omegaClawCandidateGateField
                $state $perception risk))
        ($uncertainty
            (omegaClawCandidateGateField
                $state $perception uncertainty))
    )
        (case $candidateId (
            (respond
                (case $goalName (
                    (help_user
                        (+ (omegaClawBoolContribution
                                $humanWaiting 0.12)
                           (+ (omegaClawBoolContribution
                                    $executionRequested -0.24)
                              (omegaClawBoolContribution
                                  $communicationFailure 0.20))))
                    (responsiveness
                        (+ (omegaClawBoolContribution
                                $humanWaiting 0.15)
                           (+ (omegaClawBoolContribution
                                    $executionRequested -0.20)
                              (omegaClawBoolContribution
                                  $communicationFailure 0.25))))
                    (reliability
                        (+ (omegaClawBoolContribution
                                $verifiedEvidence 0.18)
                           (omegaClawBoolContribution
                                $communicationFailure 0.40)))
                    (clarity
                        (omegaClawBoolContribution
                            $communicationFailure 0.35))
                    (coherence
                        (omegaClawBoolContribution
                            $communicationFailure 0.30))
                    (adaptivity
                        (omegaClawBoolContribution
                            $communicationFailure 0.25))
                    (risk
                        (omegaClawBoolContribution
                            $safetyRequired 0.10))
                    ($_ 0.0)
                )))
            (clarify
                (case $goalName (
                    (clarity
                        (+ (* 0.30 $uncertainty)
                           (omegaClawBoolContribution
                               $knowledgeNeeded 0.18)))
                    (cooperate
                        (omegaClawBoolContribution
                            $humanWaiting 0.12))
                    (reliability
                        (omegaClawBoolContribution
                            $safetyRequired 0.20))
                    ($_ 0.0)
                )))
            (orient
                (case $goalName (
                    (learn
                        (+ (omegaClawBoolContribution
                                $knowledgeNeeded 0.18)
                           (+ (omegaClawBoolContribution
                                   $verifiedEvidence -0.34)
                              (+ (omegaClawBoolContribution
                                      $orientationComplete -0.18)
                                 (omegaClawBoolContribution
                                      $replanReady -0.12)))))
                    (coherence
                        (+ (omegaClawBoolContribution
                                $taskActive 0.10)
                           (omegaClawBoolContribution
                                $verifiedEvidence -0.28)))
                    (clarity
                        (+ (* 0.28 $uncertainty)
                           (omegaClawBoolContribution
                                $verifiedEvidence -0.30)))
                    (reliability
                        (omegaClawBoolContribution
                            $verifiedEvidence -0.18))
                    (progress
                        (+ (omegaClawBoolContribution
                                $verifiedEvidence -0.24)
                           (+ (omegaClawBoolContribution
                                   $orientationComplete -0.18)
                              (omegaClawBoolContribution
                                   $replanReady -0.14))))
                    (responsiveness
                        (omegaClawBoolContribution
                            $humanWaiting -0.18))
                    ($_ 0.0)
                )))
            (advance
                (case $goalName (
                    (help_user
                        (+ (omegaClawBoolContribution
                                $executionRequested 0.18)
                           (omegaClawBoolContribution
                                $orientationComplete 0.08)))
                    (progress
                        (+ (omegaClawBoolContribution
                                (or $executionRequested $taskActive) 0.20)
                           (+ (omegaClawBoolContribution
                                   $orientationComplete 0.24)
                              (omegaClawBoolContribution
                                   $replanReady 0.22))))
                    (adaptivity
                        (+ (omegaClawBoolContribution
                                $orientationComplete 0.12)
                           (omegaClawBoolContribution
                                $replanReady 0.10)))
                    (risk (+ (* 0.55 $risk)
                             (omegaClawBoolContribution
                                 $safetyRequired 0.40)))
                    (unsafe
                        (omegaClawBoolContribution
                            $safetyRequired 0.55))
                    (contradiction
                        (omegaClawBoolContribution
                            $knowledgeNeeded 0.12))
                    ($_ 0.0)
                )))
            (verify
                (case $goalName (
                    (reliability
                        (omegaClawBoolContribution
                            $verificationNeeded 0.22))
                    (coherence
                        (omegaClawBoolContribution
                            $verificationNeeded 0.14))
                    (clarity
                        (omegaClawBoolContribution
                            $verificationNeeded 0.10))
                    ($_ 0.0)
                )))
            (learn
                (case $goalName (
                    (learn
                        (omegaClawBoolContribution
                            $verifiedEvidence 0.22))
                    (adaptivity
                        (omegaClawBoolContribution
                            $verifiedEvidence 0.12))
                    (coherence
                        (omegaClawBoolContribution
                            $verifiedEvidence 0.20))
                    (reliability
                        (omegaClawBoolContribution
                            $verifiedEvidence 0.18))
                    ($_ 0.0)
                )))
            (repair
                (case $goalName (
                    (adaptivity
                        (omegaClawBoolContribution
                            $failurePresent 0.08))
                    (reliability
                        (omegaClawBoolContribution
                            $failurePresent 0.12))
                    (progress
                        (omegaClawBoolContribution
                            $failurePresent 0.10))
                    ($_ 0.0)
                )))
            (defer
                (case $goalName (
                    (reliability
                        (omegaClawBoolContribution
                            $safetyRequired 0.25))
                    (coherence
                        (omegaClawBoolContribution
                            $safetyRequired 0.18))
                    (responsiveness
                        (omegaClawBoolContribution
                            $humanWaiting -0.12))
                    ($_ 0.0)
                )))
            (idle
                (case $goalName (
                    (responsiveness
                        (omegaClawBoolContribution
                            $humanWaiting -0.70))
                    (progress
                        (omegaClawBoolContribution
                            $taskActive -0.45))
                    ($_ 0.0)
                )))
            ($_ 0.0)
        ))))

(= (omegaClawContextualCorrelationVector
        () $candidateId $state $perception $basePairs)
    ())

(= (omegaClawContextualCorrelationVector
        $goalNames $candidateId $state $perception $basePairs)
    (let* (
        (($head $tail) (decons $goalNames))
        ($base (featurePairsGet $basePairs $head 0.0))
        ($adjustment
            (omegaClawCandidateContextAdjustment
                $candidateId $head $state $perception))
    )
        (cons-atom
            (clipRange (+ $base $adjustment) -1.0 1.0)
            (omegaClawContextualCorrelationVector
                $tail $candidateId $state $perception $basePairs))))

(= (omegaClawCandidateCorrelationsFor
        $state $perception $candidateId)
    (case (omegaClawCandidateBaseCorrelationPairs $candidateId) (
        ((validationError $code $details)
            (validationError $code $details))
        ($pairs
            (omegaClawContextualCorrelationVector
                (omegaClawGoalNames)
                $candidateId $state $perception $pairs))
    )))

;; Runtime selection always uses contextual correlations.
(= (omegaClawCandidateCorrelations $candidateId)
    (omegaClawCandidateBaseCorrelations $candidateId))

(= (omegaClawCandidateRealizationId
        $state $perception $candidateId)
    (let* (
        ($phase
            (omegaClawCandidateGateField
                $state $perception autonomy-phase))
        ($taskActive
            (omegaClawCandidateGateField
                $state $perception task-active))
        ($taskStatus
            (omegaClawCandidateGateField
                $state $perception task-status))
        ($autonomousGoalActive
            (omegaClawCandidateGateField
                $state $perception autonomous-goal-active))
    )
        (case $candidateId (
            (respond respond)
            (clarify ask-clarification)
            (orient
                (case $phase (
                    (recall recall-goals)
                    ($_ retrieve-memory)
                )))
            (advance
                (if $taskActive
                    execute-skill
                    (case $phase (
                        (invent invent-goal)
                        (plan plan-goal)
                        (act background-work)
                        ($_ execute-skill)
                    ))))
            (verify
                (if $taskActive
                    verify-goal
                    (case $phase (
                        (assess assess-progress)
                        ($_ verify-goal)
                    ))))
            (learn learn)
            (repair
                (if $taskActive
                    (case $taskStatus (
                        (ready verify-goal)
                        (verifying verify-goal)
                        (verified respond)
                        (blocked respond)
                        ($_ repair-failure)
                    ))
                    (if $autonomousGoalActive
                        repair-autonomy
                        self-improve)))
            (defer defer)
            (idle idle)
            ($_ unknown)
        ))))

(= (omegaClawCandidateCapabilityEnvelope
        $state $perception $candidateId)
    (case (omegaClawCandidateRealizationId
            $state $perception $candidateId) (
        (respond send-only)
        (ask-clarification send-only)
        (recall-goals memory-read)
        (retrieve-memory external-read)
        (execute-skill requested-effect)
        (invent-goal goal-definition)
        (plan-goal working-memory-write)
        (background-work autonomy-work)
        (assess-progress goal-assessment)
        (verify-goal verification)
        (learn memory-write)
        (repair-failure requested-effect)
        (repair-autonomy autonomy-work)
        (self-improve memory-update)
        (defer no-effect)
        (idle no-effect)
        ($_ no-effect)
    )))

(= (omegaClawCandidateBaseMetadata $candidateId)
    (case $candidateId (
        (respond
            ((cognitive-mode communicate)
             (prompt-guidance communicate-best-supported-result)
             (intrinsic-risk 0.06) (expected-cost 0.10)
             (host-mapping send-response)))
        (clarify
            ((cognitive-mode clarify)
             (prompt-guidance obtain-decision-relevant-input)
             (intrinsic-risk 0.01) (expected-cost 0.06)
             (host-mapping send-question)))
        (orient
            ((cognitive-mode orient)
             (prompt-guidance improve-task-or-environment-model)
             (intrinsic-risk 0.04) (expected-cost 0.18)
             (host-mapping evidence-acquisition)))
        (advance
            ((cognitive-mode execute)
             (prompt-guidance advance-one-bounded-objective-step)
             (intrinsic-risk 0.18) (expected-cost 0.30)
             (host-mapping bounded-skill)))
        (verify
            ((cognitive-mode verify)
             (prompt-guidance test-result-or-evaluate-existing-evidence)
             (intrinsic-risk 0.02) (expected-cost 0.14)
             (host-mapping verify-result)))
        (learn
            ((cognitive-mode learn)
             (prompt-guidance consolidate-one-verified-lesson)
             (intrinsic-risk 0.05) (expected-cost 0.12)
             (host-mapping memory-store)))
        (repair
            ((cognitive-mode recover)
             (prompt-guidance make-smallest-justified-correction)
             (intrinsic-risk 0.06) (expected-cost 0.18)
             (host-mapping repair-step)))
        (defer
            ((cognitive-mode defer)
             (prompt-guidance wait-for-blocking-condition-to-change)
             (intrinsic-risk 0.00) (expected-cost 0.00)
             (host-mapping no-effect)))
        (idle
            ((cognitive-mode defer)
             (prompt-guidance yield-until-input-or-wake)
             (intrinsic-risk 0.00) (expected-cost 0.00)
             (host-mapping idle)))
        ($_ (validationError unknown-omegaclaw-candidate $candidateId))
    )))

(= (omegaClawCandidateMetadata $candidateId)
    (case (omegaClawCandidateBaseMetadata $candidateId) (
        ((validationError $code $details)
            (validationError $code $details))
        ($metadata
            (listAppend
                $metadata
                ((capability-envelope no-effect)
                 (realization-id $candidateId))))
    )))

(= (omegaClawCandidateMetadataFor
        $state $perception $candidateId)
    (case (omegaClawCandidateBaseMetadata $candidateId) (
        ((validationError $code $details)
            (validationError $code $details))
        ($metadata
            (listAppend
                $metadata
                ((capability-envelope
                    (omegaClawCandidateCapabilityEnvelope
                        $state $perception $candidateId))
                 (realization-id
                    (omegaClawCandidateRealizationId
                        $state $perception $candidateId)))))
    )))

(= (omegaClawCandidate $candidateId)
    (if (listContains (omegaClawCandidateIds) $candidateId)
        (actionCandidate
            $candidateId
            (omegaClawSchema)
            (omegaClawCandidateCorrelations $candidateId)
            (omegaClawZeroGoalVector)
            (omegaClawCandidateMetadata $candidateId))
        (validationError unknown-omegaclaw-candidate $candidateId)))

(= (omegaClawCandidateFor $state $perception $candidateId)
    (if (listContains (omegaClawCandidateIds) $candidateId)
        (actionCandidate
            $candidateId
            (omegaClawSchema)
            (omegaClawCandidateCorrelationsFor
                $state $perception $candidateId)
            (omegaClawZeroGoalVector)
            (omegaClawCandidateMetadataFor
                $state $perception $candidateId))
        (validationError unknown-omegaclaw-candidate $candidateId)))

(= (omegaClawCandidatePolicyField $candidate $field)
    (featurePairsGet (candidateMetadata $candidate) $field none))

(= (omegaClawRepresentativeCandidates)
    ((omegaClawCandidate respond)
     (omegaClawCandidate clarify)
     (omegaClawCandidate orient)
     (omegaClawCandidate advance)
     (omegaClawCandidate verify)
     (omegaClawCandidate learn)
     (omegaClawCandidate repair)
     (omegaClawCandidate defer)
     (omegaClawCandidate idle)))

(= (omegaClawAutonomyCanAdvance $phase)
    (case $phase (
        (invent True)
        (plan True)
        (act True)
        ($_ False)
    )))

(= (omegaClawCandidateEligible
        $state $perception $candidateId)
    (let* (
        ($taskStatus
            (omegaClawCandidateGateField
                $state $perception task-status))
        ($taskActive
            (omegaClawCandidateGateField
                $state $perception task-active))
        ($newMessage
            (omegaClawCandidateGateField
                $state $perception new-message))
        ($humanWaiting
            (omegaClawCandidateGateField
                $state $perception human-waiting))
        ($awaitingHuman
            (omegaClawCandidateGateField
                $state $perception awaiting-human))
        ($autonomyPhase
            (omegaClawCandidateGateField
                $state $perception autonomy-phase))
        ($wakeReason
            (omegaClawCandidateGateField
                $state $perception wake-reason))
        ($executionAllowed
            (omegaClawCandidateGateField
                $state $perception execution-allowed))
        ($knowledgeNeeded
            (omegaClawCandidateGateField
                $state $perception knowledge-needed))
        ($verificationNeeded
            (omegaClawCandidateGateField
                $state $perception verification-needed))
        ($verifiedEvidence
            (omegaClawCandidateGateField
                $state $perception verified-evidence))
        ($failurePresent
            (omegaClawCandidateGateField
                $state $perception failure-present))
        ($communicationFailure
            (omegaClawCandidateGateField
                $state $perception communication-failure))
        ($responseReady
            (omegaClawCandidateGateField
                $state $perception response-ready))
        ($safetyRequired
            (omegaClawCandidateGateField
                $state $perception safety-required))
        ($idleWake
            (and
                (== $autonomyPhase idle)
                (not (== $wakeReason scheduled-wake))))
    )
        (case $candidateId (
            (respond
                $responseReady)
            (clarify
                (and (or $newMessage $communicationFailure)
                    (or
                        $knowledgeNeeded
                        (or $safetyRequired
                            (and
                                (omegaClawCandidateGateField
                                    $state $perception
                                    execution-requested)
                                (not $executionAllowed))))))
            (orient
                (and
                    (not $awaitingHuman)
                    (or
                        $newMessage
                        (or $taskActive
                            (not $idleWake)))))
            (advance
                (and
                    (not $safetyRequired)
                    (or
                        $executionAllowed
                        (and
                            (not $taskActive)
                            (omegaClawAutonomyCanAdvance
                                $autonomyPhase)))))
            (verify $verificationNeeded)
            (learn
                (and
                    $verifiedEvidence
                    (or
                        (== $autonomyPhase integrate)
                        (== $taskStatus verified))))
            (repair $failurePresent)
            (defer
                (or
                    $safetyRequired
                    (or
                        $failurePresent
                        (or $knowledgeNeeded
                            (or $taskActive
                                (not $idleWake))))))
            (idle
                (and
                    (not $humanWaiting)
                    (not $taskActive)))
            ($_ False)
        ))))

(= (omegaClawCandidateExclusionReason
        $state $perception $candidateId)
    (let* (
        ($safetyRequired
            (omegaClawCandidateGateField
                $state $perception safety-required))
        ($failurePresent
            (omegaClawCandidateGateField
                $state $perception failure-present))
        ($verificationNeeded
            (omegaClawCandidateGateField
                $state $perception verification-needed))
        ($verifiedEvidence
            (omegaClawCandidateGateField
                $state $perception verified-evidence))
        ($humanWaiting
            (omegaClawCandidateGateField
                $state $perception human-waiting))
        ($awaitingHuman
            (omegaClawCandidateGateField
                $state $perception awaiting-human))
    )
        (case $candidateId (
            (respond
                (if $awaitingHuman
                    awaiting-human-input
                    no-response-recipient-or-result))
            (clarify no-decision-relevant-question)
            (orient
                (if $awaitingHuman
                    awaiting-human-input
                    no-orientation-context))
            (advance
                (if $safetyRequired
                    unsafe-effect
                    no-authorized-objective-step))
            (verify
                (if $verificationNeeded
                    verification-capability-unavailable
                    no-verification-context))
            (learn
                (if $verifiedEvidence
                    learning-capability-unavailable
                    no-verified-learning))
            (repair
                (if $failurePresent
                    repair-capability-unavailable
                    no-failure-to-repair))
            (defer no-blocking-condition)
            (idle
                (if $humanWaiting
                    human-waiting
                    active-work-not-yieldable))
            ($_ unknown-candidate)
        ))))

(= (omegaClawEligibleCandidateIdsFrom
        () $state $perception)
    ())

(= (omegaClawEligibleCandidateIdsFrom
        $candidateIds $state $perception)
    (let* (
        (($head $tail) (decons $candidateIds))
        ($remaining
            (omegaClawEligibleCandidateIdsFrom
                $tail $state $perception))
    )
        (if (omegaClawCandidateEligible
                $state $perception $head)
            (cons-atom $head $remaining)
            $remaining)))

(= (omegaClawExcludedCandidatesFrom
        () $state $perception)
    ())

(= (omegaClawExcludedCandidatesFrom
        $candidateIds $state $perception)
    (let* (
        (($head $tail) (decons $candidateIds))
        ($remaining
            (omegaClawExcludedCandidatesFrom
                $tail $state $perception))
    )
        (if (omegaClawCandidateEligible
                $state $perception $head)
            $remaining
            (cons-atom
                (omegaClawCandidateExclusionRecord
                    $head
                    (omegaClawCandidateExclusionReason
                        $state $perception $head))
                $remaining))))

(= (omegaClawAvailableCandidateIds $state $perception)
    (omegaClawEligibleCandidateIdsFrom
        (omegaClawCandidateIds) $state $perception))

(= (omegaClawExcludedCandidates $state $perception)
    (omegaClawExcludedCandidatesFrom
        (omegaClawCandidateIds) $state $perception))

(= (omegaClawCandidatesFromIds
        () $state $perception)
    ())

(= (omegaClawCandidatesFromIds
        $candidateIds $state $perception)
    (let* (
        (($head $tail) (decons $candidateIds))
    )
        (cons-atom
            (omegaClawCandidateFor $state $perception $head)
            (omegaClawCandidatesFromIds
                $tail $state $perception))))

;; Availability encodes legality; MAGUS owns preference and selection.
(= (omegaClawCandidateBuilderFn $state $perception)
    (omegaClawCandidatesFromIds
        (omegaClawAvailableCandidateIds $state $perception)
        $state
        $perception))


;; Record enough evidence to verify the exact winning score.
(= (omegaClawCandidateScoreTrace
        $candidateId $realizationId $correlations $score)
    (omegaClawCandidateScoreTraceRecord
        $candidateId $realizationId $correlations $score))

(= (omegaClawCandidateScoreTraceField $trace $field)
    (let (omegaClawCandidateScoreTraceRecord
            $candidateId $realizationId $correlations $score)
        $trace
        (case $field (
            (candidate-id $candidateId)
            (realization-id $realizationId)
            (correlations $correlations)
            (score $score)
            ($_ (empty))
        ))))

(= (omegaClawCandidateScoreTraces
        $profile $decisionState ())
    ())

(= (omegaClawCandidateScoreTraces
        $profile $decisionState $candidates)
    (let* (
        (($head $tail) (decons $candidates))
        ($trace
            (omegaClawCandidateScoreTrace
                (candidateId $head)
                (omegaClawCandidatePolicyField
                    $head realization-id)
                (candidateGoalCorrelations $head)
                (decisionProfileScoreCandidate
                    $profile $decisionState $head 0.5 0.5)))
    )
        (cons-atom
            $trace
            (omegaClawCandidateScoreTraces
                $profile $decisionState $tail))))

(= (omegaClawBestCandidateScoreTrace $traces)
    (case $traces (
        (() none)
        ($_
            (let* (
                (($first $rest) (decons $traces))
            )
                (omegaClawBestCandidateScoreTraceLoop
                    $first $rest)))
    )))

(= (omegaClawBestCandidateScoreTraceLoop
        $currentBest ())
    $currentBest)

(= (omegaClawBestCandidateScoreTraceLoop
        $currentBest $remaining)
    (let* (
        (($head $tail) (decons $remaining))
        ($bestScore
            (omegaClawCandidateScoreTraceField
                $currentBest score))
        ($headScore
            (omegaClawCandidateScoreTraceField
                $head score))
    )
        (if (> $headScore $bestScore)
            (omegaClawBestCandidateScoreTraceLoop
                $head $tail)
            (omegaClawBestCandidateScoreTraceLoop
                $currentBest $tail))))

(= (omegaClawCandidateScoreTracesWithout
        () $candidateId)
    ())

(= (omegaClawCandidateScoreTracesWithout
        $traces $candidateId)
    (let* (
        (($head $tail) (decons $traces))
        ($remaining
            (omegaClawCandidateScoreTracesWithout
                $tail $candidateId))
    )
        (if (== (omegaClawCandidateScoreTraceField
                    $head candidate-id)
                $candidateId)
            $remaining
            (cons-atom $head $remaining))))

(= (omegaClawSubstantiveCandidateCount ())
    0)

(= (omegaClawSubstantiveCandidateCount $candidateIds)
    (let* (
        (($head $tail) (decons $candidateIds))
        ($increment
            (case $head (
                (defer 0)
                (idle 0)
                ($_ 1)
            )))
    )
        (+ $increment
           (omegaClawSubstantiveCandidateCount $tail))))

(= (omegaClawDecisionEvidence
        $eligibleIds $excluded $scoreTraces
        $winnerId $runnerUpId $winnerScore $margin
        $forced $exactArgmax)
    (omegaClawDecisionEvidenceRecord
        $eligibleIds $excluded $scoreTraces
        $winnerId $runnerUpId $winnerScore $margin
        $forced $exactArgmax))

(= (omegaClawDecisionEvidenceField $evidence $field)
    (let (omegaClawDecisionEvidenceRecord
            $eligibleIds $excluded $scoreTraces
            $winnerId $runnerUpId $winnerScore $margin
            $forced $exactArgmax)
        $evidence
        (case $field (
            (eligible-ids $eligibleIds)
            (excluded $excluded)
            (score-traces $scoreTraces)
            (winner-id $winnerId)
            (runner-up-id $runnerUpId)
            (winner-score $winnerScore)
            (margin $margin)
            (forced $forced)
            (exact-argmax $exactArgmax)
            ($_ (empty))
        ))))

(= (omegaClawDecisionEvidenceFromBest
        $state $perception $eligibleIds
        $scoreTraces $winnerId $best)
    (let* (
        ($bestId
            (omegaClawCandidateScoreTraceField
                $best candidate-id))
        ($runnerUp
            (omegaClawBestCandidateScoreTrace
                (omegaClawCandidateScoreTracesWithout
                    $scoreTraces $bestId)))
    )
        (omegaClawDecisionEvidenceFromRunnerUpCase
            $state
            $perception
            $eligibleIds
            $scoreTraces
            $winnerId
            $best
            $runnerUp)))

(= (omegaClawDecisionEvidenceFromRunnerUpCase
        $state $perception $eligibleIds
        $scoreTraces $winnerId $best $runnerUp)
    (case $runnerUp (
        (none
            (omegaClawDecisionEvidenceWithoutRunnerUp
                $state $perception $eligibleIds
                $scoreTraces $winnerId $best))
        ($_
            (omegaClawDecisionEvidenceWithRunnerUp
                $state $perception $eligibleIds
                $scoreTraces $winnerId $best $runnerUp))
    )))

(= (omegaClawDecisionEvidenceWithoutRunnerUp
        $state $perception $eligibleIds
        $scoreTraces $winnerId $best)
    (let* (
        ($bestId
            (omegaClawCandidateScoreTraceField
                $best candidate-id))
        ($winnerScore
            (omegaClawCandidateScoreTraceField
                $best score))
    )
        (omegaClawDecisionEvidence
            $eligibleIds
            (omegaClawExcludedCandidates
                $state $perception)
            $scoreTraces
            $winnerId
            none
            $winnerScore
            0.0
            (<=
                (omegaClawSubstantiveCandidateCount
                    $eligibleIds)
                1)
            (== $winnerId $bestId))))

(= (omegaClawDecisionEvidenceWithRunnerUp
        $state $perception $eligibleIds
        $scoreTraces $winnerId $best $runnerUp)
    (let* (
        ($bestId
            (omegaClawCandidateScoreTraceField
                $best candidate-id))
        ($winnerScore
            (omegaClawCandidateScoreTraceField
                $best score))
        ($runnerUpId
            (omegaClawCandidateScoreTraceField
                $runnerUp candidate-id))
        ($runnerUpScore
            (omegaClawCandidateScoreTraceField
                $runnerUp score))
    )
        (omegaClawDecisionEvidence
            $eligibleIds
            (omegaClawExcludedCandidates
                $state $perception)
            $scoreTraces
            $winnerId
            $runnerUpId
            $winnerScore
            (- $winnerScore $runnerUpScore)
            (<=
                (omegaClawSubstantiveCandidateCount
                    $eligibleIds)
                1)
            (== $winnerId $bestId))))
