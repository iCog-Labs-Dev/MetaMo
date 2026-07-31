
;; Return task intents in Python order.
;; Example: (researchAssistantPromptTaskIntents) -> (answer summarize compare clarify explore decline)
(= (researchAssistantPromptTaskIntents)
    (researchAssistantTaskIntents)
)

;; Build a perception prompt request record.
;; Example: (researchAssistantPerceptionPrompt "text") -> prompt record
(= (researchAssistantPerceptionPrompt $documentText)
    (researchAssistantPromptRecord
        perception
        $documentText
        (researchAssistantPromptTaskIntents)
        requires_json
    )
)

;; Build a four-field appraisal prompt request record.
;; Example: (researchAssistantAppraisalPrompt "text") -> prompt record
(= (researchAssistantAppraisalPrompt $documentText)
    (researchAssistantPromptRecord
        appraisal
        $documentText
        (novelty conduciveness risk effort)
        requires_json
    )
)

