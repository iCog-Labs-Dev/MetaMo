
;; Return exact goal-to-modulator mappings
(= (qwestorGoalModulatorMap)
    (
        (beneficial (valence resolution))
        (honesty (threshold securing failure_wariness))
        (safety (securing threshold risk_aversion))
        (help_short (urgency resolution))
        (help_long (resolution topic_familiarity))
        (knowledge (arousal resolution))
        (novelty (approach))
        (originality (creativity approach))
        (success_moderate (securing resolution))
        (success_breakthrough (approach creativity))
        (coherence (resolution failure_wariness))
        (social (valence user_expertise))
        (efficiency (urgency error_tolerance))
        (accuracy (threshold resolution topic_familiarity))
    )
)

;; Return goals supported primarily by individuation
(= (qwestorIndividuationGoals)
    (beneficial honesty safety help_short success_moderate coherence efficiency accuracy)
)

;; Return goals supported primarily by transcendence
(= (qwestorTranscendenceGoals)
    (knowledge novelty originality success_breakthrough)
)

;; Return goals balanced across both structural overgoals
(= (qwestorBalancedGoals)
    (help_long social)
)

;; Return Qwestor anti-goal penalty weights
(= (qwestorAntiGoalWeights)
    (
        (hallucinate 1.60)
        (redundant 0.80)
        (rabbit_hole 1.00)
        (premature 1.20)
    )
)

;; Build the complete Qwestor MAGUS decision profile
(= (qwestorDecisionProfile)
    (let* (
        ($schema (qwestorSchema))
        ($config (qwestorDecisionConfig))
    )
        (decisionProfile
            (motivationSchemaDecisionProfile $schema)
            $schema
            (qwestorGoalModulatorMap)
            (qwestorIndividuationGoals)
            (qwestorTranscendenceGoals)
            (qwestorBalancedGoals)
            (qwestorAntiGoalWeights)
            (
                (individuation individuation_target)
                (transcendence transcendence_target)
            )
            (
                (hallucinate hallucinate_target)
                (redundant redundant_target)
                (rabbit_hole rabbit_hole_target)
                (premature premature_target)
            )
            none
            (qwestorConfigGet $config OVERGOAL_DELTA_SCALE 0.01)
            (qwestorConfigGet $config ANTI_GOAL_DELTA_SCALE 0.16)
            (qwestorConfigGet $config PRIMARY_GOAL_DELTA_SCALE 0.18)
            (qwestorConfigGet $config CANDIDATE_DELTA_WEIGHT 0.25)
            (qwestorConfigGet $config MAX_GOAL_DELTA 0.10)
        )
    )
)

;; Return configured decision lambdas
(= (qwestorDecisionLambdas)
    (let* (
        ($config (qwestorDecisionConfig))
    )
        (
            (qwestorConfigGet $config LAMBDA_INDIVIDUATION 0.50)
            (qwestorConfigGet $config LAMBDA_TRANSCENDENCE 0.50)
        )
    )
)
