!(import! &self ../../../core/validation)
!(import! &self ../../../core/schema)
!(import! &self ../../../core/features)
!(import! &self ../../../core/state)
!(import! &self ../../../openpsi/profile)
!(import! &self ../../../magus/profile)
!(import! &self ../../../category/functors)
!(import! &self ../../../applications/common/openpsi_conventions)
!(import! &self ../schema)
!(import! &self ../state)
!(import! &self ../stimulus)
!(import! &self ../appraisal_profile)
!(import! &self ../decision_profile)
!(import! &self ../translations)

!(test
    (appraisalProfileName (researchAssistantAppraisalProfile))
    research_assistant_openpsi
)

!(test
    (decisionProfileName (researchAssistantDecisionProfile))
    research_assistant_magus_additive
)

!(test
    (validateTranslationFunctor (researchAssistantCuriosityToEthicsTranslation))
    (validationOk (researchAssistantCuriosityToEthicsTranslation))
)

!(test
    (index-atom
        (index-atom (researchAssistantCuriosityToEthicsGoalMatrix) 0)
        0
    )
    0.75
)

