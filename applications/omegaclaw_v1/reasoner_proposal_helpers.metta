
;; Positional access to proposal records belongs here so callers can use
;; named accessors instead of coupling themselves to the wire layout.
(= (getProposalId $proposal)
    (if (<= (size-atom $proposal) 10) (Error "There is a proposal error") (index-atom $proposal 1))
)

(= (getProposalSource $proposal)
    (if (<= (size-atom $proposal) 10) (Error "There is a proposal error") (index-atom $proposal 2))
)

(= (getProposalKind $proposal)
    (if (<= (size-atom $proposal) 10) (Error "There is a proposal error") (index-atom $proposal 3))
)

(= (getProposalTarget $proposal)
    (if (<= (size-atom $proposal) 10) (Error "There is a proposal error") (index-atom $proposal 4))
)

(= (getProposalCandidate $proposal)
    (if (<= (size-atom $proposal) 10) (Error "There is a proposal error") (index-atom $proposal 5))
)

(= (getProposalClaim $proposal)
    (if (<= (size-atom $proposal) 10) (Error "There is a proposal error") (index-atom $proposal 6))
)

(= (getProposalSupport $proposal)
    (if (<= (size-atom $proposal) 10) (Error "There is a proposal error") (index-atom $proposal 7))
)

(= (getProposalConfidence $proposal)
    (if (<= (size-atom $proposal) 10) (Error "There is a proposal error") (index-atom $proposal 8))
)

(= (getProposalEvidence $proposal)
    (if (<= (size-atom $proposal) 10) (Error "There is a proposal error") (index-atom $proposal 9))
)

(= (getProposalPrediction $proposal)
    (if (<= (size-atom $proposal) 10) (Error "There is a proposal error") (index-atom $proposal 10))
)

;; A proposal event stores the proposal under its first named field.
(= (getProposalEventProposal $proposal-event)
    (if (<= (size-atom $proposal-event) 1)
        (Error "There is a proposal event error")
        (index-atom (index-atom $proposal-event 1) 1))
)


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

(= (getScore $decision)
    (if (<= (size-atom $decision) 5) (Error "There is a decision error") (index-atom $decision 5))
)
