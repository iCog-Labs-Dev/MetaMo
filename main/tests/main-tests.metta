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
!(import! &self ../../category/merge)
!(import! &self ../../category/diagnostics)
!(import! &self ../../category/functors)
!(import! &self ../../category/bimonad)
!(import! &self ../../core/runtime)
!(import! &self ../../core/registry)
!(import! &self ../main)

(= (mainSmokeStimulus $raw) $raw)
(= (mainSmokeFeatures $state $stimulus) $stimulus)
(= (mainSmokeCoreDeltas $state $features) ((valence 0.0)))
(= (mainSmokeAppDeltas $state $features) ())
(= (mainSmokeFeedback $state $stimulus $features) (goalChangeFeedback ()))

(= (mainSmokeSchema)
    (motivationSchema
        main_smoke
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence threshold securing) () (valence threshold securing))
        decision
        appraisal
    )
)

(= (mainSmokeProfile)
    (decisionProfile main_smoke (mainSmokeSchema) ((help (valence))) (help) () () () () () none 0.01 0.02 0.05 0.0 0.1)
)

(= (mainSmokeAppraisal)
    (appraisalProfile main_smoke (valence) mainSmokeFeatures mainSmokeCoreDeltas mainSmokeAppDeltas mainSmokeFeedback 1.0 ())
)

(= (mainSmokeCandidates $state $stimulus)
    ((actionCandidate answer (mainSmokeSchema) (0.0 0.0 0.8) (0.0 0.0 0.0) ()))
)

(= (mainSmokeBundle)
    (applicationBundle
        main_smoke
        (mainSmokeSchema)
        (mainSmokeAppraisal)
        (mainSmokeProfile)
        defaultGoalChangeDeltaG
        (makeDefaultStabilityPolicy)
        (makeDefaultCoherencePolicy)
        (makeDefaultParallelMergePolicy)
        mainSmokeStimulus
        mainSmokeCandidates
        ()
    )
)

(= (mainSmokeState)
    (motivationState (mainSmokeSchema) (0.5 0.5 0.8) (0.5 0.5 0.5))
)

!(test
    (bimonadStability (mainBuildMetaMo (mainSmokeBundle)))
    (makeDefaultStabilityPolicy)
)

!(test
    (diagnosticsFinalInSafeRegion
        (diagnosedDiagnostics
            (runMetaMoBundleStepWithDiagnostics
                (mainSmokeBundle)
                (mainSmokeState)
                (stimulusFeatures ())
                True
            )
        )
    )
    True
)


!(test
    (candidateId
        (runMetaMoBundleAction
            (mainSmokeBundle)
            (mainSmokeState)
            (stimulusFeatures ())
        )
    )
    answer
)

!(test
    (stateSchema
        (runMetaMoBundleState
            (mainSmokeBundle)
            (mainSmokeState)
            (stimulusFeatures ())
        )
    )
    (mainSmokeSchema)
)
