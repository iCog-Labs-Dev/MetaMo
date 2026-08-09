(: qwestorStabilityPolicyRecord
    (-> Number Number Number Number Number Number Number Number Number Number
        Number Number Expression StabilityPolicy))

(: QwestorStabilityDiagnostics Type)
(: qwestorStabilityDiagnosticsRecord
    (-> Number Bool Bool Number QwestorStabilityDiagnostics))

;; Build the configured Qwestor stability policy
(= (qwestorStabilityPolicy)
    (let* (
        ($config (qwestorStabilityConfig))
    )
        (qwestorStabilityPolicyRecord
            (qwestorConfigGet $config INDIVIDUATION_FLOOR 0.30)
            (qwestorConfigGet $config BENEFICIAL_FLOOR 0.55)
            (qwestorConfigGet $config HONESTY_FLOOR 0.55)
            (qwestorConfigGet $config SAFETY_FLOOR 0.55)
            (qwestorConfigGet $config GOAL_NORM_MAX 3.00)
            (qwestorConfigGet $config THRESHOLD_MIN 0.20)
            (qwestorConfigGet $config THRESHOLD_MAX 0.95)
            (qwestorConfigGet $config AROUSAL_MIN 0.10)
            (qwestorConfigGet $config AROUSAL_MAX 0.90)
            (qwestorConfigGet $config BOUNDARY_WIDTH 0.10)
            (qwestorConfigGet $config CONTRACTION_CONSTANT 0.90)
            (qwestorConfigGet $config CONTRACTION_EPSILON 0.05)
            (threshold securing risk_aversion failure_wariness)
        )
    )
)

;; Return the Qwestor individuation floor
(= (qwestorStabilityIndividuationFloor
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $indFloor
)

;; Return the Qwestor beneficial floor
(= (qwestorStabilityBeneficialFloor
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $beneficialFloor
)

;; Return the Qwestor honesty floor
(= (qwestorStabilityHonestyFloor
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $honestyFloor
)

;; Return the Qwestor safety floor
(= (qwestorStabilitySafetyFloor
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $safetyFloor
)

;; Return the Qwestor maximum goal norm
(= (qwestorStabilityGoalNormMax
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $goalNormMax
)

;; Return the Qwestor threshold lower bound
(= (qwestorStabilityThresholdMin
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $thresholdMin
)

;; Return the Qwestor threshold upper bound
(= (qwestorStabilityThresholdMax
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $thresholdMax
)

;; Return the Qwestor arousal lower bound
(= (qwestorStabilityArousalMin
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $arousalMin
)

;; Return the Qwestor arousal upper bound
(= (qwestorStabilityArousalMax
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $arousalMax
)

;; Return the Qwestor boundary width
(= (qwestorStabilityBoundaryWidth
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $boundaryWidth
)

;; Return the Qwestor contraction constant
(= (qwestorStabilityContraction
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $contraction
)

;; Return the Qwestor contraction epsilon
(= (qwestorStabilityEpsilon
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $epsilon
)

;; Return the Qwestor caution modulator names
(= (qwestorStabilityCautionNames
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $cautionNames
)

;; Expose the universal individuation floor to the generic runtime
(= (stabilityThetaSafe
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $indFloor
)

;; Expose the calibrated goal norm to the generic runtime
(= (stabilityGMax
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $goalNormMax
)

;; Expose the boundary width to the generic runtime
(= (stabilityEtaBoundary
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $boundaryWidth
)

;; Expose the contraction constant to the generic runtime
(= (stabilityCContract
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $contraction
)

;; Expose the contraction epsilon to the generic runtime
(= (stabilityEpsilon
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $epsilon
)

;; Expose all four caution modulators to the generic runtime
(= (stabilityCautionModulators
        (qwestorStabilityPolicyRecord
            $indFloor $beneficialFloor $honestyFloor $safetyFloor $goalNormMax
            $thresholdMin $thresholdMax $arousalMin $arousalMax $boundaryWidth
            $contraction $epsilon $cautionNames))
    $cautionNames
)

;; Validate all Qwestor stability-policy parameters
(= (qwestorValidateStabilityPolicy $policy)
    (let* (
        ($floorNorm
            (eval (norm
                (
                    (qwestorStabilityIndividuationFloor $policy)
                    (qwestorStabilityBeneficialFloor $policy)
                    (qwestorStabilityHonestyFloor $policy)
                    (qwestorStabilitySafetyFloor $policy)
                ))))
    )
        (if (> (qwestorStabilityBoundaryWidth $policy) 0.0)
            (if (>= (qwestorStabilityGoalNormMax $policy) $floorNorm)
                (if (<=
                        (qwestorStabilityThresholdMin $policy)
                        (qwestorStabilityThresholdMax $policy))
                    (if (<=
                            (qwestorStabilityArousalMin $policy)
                            (qwestorStabilityArousalMax $policy))
                        (if (and
                                (>= (qwestorStabilityContraction $policy) 0.0)
                                (<= (qwestorStabilityContraction $policy) 1.0))
                            (validationOk $policy)
                            (validationError
                                invalid-qwestor-contraction
                                (qwestorStabilityContraction $policy)))
                        (validationError invalid-qwestor-arousal-bounds $policy))
                    (validationError invalid-qwestor-threshold-bounds $policy))
                (validationError qwestor-goal-norm-below-floor-norm $policy))
            (validationError invalid-qwestor-boundary-width $policy)
        )
    )
)

;; Measure the smallest signed distance to every Qwestor safety bound
(= (qwestorDistanceToUnsafeBoundary $policy $state)
    (py-call
        (policy_helpers.signed_safe_distance
            (stateGoals $state)
            (stateModulators $state)
            (0 2 3 4)
            (
                (qwestorStabilityIndividuationFloor $policy)
                (qwestorStabilityBeneficialFloor $policy)
                (qwestorStabilityHonestyFloor $policy)
                (qwestorStabilitySafetyFloor $policy)
            )
            (qwestorStabilityGoalNormMax $policy)
            4
            (qwestorStabilityThresholdMin $policy)
            (qwestorStabilityThresholdMax $policy)
            1
            (qwestorStabilityArousalMin $policy)
            (qwestorStabilityArousalMax $policy)
        )
    )
)

;; Check every normative, norm, threshold, and arousal bound
(= (qwestorIsInSafeRegion $policy $state)
    (>= (qwestorDistanceToUnsafeBoundary $policy $state) 0.0)
)

;; Compute Qwestor boundary pressure from signed distance
(= (qwestorBoundaryPressure $policy $state)
    (let* (
        ($distance (qwestorDistanceToUnsafeBoundary $policy $state))
        ($width (qwestorStabilityBoundaryWidth $policy))
    )
        (if (< $distance 0.0)
            1.0
            (if (>= $distance $width)
                0.0
                (clipUnit (- 1.0 (/ $distance $width)))
            )
        )
    )
)

;; Raise all Qwestor caution modulators near any configured boundary
(= (qwestorRaiseBoundaryCaution $policy $state)
    (let* (
        ($pressure (qwestorBoundaryPressure $policy $state))
        ($gain
            (qwestorConfigGet
                (qwestorStabilityConfig) BOUNDARY_CAUTION_GAIN 0.25))
    )
        (if (== $pressure 0.0)
            $state
            (boostNamedModulators
                $state
                (qwestorStabilityCautionNames $policy)
                (* $gain $pressure)
            )
        )
    )
)

;; Damp a complete goal delta under Qwestor boundary pressure
(= (qwestorApplyHomeostaticDamping $policy $state $deltaG)
    (let* (
        ($pressure (qwestorBoundaryPressure $policy $state))
        ($factor
            (positivePart
                (- 1.0 (* $pressure (stateGoal $state individuation)))))
    )
        (scaleArray $deltaG $factor)
    )
)

;; Clamp state modulators governed directly by the safe region
(= (qwestorClampStabilityModulators $policy $state)
    (let* (
        ($boundedModulators (clipVector (stateModulators $state) 0.0 1.0))
        ($boundedState
            (motivationState
                (stateSchema $state)
                (stateGoals $state)
                $boundedModulators))
        ($thresholdState
            (stateSetModulator
                $boundedState
                threshold
                (clipRange
                    (stateModulator $boundedState threshold)
                    (qwestorStabilityThresholdMin $policy)
                    (qwestorStabilityThresholdMax $policy))))
    )
        (stateSetModulator
                $thresholdState
                arousal
                (clipRange
                    (stateModulator $thresholdState arousal)
                    (qwestorStabilityArousalMin $policy)
                    (qwestorStabilityArousalMax $policy)))
    )
)

;; Project goals and bounded core modulators into the Qwestor safe region
(= (qwestorProjectToSafeRegion $policy $state)
    (let* (
        ($initialPressure (qwestorBoundaryPressure $policy $state))
        ($safeGoals
            (py-call
                (policy_helpers.project_goals_with_floors
                    (stateGoals $state)
                    (0 2 3 4)
                    (
                        (qwestorStabilityIndividuationFloor $policy)
                        (qwestorStabilityBeneficialFloor $policy)
                        (qwestorStabilityHonestyFloor $policy)
                        (qwestorStabilitySafetyFloor $policy)
                    )
                    (qwestorStabilityGoalNormMax $policy)
                )
            ))
        ($goalProjected
            (motivationState
                (stateSchema $state)
                $safeGoals
                (stateModulators $state)))
        ($projected (qwestorClampStabilityModulators $policy $goalProjected))
        ($projectionGain
            (qwestorConfigGet
                (qwestorStabilityConfig) PROJECTION_CAUTION_GAIN 0.10))
        ($cautioned
            (if (> $initialPressure 0.0)
                (boostNamedModulators
                    $projected
                    (qwestorStabilityCautionNames $policy)
                    (* $projectionGain $initialPressure)
                )
                $projected
            ))
    )
        (qwestorClampStabilityModulators $policy $cautioned)
    )
)

;; Check a measured transition against the configured contraction bound
(= (qwestorContractiveDistancesHold
        $policy $initialDistance $finalDistance)
    (<=
        $finalDistance
        (+
            (* (qwestorStabilityContraction $policy) $initialDistance)
            (qwestorStabilityEpsilon $policy))
    )
)

;; Diagnose whether projection intervened and produced a safe state
(= (qwestorDiagnoseProjection $policy $state)
    (let* (
        ($projected (qwestorProjectToSafeRegion $policy $state))
    )
        (qwestorStabilityDiagnosticsRecord
            (qwestorBoundaryPressure $policy $state)
            (qwestorIsInSafeRegion $policy $state)
            (qwestorIsInSafeRegion $policy $projected)
            (stateDistance $state $projected)
        )
    )
)

;; Return diagnostic pressure before projection
(= (qwestorDiagnosticsPressure
        (qwestorStabilityDiagnosticsRecord
            $pressure $safeBefore $safeAfter $projectionDistance))
    $pressure
)

;; Return diagnostic safe-region status before projection
(= (qwestorDiagnosticsSafeBefore
        (qwestorStabilityDiagnosticsRecord
            $pressure $safeBefore $safeAfter $projectionDistance))
    $safeBefore
)

;; Return diagnostic safe-region status after projection
(= (qwestorDiagnosticsSafeAfter
        (qwestorStabilityDiagnosticsRecord
            $pressure $safeBefore $safeAfter $projectionDistance))
    $safeAfter
)

;; Return diagnostic projection distance
(= (qwestorDiagnosticsProjectionDistance
        (qwestorStabilityDiagnosticsRecord
            $pressure $safeBefore $safeAfter $projectionDistance))
    $projectionDistance
)
