
(= (omegaClawDecisionProfile)
    (decisionProfile
        omegaclaw_magus_additive
        (omegaClawSchema)
        ((help_user (valence human_deference))
         (learn (approach context_depth))
         (cooperate (human_deference resolution))
         (responsiveness (urgency arousal))
         (clarity (resolution context_depth))
         (coherence (focus resolution))
         (reliability (threshold securing))
         (progress (urgency persistence))
         (adaptivity (approach arousal)))
        (help_user responsiveness clarity coherence reliability)
        (learn adaptivity)
        (cooperate progress)
        ((risk 0.50) (contradiction 0.75) (unsafe 1.00))
        ((gInd_over individuation_target)
         (gTrans_over transcendence_target))
        ((risk risk_target)
         (contradiction contradiction_target)
         (unsafe unsafe_target))
        none
        0.01
        0.02
        0.05
        0.0
        0.10))

