;; Return a unit feature value used by contextual planning
(= (qwestorPlanningFeature $features $name $default)
    (featureMapNumericUnit $features $name $default)
)

(= (qwestorPlanningValue $features $name $default)
    (featureMapGet $features $name $default)
)

;; Return sparse context adjustments for one registered action
(= (qwestorContextAdjustments $actionId $features)
    (let* (
        ($novelty (qwestorPlanningFeature $features novelty 0.00))
        ($risk (qwestorPlanningFeature $features risk 0.00))
        ($effort (qwestorPlanningFeature $features effort 0.00))
        ($complexity (qwestorPlanningFeature $features complexity 0.30))
        ($ambiguity (qwestorPlanningFeature $features ambiguity 0.00))
        ($urgency (qwestorPlanningFeature $features urgency 0.00))
        ($familiarity (qwestorPlanningFeature $features topic_familiarity 0.50))
        ($verification (qwestorPlanningFeature $features verification 0.00))
        ($reflection (qwestorPlanningFeature $features reflective_intent 0.00))
        ($externalEvidence (qwestorPlanningFeature $features external_evidence 0.00))
        ($synthesisReady (qwestorPlanningFeature $features synthesis_ready 0.00))
        ($taskPlan (qwestorPlanningFeature $features task_plan 0.00))
        ($multiSource (qwestorPlanningFeature $features multi_source 0.00))
        ($waiting (qwestorPlanningFeature $features additional_information_expected 0.00))
        ($evidencePressure $externalEvidence)
    )
        (case $actionId (
            (act_clarify
                ((help_short
                    (-
                        (- (* 0.30 $ambiguity) (* 0.15 $urgency))
                        (* 0.30 $waiting)))
                 (coherence (* 0.15 $ambiguity))
                 (social (* 0.10 $ambiguity))
                 (accuracy (* 0.10 $ambiguity))
                 (efficiency (* -0.30 $waiting))
                 (redundant (* 0.20 $waiting))
                 (premature (* -0.05 $ambiguity))))
            (act_search
                ((beneficial (* 0.08 $externalEvidence))
                 (honesty (* 0.08 $externalEvidence))
                 (help_short (- (* 0.20 $externalEvidence) (* 0.15 $urgency)))
                 (help_long (* 0.10 $externalEvidence))
                 (knowledge (* 0.10 $externalEvidence))
                 (novelty (* 0.10 $externalEvidence))
                 (accuracy
                    (+ (* 0.08 $externalEvidence) (* 0.10 $verification)))
                 (hallucinate (* -0.04 $verification))
                 (rabbit_hole (* 0.20 $effort))))
            (act_think
                ((beneficial (* 0.10 $reflection))
                 (help_short
                    (- (* 0.75 $reflection) (* 0.20 $urgency)))
                 (help_long (* 0.20 $reflection))
                 (knowledge (* 0.20 $reflection))
                 (novelty (* 0.15 $novelty))
                 (originality (* 0.15 $reflection))
                 (success_breakthrough (* 0.10 $novelty))
                 (coherence (* 0.10 $reflection))
                 (efficiency
                    (- (* 0.70 $reflection) (* 0.15 $urgency)))
                 (accuracy (* 0.10 $reflection))
                 (hallucinate (* 0.20 $risk))
                 (rabbit_hole
                    (- (* 0.25 $effort) (* 0.10 $reflection)))))
            (act_respond
                ((honesty (- (* -0.15 $risk) (* 0.12 $evidencePressure)))
                 (safety (* -0.15 $risk))
                 (help_short (- (* 0.20 $urgency) (* 0.35 $ambiguity)))
                 (efficiency (* 0.10 $urgency))
                 (accuracy
                    (- (* 0.10 $familiarity) (* 0.10 $evidencePressure)))
                 (hallucinate
                    (+
                        (+ (* 0.35 $risk) (* 0.20 $verification))
                        (* 0.15 $evidencePressure)))
                 (premature
                    (+
                        (+ (* 0.35 $ambiguity) (* 0.20 $taskPlan))
                        (* 0.08 $evidencePressure)))))
            (act_decompose
                ((help_short
                    (- (* 0.25 $taskPlan) (* 0.35 $ambiguity)))
                 (help_long (* 0.10 $taskPlan))
                 (success_moderate (* 0.10 $complexity))
                 (coherence
                    (- (* 0.10 $complexity) (* 0.15 $ambiguity)))
                 (efficiency
                    (- (* 0.25 $taskPlan) (* 0.20 $ambiguity)))
                 (rabbit_hole (* -0.05 $taskPlan))
                 (premature
                    (+ (* -0.03 $taskPlan) (* 0.25 $ambiguity)))))
            (act_verify
                ((honesty (* 0.10 $verification))
                 (safety (* 0.10 $risk))
                 (help_short (* -0.12 $urgency))
                 (accuracy (* 0.10 (maxNumber $verification $risk)))
                 (hallucinate (* -0.01 $verification))
                 (premature (* -0.01 $verification))))
            (act_synthesize
                ((help_long (* 0.10 $synthesisReady))
                 (knowledge (* 0.10 $synthesisReady))
                 (originality (* 0.08 $synthesisReady))
                 (coherence (* 0.10 $synthesisReady))
                 (rabbit_hole (* 0.10 $effort))
                 (premature
                    (+ (* -0.05 $synthesisReady)
                       (* 0.25 (* $multiSource (- 1.0 $synthesisReady)))))))
            (act_wait
                ((beneficial (* 0.35 $waiting))
                 (honesty (* 0.15 $waiting))
                 (safety (* 0.15 $waiting))
                 (help_short (* 0.25 $waiting))
                 (help_long (* 0.30 $waiting))
                 (success_moderate (* 0.20 $waiting))
                 (coherence (* 0.20 $waiting))
                 (efficiency
                    (- (* 0.20 $waiting) (* 0.10 $urgency)))
                 (accuracy (* 0.15 $waiting))
                 (premature (* -0.05 $waiting))))
            ($_ ())
        ))
    )
)

;; Return continuous evidence that an action fits the current research operation
(= (qwestorActionSupport $actionId $features)
    (let* (
        ($specificity (qwestorPlanningFeature $features specificity 0.50))
        ($ambiguity (qwestorPlanningFeature $features ambiguity 0.00))
        ($complexity (qwestorPlanningFeature $features complexity 0.30))
        ($risk (qwestorPlanningFeature $features risk 0.00))
        ($novelty (qwestorPlanningFeature $features novelty 0.00))
        ($urgency (qwestorPlanningFeature $features urgency 0.00))
        ($familiarity (qwestorPlanningFeature $features topic_familiarity 0.50))
        ($failure (qwestorPlanningFeature $features failure_pressure 0.00))
        ($verification (qwestorPlanningFeature $features verification 0.00))
        ($reflection (qwestorPlanningFeature $features reflective_intent 0.00))
        ($externalEvidence (qwestorPlanningFeature $features external_evidence 0.00))
        ($synthesisReady (qwestorPlanningFeature $features synthesis_ready 0.00))
        ($taskPlan (qwestorPlanningFeature $features task_plan 0.00))
        ($multiSource (qwestorPlanningFeature $features multi_source 0.00))
        ($waiting (qwestorPlanningFeature $features additional_information_expected 0.00))
        ($missingInput (qwestorPlanningFeature $features missing_required_input 0.00))
        ($researchFeasibility (- 1.0 $missingInput))
        ($operationPressure
            (maxNumber $externalEvidence
                (maxNumber $reflection
                    (maxNumber $taskPlan
                        (maxNumber $multiSource $verification)))))
    )
        (case $actionId (
            (act_clarify (clipUnit (maxNumber $ambiguity $missingInput)))
            (act_search
                (clipUnit
                    (* $researchFeasibility
                       (* (- 1.0 $verification)
                          (+ (* 0.75 $externalEvidence)
                             (* 0.15 (- 1.0 $familiarity)))))))
            (act_think
                (clipUnit
                    (* $researchFeasibility
                       (+ (* 0.65 $reflection)
                          (+ (* 0.20 $complexity) (* 0.15 $novelty))))))
            (act_respond
                (clipUnit
                    (- (+ (* 0.70 $specificity)
                          (+ (* 0.20 $urgency) (* 0.10 $familiarity)))
                       (* 0.65 $operationPressure))))
            (act_decompose
                (clipUnit
                    (* $researchFeasibility
                       (+ (* 0.80 $taskPlan) (* 0.20 $complexity)))))
            (act_verify
                (clipUnit
                    (* $researchFeasibility
                       (+ (* 0.65 $verification)
                          (+ (* 0.20 $risk) (* 0.15 $failure))))))
            (act_synthesize
                (clipUnit
                    (* (- 1.0 $reflection)
                       (* $synthesisReady
                          (+ (* 0.85 $multiSource) (* 0.15 $complexity))))))
            (act_wait (clipUnit $waiting))
            ($_ 0.0)
        ))
    )
)

;; Combine intrinsic utility, context adjustment, and graded action fit
(= (qwestorCandidateCorrelationValue
        $basePairs $adjustments $support $goalName)
    (let* (
        ($raw
            (+
                (featurePairsGet $basePairs $goalName 0.0)
                (featurePairsGet $adjustments $goalName 0.0)
            ))
    )
        (if (schemaIsAntiGoal (qwestorSchema) $goalName)
            (clipUnit (+ $raw (* 0.40 (- 1.0 $support))))
            (clipRange (* $raw (+ 0.20 (* 0.80 $support))) -1.0 1.0)
        )
    )
)

;; Build full-schema named correlations recursively
(= (qwestorCandidateCorrelationPairsLoop
        $goalNames $basePairs $adjustments $support)
    (if (== $goalNames ())
        ()
        (let* (
            (($head $tail) (decons $goalNames))
            ($value
                (qwestorCandidateCorrelationValue
                    $basePairs $adjustments $support $head))
        )
            (cons-atom
                ($head $value)
                (qwestorCandidateCorrelationPairsLoop
                    $tail $basePairs $adjustments $support)
            )
        )
    )
)

;; Build all twenty candidate correlations in canonical order
(= (qwestorCandidateCorrelationPairs $actionId $features)
    (qwestorCandidateCorrelationPairsLoop
        (qwestorGoalNames)
        (qwestorActionBaseCorrelationPairs $actionId)
        (qwestorContextAdjustments $actionId $features)
        (qwestorActionSupport $actionId $features)
    )
)

;; Return an intrinsic risk estimate used only for reporting
(= (qwestorCandidateRiskEstimate $actionId $features)
    (let* (
        ($risk (qwestorPlanningFeature $features risk 0.00))
        ($ambiguity (qwestorPlanningFeature $features ambiguity 0.00))
        ($effort (qwestorPlanningFeature $features effort 0.00))
        ($base
            (symbolMapGet
                ((act_clarify 0.03) (act_search 0.08) (act_think 0.10)
                 (act_respond 0.08) (act_decompose 0.06) (act_verify 0.02)
                 (act_synthesize 0.07) (act_wait 0.01))
                $actionId
                0.10
            ))
        ($riskWeight
            (symbolMapGet
                ((act_clarify 0.05) (act_search 0.15) (act_think 0.30)
                 (act_respond 0.40) (act_decompose 0.10) (act_verify 0.05)
                 (act_synthesize 0.15) (act_wait 0.02))
                $actionId
                0.20
            ))
    )
        (clipUnit
            (+ $base
               (+ (* $riskWeight $risk)
                  (* 0.05 (+ $ambiguity $effort))))
        )
    )
)

;; Build diagnostic metadata without adding another decision penalty
(= (qwestorCandidateMetadata $actionId $features)
    (
        (risk (qwestorCandidateRiskEstimate $actionId $features))
        (generated_by qwestor_contextual_planner)
        (action_policy $actionId)
        (ambiguity (qwestorPlanningFeature $features ambiguity 0.00))
        (risk_feature (qwestorPlanningFeature $features risk 0.00))
        (effort (qwestorPlanningFeature $features effort 0.00))
        (retrieval_required
            (qwestorPlanningFeature $features external_evidence 0.00))
        (evidence_available
            (qwestorPlanningFeature $features evidence_available 0.00))
        (synthesis_ready
            (qwestorPlanningFeature $features synthesis_ready 0.00))
        (primary_operation
            (qwestorPlanningValue $features primary_operation unknown))
        (final_deliverable
            (qwestorPlanningValue $features final_deliverable unknown))
    )
)

;; Build one full-schema action candidate
(= (qwestorBuildCandidate $actionId $features)
    (actionCandidate
        $actionId
        (qwestorSchema)
        (qwestorGoalVectorFromPairs
            (qwestorCandidateCorrelationPairs $actionId $features))
        (qwestorDeltaVector (qwestorActionDeltaPairs $actionId))
        (qwestorCandidateMetadata $actionId $features)
    )
)

;; Exclude actions only when a genuine semantic precondition blocks useful work
(= (qwestorAvailableActionIds $features)
    (let* (
        ($waiting
            (qwestorPlanningFeature $features additional_information_expected 0.00))
    )
        (if (== $waiting 1.0)
            (act_wait act_clarify)
            (act_clarify act_search act_think act_respond act_decompose
             act_verify act_synthesize)
        )
    )
)

;; Build candidates recursively from available action ids
(= (qwestorBuildCandidatesFromIds $actionIds $features)
    (if (== $actionIds ())
        ()
        (let* (
            (($head $tail) (decons $actionIds))
        )
            (cons-atom
                (qwestorBuildCandidate $head $features)
                (qwestorBuildCandidatesFromIds $tail $features)
            )
        )
    )
)

;; Build contextual candidates from raw Qwestor perception
(= (qwestorBuildCandidates $state $perception)
    (let* (
        ($features (qwestorStimulusFeatureFn $state $perception))
    )
        (qwestorBuildCandidatesFromIds
            (qwestorAvailableActionIds $features)
            $features
        )
    )
)

;; Validate every candidate in a list
(= (qwestorValidateCandidates $candidates)
    (if (== $candidates ())
        (validationOk ())
        (let* (
            (($head $tail) (decons $candidates))
            ($headResult (validateActionCandidate $head))
        )
            (if (validationIsOk $headResult)
                (qwestorValidateCandidates $tail)
                $headResult
            )
        )
    )
)

;; Compute one response-style score from named modulators
(= (qwestorResponseStyleScore $state $styleName)
    (case $styleName (
        (style_concise
            (clipUnit
                (+
                    (+ (* 0.60 (stateModulator $state urgency))
                       (* 0.25 (stateModulator $state error_tolerance)))
                    (* 0.15 (- 1.0 (stateModulator $state resolution)))
                )))
        (style_thorough
            (clipUnit
                (+
                    (+ (* 0.45 (stateModulator $state resolution))
                       (* 0.30 (stateModulator $state threshold)))
                    (* 0.25 (- 1.0 (stateModulator $state urgency)))
                )))
        (style_exploratory
            (clipUnit
                (+
                    (+ (* 0.45 (stateModulator $state approach))
                       (* 0.40 (stateModulator $state creativity)))
                    (* 0.15 (- 1.0 (stateModulator $state risk_aversion)))
                )))
        (style_cautious
            (clipUnit
                (+
                    (+ (* 0.35 (stateModulator $state threshold))
                       (* 0.30 (stateModulator $state securing)))
                    (* 0.35 (stateModulator $state risk_aversion))
                )))
        (style_tutorial
            (clipUnit
                (+
                    (* 0.55 (- 1.0 (stateModulator $state user_expertise)))
                    (* 0.45 (stateModulator $state resolution))
                )))
        ($_ 0.0)
    ))
)

;; Return all response-style scores in deterministic order
(= (qwestorResponseStyleScores $state)
    (
        (style_concise (qwestorResponseStyleScore $state style_concise))
        (style_thorough (qwestorResponseStyleScore $state style_thorough))
        (style_exploratory (qwestorResponseStyleScore $state style_exploratory))
        (style_cautious (qwestorResponseStyleScore $state style_cautious))
        (style_tutorial (qwestorResponseStyleScore $state style_tutorial))
    )
)

;; Find the highest-scoring style pair while preserving order on ties
(= (qwestorBestStyleLoop $currentBest $remaining)
    (if (== $remaining ())
        $currentBest
        (let* (
            (($head $tail) (decons $remaining))
            ($nextBest
                (if (> (featurePairValue $head) (featurePairValue $currentBest))
                    $head
                    $currentBest
                ))
        )
            (qwestorBestStyleLoop $nextBest $tail)
        )
    )
)

;; Return the highest-scoring style pair
(= (qwestorBestStylePair $styleScores)
    (let* (
        (($first $rest) (decons $styleScores))
    )
        (qwestorBestStyleLoop $first $rest)
    )
)

;; Remove one style from a score list
(= (qwestorRemoveStyleScore $styleScores $styleName)
    (if (== $styleScores ())
        ()
        (let* (
            (($head $tail) (decons $styleScores))
        )
            (if (== (featurePairName $head) $styleName)
                (qwestorRemoveStyleScore $tail $styleName)
                (cons-atom
                    $head
                    (qwestorRemoveStyleScore $tail $styleName)
                )
            )
        )
    )
)

;; Select a primary style and an optional close secondary style
(= (qwestorResponseStyles $state)
    (let* (
        ($scores (qwestorResponseStyleScores $state))
        ($best (qwestorBestStylePair $scores))
        ($bestName (featurePairName $best))
        ($remaining (qwestorRemoveStyleScore $scores $bestName))
        ($second (qwestorBestStylePair $remaining))
        ($margin
            (qwestorConfigGet
                (qwestorDecisionConfig) SECONDARY_STYLE_MARGIN 0.08))
    )
        (if (<= (- (featurePairValue $best) (featurePairValue $second)) $margin)
            ($bestName (featurePairName $second))
            ($bestName)
        )
    )
)
