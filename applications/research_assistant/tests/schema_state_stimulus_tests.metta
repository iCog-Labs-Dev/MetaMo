!(import! &self ../../../core/validation)
!(import! &self ../../../core/schema)
!(import! &self ../../../core/features)
!(import! &self ../../../core/state)
!(import! &self ../../../magus/profile)
!(import! &self ../schema)
!(import! &self ../state)
!(import! &self ../stimulus)

!(test
    (researchAssistantGoalNames)
    (individuation transcendence help curiosity novelty self_improvement ethics sociality misinformation unsupported_claim privacy_violation unsafe_assistance context_loss)
)

!(test
    (stateGoal (researchAssistantCuriosityState) transcendence)
    0.9
)

!(test
    (stateGoal (researchAssistantEthicsState) individuation)
    0.9
)

!(test
    (researchAssistantSignalTaskIntent
        (makeResearchAssistantSignals answer 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9)
    )
    answer
)

!(test
    (researchAssistantStimulusFeatures
        (makeResearchAssistantStimulus 0.1 0.2 0.3 0.4)
    )
    (stimulusFeatures ((novelty 0.1) (conduciveness 0.2) (risk 0.3) (effort 0.4)))
)

