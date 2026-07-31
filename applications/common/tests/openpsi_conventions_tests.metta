!(import! &self ../../../core/validation)
!(import! &self ../../../core/schema)
!(import! &self ../../../core/features)
!(import! &self ../../../core/state)
!(import! &self ../openpsi_conventions)

!(test
    (featureMapHas
        (commonOpenPsiGoalFeedback
            (motivationState
                (motivationSchema
                    research_assistant
                    (magusGoalSchema
                        (help)
                        (misinformation)
                        (individuation transcendence help misinformation)
                        individuation
                        transcendence
                    )
                    (modulatorSchema
                        (valence arousal approach resolution threshold securing)
                        ()
                        (valence arousal approach resolution threshold securing)
                    )
                    decision
                    appraisal
                )
                (0.5 0.5 0.8 0.35)
                (0.5 0.5 0.5 0.5 0.5 0.5)
            )
            stimulus
            (stimulusFeatures ((novelty 0.4) (conduciveness 0.8) (risk 0.2) (effort 0.3)))
        )
        safety_pressure
    )
    True
)

