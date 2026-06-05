!(import! &self ../../core/helper)
!(import! &self "../../core/helpers.py")
!(import! &self ../../core/state)
!(import! &self ../../core/state_accessors)
!(import! &self ../../core/config)
!(import! &self ../../openpsi/config)
!(import! &self ../../openpsi/appraisal_helpers)
!(import! &self ../../openpsi/appraisal)
!(import! &self ../../category/functors)
!(import! &self ../../category/bimonad)
!(import! &self ../../magus/decision)
!(import! &self ../../dynamics/stability)
!(import! &self ../../dynamics/coherence)
!(import! &self ../main)
;; Mock bimonad fixture for deterministic integration tests.
;; Example: (runMetaMoCycle (integrationBimonad) states stimulus candidates () () False 0.05)
(= (integrationBimonad)
    (metaMoPseudoBimonad
        (appraisalComonad integrationIdentityExtract integrationRichAppraise)
        (decisionMonad integrationIdentityExtract integrationConstantDecide integrationSimpleScore)
        integrationIdentityDamping
        integrationIdentityProject
        integrationIdentityProject
        integrationAlwaysContractive
        integrationAlwaysSafe)
)

;; Shared OpenPSI-shaped state fixture.
;; Example: (integrationState)
(= (integrationState)
    (motivation
        (0.25 0.75 0.5 0.5 0.5 0.5 0.5 0.5)
        (0.125 0.25 0.375 0.5 0.625 0.75))
)

;; Two-subsystem state fixture used by most cycle tests.
;; Example: (integrationStates)
(= (integrationStates)
    (
        (subsystemState curiosity (integrationState))
        (subsystemState ethics (integrationState))
    )
)

;; Stimulus fixture used by integration tests.
;; Example: (integrationStimulus)
(= (integrationStimulus)
    (stimulus (0.125 0.125 0.0 0.0))
)

;; Candidate action fixture. Local test decisions pick act1; consensus scoring
;; prefers act2.
;;
;; Example: (integrationCandidates)
(= (integrationCandidates)
    (
        (action act1
            (0.25 0.25 0.0 0.0 0.0 0.0 0.0 0.0)
            0.25
            (0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0))
        (action act2
            (0.5 0.75 0.0 0.0 0.0 0.0 0.0 0.0)
            0.25
            (-0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0))
    )
)

;; Expected target from one local subsystem step with the mock bimonad.
;; Example: (integrationExpectedLocalTarget)
(= (integrationExpectedLocalTarget)
    (motivation
        (0.375 0.875 0.5 0.5 0.5 0.5 0.5 0.5)
        (0.25 0.375 0.375 0.5 0.625 0.75))
)

;; Expected default blended next state from integrationState toward
;; integrationExpectedLocalTarget. The fixture's blend factor is 0.1875.
;; Example: (integrationExpectedBlendedLocalTarget)
(= (integrationExpectedBlendedLocalTarget)
    (motivation
        (0.2734375 0.7734375 0.5 0.5 0.5 0.5 0.5 0.5)
        (0.1484375 0.2734375 0.375 0.5 0.625 0.75))
)

;; Expected merged target from consensus over the two fixture subsystem states.
;; Example: (integrationExpectedConsensusTarget)
(= (integrationExpectedConsensusTarget)
    (motivation
        (0.125 0.875 0.5 0.5 0.5 0.5 0.5 0.5)
        (0.25 0.375 0.375 0.5 0.625 0.75))
)

;; Precomputed no-blend cycle result fixture used by accessor tests.
;; Example: (cycleFinalAction (integrationCycleNoBlend))
(= (integrationCycleNoBlend)
    (runMetaMoCycle
        (integrationBimonad)
        (integrationStates)
        (integrationStimulus)
        (integrationCandidates)
        (consensusPair curiosity ethics)
        ()
        False
        0.05)
)

;; Identity translation functor fixture for peer simulation tests.
;; Example:
;;   (computePeerSimulations (integrationStates) (integrationIdentityTranslator))
(= (integrationIdentityTranslator)
    (translationFunctor
        ((1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0)
         (0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0)
         (0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0)
         (0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0)
         (0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0)
         (0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0)
         (0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0)
         (0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0))
        ((1.0 0.0 0.0 0.0 0.0 0.0)
         (0.0 1.0 0.0 0.0 0.0 0.0)
         (0.0 0.0 1.0 0.0 0.0 0.0)
         (0.0 0.0 0.0 1.0 0.0 0.0)
         (0.0 0.0 0.0 0.0 1.0 0.0)
         (0.0 0.0 0.0 0.0 0.0 1.0)))
)

!(cycleFinalAction (eval (integrationCycleNoBlend)))
 !(get-type (metaMoPseudoBimonad (appraisalComonad integrationIdentityExtract integrationRichAppraise) 
         (decisionMonad integrationIdentityExtract integrationConstantDecide integrationSimpleScore) 
         integrationIdentityDamping 
         integrationIdentityProject 
         integrationIdentityProject 
         integrationAlwaysContractive 
         integrationAlwaysSafe))

 !(test
     (cycleFinalAction (eval (integrationCycleNoBlend)))
     (action act2
         (0.5 0.75 0.0 0.0 0.0 0.0 0.0 0.0)
         0.25
         (-0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0))
 )

 !(test
     (cycleMergedCurrent (eval (integrationCycleNoBlend)))
     (eval (integrationState))
 )

 !(test
     (cycleMergedTarget (eval (integrationCycleNoBlend)))
     (eval (integrationExpectedConsensusTarget))
 )

 !(test
     (cycleNextStates (eval (integrationCycleNoBlend)))
     (
         (subsystemState curiosity (eval (integrationExpectedLocalTarget)))
         (subsystemState ethics (eval (integrationExpectedLocalTarget)))
     )
 )

 !(test
     (cycleLocalActions (eval (integrationCycleNoBlend)))
     (
         (namedAction curiosity
             (action act1
                 (0.25 0.25 0.0 0.0 0.0 0.0 0.0 0.0)
                 0.25
                 (0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0)))
         (namedAction ethics
             (action act1
                 (0.25 0.25 0.0 0.0 0.0 0.0 0.0 0.0)
                 0.25
                 (0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0)))
     )
 )

 !(test
     (cycleLocalTargets (eval (integrationCycleNoBlend)))
     (
         (namedMotivation curiosity (eval (integrationExpectedLocalTarget)))
         (namedMotivation ethics (eval (integrationExpectedLocalTarget)))
     )
 )

 !(test
     (cyclePeerSimulations
         (runMetaMoCycle
             (eval (integrationBimonad))
             (eval (integrationStates))
             (eval (integrationStimulus))
             (eval (integrationCandidates))
             ()
             (integrationIdentityTranslator)
             False
             0.05))
     (
         (namedMotivation curiosity (eval (integrationState))) 
         (namedMotivation ethics (eval (integrationState)))
     )
 )

 !(test
     (cycleFinalAction
         (runMetaMoCycleDefault
             (eval (integrationBimonad))
             (eval (integrationStates))
             (eval (integrationStimulus))
             (eval (integrationCandidates))
             ()
             ()))
     (action act2
         (0.5 0.75 0.0 0.0 0.0 0.0 0.0 0.0)
         0.25
         (-0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0))
 )

 !(test
     (cycleNextStates
         (runMetaMoCycleDefault
             (eval (integrationBimonad))
             (eval (integrationStates))
             (eval (integrationStimulus))
             (eval (integrationCandidates))
             ()
             ()))
     (
         (subsystemState curiosity (eval (integrationExpectedBlendedLocalTarget)))
         (subsystemState ethics (eval (integrationExpectedBlendedLocalTarget)))
     )
 )

 !(test
     (cycleFinalAction
         (runMetaMoCycle
             (integrationBimonad)
             ((subsystemState curiosity (eval (integrationState))))
             (integrationStimulus)
             (integrationCandidates)
             ()
             ()
             False
             0.05))
     (action act1
         (0.25 0.25 0.0 0.0 0.0 0.0 0.0 0.0)
         0.25
         (0.125 0.125 0.0 0.0 0.0 0.0 0.0 0.0))
 )

 !(test
     (validateActionShape
         (cycleFinalAction
             (runMetaMoCycle
                 (eval (defaultMetaMoBimonad))
                 (eval (integrationStates))
                 (eval (integrationStimulus)) 
                 (eval (integrationCandidates)) 
                 ()
                 ()
                 False
                 0.05)))
     True
 )

 !(test
     (validateMotivationalStateShape
         (cycleMergedTarget
             (runMetaMoCycle
                 (eval (defaultMetaMoBimonad))
                 (eval (integrationStates))
                 (eval (integrationStimulus))
                 (eval (integrationCandidates)) 
                 ()
                 ()
                 False
                 0.05)))
     True
 )
