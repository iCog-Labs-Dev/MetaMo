!(import! &self ../../core/validation)
!(import! &self ../../core/schema)
!(import! &self ../../core/state)
!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../../magus/profile)
!(import! &self ../../magus/decision)
!(import! &self ../merge)

(= (mergeTestSchema)
    (motivationSchema
        synthetic
        (magusGoalSchema (help curiosity) (risk) (individuation transcendence help curiosity risk) individuation transcendence)
        (modulatorSchema (valence arousal approach resolution threshold securing) () (valence arousal approach resolution threshold securing))
        decision
        appraisal
    )
)

(= (mergeTestProfile)
    (decisionProfile synthetic (mergeTestSchema) ((help (resolution)) (curiosity (arousal))) (help) (curiosity) () ((risk 1.0)) () () none 0.01 0.02 0.05 0.0 0.1)
)

!(test
    (goalIndicesForNames (mergeTestSchema) (help risk))
    (2 4)
)

!(test
    (stateSchema
        (parallelMerge
            (makeDefaultParallelMergePolicy)
            (magusDecision (mergeTestProfile) defaultGoalChangeDeltaG 0.5 0.5)
            (motivationState (mergeTestSchema) (0.5 0.5 0.8 0.4 0.2) (0.5 0.5 0.5 0.5 0.5 0.5))
            (motivationState (mergeTestSchema) (0.7 0.3 0.6 0.6 0.4) (0.6 0.4 0.5 0.5 0.7 0.7))
        )
    )
    (mergeTestSchema)
)

