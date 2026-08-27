(: ParallelMergePolicy Type)
(: defaultParallelMergePolicy (-> Expression Expression Expression Number ParallelMergePolicy))

;; Return caution modulator names.
;; Example: (mergePolicyCautionNames (makeDefaultParallelMergePolicy)) -> (threshold securing)
(= (mergePolicyCautionNames (defaultParallelMergePolicy $cautionNames $exploreNames $sharedNames $coherenceCorrection))
    $cautionNames
)

;; Return exploratory modulator names.
;; Example: (mergePolicyExploreNames (makeDefaultParallelMergePolicy)) -> (arousal approach)
(= (mergePolicyExploreNames (defaultParallelMergePolicy $cautionNames $exploreNames $sharedNames $coherenceCorrection))
    $exploreNames
)

;; Return shared modulator names.
;; Example: (mergePolicySharedNames (makeDefaultParallelMergePolicy)) -> (valence resolution)
(= (mergePolicySharedNames (defaultParallelMergePolicy $cautionNames $exploreNames $sharedNames $coherenceCorrection))
    $sharedNames
)

;; Return default coherence correction.
;; Example: (mergePolicyCoherenceCorrection (makeDefaultParallelMergePolicy)) -> 0.05
(= (mergePolicyCoherenceCorrection (defaultParallelMergePolicy $cautionNames $exploreNames $sharedNames $coherenceCorrection))
    $coherenceCorrection
)

;; Construct the Python-compatible default merge policy.
;; Example: (makeDefaultParallelMergePolicy) -> default merge policy
(= (makeDefaultParallelMergePolicy)
    (defaultParallelMergePolicy (threshold securing) (arousal approach) (valence resolution) 0.05)
)

;; Convert goal names to indices, skipping unknown names.
;; Example: (goalIndicesForNames schema (help ethics)) -> (2 3)
(= (goalIndicesForNames $schema $names)
    (if (== $names ())
        ()
        (let* (
            (($head $tail) (decons $names))
            ($idxResult (schemaGoalIndex $schema $head))
        )
            (case $idxResult (
                ((validationOk $idx) (cons-atom $idx (goalIndicesForNames $schema $tail)))
                ($_ (goalIndicesForNames $schema $tail))
            ))
        )
    )
)

;; Convert modulator names to indices, skipping unknown names.
;; Example: (modulatorIndicesForNames schema (threshold securing)) -> (4 5)
(= (modulatorIndicesForNames $schema $names)
    (if (== $names ())
        ()
        (let* (
            (($head $tail) (decons $names))
            ($idxResult (schemaModulatorIndex $schema $head))
        )
            (case $idxResult (
                ((validationOk $idx) (cons-atom $idx (modulatorIndicesForNames $schema $tail)))
                ($_ (modulatorIndicesForNames $schema $tail))
            ))
        )
    )
)

;; Build profile-derived safety goal names.
;; Example: (mergeSafetyGoalNames profile) -> (individuation help ethics)
(= (mergeSafetyGoalNames $profile)
    (let* (
        ($schema (decisionProfileSchema $profile))
        ($individuation (magusGoalSchemaIndividuationName (motivationSchemaGoals $schema)))
    )
        (cons-atom $individuation (decisionProfileIndividuationGoals $profile))
    )
)

;; Build profile-derived exploratory goal names.
;; Example: (mergeExploratoryGoalNames profile) -> (transcendence curiosity novelty)
(= (mergeExploratoryGoalNames $profile)
    (let* (
        ($schema (decisionProfileSchema $profile))
        ($transcendence (magusGoalSchemaTranscendenceName (motivationSchemaGoals $schema)))
    )
        (cons-atom $transcendence (decisionProfileTranscendenceGoals $profile))
    )
)

;; Merge two states that already share the same schema.
;; Example: (parallelMerge policy decision stateA stateB) -> merged-state
(= (parallelMerge $policy $decision $stateA $stateB)
    (let* (
        ($schema (stateSchema $stateA))
        ($profile (magusDecisionProfile $decision))
        ($goalSchema (motivationSchemaGoals $schema))
        ($indIdxResult (schemaGoalIndex $schema (magusGoalSchemaIndividuationName $goalSchema)))
    )
        (if (== $schema (stateSchema $stateB))
            (case $indIdxResult (
                ((validationOk $indIdx)
                    (let* (
                        ($safetyGoalIndices (goalIndicesForNames $schema (mergeSafetyGoalNames $profile)))
                        ($exploratoryGoalIndices (goalIndicesForNames $schema (mergeExploratoryGoalNames $profile)))
                        ($balancedGoalIndices (goalIndicesForNames $schema (decisionProfileBalancedGoals $profile)))
                        ($cautionModulatorIndices (modulatorIndicesForNames $schema (mergePolicyCautionNames $policy)))
                        ($exploreModulatorIndices (modulatorIndicesForNames $schema (mergePolicyExploreNames $policy)))
                        ($sharedModulatorIndices (modulatorIndicesForNames $schema (mergePolicySharedNames $policy)))
                        ($mergedGoals (eval (parallelMergeGoals
                            (stateGoals $stateA)
                            (stateGoals $stateB)
                            (mergePolicyCoherenceCorrection $policy)
                            $indIdx
                            $safetyGoalIndices
                            $exploratoryGoalIndices
                            $balancedGoalIndices
                        )))
                        ($mergedModulators (eval (parallelMergeModulators
                            (stateModulators $stateA)
                            (stateModulators $stateB)
                            (stateGoals $stateA)
                            (stateGoals $stateB)
                            (mergePolicyCoherenceCorrection $policy)
                            $indIdx
                            $cautionModulatorIndices
                            $exploreModulatorIndices
                            $sharedModulatorIndices
                        )))
                        ($clippedGoals (eval (clipVector $mergedGoals 0.0 1.0)))
                        ($clippedModulators (eval (clipVector $mergedModulators 0.0 1.0)))
                    )
                        (motivationState
                            $schema
                            $clippedGoals
                            $clippedModulators
                            )
                    )
                )
                ($_ $indIdxResult)
            ))
            (validationError merge-schema-mismatch ($schema (stateSchema $stateB)))
        )
    )
)

;; Merge after translating a source state into the target frame.
;; Example: (translateThenMerge policy decision translation source target) -> merged-state
(= (translateThenMerge $policy $decision $translation $sourceState $targetState)
    (parallelMerge
        $policy
        $decision
        (simulatePeer $translation $sourceState)
        $targetState
    )
)
