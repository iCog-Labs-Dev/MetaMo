!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../stability)

(= (stabilitySmokeSchema)
    (motivationSchema
        stability_smoke
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence threshold securing) () (valence threshold securing))
        decision
        appraisal
    )
)

(= (stabilitySafeState)
    (motivationState (stabilitySmokeSchema) (0.8 0.2 0.2) (0.5 0.5 0.5))
)

(= (stabilityUnsafeState)
    (motivationState (stabilitySmokeSchema) (0.1 0.5 0.5) (0.5 0.5 0.5))
)

!(test
    (isInSafeRegion (makeDefaultStabilityPolicy) (stabilitySafeState))
    True
)

!(test
    (isInSafeRegion (makeDefaultStabilityPolicy) (stabilityUnsafeState))
    False
)

!(test
    (boundaryPressure (makeDefaultStabilityPolicy) (stabilityUnsafeState))
    1.0
)

!(test
    (applyHomeostaticDamping
        (makeDefaultStabilityPolicy)
        (stabilitySafeState)
        (0.1 0.1 0.1)
    )
    (0.1 0.1 0.1)
)

!(test
    (isInSafeRegion
        (makeDefaultStabilityPolicy)
        (projectToSafeRegion (makeDefaultStabilityPolicy) (stabilityUnsafeState))
    )
    True
)

!(test
    (> (stateModulator
            (raiseBoundaryCaution (makeDefaultStabilityPolicy) (stabilityUnsafeState))
            threshold
        )
       0.5)
    True
)
