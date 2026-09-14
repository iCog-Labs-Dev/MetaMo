!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../bimonad)

!(import! &self ../../core/state)
!(import! &self ../../core/config)
!(import! &self ../functors)
!(import! &self ../../openpsi/config)

;; Mock extraction function (identity).
(= (identityExtract $state)
    $state
)

;; Mock appraisal function that updates modulators.
(= (simpleAppraise $state (stimulus $stimValues))
    (let* (
        ($stim0 (index-atom $stimValues 0))
        ($stim1 (index-atom $stimValues 1))
    )
        (motivation
            (motivationGoals $state)
            (clipVector (vectorAdd (motivationModulators $state) ($stim0 $stim1)) 0.0 1.0)
        )
    )
)

;; Mock unit function (identity).
(= (identityUnit $state)
    $state
)

;; Mock decision function (constant result).
(= (constantDecide $state $candidates)
    (decisionResult (action act1 (0.25 0.75) 0.25 (0.125 -0.125)) (0.125 -0.125))
)

;; Mock scoring function (sum correlation).
(= (simpleScore $state (action $actionId $goalCorrelations $riskEstimate $deltaG))
    (+ (sum $goalCorrelations) (sum (motivationGoals $state)))
)

;; Mock damping function (identity).
(= (identityDamping $state $deltaG)
    $deltaG
)

;; Mock boundary stabilization (identity).
(= (identityBoundary $state)
    $state
)

;; Mock projection function (identity).
(= (identityBoundary $state)
    $state
)

;; Mock contractivity check (always True).
(= (alwaysContractive $bimonad $state $referenceState $stimulus $candidates)
    True
)

;; Mock safety region check (always True).
(= (alwaysSafe $state)
    True
)

;; Mock appraisal function for high-dimensional states (6 modulators).
;; Adds first two stimulus values to the first two modulators, leaves rest unchanged.
(= (richAppraise $state (stimulus $stimValues))
    (let* (
        ($stim0 (index-atom $stimValues 0))
        ($stim1 (index-atom $stimValues 1))
    )
        (motivation
            (motivationGoals $state)
            (clipVector (vectorAdd (motivationModulators $state) ($stim0 $stim1 0.0 0.0 0.0 0.0)) 0.0 1.0)
        )
    )
)

;; A large, shared motivational state for consensus testing.
(= (consensusState)
    (motivation
        (0.25 0.75 0.5 0.5 0.5 0.5 0.5 0.5)
        (0.125 0.25 0.375 0.5 0.625 0.75)
    )
)

;; A shared candidate set for consensus and decision testing.
(= (candidateSet)
    (
        (action act1 (0.25 0.25 0.0 0.0 0.0 0.0 0.0 0.0) 0.25 (0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0))
        (action act2 (0.5 0.75 0.0 0.0 0.0 0.0 0.0 0.0) 0.25 (-0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0))
    )
)

;; Verify the consensus scoring formula: average - 0.25 * absolute difference.
!(test
    (candidateConsensusScore 4.0 2.0)
    2.5
)

;; Ensure decisionContext correctly integrates appraisal and identity boundary.
!(test
    (decisionContext
        (metaMoPseudoBimonad
            (appraisalComonad identityExtract simpleAppraise)
            (decisionMonad identityUnit constantDecide simpleScore)
            identityDamping
            identityBoundary
            identityProject
            alwaysContractive
            alwaysSafe
        )
        (motivation (0.25 0.75) (0.125 0.25))
        (stimulus (0.125 0.125 0.0 0.0))
    )
    (motivation (0.25 0.75) (0.25 0.375))
)

;; Verify that computeTransition produces the expected final state after appraisal and decision.
!(test
    (transitionState
        (computeTransition
            (metaMoPseudoBimonad
                (appraisalComonad identityExtract simpleAppraise)
                (decisionMonad identityUnit constantDecide simpleScore)
                identityDamping
                identityBoundary
                identityProject
                alwaysContractive
                alwaysSafe
            )
            (motivation (0.25 0.75) (0.125 0.25))
            (stimulus (0.125 0.125 0.0 0.0))
            ()
        )
    )
    (motivation (0.375 0.625) (0.25 0.375))
)

;; Validate the conservative fallback mechanism (averaging current and proposed states).
!(test
    (applyConservativeFallback
        (motivation (0.25 0.75) (0.125 0.25))
        (motivation (0.75 0.25) (0.625 0.75))
    )
    (motivation (0.5 0.5) (0.375 0.5))
)

;; Test consensus action selection when evaluating candidates from two identical states.
!(test
    (consensusAction
        (metaMoPseudoBimonad
            (appraisalComonad identityExtract richAppraise)
            (decisionMonad identityUnit constantDecide simpleScore)
            identityDamping
            identityBoundary
            identityProject
            alwaysContractive
            alwaysSafe
        )
        (consensusState)
        (consensusState)
        (stimulus (0.125 0.125 0.0 0.0))
        (candidateSet)
    )
    (action act2 (0.5 0.75 0.0 0.0 0.0 0.0 0.0 0.0) 0.25 (-0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0))
)

;; Ensure a complete consensus transition correctly merges states for high-dimensional motivations.
!(test
    (transitionState
        (consensusTransitionDefault
            (metaMoPseudoBimonad
                (appraisalComonad identityExtract richAppraise)
                (decisionMonad identityUnit constantDecide simpleScore)
                identityDamping
                identityBoundary
                identityProject
                alwaysContractive
                alwaysSafe
            )
            (consensusState)
            (consensusState)
            (stimulus (0.125 0.125 0.0 0.0))
            (candidateSet)
        )
    )
    (motivation
        (0.125 0.875 0.5 0.5 0.5 0.5 0.5 0.5)
        (0.25 0.375 0.375 0.5 0.625 0.75)
    )
)
