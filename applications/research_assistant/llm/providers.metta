(: LlmProviderRequest Type)
(: llmProviderRequest (-> Symbol Expression Symbol Number Bool LlmProviderRequest))

(: LlmProviderResult Type)
(: llmProviderSuccess (-> Expression LlmProviderResult))
(: llmProviderError (-> Symbol Expression Bool LlmProviderResult))

;; Build a JSON-mode perception provider request.
;; Example: (researchAssistantPerceptionProviderRequest prompt) -> request
(= (researchAssistantPerceptionProviderRequest $prompt)
    (llmProviderRequest research_assistant $prompt perception_json 0.2 True)
)

;; Return whether a provider result is retryable.
;; Example: (llmProviderRetryable (llmProviderError timeout details True)) -> True
(= (llmProviderRetryable (llmProviderError $code $details $retryable))
    $retryable
)

(= (llmProviderRetryable (llmProviderSuccess $text))
    False
)

;; Redact provider error details for logs.
;; Example: (llmProviderRedactedError (llmProviderError timeout secret True)) -> error
(= (llmProviderRedactedError (llmProviderError $code $details $retryable))
    (llmProviderError $code redacted $retryable)
)

