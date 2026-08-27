;; Canonical coherence policy, self-model, and measured blend records.

(: CoherencePolicy Type)
(: defaultCoherencePolicy (-> Number Number Number Number Number Number Number Number Expression Expression Symbol Symbol CoherencePolicy))

(: SelfModel Type)
(: selfModel (-> Expression SelfModel))

(: SelfModelDriftResult Type)
(: selfModelDriftResult (-> SelfModel SelfModel Number Number Number Number Number Bool SelfModelDriftResult))

(: BlendResult Type)
(: blendResult (-> MotivationState Number Number SelfModelDriftResult BlendResult))

;; Return policy alpha0.
;; Example: (coherenceAlpha0 (makeDefaultCoherencePolicy)) -> 0.1
(= (coherenceAlpha0 (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $alpha0
)

;; Return policy beta0.
;; Example: (coherenceBeta0 (makeDefaultCoherencePolicy)) -> 0.15
(= (coherenceBeta0 (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $beta0
)

;; Return minimum blend alpha.
;; Example: (coherenceMinAlpha (makeDefaultCoherencePolicy)) -> 0.000001
(= (coherenceMinAlpha (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $minAlpha
)

;; Return default Lipschitz constant.
;; Example: (coherenceLipschitzConstant (makeDefaultCoherencePolicy)) -> 1.0
(= (coherenceLipschitzConstant (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $lipschitz
)

;; Return maximum allowed drift.
;; Example: (coherenceMaxAllowedDrift (makeDefaultCoherencePolicy)) -> 0.1
(= (coherenceMaxAllowedDrift (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $maxDrift
)

;; Return minimum alpha scale.
;; Example: (coherenceMinAlphaScale (makeDefaultCoherencePolicy)) -> 0.125
(= (coherenceMinAlphaScale (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $minAlphaScale
)

;; Return state drift weight.
;; Example: (coherenceStateDriftWeight (makeDefaultCoherencePolicy)) -> 0.5
(= (coherenceStateDriftWeight (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $stateWeight
)

;; Return self-model drift weight.
;; Example: (coherenceSelfModelDriftWeight (makeDefaultCoherencePolicy)) -> 0.5
(= (coherenceSelfModelDriftWeight (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $modelWeight
)

;; Return caution posture modulator names.
;; Example: (coherenceCautionNames (makeDefaultCoherencePolicy)) -> (threshold securing)
(= (coherenceCautionNames (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $cautionNames
)

;; Return exploration posture modulator names.
;; Example: (coherenceExploreNames (makeDefaultCoherencePolicy)) -> (arousal approach)
(= (coherenceExploreNames (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $exploreNames
)

;; Return the clarity posture modulator name.
;; Example: (coherenceClarityName (makeDefaultCoherencePolicy)) -> resolution
(= (coherenceClarityName (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $clarityName
)

;; Return the affect posture modulator name.
;; Example: (coherenceAffectName (makeDefaultCoherencePolicy)) -> valence
(= (coherenceAffectName (defaultCoherencePolicy $alpha0 $beta0 $minAlpha $lipschitz $maxDrift $minAlphaScale $stateWeight $modelWeight $cautionNames $exploreNames $clarityName $affectName))
    $affectName
)

;; Construct the Python-compatible default coherence policy.
;; Example: (makeDefaultCoherencePolicy) -> default policy record
(= (makeDefaultCoherencePolicy)
    (defaultCoherencePolicy 0.1 0.15 0.000001 1.0 0.1 0.125 0.5 0.5 (threshold securing) (arousal approach) resolution valence)
)

;; Return the vector from a self-model record.
;; Example: (selfModelVector (selfModel (0.1 0.2))) -> (0.1 0.2)
(= (selfModelVector (selfModel $vector))
    $vector
)

;; Return a numeric summary for a value block: mean, max, norm.
;; Example: (summaryVector (0.2 0.4)) -> (0.3 0.4 0.4472135955)
(= (summaryVector $values)
    (if (== $values ())
        (0.0 0.0 0.0)
        ((eval (mean $values)) (listMax $values) (eval (norm $values)))
    )
)

;; Collect goal values for a list of schema names.
;; Example: (goalValuesForNames state (help ethics)) -> (0.8 0.9)
(= (goalValuesForNames $state $names)
    (if (== $names ())
        ()
        (let* (
            (($head $tail) (decons $names))
        )
            (cons-atom (stateGoal $state $head) (goalValuesForNames $state $tail))
        )
    )
)

;; Collect modulator values for names that exist in the schema.
;; Example: (modulatorValuesForNames state (threshold securing)) -> (0.5 0.5)
(= (modulatorValuesForNames $state $names)
    (if (== $names ())
        ()
        (let* (
            (($head $tail) (decons $names))
            ($idxResult (schemaModulatorIndex (stateSchema $state) $head))
        )
            (case $idxResult (
                ((validationOk $idx)
                    (cons-atom (index-atom (stateModulators $state) $idx) (modulatorValuesForNames $state $tail))
                )
                ($_ (modulatorValuesForNames $state $tail))
            ))
        )
    )
)

;; Compute the mean value for named modulators, defaulting to zero when none exist.
;; Example: (meanNamedModulators state (threshold securing)) -> 0.5
(= (meanNamedModulators $state $names)
    (let* (
        ($values (modulatorValuesForNames $state $names))
    )
        (if (== $values ())
            0.0
            (eval (mean $values))
        )
    )
)

;; Read a modulator by name, defaulting when the schema does not expose it.
;; Example: (stateModulatorOrDefault state resolution 0.0) -> 0.0
(= (stateModulatorOrDefault $state $name $default)
    (let* (
        ($idxResult (schemaModulatorIndex (stateSchema $state) $name))
    )
        (case $idxResult (
            ((validationOk $idx) (index-atom (stateModulators $state) $idx))
            ($_ $default)
        ))
    )
)

;; Estimate the explicit self-model vector for a canonical state.
;; Example: (estimateSelfModel (makeDefaultCoherencePolicy) state) -> (selfModel vector)
(= (estimateSelfModel $policy $state)
    (let* (
        ($schema (stateSchema $state))
        ($goalSchema (motivationSchemaGoals $schema))
        ($modSchema (motivationSchemaModulators $schema))
        ($gIndName (magusGoalSchemaIndividuationName $goalSchema))
        ($gTransName (magusGoalSchemaTranscendenceName $goalSchema))
        ($primaryValues (goalValuesForNames $state (magusGoalSchemaPrimary $goalSchema)))
        ($antiValues (goalValuesForNames $state (magusGoalSchemaAnti $goalSchema)))
        ($coreValues (modulatorValuesForNames $state (modulatorSchemaCore $modSchema)))
        ($appValues (modulatorValuesForNames $state (modulatorSchemaApplication $modSchema)))
        ($posture
            (
                (meanNamedModulators $state (coherenceCautionNames $policy))
                (meanNamedModulators $state (coherenceExploreNames $policy))
                (stateModulatorOrDefault $state (coherenceClarityName $policy) 0.0)
                (stateModulatorOrDefault $state (coherenceAffectName $policy) 0.0)
            )
        )
    )
        (selfModel
            (listAppend
                (stateGoals $state)
                (listAppend
                    (stateModulators $state)
                    (listAppend
                        ((stateGoal $state $gIndName) (stateGoal $state $gTransName))
                        (listAppend
                            (summaryVector $primaryValues)
                            (listAppend
                                (summaryVector $antiValues)
                                (listAppend
                                    (summaryVector $coreValues)
                                    (listAppend
                                        (summaryVector $appValues)
                                        $posture
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

;; Measure distance between two self-models.
;; Example: (selfModelDistance (selfModel (0.0)) (selfModel (1.0))) -> 1.0
(= (selfModelDistance $left $right)
    (eval (norm (listDifference (selfModelVector $left) (selfModelVector $right))))
)

;; Calculate the policy blend factor for a canonical state.
;; Example: (calculateBlendFactor policy state) -> alpha
(= (calculateBlendFactor $policy $state)
    (let* (
        ($schema (stateSchema $state))
        ($goalSchema (motivationSchemaGoals $schema))
        ($gInd (stateGoal $state (magusGoalSchemaIndividuationName $goalSchema)))
        ($gTrans (stateGoal $state (magusGoalSchemaTranscendenceName $goalSchema)))
        ($alpha (+ (* (coherenceAlpha0 $policy) (- 1.0 $gInd)) (* (coherenceBeta0 $policy) $gTrans)))
    )
        (clipRange $alpha (coherenceMinAlpha $policy) (- 1.0 (coherenceMinAlpha $policy)))
    )
)

;; Build an alpha-weighted canonical state toward a target.
;; Example: (stateTowardTarget current target 0.5) -> blended-state
(= (stateTowardTarget $currentState $targetState $alpha)
    (motivationState
        (stateSchema $currentState)
        (blendArrays (stateGoals $currentState) (stateGoals $targetState) $alpha)
        (blendArrays (stateModulators $currentState) (stateModulators $targetState) $alpha)
    )
)

;; Measure explicit self-model drift.
;; Example: (measureSelfModelDrift policy current next) -> drift-record
(= (measureSelfModelDrift $policy $currentState $nextState)
    (let* (
        ($stateDistance (stateDistance $currentState $nextState))
        ($currentModel (estimateSelfModel $policy $currentState))
        ($nextModel (estimateSelfModel $policy $nextState))
        ($selfDistance (selfModelDistance $currentModel $nextModel))
        ($lipschitzBound (* (coherenceLipschitzConstant $policy) $stateDistance))
        ($combined (+ (* (coherenceStateDriftWeight $policy) $lipschitzBound)
                      (* (coherenceSelfModelDriftWeight $policy) $selfDistance)))
        ($maxDrift (coherenceMaxAllowedDrift $policy))
    )
        (selfModelDriftResult
            $currentModel
            $nextModel
            $stateDistance
            $selfDistance
            $lipschitzBound
            $combined
            $maxDrift
            (<= $combined $maxDrift)
        )
    )
)

;; Return the drift hold flag.
;; Example: (selfModelDriftHolds (measureSelfModelDrift policy current next)) -> True
(= (selfModelDriftHolds (selfModelDriftResult $current $next $stateDistance $selfDistance $lipschitzBound $combined $maxDrift $holds))
    $holds
)

;; Return the measured state distance.
;; Example: (selfModelStateDistance drift) -> 0.1
(= (selfModelStateDistance (selfModelDriftResult $current $next $stateDistance $selfDistance $lipschitzBound $combined $maxDrift $holds))
    $stateDistance
)

;; Return the measured self-model distance.
;; Example: (selfModelDistanceMeasured drift) -> 0.1
(= (selfModelDistanceMeasured (selfModelDriftResult $current $next $stateDistance $selfDistance $lipschitzBound $combined $maxDrift $holds))
    $selfDistance
)

;; Return combined drift.
;; Example: (selfModelCombinedDrift drift) -> 0.1
(= (selfModelCombinedDrift (selfModelDriftResult $current $next $stateDistance $selfDistance $lipschitzBound $combined $maxDrift $holds))
    $combined
)

;; Return maximum allowed drift.
;; Example: (selfModelMaxAllowedDrift drift) -> 0.1
(= (selfModelMaxAllowedDrift (selfModelDriftResult $current $next $stateDistance $selfDistance $lipschitzBound $combined $maxDrift $holds))
    $maxDrift
)

;; Recursive measured blend with alpha backoff.
;; Example: (measureBlendLoop policy current target alpha minAlpha) -> blend-result
(= (measureBlendLoop $policy $currentState $targetState $alpha $baseAlpha $minAlpha)
    (let* (
        ($nextState (stateTowardTarget $currentState $targetState $alpha))
        ($drift (measureSelfModelDrift $policy $currentState $nextState))
    )
        (if (or (selfModelDriftHolds $drift) (<= $alpha $minAlpha))
            (blendResult $nextState $alpha $baseAlpha $drift)
            (measureBlendLoop $policy $currentState $targetState (* 0.5 $alpha) $baseAlpha $minAlpha)
        )
    )
)

;; Measure and apply policy blending toward a target.
;; Example: (measureBlend policy current target) -> blend-result
(= (measureBlend $policy $currentState $targetState)
    (let* (
        ($baseAlpha (calculateBlendFactor $policy $currentState))
        ($minAlpha (* (coherenceMinAlphaScale $policy) $baseAlpha))
    )
        (measureBlendLoop $policy $currentState $targetState $baseAlpha $baseAlpha $minAlpha)
    )
)

;; Return the blended state from a blend result.
;; Example: (blendResultState (blendResult state 0.1 0.1 drift)) -> state
(= (blendResultState (blendResult $state $alpha $baseAlpha $drift))
    $state
)

;; Return the accepted alpha from a blend result.
;; Example: (blendResultAlpha (blendResult state 0.1 0.2 drift)) -> 0.1
(= (blendResultAlpha (blendResult $state $alpha $baseAlpha $drift))
    $alpha
)

;; Return the base alpha from a blend result.
;; Example: (blendResultBaseAlpha (blendResult state 0.1 0.2 drift)) -> 0.2
(= (blendResultBaseAlpha (blendResult $state $alpha $baseAlpha $drift))
    $baseAlpha
)

;; Return the drift record from a blend result.
;; Example: (blendResultDrift (blendResult state 0.1 0.2 drift)) -> drift
(= (blendResultDrift (blendResult $state $alpha $baseAlpha $drift))
    $drift
)

;; Blend and return only the next state.
;; Example: (blendStates policy current target) -> next-state
(= (blendStates $policy $currentState $targetState)
    (blendResultState (measureBlend $policy $currentState $targetState))
)
