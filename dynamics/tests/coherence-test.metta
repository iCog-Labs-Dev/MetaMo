!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../coherence)

(= (coherenceSmokeSchema)
    (motivationSchema
        coherence_smoke
        (magusGoalSchema (help) (risk) (individuation transcendence help risk) individuation transcendence)
        (modulatorSchema (valence arousal approach resolution threshold securing) (focus) (valence arousal approach resolution threshold securing focus))
        decision
        appraisal
    )
)

(= (coherenceSmokeState)
    (motivationState (coherenceSmokeSchema) (0.5 0.5 0.8 0.2) (0.5 0.5 0.5 0.5 0.5 0.5 0.3))
)

(= (coherenceSmokeTarget)
    (motivationState (coherenceSmokeSchema) (0.6 0.5 0.7 0.1) (0.6 0.5 0.5 0.5 0.5 0.5 0.3))
)

(= (coherenceSparseSchema)
    (motivationSchema
        coherence_sparse
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence threshold securing) () (valence threshold securing))
        decision
        appraisal
    )
)

(= (coherenceSparseState)
    (motivationState (coherenceSparseSchema) (0.5 0.5 0.8) (0.5 0.5 0.5))
)

!(test
    (> (calculateBlendFactor (makeDefaultCoherencePolicy) (coherenceSmokeState)) 0.0)
    True
)

!(test
    (selfModelDriftHolds
        (measureSelfModelDrift
            (makeDefaultCoherencePolicy)
            (coherenceSmokeState)
            (coherenceSmokeState)
        )
    )
    True
)

!(test
    (stateSchema
        (blendStates
            (makeDefaultCoherencePolicy)
            (coherenceSmokeState)
            (coherenceSmokeTarget)
        )
    )
    (coherenceSmokeSchema)
)

!(test
    (stateModulatorOrDefault (coherenceSparseState) resolution 0.0)
    0.0
)
