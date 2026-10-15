;; Pure F2.5 check. Inputs come from trusted host retention, never model output.
;; Read/answer decisions are the exact required invocations, not just skill names.
;; Evidence pairs retain (owner-snapshot OperationOutcome) at admission time.

;; Example: reject duplicate tickets even if their commands differ.
(= (completionUniqueHead $items)
    (let ($head $tail) (decons-atom $items)
        (and (not (tpContains $tail $head)) (completionUnique $tail))
    )
)

;; Example: cycles 1 and 2 are distinct; replaying cycle 1 is not another read.
(= (completionUnique $items)
    (case $items
        (
            (() True)
            ($_ (completionUniqueHead $items))
        )
    )
)

;; Example: a required decision must belong to this session and native frame.
(= (completionDecisionValid $context $decision)
    (case ($context $decision)
        (
            (((OperationContext $session $now $frame)
              (OperationDecision (OperationContext $session $cycle $frame) $_ $_ (DispatchTicket $ticket)))
                (and (tpQuantity $cycle)
                    (tpAllTrue ((> $cycle 0) (== (floor-math $cycle) $cycle)
                        (<= $cycle $now) (tpId $ticket)))))
            ($_ False)
        )
    )
)

;; Example: only a bounded read-file invocation can be a required read.
(= (completionReadValid $context $decision)
    (case $decision
        (
            ((OperationDecision $_ execute-skill (read-file $path) $_)
                (and (completionDecisionValid $context $decision)
                    (tpId $path)))
            ($_ False)
        )
    )
)

;; Example: a clarification send is never the required final answer.
(= (completionAnswerValid $context $answer)
    (case $answer
        (
            ((RequiredAnswer (OperationDecision $_ respond (send $text) $_) "local:stdout")
                (and (tpId $text)
                    (let (RequiredAnswer $decision $_) $answer
                        (completionDecisionValid $context $decision))))
            ($_ False)
        )
    )
)

;; Example: an accepted empty file is a successful read, unlike Error or Unobserved.
(= (completionReadObserved $owner $decision $evidence)
    (let $matches (filter-atom $evidence $row
        (case $row
            (
                (($owner (OperationOutcome $decision (attempted-command $command) Success
                    (DispatchResult Executed Feasible $content)))
                    (and (== $command (index-atom $decision 3)) (== (get-type $content) String)))
                ($_ False)
            )
        ))
        (== (size-atom $matches) 1)
    )
)

;; Example: socket submission is not recipient acknowledgement; only local Accepted here.
(= (completionAnswerObserved $owner $answer $evidence)
    (let (RequiredAnswer $decision $destination) $answer
        (let $expected ($owner (OperationOutcome $decision
            (attempted-command (index-atom $decision 3)) Success
            (DispatchResult Executed Feasible (SendObservation $destination Accepted))))
            (== (size-atom (filter-atom $evidence $row (== $row $expected))) 1)
        )
    )
)

;; Example: all reads precede the answer and have distinct tickets and cycles.
(= (completionReadSetValid $context $reads $answer)
    (let*
        (
            ((RequiredAnswer $answerDecision $_) $answer)
            ($decisions (cons-atom $answerDecision $reads))
            ($answerCycle (index-atom (index-atom $answerDecision 1) 2))
        )
        (tpAllTrue (
            (tpAllTrue (map-atom $reads $read (completionReadValid $context $read)))
            (completionUnique (map-atom $decisions $decision (index-atom $decision 4)))
            (completionUnique (map-atom $decisions $decision (index-atom (index-atom $decision 1) 2)))
            (completionUnique (map-atom $reads $read (index-atom $read 3)))
            (tpAllTrue (map-atom $reads $read
                (< (index-atom (index-atom $read 1) 2) $answerCycle)))
        ))
    )
)

;; Example: two required reads plus the exact accepted answer make the check true.
(= (completionEvidenceReady $owner $context $reads $answer $evidence)
    (if (and (completionAnswerValid $context $answer)
             (tpAllTrue (map-atom $reads $read (completionReadValid $context $read))))
        (tpAllTrue (
            (completionReadSetValid $context $reads $answer)
            (== (size-atom $evidence) (+ (size-atom $reads) 1))
            (tpAllTrue (map-atom $reads $read (completionReadObserved $owner $read $evidence)))
            (completionAnswerObserved $owner $answer $evidence)
        ))
        False
    )
)

;; Example: no reads is incomplete; conversational no-tool requirements belong to F2.10.
(= (completionInputsReady $owner $context $reads $answer $evidence)
    (if (tpAllTrue ((== (get-metatype $reads) Expression)
                    (== (get-metatype $evidence) Expression)))
        (if (tpAllTrue ((> (size-atom $reads) 0) (<= (size-atom $reads) 16)
                        (<= (size-atom $evidence) 17)))
            (completionEvidenceReady $owner $context $reads $answer $evidence)
            False
        )
        False
    )
)

;; Example: malformed revisions or fractional current cycles cannot authorize completion.
(= (completionOwnerValid $id $frame $revision $summary $session $cycle)
    (if (and (tpQuantity $revision) (tpQuantity $cycle))
        (tpAllTrue ((tpId $id) (tpFrameId $frame) (tpId $summary) (tpId $session)
            (== (floor-math $revision) $revision)
            (> $cycle 0) (== (floor-math $cycle) $cycle)))
        False
    )
)

;; Example: a predecessor's requirements cannot complete its replacement or a terminal owner.
;; Caller supplies the current authoritative snapshot/context; this function reads no state.
(= (hostCompletionReady $current $context $requirements $evidence)
    (case ($current $context $requirements)
        (
            (((CommitmentSnapshot $id $frame $revision Open $summary)
              (OperationContext $session $cycle $frame)
              (CompletionRequirements $current $reads $answer))
                (if (and (is-ground ($current $context $requirements $evidence))
                         (completionOwnerValid $id $frame $revision $summary $session $cycle))
                    (completionInputsReady $current $context $reads $answer $evidence)
                    False
                ))
            ($_ False)
        )
    )
)
