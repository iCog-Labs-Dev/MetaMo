!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../functors)

(= (functorSchemaA)
    (motivationSchema
        functor_a
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence) () (valence))
        decision
        appraisal
    )
)

(= (functorSchemaB)
    (motivationSchema
        functor_b
        (magusGoalSchema (help curiosity) () (individuation transcendence help curiosity) individuation transcendence)
        (modulatorSchema (valence arousal) () (valence arousal))
        decision
        appraisal
    )
)

(= (functorForward)
    (translationFunctor
        ((1.0 0.0 0.0) (0.0 1.0 0.0) (0.0 0.0 1.0) (0.0 0.0 0.0))
        ((1.0) (0.0))
        (functorSchemaA)
        (functorSchemaB)
    )
)

(= (functorStateA)
    (motivationState (functorSchemaA) (0.5 0.5 0.8) (0.4))
)

!(test
    (translationSourceSchema (functorForward))
    (functorSchemaA)
)

!(test
    (validationIsOk (validateTranslationFunctor (functorForward)))
    True
)

!(test
    (stateSchema (simulatePeer (functorForward) (functorStateA)))
    (functorSchemaB)
)

!(test
    (stateGoal (simulatePeer (functorForward) (functorStateA)) help)
    0.8
)

!(test
    (stateModulator
        (adapterTranslateState
            (agentFrameAdapter (functorForward) none none none)
            (functorStateA)
        )
        valence
    )
    0.4
)
