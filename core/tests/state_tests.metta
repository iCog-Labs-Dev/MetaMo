!(import! &self ../state)
!(import! &self ../helper)
!(import! &self "../helpers.py")
!(import! &self ../config)
!(import! &self ../../openpsi/config)


!(test
    (motivation (0.3 0.2 0.1 0.3) (0.4 0.6 0.7 0.8 0.9))
    (motivation (0.3 0.2 0.1 0.3) (0.4 0.6 0.7 0.8 0.9))
)

!(test
    (stimulus (1 2 3 4))
    (stimulus (1 2 3 4))
)

!(test
    (action act1 (0.1 0.2 0.3) 0.5 (0.1 0.0 -0.1))
    (action act1 (0.1 0.2 0.3) 0.5 (0.1 0.0 -0.1))
)

!(test
    (motivationGoals (motivation (0.3 0.2 0.1 0.3) (0.4 0.6 0.7)))
    (0.3 0.2 0.1 0.3)
)

!(test
    (motivationModulators (motivation (0.3 0.2 0.1 0.3) (0.4 0.6 0.7)))
    (0.4 0.6 0.7)
)

!(test
    (stimulusValues (stimulus (1 2 3 4)))
    (1 2 3 4)
)

!(test
    (actionDeltaG (action act1 (0.1 0.2 0.3) 0.5 (0.1 0.0 -0.1)))
    (0.1 0.0 -0.1)
)


!(test
    (validateMotivationState (motivation (0.3 0.2 0.1 0.3) (0.4 0.6 0.7 0.8 0.9)) 4 5)
    True
)

!(test
    (validateMotivationState (motivation (0.3 0.2 0.1 0.3) (0.4 0.6 0.7 0.8 0.9)) 3 5)
    False
)

!(test
    (validateMotivationalStateShape
        (motivation
            (0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8)
            (0.2 0.3 0.4 0.5 0.6 0.7)
        )
    )
    True
)

!(test
    (validateMotivationalStateShape
        (motivation
            (0.1 0.2 0.3 0.4 0.5 0.6 0.7)
            (0.2 0.3 0.4 0.5 0.6 0.7)
        )
    )
    False
)


!(test
    (validateActionState (action act1 (0.1 0.2 0.3) 0.5 (0.1 0.0 -0.1)) 3)
    True
)

!(test
    (validateActionState (action act1 (0.1 0.2 0.3) 0.5 (0.1 0.0)) 3)
    False
)

!(test
    (validateActionShape
        (action
            act8
            (0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8)
            0.5
            (0.0 0.1 0.0 -0.1 0.0 0.1 0.0 -0.1)
        )
    )
    True
)
!(test
    (copyMotivationState (motivation (0.3 0.2 0.1 0.3) (0.4 0.6 0.7)))
    (motivation (0.3 0.2 0.1 0.3) (0.4 0.6 0.7))
)

!(test
    (motivationStateDistance
        (motivation (0.3 0.2 0.1 0.3) (0.4 0.6 0.7 0.8 0.9))
        (motivation (0.3 0.2 0.1 0.6) (0.4 0.6 0.7 0.8 0.4))
    )
    0.8
)

!(test
    (motivationStateDiff
        (motivation (0.3 0.2 0.1 0.3) (0.4 0.6 0.7 0.8 0.9))
        (motivation (0.3 0.2 0.1 0.6) (0.4 0.6 0.7 0.8 0.4))
    )
    0.34
)
