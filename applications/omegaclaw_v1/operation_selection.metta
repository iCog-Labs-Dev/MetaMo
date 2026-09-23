;; Optional trusted host capture. Pure composition has no Core dependency.
;; Loading dispatch.metta installs the concrete provider; absent configuration
;; in that mode produces no executable candidates, never legacy fallback.
!(bind! &operation-provider (new-state ()))
!(bind! &selected-host-operation (new-state ()))
!(bind! &operation-admitted-actions (new-state ()))

(= (captureCandidateOperations $bundle)
   (let $provider (get-state &operation-provider)
      (if (== $provider ()) LegacyCandidateAdmission
          (eval ($provider (quote $bundle))))))

(= (hostRowsForCandidate $candidate $rows)
   (filter-atom $rows $row
      (let (HostOperation $name $_ $_ $_ $_ $_) $row (== $name $candidate))))

;; Selection remains candidate-based. Multiple commands for one candidate are
;; ambiguous, so reject that candidate rather than silently choose arguments.
(= (hostOperationGate $bundle $candidate $rows)
   (let $matches (hostRowsForCandidate $candidate $rows)
      (if (== $matches ()) (GateDecision Rejected UnsupportedOperation)
          (if (!= (size-atom $matches) 1)
              (GateDecision Rejected AmbiguousOperation)
              (let (HostOperation $_ $_ $operation $global $frame $_) (car-atom $matches)
                 (candidateAdmissionForOperation $bundle $candidate $operation $global $frame))))))

(= (pruneHostOperations $bundle $actions $rows)
   (if (== $actions ()) (CandidatePruning (admitted ()) (rejected ()))
       (let* (
          (($head $tail) (decons-atom $actions))
          ($candidate (actionId $head))
          ((GateDecision $admission $reason) (hostOperationGate $bundle $candidate $rows))
          ((CandidatePruning (admitted $admitted) (rejected $rejected))
             (pruneHostOperations $bundle $tail $rows)))
          (if (== $admission Admitted)
              (CandidatePruning (admitted (cons-atom $head $admitted)) (rejected $rejected))
              (CandidatePruning (admitted $admitted)
                 (rejected (cons-atom (CandidateRejection $candidate $reason) $rejected)))))))

(= (admitCapturedOperations $bundle $actions $rows)
   (if (== $rows LegacyCandidateAdmission)
       (CandidatePruning (admitted $actions) (rejected ()))
       (pruneHostOperations $bundle $actions $rows)))

(= (retainSelectedOperation $candidate $rows)
   (change-state! &selected-host-operation
      (if (or (== $rows LegacyCandidateAdmission) (== $candidate none)) ()
          (let $matches (hostRowsForCandidate $candidate $rows)
             (if (== (size-atom $matches) 1) (car-atom $matches) ())))))

(= (selectedHostCommand)
   (case (get-state &selected-host-operation) (
      ((HostOperation $_ $command $_ $_ $_ $_) $command)
      ($_ ()))))

(= (selectedHostTicket)
   (case (get-state &selected-host-operation) (
      ((HostOperation $_ $_ $_ $_ $_ $ticket) $ticket)
      ($_ (DispatchUnavailable MissingDecision)))))

;; The model may repeat only the exact selected command. The ticket predates
;; scoring, so final Core checks also reject mutations during/after selection.
(= (dispatchSelectedHostCommand $ticket $command)
   (if (== (selectedHostCommand) ())
       (DispatchResult Blocked MissingDecision none)
       (if (and (== $ticket (selectedHostTicket)) (== $command (selectedHostCommand)))
           (eval (coreDispatchCommand (quote $ticket) (quote $command)))
           (DispatchResult Blocked UnselectedOperation none))))
