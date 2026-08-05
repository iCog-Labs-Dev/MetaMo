!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/features)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../../openpsi/profile)
!(import! &self ../../openpsi/appraisal)
!(import! &self ../../magus/correlation)
!(import! &self ../../magus/profile)
!(import! &self ../../magus/goal_change)
!(import! &self ../../magus/decision)
!(import! &self ../../dynamics/stability)
!(import! &self ../../dynamics/coherence)
!(import! &self ../diagnostics)
!(import! &self ../functors)
!(import! &self ../bimonad)

(= (bimonadTestFeatures $state $stimulus) $stimulus)
(= (bimonadTestCoreDeltas $state $features) ((valence 0.0)))
(= (bimonadTestAppDeltas $state $features) ())
(= (bimonadTestFeedback $state $stimulus $features) (goalChangeFeedback ()))

(= (bimonadTestSchema)
    (motivationSchema
        synthetic
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence threshold securing) () (valence threshold securing))
        decision
        appraisal
    )
)

(= (bimonadTestProfile)
    (decisionProfile
        synthetic
        (bimonadTestSchema)
        ((help (valence)))
        (help)
        ()
        ()
        ()
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

(= (bimonadTestAppraisal)
    (openPsiAppraisal
        (appraisalProfile
            synthetic
            (valence)
            bimonadTestFeatures
            bimonadTestCoreDeltas
            bimonadTestAppDeltas
            bimonadTestFeedback
            1.0
            ()
        )
    )
)

(= (bimonadTestDecision)
    (magusDecision (bimonadTestProfile) defaultGoalChangeDeltaG 0.5 0.5)
)

(= (bimonadTestBimonad)
    (metaMoPseudoBimonad
        (bimonadTestAppraisal)
        (bimonadTestDecision)
        (makeDefaultStabilityPolicy)
        (makeDefaultCoherencePolicy)
        none
        ()
    )
)

!(test
    (transitionComputationAction
        (computeTransition
            (bimonadTestBimonad)
            (motivationState (bimonadTestSchema) (0.5 0.5 0.8) (0.5 0.5 0.5))
            (stimulusFeatures ())
            ((actionCandidate answer (bimonadTestSchema) (0.0 0.0 0.8) (0.0 0.0 0.0) ()))
        )
    )
    (actionCandidate answer (bimonadTestSchema) (0.0 0.0 0.8) (0.0 0.0 0.0) ())
)

!(test
    (diagnosticsFinalInSafeRegion
        (diagnosedDiagnostics
            (stepWithDiagnostics
                (bimonadTestBimonad)
                (motivationState (bimonadTestSchema) (0.5 0.5 0.8) (0.5 0.5 0.5))
                (stimulusFeatures ())
                ((actionCandidate answer (bimonadTestSchema) (0.0 0.0 0.8) (0.0 0.0 0.0) ()))
                True
            )
        )
    )
    True
)
