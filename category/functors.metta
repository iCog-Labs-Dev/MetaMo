
(: AppraisalComonad Type)
(: appraisalComonad (-> Symbol Symbol AppraisalComonad))

(: DecisionMonad Type)
(: decisionMonad (-> Symbol Symbol Symbol DecisionMonad))

(: DecisionResult Type)
(: decisionResult (-> Expression Expression DecisionResult))


;; Extract the symbol identifying the extraction function from an AppraisalComonad.
;; Example: (appraisalExtractSymbol (appraisalComonad myExtractFn myAppraiseFn)) -> myExtractFn
(= (appraisalExtractSymbol (appraisalComonad $extractFn $appraiseFn))
    $extractFn
)

;; Extract the symbol identifying the mapping/appraisal function from an AppraisalComonad.
;; Example: (appraisalMapSymbol (appraisalComonad myExtractFn myAppraiseFn)) -> myAppraiseFn
(= (appraisalMapSymbol (appraisalComonad $extractFn $appraiseFn))
    $appraiseFn
)

;; Alias for appraisalMapSymbol, extracting the appraisal function symbol.
;; Example: (appraisalAppraiseSymbol (appraisalComonad f g)) -> g
(= (appraisalAppraiseSymbol (appraisalComonad $extractFn $appraiseFn))
    $appraiseFn
)

;; Extract the symbol identifying the unit function from a DecisionMonad.
;; Example: (decisionUnitSymbol (decisionMonad u d s)) -> u
(= (decisionUnitSymbol (decisionMonad $unitFn $decideFn $scoreFn))
    $unitFn
)

;; Extract the symbol identifying the decision function from a DecisionMonad.
;; Example: (decisionMapSymbol (decisionMonad u d s)) -> d
(= (decisionMapSymbol (decisionMonad $unitFn $decideFn $scoreFn))
    $decideFn
)

;; Alias for decisionMapSymbol, extracting the decision function symbol.
;; Example: (decisionDecideSymbol (decisionMonad u d s)) -> d
(= (decisionDecideSymbol (decisionMonad $unitFn $decideFn $scoreFn))
    $decideFn
)

;; Extract the symbol identifying the candidate scoring function from a DecisionMonad.
;; Example: (decisionScoreSymbol (decisionMonad u d s)) -> s
(= (decisionScoreSymbol (decisionMonad $unitFn $decideFn $scoreFn))
    $scoreFn
)

;; Extract the chosen action from a DecisionResult.
;; Example: (decisionAction (decisionResult MOVE (0.1 -0.2))) -> MOVE
(= (decisionAction (decisionResult $action $deltaG))
    $action
)

;; Extract the proposed goal change (DeltaG) from a DecisionResult.
;; Example: (decisionDeltaG (decisionResult MOVE (0.1 -0.2))) -> (0.1 -0.2)
(= (decisionDeltaG (decisionResult $action $deltaG))
    $deltaG
)

;; Wrapper to extract features from a state using an appraisal comonad.
;; Example: (extract myAppraisal currentState)
(= (extract $appraisal $state)
    (extractWith $appraisal $state)
)

;; Executes the extraction function of an AppraisalComonad on a given state.
;; Example: (extractWith (appraisalComonad getFeatures g) myState) -> (eval (getFeatures myState))
(= (extractWith (appraisalComonad $extractFn $appraiseFn) $state)
    (eval ($extractFn $state))
)

;; Wrapper to appraise a stimulus given the current state using an appraisal comonad.
;; Example: (appraise myAppraisal currentState stimulus)
(= (appraise $appraisal $state $stimulus)
    (appraiseWith $appraisal $state $stimulus)
)

;; Executes the appraisal function of an AppraisalComonad on a state and stimulus.
;; Example: (appraiseWith (appraisalComonad f myAppraise) myState myStim) -> (eval (myAppraise myState myStim))
(= (appraiseWith (appraisalComonad $extractFn $appraiseFn) $state $stimulus)
    (eval ($appraiseFn $state $stimulus))
)

;; Wrapper to compute the identity/unit state for a decision monad.
;; Example: (unit myDecision currentState)
(= (unit $decision $state)
    (unitWith $decision $state)
)

;; Executes the unit function of a DecisionMonad on a given state.
;; Example: (unitWith (decisionMonad myUnit d s) myState) -> (eval (myUnit myState))
(= (unitWith (decisionMonad $unitFn $decideFn $scoreFn) $state)
    (eval ($unitFn $state))
)

;; Wrapper to make a decision from a set of candidates using a decision monad.
;; Example: (decide myDecision currentState (MOVE STAY))
(= (decide $decision $state $candidates)
    (decideWith $decision $state $candidates)
)

;; Executes the decision function of a DecisionMonad on state and candidates.
;; Example: (decideWith (decisionMonad u myDecide s) myState myCandidates) -> (eval (myDecide myState myCandidates))
(= (decideWith (decisionMonad $unitFn $decideFn $scoreFn) $state $candidates)
    (eval ($decideFn $state $candidates))
)

;; Wrapper to score a single candidate using a decision monad.
;; Example: (scoreCandidate myDecision currentState MOVE)
(= (scoreCandidate $decision $state $candidate)
    (scoreCandidateWith $decision $state $candidate)
)

;; Executes the scoring function of a DecisionMonad for a specific candidate.
;; Example: (scoreCandidateWith (decisionMonad u d myScore) myState myCandidate) -> (eval (myScore myState myCandidate))
(= (scoreCandidateWith (decisionMonad $unitFn $decideFn $scoreFn) $state $candidate)
    (eval ($scoreFn $state $candidate))
)

;; Canonical rectangular translation and frame adapters.

(: TranslationFunctor Type)
(: translationFunctor (-> Expression Expression MotivationSchema MotivationSchema TranslationFunctor))

(: AgentFrameAdapter Type)
(: agentFrameAdapter (-> TranslationFunctor Symbol Symbol Symbol AgentFrameAdapter))

;; Return the canonical goal translation matrix.
;; Example: (translationGoalMatrix (translationFunctor g m source target)) -> g
(= (translationGoalMatrix (translationFunctor $goalTranslation $modTranslation $sourceSchema $targetSchema))
    $goalTranslation
)

;; Return the canonical modulator translation matrix.
;; Example: (translationModulatorMatrix (translationFunctor g m source target)) -> m
(= (translationModulatorMatrix (translationFunctor $goalTranslation $modTranslation $sourceSchema $targetSchema))
    $modTranslation
)

;; Return the canonical source schema.
;; Example: (translationSourceSchema (translationFunctor g m source target)) -> source
(= (translationSourceSchema (translationFunctor $goalTranslation $modTranslation $sourceSchema $targetSchema))
    $sourceSchema
)

;; Return the canonical target schema.
;; Example: (translationTargetSchema (translationFunctor g m source target)) -> target
(= (translationTargetSchema (translationFunctor $goalTranslation $modTranslation $sourceSchema $targetSchema))
    $targetSchema
)

;; Validate rectangular translation dimensions.
;; Example: (validationIsOk (validateTranslationFunctor functor)) -> True
(= (validateTranslationFunctor $translation)
    (let* (
        ($goalMatrix (translationGoalMatrix $translation))
        ($modMatrix (translationModulatorMatrix $translation))
        ($sourceSchema (translationSourceSchema $translation))
        ($targetSchema (translationTargetSchema $translation))
    )
        (if (== (size-atom $goalMatrix) (schemaGoalCount $targetSchema))
            (if (== (size-atom $modMatrix) (schemaModulatorCount $targetSchema))
                (if (== (size-atom (index-atom $goalMatrix 0)) (schemaGoalCount $sourceSchema))
                    (if (== (size-atom (index-atom $modMatrix 0)) (schemaModulatorCount $sourceSchema))
                        (validationOk $translation)
                        (validationError modulator-translation-column-mismatch $modMatrix)
                    )
                    (validationError goal-translation-column-mismatch $goalMatrix)
                )
                (validationError modulator-translation-row-mismatch $modMatrix)
            )
            (validationError goal-translation-row-mismatch $goalMatrix)
        )
    )
)

;; Simulate a peer state in a target schema.
;; Example: (simulatePeer translation state) -> target-state
(= (simulatePeer $translation $state)
    (let* (
        ($validation (eval (validateTranslationFunctor $translation)))
        ($targetSchema (eval (translationTargetSchema $translation)))
    )
        (if (validationIsOk $validation)
            (motivationState
                $targetSchema
                (eval (clipVector
                    (eval (matrixVectorDot (translationGoalMatrix $translation) (stateGoals $state)))
                    0.0
                    1.0
                ))
                (eval (clipVector
                    (eval (matrixVectorDot (translationModulatorMatrix $translation) (stateModulators $state)))
                    0.0
                    1.0
                ))
            )
            $validation
        )
    )
)

;; Measure A -> B -> A round-trip error.
;; Example: (reciprocalRoundTripError forward inverse state) -> 0.0
(= (reciprocalRoundTripError $forward $inverse $state)
    (eval (stateDistance
        $state
        (eval (simulatePeer $inverse (eval (simulatePeer $forward $state))))
    ))
)

;; Return the state translation functor from a frame adapter.
;; Example: (adapterStateTranslation (agentFrameAdapter t s c n)) -> t
(= (adapterStateTranslation (agentFrameAdapter $stateTranslation $stimulusFn $candidateFn $naturalFn))
    $stateTranslation
)

;; Translate adapter state.
;; Example: (adapterTranslateState adapter state) -> translated-state
(= (adapterTranslateState $adapter $state)
    (eval (simulatePeer (adapterStateTranslation $adapter) $state))
)

;; Translate adapter stimulus through its callback.
;; Example: (adapterTranslateStimulus adapter stimulus) -> translated-stimulus
(= (adapterTranslateStimulus (agentFrameAdapter $stateTranslation $stimulusFn $candidateFn $naturalFn) $stimulus)
    (if (== $stimulusFn none)
        $stimulus
        (eval ($stimulusFn $stimulus))
    )
)

;; Translate adapter candidates through its callback.
;; Example: (adapterTranslateCandidates adapter candidates) -> translated-candidates
(= (adapterTranslateCandidates (agentFrameAdapter $stateTranslation $stimulusFn $candidateFn $naturalFn) $candidates)
    (if (== $candidateFn none)
        $candidates
        (eval ($candidateFn $candidates))
    )
)

;; Apply a natural transformation to translated state.
;; Example: (adapterNaturalTransform adapter state) -> state
(= (adapterNaturalTransform (agentFrameAdapter $stateTranslation $stimulusFn $candidateFn $naturalFn) $state)
    (if (== $naturalFn none)
        $state
        (eval ($naturalFn $state))
    )
)
