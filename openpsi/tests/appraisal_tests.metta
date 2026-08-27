!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/features)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../profile)
!(import! &self ../appraisal)

(= (appraisalTestFeatures $state $stimulus) $stimulus)
(= (appraisalTestCoreDeltas $state $features) ((valence 0.1)))
(= (appraisalTestAppDeltas $state $features) ((focus 0.2)))
(= (appraisalTestFeedback $state $stimulus $features) (goalChangeFeedback ((help_target 0.9))))

(= (appraisalTestSchema)
    (motivationSchema
        appraisal_test
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence) (focus) (valence focus))
        decision
        appraisal
    )
)

(= (appraisalTestProfile)
    (appraisalProfile
        appraisal_test
        (valence)
        appraisalTestFeatures
        appraisalTestCoreDeltas
        appraisalTestAppDeltas
        appraisalTestFeedback
        1.0
        ((focus 0.0 1.0))
    )
)

(= (appraisalTestState)
    (motivationState (appraisalTestSchema) (0.5 0.5 0.8) (0.5 0.4))
)

!(test
    (openPsiExtract (openPsiAppraisal (appraisalTestProfile)) (appraisalTestState))
    (appraisalTestState)
)


!(test
    (openPsiGoalChangeFeedback
        (openPsiAppraisal (appraisalTestProfile))
        (appraisalTestState)
        (stimulusFeatures ((progress 0.8)))
    )
    (goalChangeFeedback ((help_target 0.9)))
)

!(test
    (stateModulator
        (openPsiAppraise
            (openPsiAppraisal (appraisalTestProfile))
            (appraisalTestState)
            (stimulusFeatures ((progress 0.8)))
        )
        focus
    )
    0.6000000000000001
)
