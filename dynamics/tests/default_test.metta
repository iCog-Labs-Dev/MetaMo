!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../stability)
!(import! &self ../coherence)
!(import! &self ../default)

(= (defaultSmokeSchema)
    (motivationSchema
        default_smoke
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence threshold securing) () (valence threshold securing))
        decision
        appraisal
    )
)

(= (defaultSafeState)
    (motivationState (defaultSmokeSchema) (0.8 0.2 0.2) (0.5 0.5 0.5))
)

(= (defaultUnsafeState)
    (motivationState (defaultSmokeSchema) (0.1 0.5 0.5) (0.5 0.5 0.5))
)

(= (defaultTargetState)
    (motivationState (defaultSmokeSchema) (0.7 0.3 0.3) (0.5 0.5 0.5))
)

!(test
    (defaultSafeRegionCheck (defaultSafeState))
    True
)

!(test
    (defaultSafeRegionCheck (defaultProject (defaultUnsafeState)))
    True
)

!(test
    (defaultDamping (defaultSafeState) (0.1 0.1 0.1))
    (0.1 0.1 0.1)
)

!(test
    (stateSchema (defaultBlend (defaultSafeState) (defaultTargetState)))
    (defaultSmokeSchema)
)
