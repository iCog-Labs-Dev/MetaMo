;; Return actions in deterministic decision order
(= (qwestorActionOrder)
    (act_clarify act_search act_think act_respond act_decompose act_verify
     act_synthesize act_wait)
)

;; Return response styles in deterministic tie-breaking order
(= (qwestorResponseStyleOrder)
    (style_concise style_thorough style_exploratory style_cautious style_tutorial)
)

;; Validate an action identifier
(= (qwestorNormalizeActionId $actionId)
    (if (listContains (qwestorActionOrder) $actionId)
        $actionId
        (validationError unknown-qwestor-action-id $actionId)
    )
)

;; Return registered base goal correlations and anti-goal exposures
(= (qwestorActionBaseCorrelationPairs $actionId)
    (symbolMapGet
        (
            (act_clarify
                ((beneficial 0.70) (honesty 0.85) (safety 0.75)
                 (help_short 0.30) (help_long 0.55) (knowledge 0.25)
                 (novelty 0.10) (originality 0.05) (success_moderate 0.75)
                 (success_breakthrough 0.10) (coherence 0.65) (social 0.70)
                 (efficiency 0.45) (accuracy 0.80) (hallucinate 0.05)
                 (redundant 0.10) (rabbit_hole 0.05) (premature 0.06)))
            (act_search
                ((beneficial 0.70) (honesty 0.85) (safety 0.65)
                 (help_short 0.55) (help_long 0.80) (knowledge 0.90)
                 (novelty 0.65) (originality 0.35) (success_moderate 0.75)
                 (success_breakthrough 0.55) (coherence 0.55) (social 0.35)
                 (efficiency 0.40) (accuracy 0.90) (hallucinate 0.10)
                 (redundant 0.15) (rabbit_hole 0.25) (premature 0.10)))
            (act_think
                ((beneficial 0.60) (honesty 0.65) (safety 0.55)
                 (help_short 0.25) (help_long 0.85) (knowledge 0.65)
                 (novelty 0.95) (originality 0.90) (success_moderate 0.45)
                 (success_breakthrough 0.90) (coherence 0.60) (social 0.25)
                 (efficiency 0.25) (accuracy 0.55) (hallucinate 0.15)
                 (redundant 0.15) (rabbit_hole 0.25) (premature 0.05)))
            (act_respond
                ((beneficial 0.80) (honesty 0.70) (safety 0.65)
                 (help_short 0.95) (help_long 0.60) (knowledge 0.45)
                 (novelty 0.45) (originality 0.50) (success_moderate 0.80)
                 (success_breakthrough 0.35) (coherence 0.75) (social 0.85)
                 (efficiency 0.90) (accuracy 0.75) (hallucinate 0.10)
                 (redundant 0.15) (rabbit_hole 0.05) (premature 0.10)))
            (act_decompose
                ((beneficial 0.75) (honesty 0.75) (safety 0.70)
                 (help_short 0.45) (help_long 0.85) (knowledge 0.65)
                 (novelty 0.40) (originality 0.30) (success_moderate 0.95)
                 (success_breakthrough 0.35) (coherence 0.90) (social 0.45)
                 (efficiency 0.65) (accuracy 0.80) (hallucinate 0.08)
                 (redundant 0.10) (rabbit_hole 0.15) (premature 0.04)))
            (act_verify
                ((beneficial 0.75) (honesty 1.00) (safety 0.90)
                 (help_short 0.55) (help_long 0.70) (knowledge 0.70)
                 (novelty 0.10) (originality 0.05) (success_moderate 0.85)
                 (success_breakthrough 0.10) (coherence 0.75) (social 0.35)
                 (efficiency 0.45) (accuracy 1.00) (hallucinate 0.01)
                 (redundant 0.12) (rabbit_hole 0.08) (premature 0.02)))
            (act_synthesize
                ((beneficial 0.80) (honesty 0.85) (safety 0.70)
                 (help_short 0.65) (help_long 0.90) (knowledge 0.85)
                 (novelty 0.65) (originality 0.75) (success_moderate 0.85)
                 (success_breakthrough 0.65) (coherence 0.95) (social 0.55)
                 (efficiency 0.70) (accuracy 0.85) (hallucinate 0.10)
                 (redundant 0.15) (rabbit_hole 0.15) (premature 0.08)))
            (act_wait
                ((beneficial 0.45) (honesty 0.80) (safety 0.85)
                 (help_short 0.05) (help_long 0.45) (knowledge 0.10)
                 (novelty 0.05) (originality 0.00) (success_moderate 0.55)
                 (success_breakthrough 0.05) (coherence 0.50) (social 0.30)
                 (efficiency 0.20) (accuracy 0.65) (hallucinate 0.00)
                 (redundant 0.00) (rabbit_hole 0.05) (premature 0.00)))
        )
        $actionId
        ()
    )
)

;; Return registered candidate goal-change hints
(= (qwestorActionDeltaPairs $actionId)
    (symbolMapGet
        (
            (act_clarify ((coherence 0.02) (accuracy 0.02) (premature -0.02)))
            (act_search ((knowledge 0.03) (accuracy 0.02)))
            (act_think ((novelty 0.03) (originality 0.03)
                        (success_breakthrough 0.02) (rabbit_hole 0.01)))
            (act_respond ((help_short 0.03) (social 0.02)))
            (act_decompose ((success_moderate 0.02) (coherence 0.03)
                            (premature -0.02)))
            (act_verify ((honesty 0.03) (safety 0.02) (accuracy 0.03)
                         (hallucinate -0.03) (premature -0.02)))
            (act_synthesize ((help_long 0.02) (knowledge 0.02) (coherence 0.03)))
            (act_wait ((safety 0.01) (premature -0.01)))
        )
        $actionId
        ()
    )
)
