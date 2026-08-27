;; Goal compatibility matrix support for canonical MAGUS profiles.

(: GoalCompatibilityMatrix Type)
(: goalCompatibilityMatrix (-> Expression Number Number Number GoalCompatibilityMatrix))

;; Return the matrix rows.
;; Example: (compatibilityMatrixRows (goalCompatibilityMatrix ((0.0)) 1.0 0.5 1.5)) -> ((0.0))
(= (compatibilityMatrixRows (goalCompatibilityMatrix $matrix $scale $minimum $maximum))
    $matrix
)

;; Return the influence scale.
;; Example: (compatibilityMatrixInfluenceScale (goalCompatibilityMatrix ((0.0)) 1.0 0.5 1.5)) -> 1.0
(= (compatibilityMatrixInfluenceScale (goalCompatibilityMatrix $matrix $scale $minimum $maximum))
    $scale
)

;; Return the minimum factor.
;; Example: (compatibilityMatrixMinFactor (goalCompatibilityMatrix ((0.0)) 1.0 0.5 1.5)) -> 0.5
(= (compatibilityMatrixMinFactor (goalCompatibilityMatrix $matrix $scale $minimum $maximum))
    $minimum
)

;; Return the maximum factor.
;; Example: (compatibilityMatrixMaxFactor (goalCompatibilityMatrix ((0.0)) 1.0 0.5 1.5)) -> 1.5
(= (compatibilityMatrixMaxFactor (goalCompatibilityMatrix $matrix $scale $minimum $maximum))
    $maximum
)

;; Sum absolute values in a row.
;; Example: (sumAbsListCanonical (-1.0 2.0)) -> 3.0
(= (sumAbsListCanonical $items)
    (if (== $items ())
        0.0
        (let* (
            (($head $tail) (decons $items))
        )
            (+ (absNumber $head) (sumAbsListCanonical $tail))
        )
    )
)

;; Validate matrix shape and factor bounds.
;; Example: (validationIsOk (validateGoalCompatibilityMatrix (goalCompatibilityMatrix ((0.0)) 1.0 0.5 1.5) 1)) -> True
(= (validateGoalCompatibilityMatrix $compatibilityMatrix $goalCount)
    (let* (
        ($matrix (compatibilityMatrixRows $compatibilityMatrix))
        ($scale (compatibilityMatrixInfluenceScale $compatibilityMatrix))
        ($minimum (compatibilityMatrixMinFactor $compatibilityMatrix))
        ($maximum (compatibilityMatrixMaxFactor $compatibilityMatrix))
    )
        (if (== (size-atom $matrix) $goalCount)
            (if (>= $scale 0.0)
                (if (<= $minimum $maximum)
                    (validationOk $compatibilityMatrix)
                    (validationError invalid-compatibility-bounds ($minimum $maximum))
                )
                (validationError negative-compatibility-scale $scale)
            )
            (validationError compatibility-row-count-mismatch ($matrix $goalCount))
        )
    )
)

;; Compute the MIC factor for one goal coordinate.
;; Example: (compatibilityFactorForGoal matrix 0 state) -> 1.0
(= (compatibilityFactorForGoal $compatibilityMatrix $goalIdx $state)
    (let* (
        ($matrix (compatibilityMatrixRows $compatibilityMatrix))
        ($row (index-atom $matrix $goalIdx))
        ($denominator (sumAbsListCanonical $row))
    )
        (if (== $denominator 0.0)
            1.0
            (clipRange
                (+ 1.0
                    (*
                        (compatibilityMatrixInfluenceScale $compatibilityMatrix)
                        (/ (dotProduct $row (stateGoals $state)) $denominator)
                    )
                )
                (compatibilityMatrixMinFactor $compatibilityMatrix)
                (compatibilityMatrixMaxFactor $compatibilityMatrix)
            )
        )
    )
)

