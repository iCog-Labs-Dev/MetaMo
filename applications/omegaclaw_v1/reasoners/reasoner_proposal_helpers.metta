
;; Pure representation checks and field access for legacy proposal data.
;; Callers quote literal records; no helper evaluates data or establishes host authority.
!(import_prolog_function string_codes)

(: ReasonerMotivationalProposalType Type)
(: ReasonerMotivationalProposal
   (-> Expression Symbol Symbol Expression Symbol Expression Expression
       Number Expression Expression ReasonerMotivationalProposalType))

;; Test a Unicode character property through SWI's existing character interface.
;; Example: (reasonerTextCodeIsSpace 32) -> True.
(= (reasonerTextCodeIsSpace $code)
    (!= (collapse (translatePredicate (code_type $code space))) ())
)

;; Reject control characters without interpreting text as a command.
;; Example: (reasonerTextCodeIsControl 10) -> True.
(= (reasonerTextCodeIsControl $code)
    (!= (collapse (translatePredicate (code_type $code cntrl))) ())
)

;; Check length before examining characters; preserve the original value.
;; Example: (reasonerProposalTextValid "proposal-1" 256) -> True.
(= (reasonerProposalTextValid $text $limit)
    (if (and (> (string_length $text) 0) (<= (string_length $text) $limit))
        (let $codes (string_codes $text)
            (and
                (== (filter-atom $codes $code (reasonerTextCodeIsControl $code)) ())
                (!= (filter-atom $codes $code (not (reasonerTextCodeIsSpace $code))) ())
            )
        )
        False
    )
)

;; IDs are nonblank symbols/strings, excluding boolean and absent-value markers.
;; Example: (reasonerProposalIdValid (quote (run code))) -> False.
(= (reasonerProposalIdValid $id)
    (if (is-ground $id)
        (if (or (== (get-type $id) String)
                (!= (collapse (translatePredicate (atom $id))) ()))
            (if (tpContains (True False None none) $id)
                False
                (reasonerProposalTextValid $id 256)
            )
            False
        )
        False
    )
)

;; Opaque payload scalars are finite bounded numbers or bounded text/symbols.
;; Example: (reasonerProposalScalarValid 0.9) -> True.
(= (reasonerProposalScalarValid $value)
    (if (== (get-type $value) Number)
        (fsNumberIn $value -9007199254740991 9007199254740991)
        (if (or (== (get-type $value) String)
                (!= (collapse (translatePredicate (atom $value))) ()))
            (<= (string_length $value) 1200)
            False
        )
    )
)

;; Walk at most 256 children, threading a shared node allowance through siblings.
;; Example: (reasonerProposalDataItems () 15 10 256) -> 10.
(= (reasonerProposalDataItems $items $depth $remaining $slots)
    (if (== $items ())
        $remaining
        (if (or (< $remaining 1) (< $slots 1))
            -1
            (let* (
                (($head $tail) (decons-atom $items))
                ;; Defer the recursive partner until both definitions are loaded.
                ($next (eval (reasonerProposalDataRemaining (quote $head) $depth $remaining)))
            )
                (if (< $next 0)
                    -1
                    (reasonerProposalDataItems $tail $depth $next (- $slots 1))
                )
            )
        )
    )
)

;; Count each scalar/list as a node and stop before descending past the limit.
;; Example: (reasonerProposalDataRemaining (quote (Expected recovered)) 16 1024) -> 1021.
(= (reasonerProposalDataRemaining $data $depth $remaining)
    (if (or (< $depth 1) (< $remaining 1))
        -1
        (if (== (get-metatype $data) Expression)
            (reasonerProposalDataItems $data (- $depth 1) (- $remaining 1) 256)
            (if (reasonerProposalScalarValid $data) (- $remaining 1) -1)
        )
    )
)

;; Require nonblank text with a 1200-character bound, permitting multiline content.
;; Example: (reasonerProposalPayloadTextValid "first\nsecond") -> True.
(= (reasonerProposalPayloadTextValid $text)
    (if (<= (string_length $text) 1200)
        (!= (filter-atom (string_codes $text) $code
            (not (reasonerTextCodeIsSpace $code))) ())
        False
    )
)

;; Require ground, nonempty data; multiline text remains inert payload content.
;; Example: (reasonerProposalPayloadValid "first\nsecond") -> True.
(= (reasonerProposalPayloadValid $data)
    (if (is-ground $data)
        (if (or (== $data ()) (== $data None))
            False
            (if (== (get-type $data) String)
                (reasonerProposalPayloadTextValid $data)
                (>= (reasonerProposalDataRemaining $data 16 1024) 0)
            )
        )
        False
    )
)

;; Accept legacy evidence stamps and typed observation-reference shapes only.
;; Example: (reasonerProposalEvidenceReferenceValid (quote (ObservationRef "host" "obs"))) -> True.
(= (reasonerProposalEvidenceReferenceValid $reference)
    (case $reference
        (
            ((ObservationRef $host $id)
                (tpAllTrue ((== (get-type $host) String) (== (get-type $id) String)
                    (reasonerProposalIdValid $host) (reasonerProposalIdValid $id))))
            ((SessionObservationRef $session $sequence)
                (tpAllTrue ((== (get-type $session) String)
                    (reasonerProposalIdValid $session) (fsCount $sequence))))
            ($_ (reasonerProposalIdValid $reference))
        )
    )
)

;; Validate a proper, duplicate-free bounded list without resolving its members.
;; Example: (reasonerProposalEvidenceList (quote (e1 e1)) 32 ()) -> False.
(= (reasonerProposalEvidenceList $references $remaining $seen)
    (case ((get-metatype $references) (== $references ()))
        (
            ((Expression True) True)
            ((Expression False)
                (if (< $remaining 1) False
                    (let ($head $tail) (decons-atom $references)
                        (if (and (reasonerProposalEvidenceReferenceValid $head)
                                (not (tpContains $seen $head)))
                            (reasonerProposalEvidenceList $tail (- $remaining 1) (cons-atom $head $seen))
                            False
                        )
                    )
                )
            )
            ($_ False)
        )
    )
)

;; NARS/PLN need nonempty support references; other sources may have none.
;; Example: (reasonerProposalEvidenceValid nars (quote (EvidenceReferences ()))) -> False.
(= (reasonerProposalEvidenceValid $source $evidence)
    (if (is-ground $evidence)
        (case $evidence
            (
                ((EvidenceReferences $references)
                    (and (reasonerProposalEvidenceList $references 32 ())
                        (or (not (tpContains (nars pln) $source)) (!= $references ())))
                )
                ($_ False)
            )
        )
        False
    )
)

;; Builders accept either a raw reference list or an already wrapped record.
;; Example: (reasonerProposalEvidenceRecord (quote (e1))) -> (EvidenceReferences (e1)).
(= (reasonerProposalEvidenceRecord $evidence)
    (case $evidence
        (
            ((EvidenceReferences $references) $evidence)
            ($_ (EvidenceReferences $evidence))
        )
    )
)

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


;; Return the host identity only from the exact outcome layout, without evaluating data.
;; Example: (getProposalOutcomeId ()) -> (ReasonerAccessorRejected InvalidProposalOutcome).
(= (getProposalOutcomeId $record)
    (if (is-ground $record)
        (case $record
            (
                ((ReasonerProposalOutcomeEvent (outcome-id (ReasonerOutcomeRef $session $ticket))
                    (proposal-event $event) (execution-status $status) (execution-evidence $execution)
                    (frame-evidence-status $frame-status) (frame-state-evidence $frame-evidence)
                    (outcome $outcome) (grade $grade))
                    (quote (ReasonerOutcomeRef $session $ticket)))
                ($_ (ReasonerAccessorRejected InvalidProposalOutcome))
            )
        )
        (ReasonerAccessorRejected InvalidProposalOutcome)
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

;; Existing source vocabulary shared by transport and admission.
;; Example: (reasonerProposalSources) includes llm.
(= (reasonerProposalSources) (nars pln llm rule-engine human-adapter))
;; Read or validate the shared proposal vocabulary.
;; Example: reasonerInferenceSources (nars pln).
(= (reasonerInferenceSources) (nars pln))
;; Read or validate the shared proposal vocabulary.
;; Example: reasonerOptionalProposalSources (llm).
(= (reasonerOptionalProposalSources) (llm))
;; Read or validate the shared proposal vocabulary.
;; Example: reasonerProposalKinds the supported request kinds.
(= (reasonerProposalKinds)
   (propose-candidate request-frame-switch request-mode-change request-attention))

;; Read or validate the shared proposal vocabulary.
;; Example: reasonerProposalSourceValid unknown -> False.
(= (reasonerProposalSourceValid $value)
   (case $value ((nars True)
      (pln True)
      (llm True)
      (rule-engine True)
      (human-adapter True)
      ($_ False))))

;; Read or validate the shared proposal vocabulary.
;; Example: reasonerProposalKindValid propose-candidate -> True.
(= (reasonerProposalKindValid $value)
   (case $value ((propose-candidate True)
      (request-frame-switch True)
      (request-mode-change True)
      (request-attention True)
      ($_ False))))

;; Confidence must be a finite number in [0,1], without coercion or clamping.
;; Example: (reasonerProposalConfidenceValid "0.9") -> False.
(= (reasonerProposalConfidenceValid $confidence)
    (fsNumberIn $confidence 0 1)
)

;; Candidate names are registry-owned. This prevents a reasoner from smuggling
;; an arbitrary executable operation through the proposal boundary.
(= (reasonerProposalCandidateValid $value)
   (case $value ((respond True)
      (retrieve-memory True)
      (search-knowledge True)
      (execute-skill True)
      (learn True)
      (self-improve True)
      (background-work True)
      (recall-goals True)
      (invent-goal True)
      (plan-goal True)
      (repair-failure True)
      (defer True)
      (verify-frame-state True)
      (ask-clarification True)
      ($_ False))))

;; A proposal may ask the scheduler to consider a frame/mode transition. The
;; target is deliberately data-shaped and is never passed to a ContextFrames
;; mutation function by MetaMo.
;; Example: (reasonerProposalTargetValid propose-candidate (quote (FrameTarget Frame-A))) -> True.
(= (reasonerProposalTargetValid $kind $target)
    (if (is-ground ($kind $target))
        (case ($kind $target)
            (
                ((propose-candidate current-frame) True)
                ((request-attention current-frame) True)
                ((propose-candidate (FrameTarget $frame)) (reasonerProposalIdValid $frame))
                ((request-attention (FrameTarget $frame)) (reasonerProposalIdValid $frame))
                ((request-frame-switch (FrameTarget $frame)) (reasonerProposalIdValid $frame))
                ((request-mode-change (ModeTarget Fast)) True)
                ((request-mode-change (ModeTarget Slow)) True)
                ($_ False)
            )
        )
        False
    )
)

;; Validate representation only. References need separate trusted host resolution.
;; Example: an unknown but well-formed evidence stamp can pass this pure check.
(= (reasonerProposalValid $proposal)
    (if (reasonerProposalShapeValid $proposal)
        (let (ReasonerMotivationalProposal $id $source $kind $target $candidate
                $claim $support $confidence $evidence $prediction) $proposal
            (tpAllTrue (
                (reasonerProposalIdValid $id)
                (reasonerProposalSourceValid $source)
                (reasonerProposalKindValid $kind)
                (reasonerProposalTargetValid $kind $target)
                (reasonerProposalCandidateValid $candidate)
                (reasonerProposalConfidenceValid $confidence)
                (reasonerProposalPayloadValid $claim)
                (reasonerProposalPayloadValid $support)
                (reasonerProposalEvidenceValid $source $evidence)
                (reasonerProposalPayloadValid $prediction)
            ))
        )
        False
    )
)
