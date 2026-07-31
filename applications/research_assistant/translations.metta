
;; Curiosity-to-ethics goal translation matrix in Research Assistant coordinate order.
;; Example: (researchAssistantCuriosityToEthicsGoalMatrix) -> matrix
(= (researchAssistantCuriosityToEthicsGoalMatrix)
    (
        (0.75 0.0 0.0 0.0 0.0 0.0 0.25 0.0 0.0 0.0 0.0 0.0 0.0)
        (0.0 0.60 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0)
        (0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0)
        (0.0 0.0 0.0 0.50 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0)
        (0.0 0.0 0.0 0.0 0.50 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0)
        (0.20 0.0 0.0 0.0 0.0 0.70 0.0 0.0 0.0 0.0 0.0 0.0 0.0)
        (0.30 0.0 0.20 0.0 0.0 0.0 0.50 0.0 0.0 0.0 0.0 0.0 0.0)
        (0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0)
        (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0)
        (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0)
        (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0)
        (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0)
        (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0)
    )
)

;; Curiosity-to-ethics modulator translation matrix in Research Assistant order.
;; Example: (researchAssistantCuriosityToEthicsModulatorMatrix) -> matrix
(= (researchAssistantCuriosityToEthicsModulatorMatrix)
    (
        (1.0 0.0 0.0 0.0 0.0 0.0)
        (0.0 0.60 0.0 0.0 0.0 0.0)
        (0.0 0.0 0.60 0.0 0.0 0.0)
        (0.0 0.0 0.0 1.0 0.0 0.0)
        (0.0 0.0 0.0 0.0 0.70 0.30)
        (0.0 0.0 0.0 0.0 0.30 0.70)
    )
)

;; Build the canonical curiosity-to-ethics translation functor.
;; Example: (researchAssistantCuriosityToEthicsTranslation) -> translationFunctor
(= (researchAssistantCuriosityToEthicsTranslation)
    (translationFunctor
        (researchAssistantCuriosityToEthicsGoalMatrix)
        (researchAssistantCuriosityToEthicsModulatorMatrix)
        (researchAssistantSchema)
        (researchAssistantSchema)
    )
)

