(: QwestorContext Type)
(: qwestorContext (-> Expression QwestorContext))

(: QwestorOutcome Type)
(: qwestorOutcome (-> Symbol Expression QwestorOutcome))

(: QwestorPerception Type)
(: qwestorPerception (-> QwestorContext Expression QwestorPerception))

(: QwestorConsumedPerception Type)
(: qwestorConsumedPerception (-> QwestorPerception Expression QwestorConsumedPerception))

;; Build a clamped context in canonical signal order
(= (makeQwestorContext $pairs)
    (qwestorContext
        (
            (complexity (clipUnit (featurePairsGet $pairs complexity 0.30)))
            (specificity (clipUnit (featurePairsGet $pairs specificity 0.50)))
            (ambiguity (clipUnit (featurePairsGet $pairs ambiguity 0.00)))
            (requested_threshold (clipUnit (featurePairsGet $pairs requested_threshold 0.00)))
            (urgency (clipUnit (featurePairsGet $pairs urgency 0.00)))
            (user_expertise (clipUnit (featurePairsGet $pairs user_expertise 0.50)))
            (topic_familiarity (clipUnit (featurePairsGet $pairs topic_familiarity 0.50)))
            (failure_pressure (clipUnit (featurePairsGet $pairs failure_pressure 0.00)))
            (verification (clipUnit (featurePairsGet $pairs verification 0.00)))
            (reflective_intent (clipUnit (featurePairsGet $pairs reflective_intent 0.00)))
            (external_evidence (clipUnit (featurePairsGet $pairs external_evidence 0.00)))
            (evidence_available (clipUnit (featurePairsGet $pairs evidence_available 0.00)))
            (primary_operation (featurePairsGet $pairs primary_operation unknown))
            (final_deliverable (featurePairsGet $pairs final_deliverable unknown))
            (task_plan (clipUnit (featurePairsGet $pairs task_plan 0.00)))
            (multi_source (clipUnit (featurePairsGet $pairs multi_source 0.00)))
            (signed_valence (clipRange (featurePairsGet $pairs signed_valence 0.00) -1.0 1.0))
            (additional_information_expected
                (clipUnit (featurePairsGet $pairs additional_information_expected 0.00)))
            (missing_required_input
                (clipUnit (featurePairsGet $pairs missing_required_input 0.00)))
            (intent_type (featurePairsGet $pairs intent_type mixed))
            (query_type (featurePairsGet $pairs query_type unknown))
        )
    )
)

;; Return canonical pairs from a Qwestor context
(= (qwestorContextPairs (qwestorContext $pairs))
    $pairs
)

;; Return a named context value
(= (qwestorContextValue $context $name $default)
    (featurePairsGet (qwestorContextPairs $context) $name $default)
)

;; Return outcome fields in canonical order
(= (qwestorOutcomeNames)
    (short_help long_help grounding safety progress novel_yield original_yield
     breakthrough_yield coherence social_quality efficiency accuracy)
)

;; Clamp an assessed outcome into its canonical record shape
(= (qwestorCanonicalOutcomePairs $pairs)
    (
        (short_help (clipUnit (featurePairsGet $pairs short_help 0.50)))
        (long_help (clipUnit (featurePairsGet $pairs long_help 0.50)))
        (grounding (clipUnit (featurePairsGet $pairs grounding 0.50)))
        (safety (clipUnit (featurePairsGet $pairs safety 0.50)))
        (progress (clipUnit (featurePairsGet $pairs progress 0.50)))
        (novel_yield (clipUnit (featurePairsGet $pairs novel_yield 0.50)))
        (original_yield (clipUnit (featurePairsGet $pairs original_yield 0.50)))
        (breakthrough_yield
            (clipUnit (featurePairsGet $pairs breakthrough_yield 0.50)))
        (coherence (clipUnit (featurePairsGet $pairs coherence 0.50)))
        (social_quality (clipUnit (featurePairsGet $pairs social_quality 0.50)))
        (efficiency (clipUnit (featurePairsGet $pairs efficiency 0.50)))
        (accuracy (clipUnit (featurePairsGet $pairs accuracy 0.50)))
    )
)

;; Construct an assessed outcome for later goal feedback
(= (makeQwestorOutcome $outcomeId $pairs)
    (qwestorOutcome $outcomeId (qwestorCanonicalOutcomePairs $pairs))
)

;; Return the identifier from an assessed outcome
(= (qwestorOutcomeId (qwestorOutcome $outcomeId $pairs))
    $outcomeId
)

;; Return the named values from an assessed outcome
(= (qwestorOutcomePairs (qwestorOutcome $outcomeId $pairs))
    $pairs
)

;; Return a named value from an assessed outcome
(= (qwestorOutcomeValue $outcome $name $default)
    (featurePairsGet (qwestorOutcomePairs $outcome) $name $default)
)

;; Validate outcome coordinate count and bounds recursively
(= (qwestorOutcomePairsValid $names $pairs)
    (if (== $names ())
        (== (size-atom $pairs) 0)
        (if (== $pairs ())
            False
            (let* (
                (($nameHead $nameTail) (decons $names))
                (($pairHead $pairTail) (decons $pairs))
                ($pairName (featurePairName $pairHead))
                ($pairValue (featurePairValue $pairHead))
            )
                (if (and
                        (== $nameHead $pairName)
                        (and (>= $pairValue 0.0) (<= $pairValue 1.0)))
                    (qwestorOutcomePairsValid $nameTail $pairTail)
                    False
                )
            )
        )
    )
)

;; Validate an assessed Qwestor outcome
(= (qwestorValidateOutcome (qwestorOutcome $outcomeId $pairs))
    (if (qwestorOutcomePairsValid (qwestorOutcomeNames) $pairs)
        (validationOk (qwestorOutcome $outcomeId $pairs))
        (validationError invalid-qwestor-outcome (qwestorOutcome $outcomeId $pairs))
    )
)

;; Return neutral outcome data when no previous outcome exists
(= (qwestorPreviousOutcomePairs none)
    (qwestorOutcomeDefaults)
)

(= (qwestorPreviousOutcomePairs (qwestorOutcome $outcomeId $pairs))
    $pairs
)

;; Convert previous outcome data to goal-feedback feature names
(= (qwestorOutcomeFeedbackPairs $previousOutcome)
    (let* (
        ($pairs (qwestorPreviousOutcomePairs $previousOutcome))
    )
        (
            (outcome_short_help (featurePairsGet $pairs short_help 0.50))
            (outcome_long_help (featurePairsGet $pairs long_help 0.50))
            (outcome_grounding (featurePairsGet $pairs grounding 0.50))
            (outcome_safety (featurePairsGet $pairs safety 0.50))
            (outcome_progress (featurePairsGet $pairs progress 0.50))
            (outcome_novel_yield (featurePairsGet $pairs novel_yield 0.50))
            (outcome_original_yield (featurePairsGet $pairs original_yield 0.50))
            (outcome_breakthrough_yield
                (featurePairsGet $pairs breakthrough_yield 0.50))
            (outcome_coherence (featurePairsGet $pairs coherence 0.50))
            (outcome_social_quality (featurePairsGet $pairs social_quality 0.50))
            (outcome_efficiency (featurePairsGet $pairs efficiency 0.50))
            (outcome_accuracy (featurePairsGet $pairs accuracy 0.50))
        )
    )
)

;; Construct a perception from context and an optional previous outcome
(= (makeQwestorPerception $context $previousOutcome)
    (qwestorPerception $context $previousOutcome)
)

;; Return context from a Qwestor perception
(= (qwestorPerceptionContext (qwestorPerception $context $previousOutcome))
    $context
)

;; Return the optional previous outcome from a Qwestor perception
(= (qwestorPerceptionPreviousOutcome (qwestorPerception $context $previousOutcome))
    $previousOutcome
)

;; Return outcome feedback pairs for a perception or neutral fallback
(= (qwestorPerceptionOutcomePairs $perception)
    (case $perception (
        ((qwestorPerception $context $previousOutcome)
            (qwestorOutcomeFeedbackPairs $previousOutcome))
        ($_ (qwestorOutcomeFeedbackPairs none))
    ))
)

;; Separate a previous outcome and clear it from the continuing perception
(= (qwestorConsumePerceptionOutcome
        (qwestorPerception $context $previousOutcome))
    (qwestorConsumedPerception
        (qwestorPerception $context none)
        $previousOutcome
    )
)

;; Return the cleared perception after outcome consumption
(= (qwestorConsumedPerceptionValue
        (qwestorConsumedPerception $perception $consumedOutcome))
    $perception
)

;; Return the outcome removed during perception consumption
(= (qwestorConsumedOutcomeValue
        (qwestorConsumedPerception $perception $consumedOutcome))
    $consumedOutcome
)

;; Compute novelty from canonical context signals
(= (qwestorNovelty $context)
    (let* (
        ($weights (qwestorFeatureWeights))
        ($familiarity (qwestorContextValue $context topic_familiarity 0.50))
        ($complexity (qwestorContextValue $context complexity 0.30))
        ($reflection (qwestorContextValue $context reflective_intent 0.00))
        ($externalEvidence (qwestorContextValue $context external_evidence 0.00))
        ($externalBonus
            (* (qwestorConfigGet $weights NOVELTY_EXTERNAL_BONUS 0.30)
               $externalEvidence))
    )
        (clipUnit
            (+
                (+
                    (* (qwestorConfigGet $weights NOVELTY_FAMILIARITY_WEIGHT 0.30)
                       (- 1.0 $familiarity))
                    (* (qwestorConfigGet $weights NOVELTY_COMPLEXITY_WEIGHT 0.25)
                       $complexity)
                )
                (+
                    (* (qwestorConfigGet $weights NOVELTY_REFLECTION_WEIGHT 0.15)
                       $reflection)
                    $externalBonus
                )
            )
        )
    )
)

;; Compute conduciveness from canonical context signals
(= (qwestorConduciveness $context)
    (let* (
        ($weights (qwestorFeatureWeights))
        ($familiarity (qwestorContextValue $context topic_familiarity 0.50))
        ($ambiguity (qwestorContextValue $context ambiguity 0.00))
        ($valence (qwestorSignedValenceToUnit
            (qwestorContextValue $context signed_valence 0.00)))
        ($failure (qwestorContextValue $context failure_pressure 0.00))
        ($verification (qwestorContextValue $context verification 0.00))
        ($ambiguityPenalty
            (* (qwestorConfigGet $weights CONDUCIVENESS_AMBIGUITY_PENALTY 0.30)
               $ambiguity))
    )
        (clipUnit
            (-
                (+
                    (+
                        (* (qwestorConfigGet $weights CONDUCIVENESS_FAMILIARITY_WEIGHT 0.40)
                           $familiarity)
                        (* (qwestorConfigGet $weights CONDUCIVENESS_CLARITY_WEIGHT 0.20)
                           (- 1.0 $ambiguity))
                    )
                    (* (qwestorConfigGet $weights CONDUCIVENESS_VALENCE_WEIGHT 0.20)
                       $valence)
                )
                (+
                    (+
                        (* (qwestorConfigGet $weights CONDUCIVENESS_FAILURE_WEIGHT 0.20)
                           $failure)
                        (* (qwestorConfigGet $weights CONDUCIVENESS_VERIFICATION_WEIGHT 0.40)
                           $verification)
                    )
                    $ambiguityPenalty
                )
            )
        )
    )
)

;; Compute risk from canonical context signals
(= (qwestorRisk $context)
    (let* (
        ($weights (qwestorFeatureWeights))
        ($requestedThreshold (qwestorContextValue $context requested_threshold 0.00))
        ($failure (qwestorContextValue $context failure_pressure 0.00))
        ($familiarity (qwestorContextValue $context topic_familiarity 0.50))
        ($verification (qwestorContextValue $context verification 0.00))
        ($ambiguity (qwestorContextValue $context ambiguity 0.00))
        ($ambiguityPenalty
            (* (qwestorConfigGet $weights RISK_AMBIGUITY_PENALTY 0.30)
               $ambiguity))
    )
        (clipUnit
            (+
                (+
                    (+
                        (* (qwestorConfigGet $weights RISK_THRESHOLD_WEIGHT 0.30)
                           $requestedThreshold)
                        (* (qwestorConfigGet $weights RISK_FAILURE_WEIGHT 0.20)
                           $failure)
                    )
                    (+
                        (* (qwestorConfigGet $weights RISK_UNFAMILIARITY_WEIGHT 0.10)
                           (- 1.0 $familiarity))
                        (* (qwestorConfigGet $weights RISK_VERIFICATION_WEIGHT 0.60)
                           $verification)
                    )
                )
                $ambiguityPenalty
            )
        )
    )
)

;; Compute effort from canonical context signals
(= (qwestorEffort $context)
    (let* (
        ($weights (qwestorFeatureWeights))
        ($complexity (qwestorContextValue $context complexity 0.30))
        ($ambiguity (qwestorContextValue $context ambiguity 0.00))
        ($taskPlan (qwestorContextValue $context task_plan 0.00))
        ($multiSource (qwestorContextValue $context multi_source 0.00))
        ($planBonus
            (* (qwestorConfigGet $weights EFFORT_PLAN_BONUS 0.50)
               $taskPlan))
        ($multiSourceBonus
            (* (qwestorConfigGet $weights EFFORT_MULTI_SOURCE_BONUS 0.40)
               $multiSource))
    )
        (clipUnit
            (+
                (+
                    (* (qwestorConfigGet $weights EFFORT_COMPLEXITY_WEIGHT 0.20)
                       $complexity)
                    (* (qwestorConfigGet $weights EFFORT_AMBIGUITY_WEIGHT 0.10)
                       $ambiguity)
                )
                (+ $planBonus $multiSourceBonus)
            )
        )
    )
)

(= (qwestorSynthesisReadiness $context)
    (let* (
        ($multiSource (qwestorContextValue $context multi_source 0.00))
        ($retrievalRequired
            (qwestorContextValue $context external_evidence 0.00))
        ($evidenceAvailable
            (qwestorContextValue $context evidence_available 0.00))
        ($missingInput
            (qwestorContextValue $context missing_required_input 0.00))
        ($availableWithoutRetrieval
            (maxNumber $evidenceAvailable (- 1.0 $retrievalRequired)))
    )
        (clipUnit
            (* $multiSource
               (* (- 1.0 $retrievalRequired)
                  (* $availableWithoutRetrieval (- 1.0 $missingInput)))))
    )
)

;; Convert a Qwestor context into generic and application feature pairs
(= (qwestorStimulusFeatures $context)
    (stimulusFeatures
        (
            (novelty (qwestorNovelty $context))
            (conduciveness (qwestorConduciveness $context))
            (risk (qwestorRisk $context))
            (effort (qwestorEffort $context))
            (complexity (qwestorContextValue $context complexity 0.30))
            (specificity (qwestorContextValue $context specificity 0.50))
            (ambiguity (qwestorContextValue $context ambiguity 0.00))
            (requested_threshold (qwestorContextValue $context requested_threshold 0.00))
            (urgency (qwestorContextValue $context urgency 0.00))
            (user_expertise (qwestorContextValue $context user_expertise 0.50))
            (topic_familiarity (qwestorContextValue $context topic_familiarity 0.50))
            (failure_pressure (qwestorContextValue $context failure_pressure 0.00))
            (verification (qwestorContextValue $context verification 0.00))
            (reflective_intent (qwestorContextValue $context reflective_intent 0.00))
            (external_evidence (qwestorContextValue $context external_evidence 0.00))
            (evidence_available (qwestorContextValue $context evidence_available 0.00))
            (synthesis_ready (qwestorSynthesisReadiness $context))
            (primary_operation (qwestorContextValue $context primary_operation unknown))
            (final_deliverable (qwestorContextValue $context final_deliverable unknown))
            (task_plan (qwestorContextValue $context task_plan 0.00))
            (multi_source (qwestorContextValue $context multi_source 0.00))
            (signed_valence (qwestorContextValue $context signed_valence 0.00))
            (valence_unit (qwestorSignedValenceToUnit
                (qwestorContextValue $context signed_valence 0.00)))
            (additional_information_expected
                (qwestorContextValue $context additional_information_expected 0.00))
            (missing_required_input
                (qwestorContextValue $context missing_required_input 0.00))
            (intent_type (qwestorContextValue $context intent_type mixed))
            (query_type (qwestorContextValue $context query_type unknown))
        )
    )
)

;; Extract features from a context or perception
(= (qwestorStimulusFeatureFn $state $contextOrPerception)
    (case $contextOrPerception (
        ((qwestorPerception $context $previousOutcome)
            (qwestorStimulusFeatures $context))
        ((qwestorContext $pairs)
            (qwestorStimulusFeatures $contextOrPerception))
        ($_
            (qwestorStimulusFeatures (makeQwestorContext (qwestorNeutralContext))))
    ))
)
