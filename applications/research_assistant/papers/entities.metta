
(: DocumentChunk Type)
(: documentChunk (-> Number Expression Symbol Number Number DocumentChunk))

(: Paper Type)
(: paperRecord (-> Symbol Expression Number Expression Symbol Symbol Paper))

;; Return chunk index.
;; Example: (documentChunkIndex (documentChunk 0 text source 0 4)) -> 0
(= (documentChunkIndex (documentChunk $index $text $sourcePath $charStart $charEnd))
    $index
)

;; Return chunk text.
;; Example: (documentChunkText (documentChunk 0 text source 0 4)) -> text
(= (documentChunkText (documentChunk $index $text $sourcePath $charStart $charEnd))
    $text
)

;; Return paper chunks.
;; Example: (paperChunks (paperRecord id title 10 chunks time source)) -> chunks
(= (paperChunks (paperRecord $paperId $title $totalChars $chunks $ingestedAt $sourcePath))
    $chunks
)

;; Build a paper record.
;; Example: (makePaperRecord id title 10 () time source) -> paper
(= (makePaperRecord $paperId $title $totalChars $chunks $ingestedAt $sourcePath)
    (paperRecord $paperId $title $totalChars $chunks $ingestedAt $sourcePath)
)

