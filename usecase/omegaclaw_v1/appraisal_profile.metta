
(= (omegaClawWeightedFeatureSum $features $weights)
    (if (== $weights ())
        0.0
        (let* (
            (($head $tail) (decons $weights))
            (($feature $weight) $head)
        )
            (+ (* $weight
                  (featureMapNumericUnit $features $feature 0.0))
               (omegaClawWeightedFeatureSum $features $tail)))))

;; Scale long-lived drives toward stable bounds instead of clipping.
(= (omegaClawDriveDelta $state $name $rawDelta)
    (let $current (stateModulator $state $name)
        (if (>= $rawDelta 0.0)
            (* $rawDelta (- 1.0 $current))
            (* $rawDelta $current))))

(= (omegaClawCoreDeltas $state $features)
    (
        (valence
            (omegaClawWeightedFeatureSum
                $features ((opportunity 0.30) (progress 0.35))))
        (arousal
            (omegaClawWeightedFeatureSum
                $features ((novelty 0.30) (risk -0.20)
                           (uncertainty -0.10) (opportunity 0.25))))
        (approach
            (omegaClawWeightedFeatureSum
                $features ((novelty 0.20) (opportunity 0.15))))
        (resolution
            (omegaClawWeightedFeatureSum
                $features ((uncertainty -0.10) (progress 0.10))))
        (threshold
            (omegaClawWeightedFeatureSum
                $features ((risk 0.35) (uncertainty 0.25))))
        (securing
            (omegaClawWeightedFeatureSum
                $features ((risk 0.40) (uncertainty 0.20))))
    ))

(= (omegaClawApplicationDeltas $state $features)
    (
        (urgency
            (omegaClawWeightedFeatureSum
                $features ((importance 0.25) (human_presence 0.35)
                           (progress -0.05))))
        (persistence
            (omegaClawDriveDelta
                $state persistence
                (omegaClawWeightedFeatureSum
                    $features ((progress 0.20) (task_focus 0.25)
                               (autonomy_drive 0.15)
                               (failure_load -0.30)))))
        (context_depth
            (omegaClawWeightedFeatureSum
                $features ((uncertainty 0.25) (ambiguity_load 0.45)
                           (failure_load 0.10)
                           (evidence_strength -0.30))))
        (human_deference
            (omegaClawWeightedFeatureSum
                $features ((human_presence 0.55)
                           (goal_control 0.25))))
        (focus
            (omegaClawDriveDelta
                $state focus
                (omegaClawWeightedFeatureSum
                    $features ((task_focus 0.40) (importance 0.15)
                               (goal_control 0.10) (novelty -0.10)
                               (failure_load -0.20)))))
    ))

(= (omegaClawOutcomeSuccessRatio $outcome)
    (/ (omegaClawOutcomeField $outcome success-count)
       (maxNumber
           1.0
           (+ (omegaClawOutcomeField $outcome success-count)
              (omegaClawOutcomeField $outcome failure-count)))))

(= (omegaClawOutcomeFailureRatio $outcome)
    (/ (omegaClawOutcomeField $outcome failure-count)
       (maxNumber
           1.0
           (size-atom
               (omegaClawOutcomeField $outcome commands-executed)))))

(= (omegaClawOutcomeBlockedRatio $outcome)
    (/ (omegaClawOutcomeField $outcome blocked-count)
       (maxNumber
           1.0
           (size-atom
               (omegaClawOutcomeField $outcome commands-proposed)))))

(= (omegaClawOutcomeRiskTarget $outcome)
    (clipUnit
        (maxNumber
            (omegaClawOutcomeField $outcome safety-events)
            (maxNumber
                (omegaClawOutcomeField
                    $outcome contradiction-evidence)
                (+ (* 0.65 (omegaClawOutcomeFailureRatio $outcome))
                   (* 0.35 (omegaClawOutcomeBlockedRatio $outcome)))))))

(= (omegaClawOutcomeHasRiskEvidence $outcome)
    (or
        (> (omegaClawOutcomeFailureRatio $outcome) 0.0)
        (or
            (> (omegaClawOutcomeBlockedRatio $outcome) 0.0)
            (or
                (> (omegaClawOutcomeField
                        $outcome safety-events) 0.0)
                (> (omegaClawOutcomeField
                        $outcome contradiction-evidence) 0.0)))))

(= (omegaClawOutcomeQuality $outcome)
    (if (not (omegaClawOutcomeField $outcome evidence-relevant))
        0.0
        (case (omegaClawOutcomeField $outcome failure-reason) (
            (safety-event -1.0)
            (contradiction -0.95)
            (dispatch-failed -0.90)
            (delivery-failed -0.90)
            (verification-failed -0.80)
            (proposal-invalid -0.70)
            (dispatch-partial-failure -0.65)
            (proposal-empty -0.60)
            (delivery-suppressed -0.55)
            (result-empty -0.50)
            ($_ (case (omegaClawOutcomeField
                            $outcome verification-status) (
                (passed 1.0)
                ($_ (case (omegaClawOutcomeField
                                $outcome delivery-status) (
                    (sent 0.90)
                    ($_ (case (omegaClawOutcomeField
                                    $outcome result-utility) (
                        (useful 0.80)
                        ($_ 0.25)
                    )))
                )))
            )))
        ))))

(= (omegaClawOutcomeAchievementTarget $quality)
    (clipUnit (/ (+ $quality 1.0) 2.0)))

(= (omegaClawAdministrativeRealization $realizationId)
    (case $realizationId (
        (invent-goal True)
        (plan-goal True)
        (assess-progress True)
        ($_ False)
    )))

(= (omegaClawOutcomeAdministrativeSuccess $outcome)
    (and
        (omegaClawAdministrativeRealization
            (omegaClawOutcomeField $outcome realization-id))
        (and
            (> (omegaClawOutcomeField $outcome success-count) 0)
            (== (omegaClawOutcomeField $outcome failure-reason) none))))

(= (omegaClawOutcomeLearningSuccess $outcome)
    (and
        (== (omegaClawOutcomeField $outcome realization-id) learn)
        (and
            (== (omegaClawOutcomeField $outcome result-utility) useful)
            (== (omegaClawOutcomeField $outcome failure-reason) none))))

(= (omegaClawOutcomeGoalRelevant $outcome $goalName)
    (let* (
        ($delivery
            (omegaClawOutcomeField $outcome delivery-status))
        ($verification
            (omegaClawOutcomeField $outcome verification-status))
        ($failureReason
            (omegaClawOutcomeField $outcome failure-reason))
        ($evidence
            (omegaClawOutcomeField $outcome evidence-quality))
        ($progress
            (omegaClawOutcomeField $outcome task-progress))
        ($relevant
            (omegaClawOutcomeField $outcome evidence-relevant))
        ($administrativeSuccess
            (omegaClawOutcomeAdministrativeSuccess $outcome))
        ($learningSuccess
            (omegaClawOutcomeLearningSuccess $outcome))
    )
        (if (or (not $relevant)
                (omegaClawOutcomeExpectedEmpty $outcome))
            0.0
            (case $goalName (
                (gInd_over
                    (if $administrativeSuccess 0.0 1.0))
                (gTrans_over
                    (if (or (> $evidence 0.0)
                            (or (== $verification passed)
                                $learningSuccess))
                        1.0 0.0))
                (help_user
                    (if (or (not (== $delivery not-applicable))
                            (> $progress 0.0))
                        1.0 0.0))
                (learn
                    (if (or (> $evidence 0.0)
                            (or (not (== $verification not-required))
                                $learningSuccess))
                        1.0 0.0))
                (cooperate
                    (if (or (not (== $delivery not-applicable))
                            (or (> (omegaClawOutcomeField
                                    $outcome safety-events) 0.0)
                                (> (omegaClawOutcomeField
                                    $outcome contradiction-evidence) 0.0)))
                        1.0 0.0))
                (responsiveness
                    (if (== $delivery not-applicable) 0.0 1.0))
                (clarity
                    (if (or (> $evidence 0.0)
                            (or (not (== $verification not-required))
                                (or $administrativeSuccess
                                    (not (== (omegaClawOutcomeField
                                        $outcome proposal-status) valid)))))
                        1.0 0.0))
                (coherence 1.0)
                (reliability
                    (if (or (> $evidence 0.0)
                            (or (not (== $verification not-required))
                                (not (== $failureReason none))))
                        1.0 0.0))
                (progress
                    (if (or (> $progress 0.0)
                            (not (== $failureReason none)))
                        1.0 0.0))
                (adaptivity
                    (if (or (not (== $failureReason none))
                            (== (omegaClawOutcomeField
                                    $outcome guidance-candidate-id) repair))
                        1.0 0.0))
                (risk
                    (if (omegaClawOutcomeHasRiskEvidence $outcome)
                        1.0 0.0))
                (contradiction
                    (if (> (omegaClawOutcomeField
                                $outcome contradiction-evidence) 0.0)
                        1.0 0.0))
                (unsafe
                    (if (> (omegaClawOutcomeField
                                $outcome safety-events) 0.0)
                        1.0 0.0))
                ($_ 0.0)
            )))))

(= (omegaClawOutcomeGoalTarget $outcome $goalName $baseTarget)
    (let* (
        ($delivery
            (omegaClawOutcomeField $outcome delivery-status))
        ($verification
            (omegaClawOutcomeField $outcome verification-status))
        ($failureReason
            (omegaClawOutcomeField $outcome failure-reason))
        ($evidence
            (clipUnit (omegaClawOutcomeField
                $outcome evidence-quality)))
        ($progress
            (clipUnit (omegaClawOutcomeField
                $outcome task-progress)))
        ($riskTarget (omegaClawOutcomeRiskTarget $outcome))
        ($unsafeTarget
            (clipUnit
                (omegaClawOutcomeField $outcome safety-events)))
    )
        (case $goalName (
            (gInd_over
                (clipUnit (- 1.0 (maxNumber $riskTarget $unsafeTarget))))
            (gTrans_over
                (maxNumber $baseTarget $evidence))
            (help_user
                (case $delivery (
                    (sent 0.95)
                    (failed 0.15)
                    (suppressed 0.20)
                    ($_ (maxNumber $baseTarget $progress))
                )))
            (learn (maxNumber $baseTarget $evidence))
            (cooperate
                (if (or (> (omegaClawOutcomeField
                                $outcome safety-events) 0.0)
                        (> (omegaClawOutcomeField
                                $outcome contradiction-evidence) 0.0))
                    0.10
                    (if (== $delivery sent) 0.90 $baseTarget)))
            (responsiveness
                (if (== $delivery sent) 0.95 0.20))
            (clarity (maxNumber $baseTarget $evidence))
            (coherence
                (if (> (omegaClawOutcomeField
                            $outcome contradiction-evidence) 0.0)
                    0.10
                    (maxNumber $baseTarget $evidence)))
            (reliability
                (case $verification (
                    (passed 1.00)
                    (failed 0.15)
                    ($_ (if (not (== $failureReason none))
                        0.25
                        (maxNumber $baseTarget $evidence)))
                )))
            (progress (maxNumber $baseTarget $progress))
        (adaptivity
                (if (not (== $failureReason none)) 0.90 0.65))
            (risk $riskTarget)
            (contradiction
                (clipUnit (omegaClawOutcomeField
                    $outcome contradiction-evidence)))
            (unsafe $unsafeTarget)
            ($_ $baseTarget)
        ))))

(= (omegaClawOutcomeFeedbackGoalPairs $outcome $baseTarget)
    ((outcome_gInd_target
        (omegaClawOutcomeGoalTarget $outcome gInd_over $baseTarget))
     (outcome_gInd_relevant
        (omegaClawOutcomeGoalRelevant $outcome gInd_over))
     (outcome_gTrans_target
        (omegaClawOutcomeGoalTarget $outcome gTrans_over $baseTarget))
     (outcome_gTrans_relevant
        (omegaClawOutcomeGoalRelevant $outcome gTrans_over))
     (outcome_help_user_target
        (omegaClawOutcomeGoalTarget $outcome help_user $baseTarget))
     (outcome_help_user_relevant
        (omegaClawOutcomeGoalRelevant $outcome help_user))
     (outcome_learn_target
        (omegaClawOutcomeGoalTarget $outcome learn $baseTarget))
     (outcome_learn_relevant
        (omegaClawOutcomeGoalRelevant $outcome learn))
     (outcome_cooperate_target
        (omegaClawOutcomeGoalTarget $outcome cooperate $baseTarget))
     (outcome_cooperate_relevant
        (omegaClawOutcomeGoalRelevant $outcome cooperate))
     (outcome_responsiveness_target
        (omegaClawOutcomeGoalTarget $outcome responsiveness $baseTarget))
     (outcome_responsiveness_relevant
        (omegaClawOutcomeGoalRelevant $outcome responsiveness))
     (outcome_clarity_target
        (omegaClawOutcomeGoalTarget $outcome clarity $baseTarget))
     (outcome_clarity_relevant
        (omegaClawOutcomeGoalRelevant $outcome clarity))
     (outcome_coherence_target
        (omegaClawOutcomeGoalTarget $outcome coherence $baseTarget))
     (outcome_coherence_relevant
        (omegaClawOutcomeGoalRelevant $outcome coherence))
     (outcome_reliability_target
        (omegaClawOutcomeGoalTarget $outcome reliability $baseTarget))
     (outcome_reliability_relevant
        (omegaClawOutcomeGoalRelevant $outcome reliability))
     (outcome_progress_target
        (omegaClawOutcomeGoalTarget $outcome progress $baseTarget))
     (outcome_progress_relevant
        (omegaClawOutcomeGoalRelevant $outcome progress))
     (outcome_adaptivity_target
        (omegaClawOutcomeGoalTarget $outcome adaptivity $baseTarget))
     (outcome_adaptivity_relevant
        (omegaClawOutcomeGoalRelevant $outcome adaptivity))
     (outcome_risk_target
        (omegaClawOutcomeGoalTarget $outcome risk $baseTarget))
     (outcome_risk_relevant
        (omegaClawOutcomeGoalRelevant $outcome risk))
     (outcome_contradiction_target
        (omegaClawOutcomeGoalTarget $outcome contradiction $baseTarget))
     (outcome_contradiction_relevant
        (omegaClawOutcomeGoalRelevant $outcome contradiction))
     (outcome_unsafe_target
        (omegaClawOutcomeGoalTarget $outcome unsafe $baseTarget))
     (outcome_unsafe_relevant
        (omegaClawOutcomeGoalRelevant $outcome unsafe))))

(= (omegaClawOutcomeFeedback $outcome $features)
    (let* (
        ($successRatio (omegaClawOutcomeSuccessRatio $outcome))
        ($safetyEvents
            (clipUnit (omegaClawOutcomeField $outcome safety-events)))
        ($evidenceQuality
            (clipUnit (omegaClawOutcomeField $outcome evidence-quality)))
        ($taskProgress
            (clipUnit (omegaClawOutcomeField $outcome task-progress)))
        ($progressTarget
            (clipUnit (* (* $taskProgress $evidenceQuality) $successRatio)))
        ($riskTarget (omegaClawOutcomeRiskTarget $outcome))
        ($unsafeTarget $safetyEvents)
        ($contradictionTarget
            (clipUnit
                (omegaClawOutcomeField
                    $outcome contradiction-evidence)))
        ($individuationTarget
            (clipUnit
                (- 1.0 (maxNumber $riskTarget $unsafeTarget))))
        ($transcendenceTarget
            (clipUnit
                (+ (* 0.50 $evidenceQuality)
                   (* 0.50
                      (featureMapNumericUnit
                          $features opportunity 0.0)))))
        ($quality (omegaClawOutcomeQuality $outcome))
        ($learningWeight (clipUnit (absNumber $quality)))
        ($baseTarget (omegaClawOutcomeAchievementTarget $quality))
        ($goalPairs
            (omegaClawOutcomeFeedbackGoalPairs $outcome $baseTarget))
    )
        (goalChangeFeedback
            (listAppend
                ((outcome_available 1.0)
                 (outcome_quality $quality)
                 (outcome_learning_weight $learningWeight)
                 (individuation_target $individuationTarget)
                 (transcendence_target $transcendenceTarget)
                 (risk_target $riskTarget)
                 (contradiction_target $contradictionTarget)
                 (unsafe_target $unsafeTarget)
                 (observed_progress $progressTarget))
                $goalPairs))))

(= (omegaClawOutcomeGoalFeedbackFeature $goalName $field)
    (case $goalName (
        (gInd_over (case $field (
            (target outcome_gInd_target)
            (relevant outcome_gInd_relevant))))
        (gTrans_over (case $field (
            (target outcome_gTrans_target)
            (relevant outcome_gTrans_relevant))))
        (help_user (case $field (
            (target outcome_help_user_target)
            (relevant outcome_help_user_relevant))))
        (learn (case $field (
            (target outcome_learn_target)
            (relevant outcome_learn_relevant))))
        (cooperate (case $field (
            (target outcome_cooperate_target)
            (relevant outcome_cooperate_relevant))))
        (responsiveness (case $field (
            (target outcome_responsiveness_target)
            (relevant outcome_responsiveness_relevant))))
        (clarity (case $field (
            (target outcome_clarity_target)
            (relevant outcome_clarity_relevant))))
        (coherence (case $field (
            (target outcome_coherence_target)
            (relevant outcome_coherence_relevant))))
        (reliability (case $field (
            (target outcome_reliability_target)
            (relevant outcome_reliability_relevant))))
        (progress (case $field (
            (target outcome_progress_target)
            (relevant outcome_progress_relevant))))
        (adaptivity (case $field (
            (target outcome_adaptivity_target)
            (relevant outcome_adaptivity_relevant))))
        (risk (case $field (
            (target outcome_risk_target)
            (relevant outcome_risk_relevant))))
        (contradiction (case $field (
            (target outcome_contradiction_target)
            (relevant outcome_contradiction_relevant))))
        (unsafe (case $field (
            (target outcome_unsafe_target)
            (relevant outcome_unsafe_relevant))))
        ($_ none)
    )))

(= (omegaClawOutcomeGoalChangeValue
        $state $feedback $goalName)
    (let* (
        ($relevant
            (featureMapNumeric
                $feedback
                (omegaClawOutcomeGoalFeedbackFeature
                    $goalName relevant)
                0.0))
        ($current (stateGoal $state $goalName))
        ($target
            (featureMapNumeric
                $feedback
                (omegaClawOutcomeGoalFeedbackFeature
                    $goalName target)
                $current))
        ($weight
            (featureMapNumericUnit
                $feedback outcome_learning_weight 0.0))
        ($rawDelta
            (* (* (omegaClawOutcomeLearningRate) $weight)
               (- $target $current)))
    )
        (if (> $relevant 0.0)
            (clipRange
                $rawDelta
                (- 0.0 (omegaClawOutcomeMaxGoalDelta))
                (omegaClawOutcomeMaxGoalDelta))
            0.0)))

(= (omegaClawOutcomeGoalChangeLoop
        $state $feedback ())
    ())

(= (omegaClawOutcomeGoalChangeLoop
        $state $feedback $goalNames)
    (let* (
        (($head $tail) (decons $goalNames))
    )
        (cons-atom
            (omegaClawOutcomeGoalChangeValue
                $state $feedback $head)
            (omegaClawOutcomeGoalChangeLoop
                $state $feedback $tail))))

;; Derive a pure full-schema goal delta from committed outcomes only.
(= (omegaClawOutcomeGoalChangeDeltaG
        $profile $state $candidate $feedback $lambdaInd $lambdaTrans)
    (omegaClawOutcomeGoalChangeLoop
        $state $feedback
        (magusGoalSchemaNames
            (motivationSchemaGoals
                (decisionProfileSchema $profile)))))

(= (omegaClawGoalFeedback $state $perception $features)
    (case (omegaClawPerceptionField $perception outcome) (
        (none (goalChangeFeedback ()))
        ($outcome (omegaClawOutcomeFeedback $outcome $features))
    )))

(= (omegaClawAppraisalProfile)
    (appraisalProfile
        omegaclaw_openpsi
        (omegaClawModulatorNames)
        omegaClawStimulusFeatureFn
        omegaClawCoreDeltas
        omegaClawApplicationDeltas
        omegaClawGoalFeedback
        (omegaClawApplicationScale)
        ((urgency 0.0 1.0)
         (persistence 0.0 1.0)
         (context_depth 0.0 1.0)
         (human_deference 0.0 1.0)
         (focus 0.0 1.0))))
