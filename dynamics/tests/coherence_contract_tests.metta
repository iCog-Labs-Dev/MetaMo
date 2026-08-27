!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../coherence)

(= (coherenceTestSchema)
    (motivationSchema
        synthetic
        (magusGoalSchema (help) (risk) (individuation transcendence help risk) individuation transcendence)
        (modulatorSchema (valence arousal approach resolution threshold securing) (focus) (valence arousal approach resolution threshold securing focus))
        decision
        appraisal
    )
)

(= (coherenceState)
    (motivationState
        (coherenceTestSchema)
        (0.5 0.5 0.8 0.2)
        (0.5 0.5 0.5 0.5 0.5 0.5 0.3)
    )
)

(= (coherenceSparseSchema)
    (motivationSchema
        sparse
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence threshold securing) () (valence threshold securing))
        decision
        appraisal
    )
)

(= (coherenceSparseState)
    (motivationState
        (coherenceSparseSchema)
        (0.5 0.5 0.8)
        (0.5 0.5 0.5)
    )
)

!(test
    (> (size-atom (selfModelVector (estimateSelfModel (makeDefaultCoherencePolicy) (coherenceState)))) 0)
    True
)

!(test
    (selfModelDriftHolds
        (measureSelfModelDrift
            (makeDefaultCoherencePolicy)
            (coherenceState)
            (coherenceState)
        )
    )
    True
)

!(test
    (stateSchema
        (blendResultState
            (measureBlend
                (makeDefaultCoherencePolicy)
                (coherenceState)
                (coherenceState)
            )
        )
    )
    (coherenceTestSchema)
)

!(test
    (stateModulatorOrDefault (coherenceSparseState) resolution 0.0)
    0.0
)

!(test
    (selfModelDriftHolds
        (measureSelfModelDrift
            (makeDefaultCoherencePolicy)
            (coherenceSparseState)
            (coherenceSparseState)
        )
    )
    True
)
