!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/features)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../correlation)
!(import! &self ../profile)
!(import! &self ../goal_change)

!(test
    (size-atom
        (defaultGoalChangeDeltaG
            (decisionProfile
                demo
                (motivationSchema
                    demo
                    (magusGoalSchema
                        (help)
                        (risk)
                        (individuation transcendence help risk)
                        individuation
                        transcendence
                    )
                    (modulatorSchema
                        (resolution)
                        ()
                        (resolution)
                    )
                    decision
                    appraisal
                )
                ((help (resolution)))
                (help)
                ()
                ()
                ((risk 1.0))
                ((individuation individuation_target))
                ((risk risk_target))
                none
                0.01
                0.02
                0.05
                0.0
                0.1
            )
            (motivationState
                (motivationSchema
                    demo
                    (magusGoalSchema
                        (help)
                        (risk)
                        (individuation transcendence help risk)
                        individuation
                        transcendence
                    )
                    (modulatorSchema
                        (resolution)
                        ()
                        (resolution)
                    )
                    decision
                    appraisal
                )
                (0.5 0.5 0.8 0.2)
                (0.7)
            )
            (actionCandidate answer
                (motivationSchema
                    demo
                    (magusGoalSchema
                        (help)
                        (risk)
                        (individuation transcendence help risk)
                        individuation
                        transcendence
                    )
                    (modulatorSchema
                        (resolution)
                        ()
                        (resolution)
                    )
                    decision
                    appraisal
                )
                (0.0 0.0 0.9 0.1)
                0.1
                (0.0 0.0 0.01 0.0)
                ()
            )
            (goalChangeFeedback ((individuation_target 0.6) (risk_target 0.1)))
            0.5
            0.5
        )
    )
    4
)

