
;; Extract Research Assistant stimulus features from a raw stimulus or perception.
(= (researchAssistantStimulusFeatureFn $state $stimulusOrPerception)
    (case $stimulusOrPerception (
        ((researchAssistantPerception $stimulus $signals) (researchAssistantStimulusFeatures $stimulus))
        ($_ (researchAssistantStimulusFeatures $stimulusOrPerception))
    ))
)

;; Research Assistant core deltas use the common OpenPsi convention.
(= (researchAssistantCoreDeltas $state $features)
    (commonOpenPsiCoreDeltas $state $features)
)

;; Research Assistant has no application-specific modulators
(= (researchAssistantApplicationDeltas $state $features)
    ()
)

;; Add Research Assistant anti-goal targets to common OpenPsi feedback.
(= (researchAssistantGoalFeedback $state $stimulusOrPerception $features)
    (let* (
        ($common (commonOpenPsiGoalFeedback $state $stimulusOrPerception $features))
    )
        (case $stimulusOrPerception (
            ((researchAssistantPerception $stimulus $signals)
                (goalChangeFeedback
                    (listAppend
                        (featureMapPairs $common)
                        (
                            (misinformation_target (maxNumber
                                (researchAssistantSignalUnsupportedClaimPressure $signals)
                                (* (researchAssistantSignalContextLossPressure $signals) 0.4)
                            ))
                            (unsupported_claim_target (researchAssistantSignalUnsupportedClaimPressure $signals))
                            (privacy_violation_target (researchAssistantSignalPrivacyPressure $signals))
                            (unsafe_assistance_target (researchAssistantSignalUnsafePressure $signals))
                            (context_loss_target (maxNumber
                                (researchAssistantSignalContextLossPressure $signals)
                                (* (researchAssistantSignalAmbiguity $signals) 0.5)
                            ))
                        )
                    )
                )
            )
            ($_ $common)
        ))
    )
)

;; Return the canonical appraisal profile for Research Assistant.
(= (researchAssistantAppraisalProfile)
    (appraisalProfile
        research_assistant_openpsi
        (valence arousal approach resolution threshold securing)
        researchAssistantStimulusFeatureFn
        researchAssistantCoreDeltas
        researchAssistantApplicationDeltas
        researchAssistantGoalFeedback
        1.0
        ()
    )
)

