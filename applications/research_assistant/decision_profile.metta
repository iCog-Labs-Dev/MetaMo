
;; Return the generic decision profile data for Research Assistant.
(= (researchAssistantDecisionProfile)
    (let* (
        ($schema (researchAssistantSchema))
    )
        (decisionProfile
            research_assistant_magus_additive
            $schema
            (
                (help (resolution))
                (curiosity (arousal))
                (novelty (approach))
                (self_improvement (approach resolution))
                (ethics (threshold securing))
                (sociality (valence approach))
            )
            (help ethics)
            (curiosity novelty)
            (self_improvement sociality)
            (
                (misinformation 1.4)
                (unsupported_claim 1.3)
                (privacy_violation 1.6)
                (unsafe_assistance 1.8)
                (context_loss 1.1)
            )
            (
                (individuation individuation_target)
                (transcendence transcendence_target)
            )
            (
                (misinformation misinformation_target)
                (unsupported_claim unsupported_claim_target)
                (privacy_violation privacy_violation_target)
                (unsafe_assistance unsafe_assistance_target)
                (context_loss context_loss_target)
            )
            none
            0.01
            0.02
            0.05
            0.0
            0.1
        )
    )
)

;; Research Assistant compatibility override for curiosity/novelty versus ethics.
(= (researchAssistantCompatibilityFactor $profile $goalName $state $candidate)
    (let* (
        ($base (decisionProfileCompatibilityFactor $profile $goalName $state $candidate))
        ($ethicsCorrelation (candidateGoalCorrelation $candidate ethics))
    )
        (if (and (or (== $goalName curiosity) (== $goalName novelty)) (< $ethicsCorrelation -0.2))
            (* $base 0.5)
            $base
        )
    )
)

;; Return Research Assistant growth goals.
(= (researchAssistantGrowthGoals)
    (curiosity novelty self_improvement)
)
