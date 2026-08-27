!(import! &self ../validation)
!(import! &self ../schema)
!(import! &self ../features)
!(import! &self ../state)
!(import! &self ../helper)
!(import! &self "../helpers.py")
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
!(import! &self ../runtime)
!(import! &self ../registry)

(= (registrySmokeStimulus $raw) $raw)
(= (registrySmokeFeatures $state $stimulus) $stimulus)
(= (registrySmokeCoreDeltas $state $features) ((valence 0.0)))
(= (registrySmokeAppDeltas $state $features) ())
(= (registrySmokeFeedback $state $stimulus $features) (goalChangeFeedback ()))

(= (registrySmokeSchema)
    (motivationSchema
        registry_smoke
        (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence)
        (modulatorSchema (valence threshold securing) () (valence threshold securing))
        decision
        appraisal
    )
)

(= (registrySmokeProfile)
    (decisionProfile registry_smoke (registrySmokeSchema) ((help (valence))) (help) () () () () () none 0.01 0.02 0.05 0.0 0.1)
)

(= (registrySmokeAppraisal)
    (appraisalProfile registry_smoke (valence) registrySmokeFeatures registrySmokeCoreDeltas registrySmokeAppDeltas registrySmokeFeedback 1.0 ())
)

(= (registrySmokeCandidates $state $stimulus)
    ((actionCandidate answer (registrySmokeSchema) (0.0 0.0 0.8) (0.0 0.0 0.0) ()))
)

(= (registrySmokeBundle)
    (applicationBundle
        registry_smoke
        (registrySmokeSchema)
        (registrySmokeAppraisal)
        (registrySmokeProfile)
        defaultGoalChangeDeltaG
        (makeDefaultStabilityPolicy)
        (makeDefaultCoherencePolicy)
        (makeDefaultParallelMergePolicy)
        registrySmokeStimulus
        registrySmokeCandidates
        ()
    )
)

(= (registrySmokeState)
    (motivationState (registrySmokeSchema) (0.5 0.5 0.8) (0.5 0.5 0.5))
)

!(test
    (validationIsOk (validateApplicationBundle (registrySmokeBundle)))
    True
)

!(test
    (bimonadMerge (buildMetaMoFromBundle (registrySmokeBundle)))
    (makeDefaultParallelMergePolicy)
)

!(test
    (bimonadStability (buildValidatedMetaMoFromBundle (registrySmokeBundle)))
    (makeDefaultStabilityPolicy)
)

!(test
    (candidateId
        (transitionAction
            (runRegisteredBundleStep
                (registrySmokeBundle)
                (registrySmokeState)
                (stimulusFeatures ())
            )
        )
    )
    answer
)
