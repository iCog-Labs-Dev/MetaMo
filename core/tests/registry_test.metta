
!(import! &self "../helpers.py")
!(import! &self ../helper)
!(import! &self ../state)
!(import! &self ../state_accessors)
!(import! &self ../config)
!(import! &self ../../openpsi/config)
!(import! &self ../../openpsi/appraisal_helpers)
!(import! &self ../../openpsi/appraisal)
!(import! &self ../../magus/decision)
!(import! &self ../../category/functors)
!(import! &self ../../category/bimonad)
!(import! &self ../../dynamics/default)
!(import! &self ../registry)

(= (regTestState)
    (motivation
        (0.5 0.4 0.6 0.5 0.5 0.5 0.6 0.4)
        (0.5 0.5 0.5 0.5 0.5 0.5)
    )
)

(= (regStimulus)
    (openPsiStimulus 0.3 0.6 0.1 0.2)
)

(= (regCandidateA)
    (action MOVE
        (0.3  0.1  0.5  0.2  0.0 -0.1  0.4  0.1)
        0.1
        (0.02 0.01 0.03 0.01 0.01 0.01 0.02 0.01)
    )
)

(= (regCandidates) 
    (let $regCandidateB 
        (|-> () 
            (action STAY 
                (0.1 0.0 0.2 0.1 0.1 0.2 0.1 0.3) 
                0.05 
                (0.01 0.00 0.01 0.01 0.02 0.01 0.01 0.01)
            )
        )
        ( (regCandidateA) ($regCandidateB) )
    )
)

;; Symbol readers resolve to config atoms  

!(test (metaMoAppraisalModuleSymbol) openPsiAppraisal)
!(test (metaMoDecisionModuleSymbol)  magusDecision)
!(test (metaMoDampingSymbol)         defaultDamping)
!(test (metaMoBoundarySymbol)        defaultBoundaryStabilize)
!(test (metaMoProjectSymbol)         defaultProject)
!(test (metaMoContractiveSymbol)     defaultContractiveCheck)
!(test (metaMoSafeRegionSymbol)      defaultSafeRegionCheck)


;;  buildMetaMo slots match config  

;; Decision slot holds a DecisionMonad wired to magusDecide
!(test
    (decisionDecideSymbol (bimonadDecision (buildMetaMo)))
    magusDecide
)

;; Dynamics symbols stored in the built bimonad match config
!(test (bimonadDampingSymbol    (buildMetaMo)) defaultDamping)
!(test (bimonadBoundarySymbol   (buildMetaMo)) defaultBoundaryStabilize)
!(test (bimonadProjectSymbol    (buildMetaMo)) defaultProject)
!(test (bimonadContractiveSymbol (buildMetaMo)) defaultContractiveCheck)
!(test (bimonadSafeRegionSymbol (buildMetaMo)) defaultSafeRegionCheck)


;; defaultMetaMo mirrors buildMetaMo  

!(test
    (bimonadDampingSymbol (defaultMetaMo))
    (bimonadDampingSymbol (buildMetaMo))
)

!(test
    (bimonadSafeRegionSymbol (defaultMetaMo))
    (bimonadSafeRegionSymbol (buildMetaMo))
)


;; end-to-end: step runs 

;; Returns a TransitionResult
!(test
    (validateMotivationalStateShape
        (transitionState
            (step (defaultMetaMo) (regTestState) (regStimulus) (regCandidates))
        )
    )
    True
)

!(test
    (actionId
        (transitionAction
            (step (defaultMetaMo) (regTestState) (regStimulus) (regCandidates))
        )
    )
    MOVE
)

;; Next state passes shape validation
!(test
    (validateMotivationalStateShape
        (transitionState
            (step (defaultMetaMo) (regTestState) (regStimulus) (regCandidates))
        )
    )
    True
)

;; Transition action has the expected action shape
!(test
    (validateActionShape
        (transitionAction
        (step (defaultMetaMo) (regTestState) (regStimulus) (regCandidates))
        )
    )
    True
)

;; Same inputs → same action 
!(test
    (transitionAction
        (step (defaultMetaMo) (regTestState) (regStimulus) (regCandidates))
    )
    (transitionAction
        (step (defaultMetaMo) (regTestState) (regStimulus) (regCandidates))
    )
)


;; module swap: custom decision wired at call-site
(= (regFirstDecision)
    (let* (
        ($regFirstUnit   (|-> ($state) 
                             $state))

        ($regFirstDecide (|-> ($state $candidates)
                             (let* ((($head $rest) (decons $candidates)))
                                 (decisionResult $head (actionDeltaG $head)))))

        ($regFirstScore  (|-> ($state $candidate) 
                             1.0))
    )
        (decisionMonad $regFirstUnit $regFirstDecide $regFirstScore)
    )
)

(= (regSwappedBimonad)
    (metaMoPseudoBimonad
        (eval (openPsiAppraisal))
        (regFirstDecision)
        defaultDamping
        defaultBoundaryStabilize
        defaultProject
        defaultContractiveCheck
        defaultSafeRegionCheck
    )
)

;; Swapped bimonad produces a valid result
!(test
    (validateMotivationalStateShape
        (transitionState
            (step (regSwappedBimonad) (regTestState) (regStimulus) (regCandidates))
        )
    )
    True
)

;; firstDecide always picks the first candidate
!(test
    (actionId
        (transitionAction
            (step (regSwappedBimonad) (regTestState) (regStimulus) (regCandidates))
        )
    )
    (actionId (regCandidateA))
)
