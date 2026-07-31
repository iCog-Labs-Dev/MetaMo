!(import! &self ../../../core/validation)
!(import! &self ../../../core/schema)
!(import! &self ../../../core/features)
!(import! &self ../../../core/state)
!(import! &self ../schema)
!(import! &self ../stimulus)
!(import! &self ../actions)
!(import! &self ../prompts)
!(import! &self ../llm/parser)
!(import! &self ../llm/providers)
!(import! &self ../llm/conversation)
!(import! &self ../papers/config)
!(import! &self ../papers/entities)
!(import! &self ../papers/services/chunker)
!(import! &self ../papers/services/context)
!(import! &self ../papers/services/ingestion)

!(test
    (parseIsOk
        (researchAssistantParsePerceptionPairs
            (
                (stimulus ((novelty 0.1) (conduciveness 0.2) (risk 0.3) (effort 0.4)))
                (signals ((task_intent answer)))
            )
        )
    )
    True
)

!(test
    (llmProviderRetryable (llmProviderError timeout details True))
    True
)

!(test
    (researchAssistantValidatePaperConfig 2000 200)
    (validationOk (paperConfig 2000 200))
)

!(test
    (researchAssistantEmptyPaperContext)
    (paperContextResult () 0 no_papers)
)

