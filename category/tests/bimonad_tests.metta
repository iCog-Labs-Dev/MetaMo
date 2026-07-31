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

(= (bimonadSmokeFeatures $state $stimulus) $stimulus)
(= (bimonadSmokeCoreDeltas $state $features) ((valence 0.0)))
(= (bimonadSmokeAppDeltas $state $features) ())
(= (bimonadSmokeFeedback $state $stimulus $features) (goalChangeFeedback ()))

(= (bimonadSmokeSchema)
    (motivationSchema
        bimonad_smoke
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence threshold securing) () (valence threshold securing))
        decision
        appraisal
    )
)

(= (bimonadSmokeProfile)
    (decisionProfile
        bimonad_smoke
        (bimonadSmokeSchema)
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

(= (bimonadSmokeAppraisalProfile)
    (appraisalProfile
        bimonad_smoke
        (valence)
        bimonadSmokeFeatures
        bimonadSmokeCoreDeltas
        bimonadSmokeAppDeltas
        bimonadSmokeFeedback
        1.0
        ()
    )
)

(= (bimonadSmokeBimonad)
    (metaMoPseudoBimonad
        (openPsiAppraisal (bimonadSmokeAppraisalProfile))
        (magusDecision (bimonadSmokeProfile) defaultGoalChangeDeltaG 0.5 0.5)
        (makeDefaultStabilityPolicy)
        (makeDefaultCoherencePolicy)
        none
        ()
    )
)

(= (bimonadSmokeState)
    (motivationState (bimonadSmokeSchema) (0.5 0.5 0.8) (0.5 0.5 0.5))
)

(= (bimonadSmokeCandidate)
    (actionCandidate answer (bimonadSmokeSchema) (0.0 0.0 0.8) 0.0 (0.0 0.0 0.0) ())
)

!(test
    (bimonadStability (bimonadSmokeBimonad))
    (makeDefaultStabilityPolicy)
)

!(test
    (transitionComputationAction
        (computeTransition
            (bimonadSmokeBimonad)
            (bimonadSmokeState)
            (stimulusFeatures ())
            ((bimonadSmokeCandidate))
        )
    )
    (bimonadSmokeCandidate)
)


!(test
    (diagnosticsFinalInSafeRegion
        (diagnosedDiagnostics
            (stepWithDiagnostics
                (bimonadSmokeBimonad)
                (bimonadSmokeState)
                (stimulusFeatures ())
                ((bimonadSmokeCandidate))
                True
            )
        )
    )
    True
)

!(test
    (stateSchema
        (transitionState
            (stepTargetOnly
                (bimonadSmokeBimonad)
                (bimonadSmokeState)
                (stimulusFeatures ())
                ((bimonadSmokeCandidate))
            )
        )
    )
    (bimonadSmokeSchema)
)