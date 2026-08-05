;; Stability and Safety Region Dynamics

;; Safe Region Check
;; Checks if the state is within the safe region R.
;; R = {(G, M) | g_over^Ind >= θ_safe ∧ ||G|| <= G_max}
(= (isInSafeRegion $state)
    (let* (
        ($gInd (getGoal $state gInd))
        ($gNorm (eval (norm (motivationGoals $state))))
    )
        (and (>= $gInd (eval (THETA_SAFE))) (<= $gNorm (eval (G_MAX))))
    )
)

;; Distance to Unsafe Boundary
;; Approximates distance from current state to the edge of the safe region (∂R).
;; Returns the minimum of: distance to individuation floor, distance to goal norm ceiling.
;; Example: (distanceToUnsafeBoundary $state)
(= (distanceToUnsafeBoundary $state)
    (let* (
        ($gInd (getGoal $state gInd))
        ($gNorm (eval (norm (motivationGoals $state))))
        ($distTheta (positivePart (- $gInd (eval (THETA_SAFE)))))
        ($distGMax (positivePart (- (eval (G_MAX)) $gNorm)))
    )
        (if (< $distTheta $distGMax) $distTheta $distGMax)
    )
)

;; Boundary Band Check
;; Checks if the state is in the boundary band B_η (inside safe region but close to boundary).
;; B_η = {x ∈ R | dist(x, X\R) <= η}
;; Example: (isInBoundaryBand $state)
(= (isInBoundaryBand $state)
    (if (isInSafeRegion $state)
        (<= (distanceToUnsafeBoundary $state) (eval (ETA_BOUNDARY)))
        False
    )
)

;; Boundary Pressure
;; Returns how strongly the safety boundary should constrain updates.
;; 0.0 = comfortably inside safe region, 1.0 = outside or on the edge.
;; Example: (boundaryPressure $state)
(= (boundaryPressure $state)
    (if (isInSafeRegion $state)
        (let $dist (distanceToUnsafeBoundary $state)
            (if (>= $dist (eval (ETA_BOUNDARY)))
                0.0
                (let $raw (- 1.0 (/ $dist (eval (ETA_BOUNDARY))))
                    (if (< $raw 0.0) 0.0 (if (> $raw 1.0) 1.0 $raw))
                )
            )
        )
        1.0
    )
)

;; Raise Boundary Caution
;; Boosts caution-related modulators as state approaches or crosses safety boundary.
;; Uses OPENPSI_CAUTION_MOD_IDX from project config to identify which modulators to boost.
;; This is the $boundaryFn plugged into the bimonad.
;; Example: (raiseBoundaryCaution (motivation (...) (...)))
(= (raiseBoundaryCaution $state)
    (let $pressure (boundaryPressure $state)
        (if (== $pressure 0.0)
            $state
            (let $boostedMods (boostAtIndices
                    (motivationModulators $state)
                    (eval (OPENPSI_CAUTION_MOD_IDX))
                    (* 0.25 $pressure)
                    1.0)
                (motivation (motivationGoals $state) $boostedMods)
            )
        )
    )
)

;; Homeostatic Damping
;; Damps goal updates near the boundary to enforce contractive dynamics.
;; Stronger boundary pressure and higher individuation induce more contraction.
;; This is the $dampingFn plugged into the bimonad.
;; Example: (applyHomeostaticDamping $state (0.1 -0.05 0.0 ...))
(= (applyHomeostaticDamping $state $deltaG)
    (let $pressure (boundaryPressure $state)
        (if (== $pressure 0.0)
            $deltaG
            (let* (
                ($gInd (getGoal $state gInd))
                ($dampingFactor (positivePart (- 1.0 (* $pressure $gInd))))
            )
                (scaleArray $deltaG $dampingFactor)
            )
        )
    )
)

;; Project to Safe Region
;; Projects a state back into the safe region by restoring individuation floor
;; and shrinking goal vector if it exceeds the allowed norm.
;; Also boosts caution modulators as a protective response.
;; This is the $projectFn plugged into the bimonad.
;; Example: (projectToSafeRegion $state)
(= (projectToSafeRegion $state)
    (let* (
        ($safeGoals (projectGoalsToSafe
            (motivationGoals $state)
            (eval (OPENPSI_GOAL_WEIGHT_IDX))
            (eval (THETA_SAFE))
            (eval (G_MAX))))
        ($boostedMods (boostAtIndices
            (motivationModulators $state)
            (eval (OPENPSI_CAUTION_MOD_IDX))
            0.1
            1.0))
    )
        (motivation $safeGoals $boostedMods)
    )
)

;; Contractive Update Law Check
;; Validates that the bimonad update F = D ∘ Ψ is contractive near the boundary.
;; Requirement: d(F(x), F(y)) <= c * d(x,y) + ε where c < 1.
;; If neither state is in the boundary band, contractivity relaxes.
;; This is the $contractiveFn plugged into the bimonad.
;; Example: (checkContractiveUpdateLaw $bimonad $x $y $stimulus $candidates)
(= (checkContractiveUpdateLaw $bimonad $x $y $stimulus $candidates)
    (if (not (or (isInBoundaryBand $x) (isInBoundaryBand $y)))
        True
        (let* (
            ($distInitial (motivationStateDistance $x $y))
            ($transX (computeTransition $bimonad $x $stimulus $candidates))
            ($transY (computeTransition $bimonad $y $stimulus $candidates))
            ($fX (transitionState $transX))
            ($fY (transitionState $transY))
            ($distFinal (motivationStateDistance $fX $fY))
        )
            (<= $distFinal (+ (* (eval (C_CONTRACT)) $distInitial) (eval (EPSILON))))
        )
    )
)
