

(= (getStatus $conversion)
    (if (<= (size-atom $conversion) 5) (Error "There is a conversion error") (index-atom $conversion 1))
)

(= (getReason $conversion)
    (if (<= (size-atom $conversion) 5) (Error "There is a conversion error") (index-atom $conversion 2))
)

(= (getCandidate $conversion)
    (if (<= (size-atom $conversion) 5) (Error "There is a conversion error") (index-atom $conversion 3))
)

(= (getAction $conversion)
    (if (<= (size-atom $conversion) 5) (Error "There is a conversion error") (index-atom $conversion 4))
)
