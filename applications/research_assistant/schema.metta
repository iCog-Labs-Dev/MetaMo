
;; Return Research Assistant goals in exact Python order.
;; Example: (researchAssistantGoalNames) -> (individuation transcendence help ...)
(= (researchAssistantGoalNames)
    (individuation transcendence help curiosity novelty self_improvement ethics sociality misinformation unsupported_claim privacy_violation unsafe_assistance context_loss)
)

;; Return Research Assistant primary goals in exact Python order.
;; Example: (researchAssistantPrimaryGoalNames) -> (help curiosity novelty self_improvement ethics sociality)
(= (researchAssistantPrimaryGoalNames)
    (help curiosity novelty self_improvement ethics sociality)
)

;; Return Research Assistant anti-goals in exact Python order.
;; Example: (researchAssistantAntiGoalNames) -> (misinformation unsupported_claim privacy_violation unsafe_assistance context_loss)
(= (researchAssistantAntiGoalNames)
    (misinformation unsupported_claim privacy_violation unsafe_assistance context_loss)
)

;; Return Research Assistant core modulators in exact Python order.
;; Example: (researchAssistantModulatorNames) -> (valence arousal approach resolution threshold securing)
(= (researchAssistantModulatorNames)
    (valence arousal approach resolution threshold securing)
)

;; Return the canonical MAGUS goal schema for Research Assistant.
;; Example: (researchAssistantGoalSchema) -> magusGoalSchema
(= (researchAssistantGoalSchema)
    (let* (
        ($primaryGoals (researchAssistantPrimaryGoalNames))
        ($antiGoals (researchAssistantAntiGoalNames))
        ($allGoals (researchAssistantGoalNames))
    )
        (magusGoalSchema
            $primaryGoals
            $antiGoals
            $allGoals
            individuation
            transcendence
        )
    )
)

;; Return the canonical modulator schema for Research Assistant.
;; Example: (researchAssistantModulatorSchema) -> modulatorSchema
(= (researchAssistantModulatorSchema)
    (let* (
        ($modulators (researchAssistantModulatorNames))
    )
        (modulatorSchema
            $modulators
            ()
            $modulators
        )
    )
)

;; Return the full canonical motivation schema for Research Assistant.
;; Example: (researchAssistantSchema) -> motivationSchema
(= (researchAssistantSchema)
    (let* (
        ($goalSchema (researchAssistantGoalSchema))
        ($modulatorSchema (researchAssistantModulatorSchema))
    )
        (motivationSchema
            research_assistant
            $goalSchema
            $modulatorSchema
            research_assistant_magus_additive
            research_assistant_openpsi
        )
    )
)

;; Return a goal index by name as a validation result.
;; Example: (researchAssistantGoalIndex help) -> (validationOk 2)
(= (researchAssistantGoalIndex $goalName)
    (schemaGoalIndex (researchAssistantSchema) $goalName)
)

;; Return a modulator index by name as a validation result.
;; Example: (researchAssistantModulatorIndex valence) -> (validationOk 0)
(= (researchAssistantModulatorIndex $modulatorName)
    (schemaModulatorIndex (researchAssistantSchema) $modulatorName)
)

;; Return default goal values in coordinate order.
;; Example: (researchAssistantDefaultGoals) -> (0.5 0.5 0.8 ...)
(= (researchAssistantDefaultGoals)
    (0.5 0.5 0.8 0.6 0.4 0.3 0.9 0.2 0.35 0.35 0.30 0.35 0.25)
)

;; Return default modulator values in coordinate order.
;; Example: (researchAssistantDefaultModulators) -> (0.5 0.5 0.5 0.5 0.5 0.5)
(= (researchAssistantDefaultModulators)
    (0.5 0.5 0.5 0.5 0.5 0.5)
)

;; Return goal descriptions as application-owned data.
;; Example: (researchAssistantGoalDescription help) -> "useful_answers"
(= (researchAssistantGoalDescription $goalName)
    (symbolMapGet
        (
            (individuation identity_safety_and_coherent_operation)
            (transcendence beneficial_growth_exploration_and_learning)
            (help useful_answers_and_task_completion)
            (curiosity investigation_and_question_generation)
            (novelty creative_but_bounded_new_directions)
            (self_improvement learning_from_interaction_and_improving_methods)
            (ethics safe_honest_and_responsible_behavior)
            (sociality cooperative_communication_with_the_user)
            (misinformation avoid_false_or_misleading_claims)
            (unsupported_claim avoid_unsupported_or_fabricated_claims)
            (privacy_violation avoid_exposing_private_or_sensitive_information)
            (unsafe_assistance avoid_harmful_or_unsafe_instructions)
            (context_loss avoid_ignoring_supplied_context)
        )
        $goalName
        unknown_goal
    )
)

;; Build a goal vector from name/value pairs, defaulting missing coordinates to zero.
;; Example: (researchAssistantGoalVectorFromPairs ((help 0.8))) -> vector
(= (researchAssistantGoalVectorFromPairs $pairs)
    (
        (featurePairsGet $pairs individuation 0.0)
        (featurePairsGet $pairs transcendence 0.0)
        (featurePairsGet $pairs help 0.0)
        (featurePairsGet $pairs curiosity 0.0)
        (featurePairsGet $pairs novelty 0.0)
        (featurePairsGet $pairs self_improvement 0.0)
        (featurePairsGet $pairs ethics 0.0)
        (featurePairsGet $pairs sociality 0.0)
        (featurePairsGet $pairs misinformation 0.0)
        (featurePairsGet $pairs unsupported_claim 0.0)
        (featurePairsGet $pairs privacy_violation 0.0)
        (featurePairsGet $pairs unsafe_assistance 0.0)
        (featurePairsGet $pairs context_loss 0.0)
    )
)

;; Build a clamped candidate correlation vector from name/value pairs.
;; Example: (researchAssistantCorrelationVector ((help 2.0))) -> vector
(= (researchAssistantCorrelationVector $pairs)
    (clipVector (researchAssistantGoalVectorFromPairs $pairs) -1.0 1.0)
)

;; Build a clamped Delta G vector from name/value pairs.
;; Example: (researchAssistantDeltaVector ((help 0.2))) -> vector
(= (researchAssistantDeltaVector $pairs)
    (clipVector (researchAssistantGoalVectorFromPairs $pairs) -0.1 0.1)
)
