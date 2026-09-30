!(import! &self "../../core/helpers.py")

!(import! &self ../../core/helper)
!(import! &self ../../core/state)
!(import! &self ../../core/state_accessors)
!(import! &self ../../core/config)
!(import! &self ../../openpsi/appraisal_helpers)
!(import! &self ../../openpsi/appraisal)
!(import! &self ../../magus/decision)
!(import! &self ../../category/functors)
!(import! &self ../../category/bimonad)
!(import! &self ../../openpsi/config)
!(import! &self ../default)
!(import! &self ../../core/registry)


(= (defTestState)
    (motivation
        (0.5 0.4 0.6 0.5 0.5 0.5 0.6 0.4)
        (0.5 0.5 0.5 0.5 0.5 0.5)
    )
)

(= (defLowIndState)
    (motivation
        (0.1 0.4 0.6 0.5 0.5 0.5 0.6 0.4)
        (0.5 0.5 0.5 0.5 0.5 0.5)
    )
)

(= (defExactBoundaryState)
    (motivation
        (0.3 0.4 0.6 0.5 0.5 0.5 0.6 0.4)
        (0.5 0.5 0.5 0.5 0.5 0.5)
    )
)

(= (defStimulus)
    (openPsiStimulus 0.3 0.6 0.1 0.2)
)

(= (defCandidates)
    (let* (
        ($candidateA (|-> () 
            (action MOVE 
                (0.3 0.1 0.5 0.2 0.0 -0.1 0.4 0.1) 
                0.1 
                (0.02 0.01 0.03 0.01 0.01 0.01 0.02 0.01)
            )
        ))

        ($candidateB (|-> () 
            (action STAY 
                (0.1 0.0 0.2 0.1 0.1 0.2 0.1 0.3) 
                0.05 
                (0.01 0.00 0.01 0.01 0.02 0.01 0.01 0.01)
            )
        ))
    )
        ( ($candidateA) ($candidateB) )
    )
)

;; defaultDamping  

;; Zero delta stays zero
!(test
    (defaultDamping (defTestState) (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0))
    (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0)
)

;; Positive unit vector scaled down by C_CONTRACT = 0.9
!(test
    (defaultDamping (defTestState) (1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0))
    (0.9 0.9 0.9 0.9 0.9 0.9 0.9 0.9)
)

;; Negative vector — sign is preserved
!(test
    (defaultDamping (defTestState) (-1.0 -1.0 -1.0 -1.0 -1.0 -1.0 -1.0 -1.0))
    (-0.9 -0.9 -0.9 -0.9 -0.9 -0.9 -0.9 -0.9)
)

;; damping is independent of the state argument (state is unused in default impl)
!(test
    (defaultDamping (defLowIndState) (1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0))
    (0.9 0.9 0.9 0.9 0.9 0.9 0.9 0.9)
)

;; defaultBoundaryStabilize  

;; Goals are never touched
!(test
    (motivationGoals (defaultBoundaryStabilize (defTestState)))
    (motivationGoals (defTestState))
)
;; Modulators already in [0.1, 0.9] are unchanged
!(test
    (motivationModulators (defaultBoundaryStabilize (defTestState)))
    (0.5 0.5 0.5 0.5 0.5 0.5)
)
;; Modulators at 0.0 clip up to ETA_BOUNDARY = 0.1
!(test
    (let $defzeroModState 
        (motivation 
            (0.5 0.4 0.6 0.5 0.5 0.5 0.6 0.4) 
            (0.0 0.0 0.0 0.0 0.0 0.0)
        )
        (motivationModulators (defaultBoundaryStabilize $defzeroModState))
    )
    (0.1 0.1 0.1 0.1 0.1 0.1)
)

;; Modulators at 1.0 clip down to 1 - ETA_BOUNDARY = 0.9
!(test
    (let $defMaxModState 
        (motivation 
            (0.5 0.4 0.6 0.5 0.5 0.5 0.6 0.4) 
            (1.0 1.0 1.0 1.0 1.0 1.0)
        )
        (motivationModulators (defaultBoundaryStabilize $defMaxModState))
    )
    (0.9 0.9 0.9 0.9 0.9 0.9)
)
;; defaultProject  


;; Modulators are untouched by projection
!(test
    (motivationModulators (defaultProject (defTestState)))
    (motivationModulators (defTestState))
)

;; A safe state (gInd = 0.5) passes through without change to gInd
!(test
    (getGoal (defaultProject (defTestState)) gInd)
    0.5
)

;; gInd below THETA_SAFE is lifted to at least THETA_SAFE
!(test
    (>= (getGoal (defaultProject (defLowIndState)) gInd) (THETA_SAFE))
    True
)

;; gInd exactly at THETA_SAFE is left alone
!(test
    (getGoal (defaultProject (defExactBoundaryState)) gInd)
    0.3
)

;;  defaultSafeRegionCheck  

;; gInd = 0.5 → safely above threshold
!(test
    (defaultSafeRegionCheck (defTestState))
    True
)

;; gInd = 0.2 -> below THETA_SAFE = 0.3
!(test
    (let $defunsafeState 
        (motivation 
            (0.2 0.4 0.6 0.5 0.5 0.5 0.6 0.4) 
            (0.5 0.5 0.5 0.5 0.5 0.5)
        )
        (defaultSafeRegionCheck $defunsafeState)
    )
    False
)

;; gInd exactly at THETA_SAFE → boundary is inclusive
!(test
    (defaultSafeRegionCheck (defExactBoundaryState))
    True
)


;; defaultContractiveCheck  

;; Identical state and reference → refDist = 0, short-circuit returns True
!(test
    (defaultContractiveCheck
        (defaultMetaMo)
        (defTestState) (defTestState)
        (defStimulus) (defCandidates)
    )
    True
)

;; Small perturbation (0.01 on one goal) — nearby trajectories should stay close
!(test
    (let $defNearbyState 
        (motivation 
            (0.51 0.4 0.6 0.5 0.5 0.5 0.6 0.4) 
            (0.5 0.5 0.5 0.5 0.5 0.5)
        )
        (defaultContractiveCheck
            (defaultMetaMo)
            (defTestState)
            $defNearbyState
            (defStimulus)
            (defCandidates)
        )
    )
    True
)
