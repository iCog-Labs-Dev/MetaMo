
;; Build a context request.
;; Example: (researchAssistantPaperContextRequest paper 4000) -> request
(= (researchAssistantPaperContextRequest $paper $maxChars)
    (paperContextRequest $paper $maxChars stable_chunk_order)
)

;; Build an empty-context result.
;; Example: (researchAssistantEmptyPaperContext) -> result
(= (researchAssistantEmptyPaperContext)
    (paperContextResult () 0 no_papers)
)

