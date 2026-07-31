;; Default profile-driven goal-change calculator for canonical MAGUS.

;; Apply overgoal target feedback when a matching feature is present.
;; Example: (applyOvergoalTargets profile state feedback individuation 0.0) -> delta
(= (applyOvergoalTargets $profile $state $feedback $goalName $currentDelta)
    (let* (
        ($featureResult (symbolMapGetResult (decisionProfileOvergoalTargets $profile) $goalName))
    )
        (case $featureResult (
            ((validationOk $featureName)
                (if (featureMapHas $feedback $featureName)
                    (* (decisionProfileOvergoalDeltaScale $profile)
                       (- (featureMapNumeric $feedback $featureName 0.0)
                          (stateGoal $state $goalName)))
                    $currentDelta
                )
            )
            ($_ $currentDelta)
        ))
    )
)

;; Apply anti-goal target feedback when a matching feature is present.
;; Example: (applyAntiGoalTargets profile state feedback misinformation 0.0) -> delta
(= (applyAntiGoalTargets $profile $state $feedback $goalName $currentDelta)
    (let* (
        ($featureResult (symbolMapGetResult (decisionProfileAntiTargets $profile) $goalName))
    )
        (case $featureResult (
            ((validationOk $featureName)
                (if (featureMapHas $feedback $featureName)
                    (* (decisionProfileAntiGoalDeltaScale $profile)
                       (- (featureMapNumeric $feedback $featureName 0.0)
                          (stateGoal $state $goalName)))
                    $currentDelta
                )
            )
            ($_ $currentDelta)
        ))
    )
)

;; Compute the primary-goal contribution or zero for non-primary goals.
;; Example: (primaryGoalDeltaValue profile state candidate help 0.5 0.5) -> delta
(= (primaryGoalDeltaValue $profile $state $candidate $goalName $lambdaInd $lambdaTrans)
    (let* (
        ($primaryNames (magusGoalSchemaPrimary (motivationSchemaGoals (decisionProfileSchema $profile))))
    )
        (if (listContains $primaryNames $goalName)
            (* (decisionProfileDeltaScale $profile)
               (decisionProfileGoalUpdateValue $profile $state $candidate $goalName $lambdaInd $lambdaTrans))
            0.0
        )
    )
)

;; Apply the candidate Delta G hint when the profile asks for it.
;; Example: (applyCandidateDeltaHint profile candidate 2 0.01) -> delta
(= (applyCandidateDeltaHint $profile $candidate $goalIdx $currentDelta)
    (let* (
        ($weight (decisionProfileCandidateDeltaWeight $profile))
    )
        (if (== $weight 0.0)
            $currentDelta
            (+ $currentDelta (* $weight (index-atom (candidateDeltaG $candidate) $goalIdx)))
        )
    )
)

;; Compute one bounded goal delta.
;; Example: (defaultGoalChangeValue profile state candidate feedback help 2 0.5 0.5) -> delta
(= (defaultGoalChangeValue $profile $state $candidate $feedback $goalName $goalIdx $lambdaInd $lambdaTrans)
    (let* (
        ($primaryDelta (primaryGoalDeltaValue $profile $state $candidate $goalName $lambdaInd $lambdaTrans))
        ($afterOvergoal (applyOvergoalTargets $profile $state $feedback $goalName $primaryDelta))
        ($afterAnti (applyAntiGoalTargets $profile $state $feedback $goalName $afterOvergoal))
        ($afterCandidate (applyCandidateDeltaHint $profile $candidate $goalIdx $afterAnti))
    )
        (clipRange
            $afterCandidate
            (- 0.0 (decisionProfileMaxGoalDelta $profile))
            (decisionProfileMaxGoalDelta $profile)
        )
    )
)

;; Recursively compute Delta G in schema coordinate order.
;; Example: (defaultGoalChangeLoop profile state candidate feedback (help) 2 0.5 0.5) -> (delta)
(= (defaultGoalChangeLoop $profile $state $candidate $feedback $goalNames $goalIdx $lambdaInd $lambdaTrans)
    (if (== $goalNames ())
        ()
        (let* (
            (($head $tail) (decons $goalNames))
            ($value (defaultGoalChangeValue $profile $state $candidate $feedback $head $goalIdx $lambdaInd $lambdaTrans))
        )
            (cons-atom
                $value
                (defaultGoalChangeLoop $profile $state $candidate $feedback $tail (+ $goalIdx 1) $lambdaInd $lambdaTrans)
            )
        )
    )
)

;; Compute profile-driven Delta G for a selected candidate.
;; Example: (defaultGoalChangeDeltaG profile state candidate feedback 0.5 0.5) -> delta-vector
(= (defaultGoalChangeDeltaG $profile $state $candidate $feedback $lambdaInd $lambdaTrans)
    (defaultGoalChangeLoop
        $profile
        $state
        $candidate
        $feedback
        (magusGoalSchemaNames (motivationSchemaGoals (decisionProfileSchema $profile)))
        0
        $lambdaInd
        $lambdaTrans
    )
)

