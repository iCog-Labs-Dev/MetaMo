!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/features)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../profile)
!(import! &self ../appraisal)

(= (demoOpenPsiFeatureFn $state $stimulus)
    $stimulus
)

(= (demoOpenPsiCoreDeltas $state $features)
    ((valence 0.0) (arousal 0.0))
)

(= (demoOpenPsiApplicationDeltas $state $features)
    ((focus 0.1))
)

(= (demoOpenPsiFeedback $state $stimulus $features)
    (goalChangeFeedback ())
)

!(test
    (stateModulator
        (openPsiAppraiseWithProfile
            (appraisalProfile
                demo
                (valence arousal)
                demoOpenPsiFeatureFn
                demoOpenPsiCoreDeltas
                demoOpenPsiApplicationDeltas
                demoOpenPsiFeedback
                1.0
                ((focus 0.0 1.0))
            )
            (motivationState
                (motivationSchema
                    demo
                    (magusGoalSchema
                        (help)
                        ()
                        (individuation transcendence help)
                        individuation
                        transcendence
                    )
                    (modulatorSchema
                        (valence arousal)
                        (focus)
                        (valence arousal focus)
                    )
                    decision
                    appraisal
                )
                (0.5 0.5 0.8)
                (0.5 0.5 0.4)
            )
            (stimulusFeatures ((progress 0.8)))
        )
        valence
    )
    0.5
)

!(test
    (openPsiExtract
        (openPsiAppraisal profile)
        (motivationState schema (0.5) (0.5))
    )
    (motivationState schema (0.5) (0.5))
)

