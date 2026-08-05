!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/features)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../correlation)
!(import! &self ../profile)

(= (profileContractSchema)
    (motivationSchema
        demo
        (magusGoalSchema
            (help)
            (risk)
            (individuation transcendence help risk)
            individuation
            transcendence
        )
        (modulatorSchema
            (resolution)
            ()
            (resolution)
        )
        decision
        appraisal
    )
)

(= (profileContractProfile)
    (decisionProfile
        demo
        (profileContractSchema)
        ((help (resolution)))
        (help)
        ()
        ()
        ((risk 1.0))
        ()
        ()
        none
        0.01
        0.02
        0.05
        0.0
        0.1
    )
)

(= (profileContractState)
    (motivationState
        (profileContractSchema)
        (0.5 0.5 0.8 0.2)
        (0.7)
    )
)

(= (profileContractCandidate)
    (actionCandidate
        answer
        (profileContractSchema)
        (0.0 0.0 0.9 0.1)
        (0.0 0.0 0.01 0.0)
        ()
    )
)

!(test
    (> (decisionProfileScoreCandidate
        (profileContractProfile)
        (profileContractState)
        (profileContractCandidate)
        0.5
        0.5
    ) -100.0)
    True
)


!(test
    (decisionProfileRelevantModulator
        (profileContractProfile)
        (profileContractState)
        help
    )
    0.7
)

