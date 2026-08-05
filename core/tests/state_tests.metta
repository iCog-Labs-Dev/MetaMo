!(import! &self ../validation)
!(import! &self ../schema)
!(import! &self ../features)
!(import! &self ../state)
!(import! &self ../helper)
!(import! &self "../helpers.py")

(= (stateTestSchema)
    (motivationSchema
        state_test
        (magusGoalSchema (help) (risk) (individuation transcendence help risk) individuation transcendence)
        (modulatorSchema (valence threshold securing) (focus) (valence threshold securing focus))
        decision
        appraisal
    )
)

(= (stateTestState)
    (motivationState
        (stateTestSchema)
        (0.5 0.5 0.8 0.2)
        (0.4 0.5 0.6 0.3)
    )
)

(= (stateTestCandidate)
    (actionCandidate
        answer
        (stateTestSchema)
        (0.0 0.0 0.7 -0.2)
        (0.0 0.0 0.05 -0.01)
        ((source test) (risk 0.1))
    )
)

!(test
    (stateSchema (stateTestState))
    (stateTestSchema)
)

!(test
    (stateGoal (stateTestState) help)
    0.8
)

!(test
    (stateModulator (stateTestState) focus)
    0.3
)

!(test
    (candidateGoalDelta (stateTestCandidate) help)
    0.05
)

!(test
    (candidateRiskEstimate (stateTestCandidate))
    0.1
)

!(test
    (validationIsOk (validateMotivationState (stateTestState)))
    True
)

!(test
    (validationIsOk (validateActionCandidate (stateTestCandidate)))
    True
)

!(test
    (stateGoal (stateSetGoal (stateTestState) help 0.9) help)
    0.9
)

!(test
    (stateModulator (stateApplyModulatorDelta (stateTestState) focus 0.2) focus)
    0.5
)

!(test
    (> (stateDistance (stateTestState) (stateSetGoal (stateTestState) help 0.7)) 0.0)
    True
)
