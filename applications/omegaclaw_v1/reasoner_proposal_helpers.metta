
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


(= (getStatus (ReasonerMotivationalDecision $status $reason $proposal $candidate $score)) $status)
(= (getStatus (ReasonerProposalActionResult $status $reason $candidate $action)) $status)
(= (getReason (ReasonerMotivationalDecision $status $reason $proposal $candidate $score)) $reason)
(= (getReason (ReasonerProposalActionResult $status $reason $candidate $action)) $reason)
(= (getCandidate (ReasonerMotivationalDecision $status $reason $proposal $candidate $score)) $candidate)
(= (getCandidate (ReasonerProposalActionResult $status $reason $candidate $action)) $candidate)
(= (getAction (ReasonerProposalActionResult $status $reason $candidate $action)) $action)
(= (getScore (ReasonerMotivationalDecision $status $reason $proposal $candidate $score)) $score)
