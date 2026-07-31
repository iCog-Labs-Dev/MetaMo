
;; Return an empty chunking plan for empty text.
;; Example: (researchAssistantChunkPlan "" source 2000 200) -> plan
(= (researchAssistantChunkPlan $text $sourcePath $chunkSize $overlap)
    (researchAssistantChunkPlanRecord $text $sourcePath $chunkSize $overlap)
)

;; Build one chunk record.
;; Example: (researchAssistantMakeChunk 0 text source 0 4) -> chunk
(= (researchAssistantMakeChunk $index $text $sourcePath $charStart $charEnd)
    (documentChunk $index $text $sourcePath $charStart $charEnd)
)

