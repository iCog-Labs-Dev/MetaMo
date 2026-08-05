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

(= (runtimeIdentityStimulus $raw) $raw)
(= (runtimeFeatures $state $stimulus) $stimulus)
(= (runtimeCoreDeltas $state $features) ((valence 0.0)))
(= (runtimeAppDeltas $state $features) ())
(= (runtimeFeedback $state $stimulus $features) (goalChangeFeedback ()))

(= (runtimeSchemaA)
    (motivationSchema appA (magusGoalSchema (help) () (individuation transcendence help) individuation transcendence) (modulatorSchema (valence threshold securing) () (valence threshold securing)) decision appraisal)
)

(= (runtimeSchemaB)
    (motivationSchema appB (magusGoalSchema (help curiosity) () (individuation transcendence help curiosity) individuation transcendence) (modulatorSchema (valence threshold securing) () (valence threshold securing)) decision appraisal)
)

(= (runtimeProfileA)
    (decisionProfile appA (runtimeSchemaA) ((help (valence))) (help) () () () () () none 0.01 0.02 0.05 0.0 0.1)
)

(= (runtimeProfileB)
    (decisionProfile appB (runtimeSchemaB) ((help (valence)) (curiosity (valence))) (help) (curiosity) () () () () none 0.01 0.02 0.05 0.0 0.1)
)

(= (runtimeAppraisalA)
    (appraisalProfile appA (valence) runtimeFeatures runtimeCoreDeltas runtimeAppDeltas runtimeFeedback 1.0 ())
)

(= (runtimeAppraisalB)
    (appraisalProfile appB (valence) runtimeFeatures runtimeCoreDeltas runtimeAppDeltas runtimeFeedback 1.0 ())
)

(= (runtimeCandidatesA $state $stimulus)
    ((actionCandidate answer (runtimeSchemaA) (0.0 0.0 0.8) (0.0 0.0 0.0) ()))
)

(= (runtimeBundleA)
    (applicationBundle appA (runtimeSchemaA) (runtimeAppraisalA) (runtimeProfileA) defaultGoalChangeDeltaG (makeDefaultStabilityPolicy) (makeDefaultCoherencePolicy) (makeDefaultParallelMergePolicy) runtimeIdentityStimulus runtimeCandidatesA ())
)

(= (runtimeBundleB)
    (applicationBundle appB (runtimeSchemaB) (runtimeAppraisalB) (runtimeProfileB) defaultGoalChangeDeltaG (makeDefaultStabilityPolicy) (makeDefaultCoherencePolicy) (makeDefaultParallelMergePolicy) runtimeIdentityStimulus runtimeCandidatesA ())
)

!(test
    (validationIsOk (validateApplicationBundle (runtimeBundleA)))
    True
)

!(test
    (bundleSchema (runtimeBundleA))
    (runtimeSchemaA)
)

!(test
    (== (bundleSchema (runtimeBundleA)) (bundleSchema (runtimeBundleB)))
    False
)
