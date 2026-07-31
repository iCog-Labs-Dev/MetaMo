;; Canonical policy-driven stability configuration.

(: StabilityPolicy Type)
(: defaultStabilityPolicy (-> Number Number Number Number Number Expression StabilityPolicy))

;; Return the theta-safe individuation floor.
;; Example: (stabilityThetaSafe (defaultStabilityPolicy 0.3 2.0 0.1 0.9 0.05 (threshold securing))) -> 0.3
(= (stabilityThetaSafe (defaultStabilityPolicy $thetaSafe $gMax $etaBoundary $cContract $epsilon $cautionModulators))
    $thetaSafe
)

;; Return the maximum goal norm.
;; Example: (stabilityGMax (defaultStabilityPolicy 0.3 2.0 0.1 0.9 0.05 (threshold securing))) -> 2.0
(= (stabilityGMax (defaultStabilityPolicy $thetaSafe $gMax $etaBoundary $cContract $epsilon $cautionModulators))
    $gMax
)

;; Return the boundary-band width.
;; Example: (stabilityEtaBoundary (defaultStabilityPolicy 0.3 2.0 0.1 0.9 0.05 (threshold securing))) -> 0.1
(= (stabilityEtaBoundary (defaultStabilityPolicy $thetaSafe $gMax $etaBoundary $cContract $epsilon $cautionModulators))
    $etaBoundary
)

;; Return the contraction constant.
;; Example: (stabilityCContract (defaultStabilityPolicy 0.3 2.0 0.1 0.9 0.05 (threshold securing))) -> 0.9
(= (stabilityCContract (defaultStabilityPolicy $thetaSafe $gMax $etaBoundary $cContract $epsilon $cautionModulators))
    $cContract
)

;; Return the contraction epsilon.
;; Example: (stabilityEpsilon (defaultStabilityPolicy 0.3 2.0 0.1 0.9 0.05 (threshold securing))) -> 0.05
(= (stabilityEpsilon (defaultStabilityPolicy $thetaSafe $gMax $etaBoundary $cContract $epsilon $cautionModulators))
    $epsilon
)

;; Return caution modulator names.
;; Example: (stabilityCautionModulators (defaultStabilityPolicy 0.3 2.0 0.1 0.9 0.05 (threshold securing))) -> (threshold securing)
(= (stabilityCautionModulators (defaultStabilityPolicy $thetaSafe $gMax $etaBoundary $cContract $epsilon $cautionModulators))
    $cautionModulators
)

;; Construct the Python-compatible default stability policy.
;; Example: (makeDefaultStabilityPolicy) -> (defaultStabilityPolicy 0.3 2.0 0.1 0.9 0.05 (threshold securing))
(= (makeDefaultStabilityPolicy)
    (defaultStabilityPolicy 0.3 2.0 0.1 0.9 0.05 (threshold securing))
)

;; Look up the schema-specific individuation index.
;; Example: (stabilityIndividuationIndex schema) -> (validationOk 0)
(= (stabilityIndividuationIndex $schema)
    (schemaGoalIndex
        $schema
        (magusGoalSchemaIndividuationName (motivationSchemaGoals $schema))
    )
)

;; Check whether a canonical state is in the policy safe region.
;; Example: (isInSafeRegion (makeDefaultStabilityPolicy) state) -> True
(= (isInSafeRegion $policy $state)
    (let* (
        ($schema (stateSchema $state))
        ($idxResult (stabilityIndividuationIndex $schema))
    )
        (case $idxResult (
            ((validationOk $idx)
                (and
                    (>= (index-atom (stateGoals $state) $idx) (stabilityThetaSafe $policy))
                    (<= (eval (norm (stateGoals $state))) (stabilityGMax $policy))
                )
            )
            ($_ False)
        ))
    )
)

;; Measure distance to the nearest unsafe boundary.
;; Example: (distanceToUnsafeBoundary policy state) -> 0.2
(= (distanceToUnsafeBoundary $policy $state)
    (let* (
        ($schema (stateSchema $state))
        ($idxResult (stabilityIndividuationIndex $schema))
    )
        (case $idxResult (
            ((validationOk $idx)
                (let* (
                    ($gInd (index-atom (stateGoals $state) $idx))
                    ($gNorm (eval (norm (stateGoals $state))))
                    ($distTheta (positivePart (- $gInd (stabilityThetaSafe $policy))))
                    ($distGMax (positivePart (- (stabilityGMax $policy) $gNorm)))
                )
                    (minNumber $distTheta $distGMax)
                )
            )
            ($_ 0.0)
        ))
    )
)

;; Check whether a state is in the policy boundary band.
;; Example: (isInBoundaryBand policy state) -> False
(= (isInBoundaryBandFromSafe True $policy $state)
    (eval (<=
        (eval (distanceToUnsafeBoundary $policy $state))
        (stabilityEtaBoundary $policy)
    ))
)

(= (isInBoundaryBandFromSafe False $policy $state)
    False
)

(= (isInBoundaryBand $policy $state)
    (let* (
        ($safe (eval (isInSafeRegion $policy $state)))
    )
        (isInBoundaryBandFromSafe $safe $policy $state)
    )
)

;; Compute policy boundary pressure.
;; Example: (boundaryPressure policy state) -> 0.0
(= (boundaryPressure $policy $state)
    (if (isInSafeRegion $policy $state)
        (let* (
            ($dist (distanceToUnsafeBoundary $policy $state))
        )
            (if (>= $dist (stabilityEtaBoundary $policy))
                0.0
                (clipUnit (- 1.0 (/ $dist (stabilityEtaBoundary $policy))))
            )
        )
        1.0
    )
)

;; Boost one named modulator if the schema contains it.
;; Example: (boostNamedModulator state threshold 0.1) -> updated-state
(= (boostNamedModulator $state $modulatorName $boost)
    (let* (
        ($idxResult (schemaModulatorIndex (stateSchema $state) $modulatorName))
    )
        (case $idxResult (
            ((validationOk $idx)
                (stateSetModulator
                    $state
                    $modulatorName
                    (clipUnit (+ (index-atom (stateModulators $state) $idx) $boost))
                )
            )
            ($_ $state)
        ))
    )
)

;; Boost all policy caution modulators that exist in the schema.
;; Example: (boostNamedModulators state (threshold securing) 0.1) -> updated-state
(= (boostNamedModulators $state $modulatorNames $boost)
    (if (== $modulatorNames ())
        $state
        (let* (
            (($head $tail) (decons $modulatorNames))
        )
            (boostNamedModulators
                (boostNamedModulator $state $head $boost)
                $tail
                $boost
            )
        )
    )
)

;; Raise caution-related modulators as boundary pressure rises.
;; Example: (raiseBoundaryCaution (makeDefaultStabilityPolicy) state) -> updated-state
(= (raiseBoundaryCaution $policy $state)
    (let* (
        ($pressure (boundaryPressure $policy $state))
    )
        (if (== $pressure 0.0)
            $state
            (boostNamedModulators
                $state
                (stabilityCautionModulators $policy)
                (* 0.25 $pressure)
            )
        )
    )
)

;; Apply policy homeostatic damping to a goal update.
;; Example: (applyHomeostaticDamping policy state (0.1)) -> (0.1)
(= (applyHomeostaticDamping $policy $state $deltaG)
    (let* (
        ($pressure (boundaryPressure $policy $state))
        ($idxResult (stabilityIndividuationIndex (stateSchema $state)))
    )
        (if (== $pressure 0.0)
            $deltaG
            (case $idxResult (
                ((validationOk $idx)
                    (scaleArray
                        $deltaG
                        (positivePart (- 1.0 (* $pressure (index-atom (stateGoals $state) $idx))))
                    )
                )
                ($_ $deltaG)
            ))
        )
    )
)

;; Project a canonical state into the policy safe region while preserving its schema.
;; Example: (projectToSafeRegion policy state) -> projected-state
(= (projectToSafeRegion $policy $state)
    (let* (
        ($schema (stateSchema $state))
        ($idxResult (stabilityIndividuationIndex $schema))
        ($initialPressure (boundaryPressure $policy $state))
    )
        (case $idxResult (
            ((validationOk $idx)
                (let* (
                    ($safeGoals (projectGoalsToSafe
                        (stateGoals $state)
                        $idx
                        (stabilityThetaSafe $policy)
                        (stabilityGMax $policy)
                    ))
                    ($projected (motivationState $schema $safeGoals (stateModulators $state)))
                    ($finalPressure (boundaryPressure $policy $projected))
                    ($cautionPressure (maxNumber $initialPressure $finalPressure))
                )
                    (if (> $cautionPressure 0.0)
                        (boostNamedModulators
                            $projected
                            (stabilityCautionModulators $policy)
                            (* 0.1 $cautionPressure)
                        )
                        $projected
                    )
                )
            )
            ($_ $state)
        ))
    )
)

;; Check the contractive update law through a canonical bimonad.
;; Example: (checkContractiveUpdateLaw policy bimonad x y stimulus candidates) -> True
(= (checkContractiveUpdateLawFromBoundary False $policy $bimonad $x $y $stimulus $candidates)
    True
)

(= (checkContractiveUpdateLawFromBoundary True $policy $bimonad $x $y $stimulus $candidates)
    (let* (
        ($distInitial (eval (stateDistance $x $y)))
        ($transX (eval (computeTransition $bimonad $x $stimulus $candidates)))
        ($transY (eval (computeTransition $bimonad $y $stimulus $candidates)))
        ($fX (eval (transitionComputationState $transX)))
        ($fY (eval (transitionComputationState $transY)))
        ($distFinal (eval (stateDistance $fX $fY)))
        ($limit (eval (+ (* (stabilityCContract $policy) $distInitial) (stabilityEpsilon $policy))))
    )
        (eval (<= $distFinal $limit))
    )
)

(= (checkContractiveUpdateLaw $policy $bimonad $x $y $stimulus $candidates)
    (let* (
        ($xBand (eval (isInBoundaryBand $policy $x)))
        ($yBand (eval (isInBoundaryBand $policy $y)))
        ($nearBoundary (eval (or $xBand $yBand)))
    )
        (checkContractiveUpdateLawFromBoundary $nearBoundary $policy $bimonad $x $y $stimulus $candidates)
    )
)
