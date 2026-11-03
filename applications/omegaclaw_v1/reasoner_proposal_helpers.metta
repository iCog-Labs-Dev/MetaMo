
;; Shape-only access to legacy proposal data. Literal records must be quoted
;; by callers; accessors never eval their contents or validate evidence authority.

;; Check the exact constructor and ten fields without binding missing input.
;; Example: (reasonerProposalShapeValid (quote (ReasonerMotivationalProposal broken))) -> False.
(= (reasonerProposalShapeValid $proposal)
    (if (is-ground $proposal)
        (case $proposal
            (
                ((ReasonerMotivationalProposal $id $source $kind $target $candidate
                    $claim $support $confidence $evidence $prediction) True)
                ($_ False)
            )
        )
        False
    )
)

;; Read a known field index only after the complete proposal shape matches.
;; Example: (reasonerProposalField (quote (WrongTag a b c d e f g h i j)) 1) -> rejection.
(= (reasonerProposalField $proposal $index)
    (if (reasonerProposalShapeValid $proposal)
        (index-atom $proposal $index)
        (ReasonerAccessorRejected InvalidProposal)
    )
)

;; Return the proposal ID as inert data.
;; Example: (getProposalId (quote (ReasonerMotivationalProposal p nars propose-candidate current-frame respond claim support 0.9 evidence prediction))) -> p.
(= (getProposalId $proposal)
    (reasonerProposalField $proposal 1)
)

;; Return the source without interpreting its implementation.
;; Example: (getProposalSource ()) -> (ReasonerAccessorRejected InvalidProposal).
(= (getProposalSource $proposal)
    (reasonerProposalField $proposal 2)
)

;; Return the request kind from an exact proposal record.
;; Example: (getProposalKind malformed) -> (ReasonerAccessorRejected InvalidProposal).
(= (getProposalKind $proposal)
    (reasonerProposalField $proposal 3)
)

;; Return the target without invoking frame or mode operations.
;; Example: (getProposalTarget ()) -> (ReasonerAccessorRejected InvalidProposal).
(= (getProposalTarget $proposal)
    (reasonerProposalField $proposal 4)
)

;; Return the candidate; admission remains the caller's responsibility.
;; Example: (getProposalCandidate ()) -> (ReasonerAccessorRejected InvalidProposal).
(= (getProposalCandidate $proposal)
    (reasonerProposalField $proposal 5)
)

;; Return the claim as data without running an expression it contains.
;; Example: (getProposalClaim ()) -> (ReasonerAccessorRejected InvalidProposal).
(= (getProposalClaim $proposal)
    (reasonerProposalField $proposal 6)
)

;; Return support as data; this does not establish evidence validity.
;; Example: (getProposalSupport ()) -> (ReasonerAccessorRejected InvalidProposal).
(= (getProposalSupport $proposal)
    (reasonerProposalField $proposal 7)
)

;; Return confidence without coercion or numerical validation.
;; Example: (getProposalConfidence ()) -> (ReasonerAccessorRejected InvalidProposal).
(= (getProposalConfidence $proposal)
    (reasonerProposalField $proposal 8)
)

;; Return evidence references without resolving or evaluating them.
;; Example: (getProposalEvidence ()) -> (ReasonerAccessorRejected InvalidProposal).
(= (getProposalEvidence $proposal)
    (reasonerProposalField $proposal 9)
)

;; Return the prediction as data without attempting to grade it.
;; Example: (getProposalPrediction ()) -> (ReasonerAccessorRejected InvalidProposal).
(= (getProposalPrediction $proposal)
    (reasonerProposalField $proposal 10)
)

;; Require the exact event constructor, ordered named fields and proposal shape.
;; Decision/disposition contents remain data; semantic validation is separate.
;; Example: (getProposalEventProposal (quote (ReasonerProposalEvent (proposal broken)))) -> rejection.
(= (getProposalEventProposal $proposal-event)
    (if (is-ground $proposal-event)
        (case $proposal-event
            (
                ((ReasonerProposalEvent (proposal $proposal)
                    (decision $decision) (disposition $disposition))
                    (if (reasonerProposalShapeValid $proposal)
                        $proposal
                        (ReasonerAccessorRejected InvalidProposalEvent)
                    )
                )
                ($_ (ReasonerAccessorRejected InvalidProposalEvent))
            )
        )
        (ReasonerAccessorRejected InvalidProposalEvent)
    )
)


(= (getStatus (ReasonerMotivationalDecision $status $reason $proposal $candidate $score)) $status)
(= (getStatus (ReasonerProposalActionResult $status $reason $candidate $action)) $status)
(= (getReason (ReasonerMotivationalDecision $status $reason $proposal $candidate $score)) $reason)
(= (getReason (ReasonerProposalActionResult $status $reason $candidate $action)) $reason)
(= (getCandidate (ReasonerMotivationalDecision $status $reason $proposal $candidate $score)) $candidate)
(= (getCandidate (ReasonerProposalActionResult $status $reason $candidate $action)) $candidate)
(= (getAction (ReasonerProposalActionResult $status $reason $candidate $action)) $action)
(= (getScore (ReasonerMotivationalDecision $status $reason $proposal $candidate $score)) $score)
