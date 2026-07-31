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

!(test
    (candidateId
        (decisionAction
            (profiledMagusDecide
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
                    ()
                    ()
                    none
                    0.01
                    0.02
                    0.05
                    0.0
                    0.1
                )
                defaultGoalChangeDeltaG
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
                (
                    (actionCandidate weak
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
                        (0.0 0.0 0.1 0.0)
                        0.1
                        (0.0 0.0 0.0 0.0)
                        ()
                    )
                    (actionCandidate strong
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
                        (0.0 0.0 0.9 0.0)
                        0.1
                        (0.0 0.0 0.0 0.0)
                        ()
                    )
                )
                (goalChangeFeedback ())
                0.5
                0.5
            )
        )
    )
    strong
)

!(test
    (profiledMagusUnit (motivationState schema (0.5) (0.5)))
    (motivationState schema (0.5) (0.5))
)

