!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../functors)

(= (translationSchemaA)
    (motivationSchema a (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence) (modulatorSchema (valence) () (valence)) decision appraisal)
)

(= (translationSchemaB)
    (motivationSchema b (magusGoalSchema (help curiosity) () (individuation transcendence help curiosity) individuation transcendence) (modulatorSchema (valence arousal) () (valence arousal)) decision appraisal)
)

!(test
    (validationIsOk
        (validateTranslationFunctor
            (translationFunctor
                ((1.0 0.0 0.0) (0.0 1.0 0.0) (0.0 0.0 1.0) (0.0 0.0 0.0))
                ((1.0) (0.0))
                (translationSchemaA)
                (translationSchemaB)
            )
        )
    )
    True
)

!(test
    (stateSchema
        (simulatePeer
            (translationFunctor
                ((1.0 0.0 0.0) (0.0 1.0 0.0) (0.0 0.0 1.0) (0.0 0.0 0.0))
                ((1.0) (0.0))
                (translationSchemaA)
                (translationSchemaB)
            )
            (motivationState (translationSchemaA) (0.5 0.5 0.8) (0.4))
        )
    )
    (translationSchemaB)
)

