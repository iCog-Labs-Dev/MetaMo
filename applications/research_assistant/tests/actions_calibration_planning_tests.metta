!(import! &self ../../../core/validation)
!(import! &self ../../../core/schema)
!(import! &self ../../../core/features)
!(import! &self ../../../core/state)
!(import! &self ../../../magus/profile)
!(import! &self ../schema)
!(import! &self ../state)
!(import! &self ../stimulus)
!(import! &self ../actions)
!(import! &self ../calibration)
!(import! &self ../planning)

!(test
    (researchAssistantNormalizeActionId clarify)
    ask_clarifying_question
)

!(test
    (>=
        (researchAssistantSignalContextLossPressure
            (researchAssistantPerceptionSignals
                (researchAssistantCalibrationPerception
                    (calibrateResearchAssistantPerception
                        (researchAssistantPerception
                            (makeResearchAssistantStimulus 0.2 0.7 0.0 0.0)
                            (makeResearchAssistantSignals answer 0.8 0.0 0.0 0.0 0.2 0.0 0.0 0.0 0.0)
                        )
                    )
                )
            )
        )
        0.55
    )
    True
)

!(test
    (candidateId
        (index-atom
            (researchAssistantBuildCandidates
                (researchAssistantPerception
                    (makeResearchAssistantStimulus 0.2 0.7 0.1 0.2)
                    (makeResearchAssistantSignals answer 0.1 0.4 0.0 0.0 0.2 0.0 0.0 0.0 0.0)
                )
                ((arousal 0.5) (caution 0.5))
            )
            0
        )
    )
    safe_answer
)
