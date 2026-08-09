
;; Read a unit-valued signal from goal feedback
(= (qwestorFeedbackValue $feedback $name $default)
    (featureMapNumericUnit $feedback $name $default)
)

;; Read a configured target coefficient
(= (qwestorTargetWeight $name $default)
    (qwestorConfigGet (qwestorGoalTargetWeights) $name $default)
)

;; Compute one of the fourteen positive-goal targets
(= (qwestorPositiveGoalTarget $state $feedback $goalName)
    (let* (
        ($stability (qwestorStabilityConfig))
        ($risk (qwestorFeedbackValue $feedback risk 0.00))
        ($novelty (qwestorFeedbackValue $feedback novelty 0.00))
        ($effort (qwestorFeedbackValue $feedback effort 0.00))
        ($ambiguity (qwestorFeedbackValue $feedback ambiguity 0.00))
        ($urgency (qwestorFeedbackValue $feedback urgency 0.00))
        ($expertise (qwestorFeedbackValue $feedback user_expertise 0.50))
        ($familiarity (qwestorFeedbackValue $feedback topic_familiarity 0.50))
        ($verification (qwestorFeedbackValue $feedback verification 0.00))
        ($reflection (qwestorFeedbackValue $feedback reflective_intent 0.50))
        ($externalEvidence (qwestorFeedbackValue $feedback external_evidence 0.30))
        ($taskPlan (qwestorFeedbackValue $feedback task_plan 0.20))
        ($multiSource (qwestorFeedbackValue $feedback multi_source 0.30))
        ($shortHelp (qwestorFeedbackValue $feedback outcome_short_help 0.50))
        ($longHelp (qwestorFeedbackValue $feedback outcome_long_help 0.50))
        ($grounding (qwestorFeedbackValue $feedback outcome_grounding 0.50))
        ($outcomeSafety (qwestorFeedbackValue $feedback outcome_safety 0.50))
        ($progress (qwestorFeedbackValue $feedback outcome_progress 0.50))
        ($novelYield (qwestorFeedbackValue $feedback outcome_novel_yield 0.50))
        ($originalYield
            (qwestorFeedbackValue $feedback outcome_original_yield 0.50))
        ($breakthroughYield
            (qwestorFeedbackValue $feedback outcome_breakthrough_yield 0.50))
        ($outcomeCoherence
            (qwestorFeedbackValue $feedback outcome_coherence 0.50))
        ($socialQuality
            (qwestorFeedbackValue $feedback outcome_social_quality 0.50))
        ($outcomeEfficiency
            (qwestorFeedbackValue $feedback outcome_efficiency 0.50))
        ($outcomeAccuracy
            (qwestorFeedbackValue $feedback outcome_accuracy 0.50))
    )
        (case $goalName (
            (beneficial
                (maxNumber
                    (qwestorConfigGet $stability BENEFICIAL_FLOOR 0.55)
                    (clipUnit
                        (+
                            (qwestorTargetWeight BENEFICIAL_BASE 0.55)
                            (+
                                (* (qwestorTargetWeight
                                        BENEFICIAL_SAFETY_GAP_WEIGHT 0.25)
                                   (- 1.0 $outcomeSafety))
                                (* (qwestorTargetWeight
                                        BENEFICIAL_LONG_HELP_GAP_WEIGHT 0.20)
                                   (- 1.0 $longHelp)))))))
            (honesty
                (maxNumber
                    (qwestorConfigGet $stability HONESTY_FLOOR 0.55)
                    (clipUnit
                        (+
                            (qwestorTargetWeight HONESTY_BASE 0.60)
                            (+
                                (* (qwestorTargetWeight
                                        HONESTY_GROUNDING_GAP_WEIGHT 0.25)
                                   (- 1.0 $grounding))
                                (* (qwestorTargetWeight
                                        HONESTY_VERIFICATION_WEIGHT 0.15)
                                   $verification))))))
            (safety
                (maxNumber
                    (qwestorConfigGet $stability SAFETY_FLOOR 0.55)
                    (clipUnit
                        (+
                            (qwestorTargetWeight SAFETY_BASE 0.60)
                            (+
                                (* (qwestorTargetWeight SAFETY_RISK_WEIGHT 0.25)
                                   $risk)
                                (* (qwestorTargetWeight
                                        SAFETY_OUTCOME_GAP_WEIGHT 0.15)
                                   (- 1.0 $outcomeSafety)))))))
            (help_short
                (clipUnit
                    (+
                        (* (qwestorTargetWeight HELP_SHORT_URGENCY_WEIGHT 0.55)
                           $urgency)
                        (* (qwestorTargetWeight
                                HELP_SHORT_OUTCOME_GAP_WEIGHT 0.45)
                           (- 1.0 $shortHelp)))))
            (help_long
                (clipUnit
                    (+
                        (+
                            (* (qwestorTargetWeight HELP_LONG_PLAN_WEIGHT 0.35)
                               $taskPlan)
                            (* (qwestorTargetWeight
                                    HELP_LONG_MULTI_SOURCE_WEIGHT 0.25)
                               $multiSource))
                        (* (qwestorTargetWeight
                                HELP_LONG_OUTCOME_GAP_WEIGHT 0.40)
                           (- 1.0 $longHelp)))))
            (knowledge
                (clipUnit
                    (+
                        (+
                            (* (qwestorTargetWeight
                                    KNOWLEDGE_UNFAMILIARITY_WEIGHT 0.35)
                               (- 1.0 $familiarity))
                            (* (qwestorTargetWeight KNOWLEDGE_EVIDENCE_WEIGHT 0.30)
                               $externalEvidence))
                        (* (qwestorTargetWeight
                                KNOWLEDGE_GROUNDING_GAP_WEIGHT 0.35)
                           (- 1.0 $grounding)))))
            (novelty
                (clipUnit
                    (+
                        (+
                            (* (qwestorTargetWeight NOVELTY_FEATURE_WEIGHT 0.50)
                               $novelty)
                            (* (qwestorTargetWeight NOVELTY_REFLECTION_WEIGHT 0.25)
                               $reflection))
                        (* (qwestorTargetWeight
                                NOVELTY_OUTCOME_GAP_WEIGHT 0.25)
                           (- 1.0 $novelYield)))))
            (originality
                (clipUnit
                    (+
                        (+
                            (* (qwestorTargetWeight
                                    ORIGINALITY_CREATIVITY_WEIGHT 0.45)
                               (stateModulator $state creativity))
                            (* (qwestorTargetWeight
                                    ORIGINALITY_MULTI_SOURCE_WEIGHT 0.30)
                               $multiSource))
                        (* (qwestorTargetWeight
                                ORIGINALITY_OUTCOME_GAP_WEIGHT 0.25)
                           (- 1.0 $originalYield)))))
            (success_moderate
                (clipUnit
                    (+
                        (+
                            (* (qwestorTargetWeight
                                    MODERATE_SUCCESS_RISK_WEIGHT 0.35)
                               $risk)
                            (* (qwestorTargetWeight
                                    MODERATE_SUCCESS_URGENCY_WEIGHT 0.25)
                               $urgency))
                        (* (qwestorTargetWeight
                                MODERATE_SUCCESS_OUTCOME_GAP_WEIGHT 0.40)
                           (- 1.0 $progress)))))
            (success_breakthrough
                (clipUnit
                    (+
                        (+
                            (* (qwestorTargetWeight
                                    BREAKTHROUGH_NOVELTY_WEIGHT 0.45)
                               (* $novelty (- 1.0 $risk)))
                            (* (qwestorTargetWeight
                                    BREAKTHROUGH_REFLECTION_WEIGHT 0.30)
                               $reflection))
                        (* (qwestorTargetWeight
                                BREAKTHROUGH_OUTCOME_GAP_WEIGHT 0.25)
                           (- 1.0 $breakthroughYield)))))
            (coherence
                (clipUnit
                    (+
                        (+
                            (* (qwestorTargetWeight
                                    COHERENCE_AMBIGUITY_WEIGHT 0.35)
                               $ambiguity)
                            (* (qwestorTargetWeight
                                    COHERENCE_MULTI_SOURCE_WEIGHT 0.25)
                               $multiSource))
                        (* (qwestorTargetWeight
                                COHERENCE_OUTCOME_GAP_WEIGHT 0.40)
                           (- 1.0 $outcomeCoherence)))))
            (social
                (clipUnit
                    (+
                        (+
                            (* (qwestorTargetWeight SOCIAL_AMBIGUITY_WEIGHT 0.30)
                               $ambiguity)
                            (* (qwestorTargetWeight SOCIAL_NOVICE_WEIGHT 0.20)
                               (- 1.0 $expertise)))
                        (* (qwestorTargetWeight
                                SOCIAL_OUTCOME_GAP_WEIGHT 0.50)
                           (- 1.0 $socialQuality)))))
            (efficiency
                (clipUnit
                    (+
                        (+
                            (* (qwestorTargetWeight EFFICIENCY_URGENCY_WEIGHT 0.45)
                               $urgency)
                            (* (qwestorTargetWeight EFFICIENCY_EFFORT_WEIGHT 0.25)
                               $effort))
                        (* (qwestorTargetWeight
                                EFFICIENCY_OUTCOME_GAP_WEIGHT 0.30)
                           (- 1.0 $outcomeEfficiency)))))
            (accuracy
                (clipUnit
                    (+
                        (+
                            (* (qwestorTargetWeight ACCURACY_RISK_WEIGHT 0.40)
                               $risk)
                            (* (qwestorTargetWeight
                                    ACCURACY_VERIFICATION_WEIGHT 0.25)
                               $verification))
                        (* (qwestorTargetWeight
                                ACCURACY_OUTCOME_GAP_WEIGHT 0.35)
                           (- 1.0 $outcomeAccuracy)))))
            ($_ (stateGoal $state $goalName))
        ))
    )
)

;; Compute one of the four anti-goal targets from current feedback
(= (qwestorAntiGoalTarget $state $feedback $goalName)
    (let* (
        ($weights (qwestorAppraisalWeights))
        ($risk (qwestorFeedbackValue $feedback risk 0.00))
        ($effort (qwestorFeedbackValue $feedback effort 0.00))
        ($novelty (qwestorFeedbackValue $feedback novelty 0.00))
        ($complexity (qwestorFeedbackValue $feedback complexity 0.30))
        ($ambiguity (qwestorFeedbackValue $feedback ambiguity 0.00))
        ($urgency (qwestorFeedbackValue $feedback urgency 0.00))
        ($expertise (qwestorFeedbackValue $feedback user_expertise 0.50))
        ($familiarity (qwestorFeedbackValue $feedback topic_familiarity 0.50))
        ($failure (qwestorFeedbackValue $feedback failure_pressure 0.00))
        ($verification (qwestorFeedbackValue $feedback verification 0.00))
        ($reflection (qwestorFeedbackValue $feedback reflective_intent 0.50))
        ($taskPlan (qwestorFeedbackValue $feedback task_plan 0.20))
        ($multiSource (qwestorFeedbackValue $feedback multi_source 0.30))
    )
        (case $goalName (
            (hallucinate
                (clipUnit
                    (+
                        (+
                            (* (qwestorConfigGet
                                    $weights HALLUCINATE_RISK_WEIGHT 0.45)
                               $risk)
                            (* (qwestorConfigGet
                                    $weights HALLUCINATE_VERIFICATION_WEIGHT 0.25)
                               $verification))
                        (+
                            (* (qwestorConfigGet
                                    $weights HALLUCINATE_FAILURE_WEIGHT 0.20)
                               $failure)
                            (* (qwestorConfigGet
                                    $weights HALLUCINATE_UNFAMILIARITY_WEIGHT 0.10)
                               (- 1.0 $familiarity))))))
            (redundant
                (clipUnit
                    (+
                        (+
                            (* (qwestorConfigGet
                                    $weights REDUNDANT_EXPERTISE_WEIGHT 0.45)
                               $expertise)
                            (* (qwestorConfigGet
                                    $weights REDUNDANT_FAMILIARITY_WEIGHT 0.35)
                               $familiarity))
                        (* (qwestorConfigGet
                                $weights REDUNDANT_LOW_NOVELTY_WEIGHT 0.20)
                           (- 1.0 $novelty)))))
            (rabbit_hole
                (clipUnit
                    (+
                        (+
                            (* (qwestorConfigGet
                                    $weights RABBIT_HOLE_EFFORT_WEIGHT 0.35)
                               $effort)
                            (* (qwestorConfigGet
                                    $weights RABBIT_HOLE_MULTI_SOURCE_WEIGHT 0.25)
                               $multiSource))
                        (+
                            (* (qwestorConfigGet
                                    $weights RABBIT_HOLE_REFLECTION_WEIGHT 0.20)
                               $reflection)
                            (* (qwestorConfigGet
                                    $weights RABBIT_HOLE_URGENCY_WEIGHT 0.20)
                               $urgency)))))
            (premature
                (clipUnit
                    (+
                        (+
                            (* (qwestorConfigGet
                                    $weights PREMATURE_COMPLEXITY_WEIGHT 0.40)
                               $complexity)
                            (* (qwestorConfigGet
                                    $weights PREMATURE_AMBIGUITY_WEIGHT 0.30)
                               $ambiguity))
                        (+
                            (* (qwestorConfigGet
                                    $weights PREMATURE_PLAN_WEIGHT 0.20)
                               $taskPlan)
                            (* (qwestorConfigGet
                                    $weights PREMATURE_LOW_RESOLUTION_WEIGHT 0.10)
                               (- 1.0 (stateModulator $state resolution)))))))
            ($_ (stateGoal $state $goalName))
        ))
    )
)

;; Compute the maximum current hazard pressure
(= (qwestorOvergoalPressure $feedback)
    (maxNumber
        (qwestorFeedbackValue $feedback risk 0.00)
        (maxNumber
            (qwestorFeedbackValue $feedback ambiguity 0.00)
            (maxNumber
                (qwestorFeedbackValue $feedback failure_pressure 0.00)
                (qwestorFeedbackValue $feedback verification 0.00))))
)

;; Compute the slow individuation target
(= (qwestorIndividuationTarget $state $feedback)
    (let* (
        ($weights (qwestorOvergoalWeights))
        ($normativeMean
            (/ (+
                    (+ (stateGoal $state beneficial) (stateGoal $state honesty))
                    (stateGoal $state safety))
               3.0))
        ($pressure (qwestorOvergoalPressure $feedback))
    )
        (clipUnit
            (+
                (+
                    (qwestorConfigGet $weights INDIVIDUATION_BASE 0.35)
                    (* (qwestorConfigGet
                            $weights INDIVIDUATION_NORMATIVE_WEIGHT 0.25)
                       $normativeMean))
                (+
                    (* (qwestorConfigGet
                            $weights INDIVIDUATION_COHERENCE_WEIGHT 0.15)
                       (stateGoal $state coherence))
                    (* (qwestorConfigGet
                            $weights INDIVIDUATION_PRESSURE_WEIGHT 0.25)
                       $pressure)))
        )
    )
)

;; Compute the slow transcendence target
(= (qwestorTranscendenceTarget $state $feedback)
    (let* (
        ($weights (qwestorOvergoalWeights))
        ($growthMean
            (/ (+
                    (+
                        (+ (stateGoal $state help_long)
                           (stateGoal $state knowledge))
                        (+ (stateGoal $state novelty)
                           (stateGoal $state originality)))
                    (stateGoal $state success_breakthrough))
               5.0))
        ($risk (qwestorFeedbackValue $feedback risk 0.00))
        ($novelty (qwestorFeedbackValue $feedback novelty 0.00))
        ($usefulNovelty (* $novelty (- 1.0 $risk)))
        ($pressure (qwestorOvergoalPressure $feedback))
    )
        (clipUnit
            (-
                (+
                    (+
                        (qwestorConfigGet $weights TRANSCENDENCE_BASE 0.15)
                        (* (qwestorConfigGet
                                $weights TRANSCENDENCE_GROWTH_WEIGHT 0.35)
                           $growthMean))
                    (+
                        (* (qwestorConfigGet
                                $weights TRANSCENDENCE_USEFUL_NOVELTY_WEIGHT 0.25)
                           $usefulNovelty)
                        (* (qwestorConfigGet
                                $weights TRANSCENDENCE_BENEFICIAL_WEIGHT 0.15)
                           (stateGoal $state beneficial))))
                (* (qwestorConfigGet
                        $weights TRANSCENDENCE_PRESSURE_WEIGHT 0.25)
                   $pressure))
        )
    )
)

;; Bound a proposed goal delta to the decision-profile limit
(= (qwestorBoundGoalDelta $profile $delta)
    (clipRange
        $delta
        (- 0.0 (decisionProfileMaxGoalDelta $profile))
        (decisionProfileMaxGoalDelta $profile)
    )
)

;; Compute a slow structural-overgoal delta
(= (qwestorOvergoalDelta $profile $state $feedback $goalName)
    (let* (
        ($target
            (if (== $goalName individuation)
                (qwestorIndividuationTarget $state $feedback)
                (qwestorTranscendenceTarget $state $feedback)))
        ($rate (decisionProfileOvergoalDeltaScale $profile))
    )
        (qwestorBoundGoalDelta
            $profile
            (* $rate (- $target (stateGoal $state $goalName)))
        )
    )
)

;; Compute target tracking plus the selected candidate hint for a positive goal
(= (qwestorPositiveGoalDelta
        $profile $state $candidate $feedback $goalName $goalIndex)
    (let* (
        ($target (qwestorPositiveGoalTarget $state $feedback $goalName))
        ($tracking
            (* (decisionProfileDeltaScale $profile)
               (- $target (stateGoal $state $goalName))))
        ($hint
            (* (decisionProfileCandidateDeltaWeight $profile)
               (index-atom (candidateDeltaG $candidate) $goalIndex)))
    )
        (qwestorBoundGoalDelta $profile (+ $tracking $hint))
    )
)

;; Compute target tracking for an anti-goal without duplicating candidate risk
(= (qwestorAntiGoalDelta $profile $state $feedback $goalName)
    (let* (
        ($target (qwestorAntiGoalTarget $state $feedback $goalName))
        ($tracking
            (* (decisionProfileAntiGoalDeltaScale $profile)
               (- $target (stateGoal $state $goalName))))
    )
        (qwestorBoundGoalDelta $profile $tracking)
    )
)

;; Compute one delta according to its schema category
(= (qwestorGoalChangeValue
        $profile $state $candidate $feedback $goalName $goalIndex)
    (if (or (== $goalName individuation) (== $goalName transcendence))
        (qwestorOvergoalDelta $profile $state $feedback $goalName)
        (if (listContains (qwestorPrimaryGoalNames) $goalName)
            (qwestorPositiveGoalDelta
                $profile $state $candidate $feedback $goalName $goalIndex)
            (qwestorAntiGoalDelta $profile $state $feedback $goalName)
        )
    )
)

;; Build the complete goal delta in canonical schema order
(= (qwestorGoalChangeLoop
        $profile $state $candidate $feedback $goalNames $goalIndex)
    (if (== $goalNames ())
        ()
        (let* (
            (($head $tail) (decons $goalNames))
            ($value
                (qwestorGoalChangeValue
                    $profile $state $candidate $feedback $head $goalIndex))
        )
            (cons-atom
                $value
                (qwestorGoalChangeLoop
                    $profile
                    $state
                    $candidate
                    $feedback
                    $tail
                    (+ $goalIndex 1))
            )
        )
    )
)

;; Compute the Qwestor-specific complete goal delta
(= (qwestorGoalChangeDeltaG
        $profile $state $candidate $feedback $lambdaInd $lambdaTrans)
    (qwestorGoalChangeLoop
        $profile
        $state
        $candidate
        $feedback
        (qwestorGoalNames)
        0
    )
)
