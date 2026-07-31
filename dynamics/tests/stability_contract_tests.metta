!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../stability)

(= (stabilityTestSchema)
    (motivationSchema
        synthetic
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence threshold securing) () (valence threshold securing))
        decision
        appraisal
    )
)

!(test
    (isInSafeRegion
        (makeDefaultStabilityPolicy)
        (motivationState (stabilityTestSchema) (0.5 0.5 0.5) (0.2 0.3 0.4))
    )
    True
)

!(test
    (isInSafeRegion
        (makeDefaultStabilityPolicy)
        (motivationState (stabilityTestSchema) (0.1 0.5 0.5) (0.2 0.3 0.4))
    )
    False
)

!(test
    (stateModulator
        (raiseBoundaryCaution
            (makeDefaultStabilityPolicy)
            (motivationState (stabilityTestSchema) (0.1 0.5 0.5) (0.2 0.3 0.4))
        )
        threshold
    )
    0.55
)

!(test
    (isInSafeRegion
        (makeDefaultStabilityPolicy)
        (projectToSafeRegion
            (makeDefaultStabilityPolicy)
            (motivationState (stabilityTestSchema) (0.1 0.5 0.5) (0.2 0.3 0.4))
        )
    )
    True
)

