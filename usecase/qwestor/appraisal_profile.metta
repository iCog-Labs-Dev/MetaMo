;; Use the shared core OpenPsi equations
(= (qwestorCoreDeltas $state $features)
    (commonOpenPsiCoreDeltas $state $features)
)

;; Return the additive delta required for bounded target tracking
(= (qwestorApplicationDeltaToward $state $name $target $alpha)
    (* $alpha (- (clipUnit $target) (stateModulator $state $name)))
)

;; Compute Qwestor application-modulator deltas
(= (qwestorApplicationDeltas $state $features)
    (let* (
        ($rates (qwestorLearningRates))
        ($weights (qwestorAppraisalWeights))
        ($urgency (featureMapNumericUnit $features urgency 0.00))
        ($risk (featureMapNumericUnit $features risk 0.00))
        ($verification (featureMapNumericUnit $features verification 0.00))
        ($requestedThreshold (featureMapNumericUnit $features requested_threshold 0.30))
        ($failure (featureMapNumericUnit $features failure_pressure 0.00))
        ($expertise (featureMapNumericUnit $features user_expertise 0.50))
        ($familiarity (featureMapNumericUnit $features topic_familiarity 0.50))
        ($novelty (featureMapNumericUnit $features novelty 0.00))
        ($reflection (featureMapNumericUnit $features reflective_intent 0.50))
        ($riskTarget (maxNumber $risk $verification))
        ($errorToleranceTarget (clipUnit (- 1.0 (maxNumber $requestedThreshold $risk))))
        ($failureTarget
            (clipUnit
                (+
                    (* (qwestorConfigGet $rates FAILURE_RETENTION 0.80)
                       (stateModulator $state failure_wariness))
                    (* (qwestorConfigGet $rates FAILURE_SIGNAL_GAIN 0.55)
                       $failure)
                )
            ))
        ($creativityTarget
            (clipUnit
                (+
                    (+
                        (* (qwestorConfigGet
                                $weights CREATIVITY_NOVELTY_WEIGHT 0.50)
                           (* $novelty (- 1.0 $risk)))
                        (* (qwestorConfigGet
                                $weights CREATIVITY_REFLECTION_WEIGHT 0.30)
                           $reflection))
                    (* (qwestorConfigGet
                            $weights CREATIVITY_RECOVERY_WEIGHT 0.20)
                       (- 1.0 $failure))
                )
            ))
    )
        (
            (urgency
                (qwestorApplicationDeltaToward
                    $state urgency $urgency
                    (qwestorConfigGet $rates URGENCY_ALPHA 0.60)))
            (risk_aversion
                (qwestorApplicationDeltaToward
                    $state risk_aversion $riskTarget
                    (qwestorConfigGet $rates RISK_AVERSION_ALPHA 0.45)))
            (error_tolerance
                (qwestorApplicationDeltaToward
                    $state error_tolerance $errorToleranceTarget
                    (qwestorConfigGet $rates ERROR_TOLERANCE_ALPHA 0.40)))
            (failure_wariness
                (- $failureTarget (stateModulator $state failure_wariness)))
            (user_expertise
                (qwestorApplicationDeltaToward
                    $state user_expertise $expertise
                    (qwestorConfigGet $rates USER_EXPERTISE_ALPHA 0.45)))
            (topic_familiarity
                (qwestorApplicationDeltaToward
                    $state topic_familiarity $familiarity
                    (qwestorConfigGet $rates TOPIC_FAMILIARITY_ALPHA 0.35)))
            (creativity
                (qwestorApplicationDeltaToward
                    $state creativity $creativityTarget
                    (qwestorConfigGet $rates CREATIVITY_ALPHA 0.40)))
        )
    )
)

;; Add Qwestor source signals and anti-goal targets to shared feedback
(= (qwestorGoalFeedback $state $contextOrPerception $features)
    (let* (
        ($common (commonOpenPsiGoalFeedback $state $contextOrPerception $features))
        ($weights (qwestorAppraisalWeights))
        ($risk (featureMapNumericUnit $features risk 0.00))
        ($effort (featureMapNumericUnit $features effort 0.00))
        ($novelty (featureMapNumericUnit $features novelty 0.00))
        ($ambiguity (featureMapNumericUnit $features ambiguity 0.00))
        ($complexity (featureMapNumericUnit $features complexity 0.30))
        ($requestedThreshold (featureMapNumericUnit $features requested_threshold 0.30))
        ($urgency (featureMapNumericUnit $features urgency 0.00))
        ($expertise (featureMapNumericUnit $features user_expertise 0.50))
        ($familiarity (featureMapNumericUnit $features topic_familiarity 0.50))
        ($failure (featureMapNumericUnit $features failure_pressure 0.00))
        ($verification (featureMapNumericUnit $features verification 0.00))
        ($reflection (featureMapNumericUnit $features reflective_intent 0.50))
        ($externalEvidence (featureMapNumericUnit $features external_evidence 0.30))
        ($taskPlan (featureMapNumericUnit $features task_plan 0.20))
        ($multiSource (featureMapNumericUnit $features multi_source 0.30))
        ($outcomePairs (qwestorPerceptionOutcomePairs $contextOrPerception))
        ($hallucinateTarget
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
                           (- 1.0 $familiarity)))
                )))
        ($redundantTarget
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
                       (- 1.0 $novelty))
                )))
        ($rabbitHoleTarget
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
                           $urgency))
                )))
        ($prematureTarget
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
                           (- 1.0 (stateModulator $state resolution))))
                )))
    )
        (goalChangeFeedback
            (listAppend
                (featureMapPairs $common)
                (listAppend
                    (
                        (novelty $novelty)
                        (risk $risk)
                        (effort $effort)
                        (complexity $complexity)
                        (ambiguity $ambiguity)
                        (requested_threshold $requestedThreshold)
                        (urgency $urgency)
                        (user_expertise $expertise)
                        (topic_familiarity $familiarity)
                        (failure_pressure $failure)
                        (verification $verification)
                        (reflective_intent $reflection)
                        (external_evidence $externalEvidence)
                        (task_plan $taskPlan)
                        (multi_source $multiSource)
                        (hallucinate_target $hallucinateTarget)
                        (redundant_target $redundantTarget)
                        (rabbit_hole_target $rabbitHoleTarget)
                        (premature_target $prematureTarget)
                    )
                    $outcomePairs
                )
            )
        )
    )
)

;; Build the complete Qwestor appraisal profile
(= (qwestorAppraisalProfile)
    (appraisalProfile
        qwestor_openpsi
        (qwestorModulatorNames)
        qwestorStimulusFeatureFn
        qwestorCoreDeltas
        qwestorApplicationDeltas
        qwestorGoalFeedback
        1.0
        (
            (urgency 0.0 1.0)
            (risk_aversion 0.0 1.0)
            (error_tolerance 0.0 1.0)
            (failure_wariness 0.0 1.0)
            (user_expertise 0.0 1.0)
            (topic_familiarity 0.0 1.0)
            (creativity 0.0 1.0)
        )
    )
)
