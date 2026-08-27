!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/features)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../profile)

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
    (goalChangeFeedback ((progress (featureMapNumeric $features progress 0.0))))
)

!(test
    (validationIsOk
        (appraisalProfileValidate
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
        )
    )
    True
)

!(test
    (appraisalProfileGoalChangeFeedback
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
        state
        stimulus
        (stimulusFeatures ((progress 0.8)))
    )
    (goalChangeFeedback ((progress 0.8)))
)

