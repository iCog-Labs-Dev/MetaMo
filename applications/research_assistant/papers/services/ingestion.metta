
;; Build an ingestion effect request. Adapters own filesystem and byte extraction.
;; Example: (researchAssistantPaperIngestionRequest path) -> request
(= (researchAssistantPaperIngestionRequest $path)
    (paperIngestionEffectRequest read_extract_chunk_and_persist $path)
)

;; Build a successful ingestion result.
;; Example: (researchAssistantPaperIngestionSuccess paper) -> result
(= (researchAssistantPaperIngestionSuccess $paper)
    (paperIngestionResult success $paper)
)

;; Build a failed ingestion result.
;; Example: (researchAssistantPaperIngestionFailure missing path) -> result
(= (researchAssistantPaperIngestionFailure $code $details)
    (paperIngestionResult $code $details)
)

