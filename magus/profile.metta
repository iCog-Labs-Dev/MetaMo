;; Profile-owned MAGUS decision semantics for the canonical port.

(: DecisionProfile Type)
(: decisionProfile (-> Symbol MotivationSchema Expression Expression Expression Expression Expression Expression Expression Expression Number Number Number Number Number DecisionProfile))

;; Return the decision profile name.
;; Example: (decisionProfileName (decisionProfile demo schema () () () () () () () none 0.01 0.02 0.05 0.0 0.1)) -> demo
(= (decisionProfileName (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $name
)

;; Return the schema owned by the decision profile.
;; Example: (decisionProfileSchema profile) -> schema
(= (decisionProfileSchema (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $schema
)

;; Return goal-to-modulator mappings.
;; Example: (decisionProfileGoalModulators profile) -> ((help (resolution)))
(= (decisionProfileGoalModulators (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $goalModulators
)

;; Return individuation-supported goal names.
;; Example: (decisionProfileIndividuationGoals profile) -> (help ethics)
(= (decisionProfileIndividuationGoals (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $indGoals
)

;; Return transcendence-supported goal names.
;; Example: (decisionProfileTranscendenceGoals profile) -> (curiosity novelty)
(= (decisionProfileTranscendenceGoals (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $transGoals
)

;; Return balanced goal names.
;; Example: (decisionProfileBalancedGoals profile) -> (sociality)
(= (decisionProfileBalancedGoals (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $balancedGoals
)

;; Return anti-goal penalty weights.
;; Example: (decisionProfileAntiWeights profile) -> ((misinformation 1.4))
(= (decisionProfileAntiWeights (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $antiWeights
)

;; Return overgoal target feature mappings.
;; Example: (decisionProfileOvergoalTargets profile) -> ((individuation individuation_target))
(= (decisionProfileOvergoalTargets (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $overgoalTargets
)

;; Return anti-goal target feature mappings.
;; Example: (decisionProfileAntiTargets profile) -> ((misinformation misinformation_target))
(= (decisionProfileAntiTargets (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $antiTargets
)

;; Return the optional compatibility matrix or none.
;; Example: (decisionProfileCompatibilityMatrix profile) -> none
(= (decisionProfileCompatibilityMatrix (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $compatibilityMatrix
)

;; Return the overgoal delta scale.
;; Example: (decisionProfileOvergoalDeltaScale profile) -> 0.01
(= (decisionProfileOvergoalDeltaScale (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $overgoalScale
)

;; Return the anti-goal delta scale.
;; Example: (decisionProfileAntiGoalDeltaScale profile) -> 0.02
(= (decisionProfileAntiGoalDeltaScale (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $antiScale
)

;; Return the primary-goal delta scale.
;; Example: (decisionProfileDeltaScale profile) -> 0.05
(= (decisionProfileDeltaScale (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $deltaScale
)

;; Return the candidate Delta G hint weight.
;; Example: (decisionProfileCandidateDeltaWeight profile) -> 0.0
(= (decisionProfileCandidateDeltaWeight (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $candidateDeltaWeight
)

;; Return the maximum absolute goal delta.
;; Example: (decisionProfileMaxGoalDelta profile) -> 0.1
(= (decisionProfileMaxGoalDelta (decisionProfile $name $schema $goalModulators $indGoals $transGoals $balancedGoals $antiWeights $overgoalTargets $antiTargets $compatibilityMatrix $overgoalScale $antiScale $deltaScale $candidateDeltaWeight $maxDelta))
    $maxDelta
)

;; Return a map value by symbol, or a default.
;; Example: (symbolMapGet ((help (resolution))) help ()) -> (resolution)
(= (symbolMapGet $pairs $name $default)
    (if (== $pairs ())
        $default
        (let* (
            (($head $tail) (decons $pairs))
        )
            (if (== (featurePairName $head) $name)
                (featurePairValue $head)
                (symbolMapGet $tail $name $default)
            )
        )
    )
)

;; Return a map value as validation result.
;; Example: (symbolMapGetResult ((help resolution)) help) -> (validationOk resolution)
(= (symbolMapGetResult $pairs $name)
    (if (== $pairs ())
        (validationError missing-map-key $name)
        (let* (
            (($head $tail) (decons $pairs))
        )
            (if (== (featurePairName $head) $name)
                (validationOk (featurePairValue $head))
                (symbolMapGetResult $tail $name)
            )
        )
    )
)

;; Sum state modulators by name.
;; Example: (sumStateModulators state (threshold securing)) -> 1.0
(= (sumStateModulators $state $modulatorNames)
    (if (== $modulatorNames ())
        0.0
        (let* (
            (($head $tail) (decons $modulatorNames))
        )
            (+ (stateModulator $state $head) (sumStateModulators $state $tail))
        )
    )
)

;; Compute the relevant modulator factor for a goal.
;; Example: (decisionProfileRelevantModulator profile state help) -> 0.5
(= (decisionProfileRelevantModulator $profile $state $goalName)
    (let* (
        ($modulatorNames (symbolMapGet (decisionProfileGoalModulators $profile) $goalName ()))
    )
        (if (== $modulatorNames ())
            1.0
            (/ (sumStateModulators $state $modulatorNames) (size-atom $modulatorNames))
        )
    )
)

;; Compute profile-level overgoal support for a named goal.
;; Example: (decisionProfileOvergoalSupport profile help 0.5 0.5) -> 0.75
(= (decisionProfileOvergoalSupport $profile $goalName $gInd $gTrans)
    (let* (
        ($indSupport (sigmoidNum (* (- $gInd 0.5) 6.0)))
        ($transSupport (sigmoidNum (* (- $gTrans 0.5) 6.0)))
    )
        (if (listContains (decisionProfileIndividuationGoals $profile) $goalName)
            (+ 0.5 (* 0.5 $indSupport))
            (if (listContains (decisionProfileTranscendenceGoals $profile) $goalName)
                (+ 0.5 (* 0.5 $transSupport))
                (if (listContains (decisionProfileBalancedGoals $profile) $goalName)
                    (+ 0.5 (* 0.25 (+ $indSupport $transSupport)))
                    1.0
                )
            )
        )
    )
)

;; Compute the compatibility/MIC factor for a goal.
;; Example: (decisionProfileCompatibilityFactor profile help state candidate) -> 1.0
(= (decisionProfileCompatibilityFactor $profile $goalName $state $candidate)
    (let* (
        ($schema (decisionProfileSchema $profile))
        ($idxResult (schemaGoalIndex $schema $goalName))
        ($matrix (decisionProfileCompatibilityMatrix $profile))
        ($gInd (stateGoal $state (magusGoalSchemaIndividuationName (motivationSchemaGoals $schema))))
        ($gTrans (stateGoal $state (magusGoalSchemaTranscendenceName (motivationSchemaGoals $schema))))
        ($overgoalFactor (decisionProfileOvergoalSupport $profile $goalName $gInd $gTrans))
    )
        (if (== $matrix none)
            $overgoalFactor
            (case $idxResult (
                ((validationOk $idx) (* $overgoalFactor (compatibilityFactorForGoal $matrix $idx $state)))
                ($_ $idxResult)
            ))
        )
    )
)

;; Validate that profile, state, and candidate share the same coordinate schema.
;; Example: (validationIsOk (decisionProfileValidate profile state candidate)) -> True
(= (decisionProfileValidate $profile $state $candidate)
    (if (== (stateSchema $state) (decisionProfileSchema $profile))
        (if (== (candidateSchema $candidate) (stateSchema $state))
            (validationOk $profile)
            (validationError candidate-schema-mismatch (candidateSchema $candidate))
        )
        (validationError state-schema-mismatch (stateSchema $state))
    )
)

;; Compute f_i = g_i * m_rho(i) * kappa_i(x) * corr_i(a).
;; Example: (decisionProfileF profile state candidate help) -> contribution
(= (decisionProfileF $profile $state $candidate $goalName)
    (let* (
        ($weight (stateGoal $state $goalName))
        ($modulator (decisionProfileRelevantModulator $profile $state $goalName))
        ($compatibility (decisionProfileCompatibilityFactor $profile $goalName $state $candidate))
        ($correlation (candidateGoalCorrelation $candidate $goalName))
    )
        (* (* (* $weight $modulator) $compatibility) $correlation)
    )
)

;; Sum f_i over primary goal names.
;; Example: (decisionProfilePrimaryScore profile state candidate (help)) -> score
(= (decisionProfilePrimaryScore $profile $state $candidate $goalNames)
    (if (== $goalNames ())
        0.0
        (let* (
            (($head $tail) (decons $goalNames))
        )
            (+ (decisionProfileF $profile $state $candidate $head)
               (decisionProfilePrimaryScore $profile $state $candidate $tail))
        )
    )
)

;; Sum positive anti-goal activation penalties.
;; Example: (decisionProfileAntiGoalPenalty profile state candidate (risk)) -> penalty
(= (decisionProfileAntiGoalPenalty $profile $state $candidate $antiGoalNames)
    (if (== $antiGoalNames ())
        0.0
        (let* (
            (($head $tail) (decons $antiGoalNames))
            ($weight (symbolMapGet (decisionProfileAntiWeights $profile) $head 1.0))
            ($activation (positivePart (candidateGoalCorrelation $candidate $head)))
            ($stateWeight (stateGoal $state $head))
        )
            (+ (* (* $weight $stateWeight) $activation)
               (decisionProfileAntiGoalPenalty $profile $state $candidate $tail))
        )
    )
)

;; Compute the MAGUS additive decision score.
;; Example: (decisionProfileScoreCandidate profile state candidate 0.5 0.5) -> score
(= (decisionProfileScoreCandidate $profile $state $candidate $lambdaInd $lambdaTrans)
    (let* (
        ($schema (decisionProfileSchema $profile))
        ($goalSchema (motivationSchemaGoals $schema))
        ($validation (decisionProfileValidate $profile $state $candidate))
    )
        (if (validationIsOk $validation)
            (let* (
                ($gInd (stateGoal $state (magusGoalSchemaIndividuationName $goalSchema)))
                ($gTrans (stateGoal $state (magusGoalSchemaTranscendenceName $goalSchema)))
                ($primaryScore (decisionProfilePrimaryScore $profile $state $candidate (magusGoalSchemaPrimary $goalSchema)))
                ($antiPenalty (decisionProfileAntiGoalPenalty $profile $state $candidate (magusGoalSchemaAnti $goalSchema)))
            )
                (- (+ $primaryScore (* $lambdaTrans $gTrans))
                   (+ (* $lambdaInd $gInd) $antiPenalty))
            )
            $validation
        )
    )
)

;; Compute the raw update value for one primary goal.
;; Example: (decisionProfileGoalUpdateValue profile state candidate help 0.5 0.5) -> value
(= (decisionProfileGoalUpdateValue $profile $state $candidate $goalName $lambdaInd $lambdaTrans)
    (let* (
        ($schema (decisionProfileSchema $profile))
        ($goalSchema (motivationSchemaGoals $schema))
        ($gInd (stateGoal $state (magusGoalSchemaIndividuationName $goalSchema)))
        ($gTrans (stateGoal $state (magusGoalSchemaTranscendenceName $goalSchema)))
    )
        (- (+ (decisionProfileF $profile $state $candidate $goalName) (* $lambdaTrans $gTrans))
           (* $lambdaInd $gInd))
    )
)

