!(import! &self ../validation)
!(import! &self ../schema)
!(import! &self ../state)

!(test
    (stateGoal
        (motivationState
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
            (0.5 0.5 0.8 0.9 0.2)
            (0.3 0.4)
        )
        help
    )
    0.8
)

!(test
    (candidateGoalCorrelation
        (actionCandidate
            answer
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
            (0.0 0.0 0.7 0.9 0.1)
            (0.0 0.0 0.01 0.02 -0.01)
            ()
        )
        ethics
    )
    0.9
)
