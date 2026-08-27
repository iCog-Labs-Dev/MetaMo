(= (researchAssistantPaperChunkSize) 2000)
(= (researchAssistantPaperChunkOverlap) 200)
(= (researchAssistantPaperMaxChars) 100000)
(= (researchAssistantPaperContextMaxChars) 4000)

;; Validate chunking configuration.
;; Example: (validationIsOk (researchAssistantValidatePaperConfig 2000 200)) -> True
(= (researchAssistantValidatePaperConfig $chunkSize $overlap)
    (if (> $chunkSize $overlap)
        (validationOk (paperConfig $chunkSize $overlap))
        (validationError invalid-paper-overlap ($chunkSize $overlap))
    )
)

