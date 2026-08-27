!(import! &self ../validation)
!(import! &self ../schema)

!(test
    (validationIsOk
        (validateMagusGoalSchema
            (magusGoalSchema
                (help ethics)
                (misinformation)
                (individuation transcendence help ethics misinformation)
                individuation
                transcendence
            )
        )
    )
    True
)

!(test
    (schemaIsAntiGoal
        (motivationSchema
            research
            (magusGoalSchema
                (help ethics)
                (misinformation)
                (individuation transcendence help ethics misinformation)
                individuation
                transcendence
            )
            (modulatorSchema
                (valence arousal)
                ()
                (valence arousal)
            )
            researchDecision
            researchAppraisal
        )
        misinformation
    )
    True
)

!(test
    (schemaGoalIndex
        (motivationSchema
            research
            (magusGoalSchema
                (help ethics)
                (misinformation)
                (individuation transcendence help ethics misinformation)
                individuation
                transcendence
            )
            (modulatorSchema
                (valence arousal)
                ()
                (valence arousal)
            )
            researchDecision
            researchAppraisal
        )
        help
    )
    (validationOk 2)
)

