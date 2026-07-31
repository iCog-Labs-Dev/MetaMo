;; Canonical dynamics defaults facade.

;; Check the default safe region for a schema-aware state.
;; Example: (defaultSafeRegionCheck state) -> True
(= (defaultSafeRegionCheck $state)
    (isInSafeRegion (makeDefaultStabilityPolicy) $state)
)

;; Raise default boundary caution for a schema-aware state.
;; Example: (defaultBoundaryStabilize state) -> state
(= (defaultBoundaryStabilize $state)
    (raiseBoundaryCaution (makeDefaultStabilityPolicy) $state)
)

;; Project a schema-aware state into the default safe region.
;; Example: (defaultProject state) -> projected-state
(= (defaultProject $state)
    (projectToSafeRegion (makeDefaultStabilityPolicy) $state)
)

;; Apply default homeostatic damping.
;; Example: (defaultDamping state delta) -> damped-delta
(= (defaultDamping $state $deltaG)
    (applyHomeostaticDamping (makeDefaultStabilityPolicy) $state $deltaG)
)

;; Blend a current state toward a target through the default coherence policy.
;; Example: (defaultBlend current target) -> next-state
(= (defaultBlend $currentState $targetState)
    (blendStates (makeDefaultCoherencePolicy) $currentState $targetState)
)
