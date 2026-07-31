!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../correlation)

!(test
    (validationIsOk
        (validateGoalCompatibilityMatrix
            (goalCompatibilityMatrix
                ((0.0 0.0) (0.0 0.0))
                1.0
                0.5
                1.5
            )
            2
        )
    )
    True
)

!(test
    (compatibilityFactorForGoal
        (goalCompatibilityMatrix
            ((0.0 0.0) (0.0 0.0))
            1.0
            0.5
            1.5
        )
        0
        (motivationState schema (0.5 0.5) ())
    )
    1.0
)

