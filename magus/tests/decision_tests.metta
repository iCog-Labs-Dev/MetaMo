!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/features)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../../category/functors)
!(import! &self ../correlation)
!(import! &self ../profile)
!(import! &self ../goal_change)
!(import! &self ../decision)

(= (decisionTestSchema)
    (motivationSchema
        decision_test
        (magusGoalSchema (help) (risk) (individuation transcendence help risk) individuation transcendence)
        (modulatorSchema (resolution threshold securing) () (resolution threshold securing))
        decision
        appraisal
    )
)

(= (decisionTestProfile)
    (decisionProfile
        decision_test
        (decisionTestSchema)
        ((help (resolution)))
        (help)
        ()
        ()
        ((risk 1.0))
        ()
        ()
        none
        0.01
        0.02
        0.05
        0.0
        0.1
    )
)

(= (decisionTestState)
    (motivationState (decisionTestSchema) (0.5 0.5 0.8 0.2) (0.7 0.5 0.5))
)

(= (decisionWeakCandidate)
    (actionCandidate weak (decisionTestSchema) (0.0 0.0 0.1 0.0) (0.0 0.0 0.0 0.0) ())
)

(= (decisionStrongCandidate)
    (actionCandidate strong (decisionTestSchema) (0.0 0.0 0.9 0.0) (0.0 0.0 0.0 0.0) ())
)

(= (decisionTestDecision)
    (magusDecision (decisionTestProfile) defaultGoalChangeDeltaG 0.5 0.5)
)

!(test
    (profiledMagusUnit (decisionTestState))
    (decisionTestState)
)

!(test
    (> (decisionProfileOvergoalSupport (decisionTestProfile) help 0.9 0.1) 0.5)
    True
)

!(test
    (> (magusScore (decisionTestDecision) (decisionTestState) (decisionStrongCandidate))
       (magusScore (decisionTestDecision) (decisionTestState) (decisionWeakCandidate)))
    True
)

!(test
    (candidateId
        (decisionAction
            (magusDecide
                (decisionTestDecision)
                (decisionTestState)
                ((decisionWeakCandidate) (decisionStrongCandidate))
                (goalChangeFeedback ())
            )
        )
    )
    strong
)

!(test
    (size-atom
        (decisionDeltaG
            (magusDecide
                (decisionTestDecision)
                (decisionTestState)
                ((decisionStrongCandidate))
                (goalChangeFeedback ())
            )
        )
    )
    4
)
