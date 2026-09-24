;; Optional trusted host capture. Pure composition has no Core dependency.
;; Loading dispatch.metta installs the concrete provider; absent configuration
;; in that mode produces no executable candidates, never legacy fallback.
!(bind! &operation-provider (new-state ()))
!(bind! &selected-host-operation (new-state ()))
!(bind! &operation-admitted-actions (new-state ()))
!(bind! &operation-context (new-state ()))
!(bind! &selected-operation-decision (new-state ()))
!(bind! &last-operation-outcome (new-state ()))

!(bind! &applied-operation-decision (new-state ()))
!(bind! &operation-failure-streak (new-state 0))

(= (operationFeedbackEnabled) (!= (get-state &operation-provider) ()))

;; Session-only correlation, separate from the versioned durable wire contract.
;; Pure motivational composition never needs a host identity provider.
(= (initOperationSession)
   (if (== (get-state &operation-provider) ()) False
       (progn
          (change-state! &operation-context
             (OperationContext (sread (py-call (host_operations.new_session))) 0 ()))
          (change-state! &selected-host-operation ())
          (change-state! &selected-operation-decision ())
          (change-state! &last-operation-outcome ())
          (change-state! &applied-operation-decision ())
          (change-state! &operation-failure-streak 0)
          (change-state! &operation-feedback (OperationFeedback NoOutcome 0))
          (change-state! &task-execution-observed "")
          (change-state! &host-continuation ())
          (change-state! &continuation-applied-decision ())
          (change-state! &task-continuation-view NoContinuation) True)))

(= (beginOperationCycle $bundle)
   (if (== (get-state &operation-provider) ()) False
       (let* (
          ($_ (if (== (get-state &operation-context) ()) (initOperationSession) True))
          ((OperationContext $session $cycle $_frame) (get-state &operation-context)))
          (progn
             (change-state! &selected-host-operation ())
             (change-state! &selected-operation-decision ())
             (change-state! &operation-context
                (OperationContext $session (+ $cycle 1) (frameBundleCurrentId $bundle)))))))

(= (continuationOperationRows $bundle $rows)
   (case (frameRuntimeContinuation $bundle) (
      (NoContinuation $rows)
      ((ContinuationView $_ $_ $status $expected)
       (filter-atom $rows $row
          (let (HostOperation $candidate $command $_ $_ $_ $_) $row
             (or (!= $candidate execute-skill)
                 (and (== $status Ready) (== (repr $command) $expected))))))
      ($_ ()))))

(= (captureCandidateOperations $bundle)
   (let $provider (get-state &operation-provider)
      (if (== $provider ()) LegacyCandidateAdmission
          (continuationOperationRows $bundle (eval ($provider (quote $bundle)))))))

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

(= (selectedHostCommand)
   (case (get-state &selected-host-operation) (
      ((HostOperation $_ $command $_ $_ $_ $_) $command)
      ($_ ()))))

(= (selectedHostTicket)
   (case (get-state &selected-host-operation) (
      ((HostOperation $_ $_ $_ $_ $_ $ticket) $ticket)
      ($_ (DispatchUnavailable MissingDecision)))))

(= (retainSelectedOperation $candidate $rows)
   (let $_ (change-state! &selected-host-operation
      (if (or (== $rows LegacyCandidateAdmission) (== $candidate none)) ()
          (let $matches (hostRowsForCandidate $candidate $rows)
             (if (== (size-atom $matches) 1) (car-atom $matches) ()))))
      (change-state! &selected-operation-decision
         (if (== (get-state &operation-context) ()) ()
             (OperationDecision (get-state &operation-context) $candidate
                (selectedHostCommand) (selectedHostTicket))))))

;; Only documented handler observations establish success; invocation alone
;; does not. Keep the raw result, including error/rejection reasons, untouched.
(= (operationOutcomeStatus $command $result)
   (case $result (
      ((DispatchResult Blocked $_ $_) Blocked)
      ((DispatchResult Executed $_ (Error $_ $_)) Failure)
      ((DispatchResult Executed $_ $value)
       (case (car-atom $command) (
          (read-file (if (== (get-type $value) String) Success Unobserved))
          (show-current-frame
           (if (== (get-metatype $value) Expression)
               (if (== $value ()) Unobserved
                   (if (== (car-atom $value) Frame) Success Unobserved)) Unobserved))
          ($_ Unobserved))))
      ($_ Unobserved))))

;; Trusted host callback boundary, not a model skill. Call with quoted data.
;; Correlation is checked against the retained decision, never supplied by a
;; callback itself. Late cycles are rejected in this synchronous MVP.
(= (validateOperationOutcome $outcome)
   (case $outcome (
      ((OperationOutcome
          (OperationDecision (OperationContext $session $cycle $frame) $action $command $ticket)
          (attempted-command $attempt) $status (DispatchResult $dispatchStatus $reason $value))
       (case (get-state &operation-context) (
          ((OperationContext $currentSession $currentCycle $currentFrame)
           (if (!= $session $currentSession) (OutcomeRejected WrongSession)
               (if (!= $cycle $currentCycle) (OutcomeRejected StaleCycle)
                   (if (or (!= $frame $currentFrame)
                           (!= (OperationDecision (OperationContext $session $cycle $frame)
                                  $action $command $ticket)
                               (get-state &selected-operation-decision)))
                       (OutcomeRejected MismatchedDecision)
                       (if (!= $attempt $command) (OutcomeRejected MismatchedCommand)
                           (if (not (or (== $dispatchStatus Executed)
                                      (or (== $dispatchStatus Blocked) (== $dispatchStatus Unobserved))))
                               (OutcomeRejected MalformedOutcome)
                               (if (and (== $command ())
                                        (!= (DispatchResult $dispatchStatus $reason $value)
                                            (DispatchResult Blocked MissingDecision none)))
                                   (OutcomeRejected MalformedOutcome)
                                   (if (== $status (operationOutcomeStatus $command
                                            (DispatchResult $dispatchStatus $reason $value)))
                                       OutcomeValid (OutcomeRejected InconsistentStatus)))))))))
          ($_ (OutcomeRejected MissingSession)))))
      ($_ (OutcomeRejected MalformedOutcome)))))

;; One immutable observation for the selected decision. Only this host entry
;; point publishes the slot; duplicates never reset consumption or feedback.
(= (ingestOperationOutcome $outcome)
   (let $validation (validateOperationOutcome $outcome)
      (if (!= $validation OutcomeValid) $validation
          (let (OperationOutcome $decision $_ $_ $_) $outcome
             (case (get-state &last-operation-outcome) (
                ((OperationOutcome $previousDecision $_ $_ $_)
                 (if (== $decision $previousDecision)
                     (if (== $outcome (get-state &last-operation-outcome))
                         OutcomeDuplicate (OutcomeRejected ConflictingReplay))
                     (progn (change-state! &last-operation-outcome $outcome) OutcomeAccepted)))
                ($_ (progn (change-state! &last-operation-outcome $outcome) OutcomeAccepted))))))))

;; Consume the preceding serialized cycle before publishing another snapshot.
;; A different frame/session/cycle cannot receive this feedback. Keeping only
;; the applied decision is sufficient for the single selected invocation path.
(= (applyOperationOutcome $frame)
   (if (not (operationFeedbackEnabled))
       (change-state! &operation-feedback LegacyFeedback)
       (let* (
          ($_ (change-state! &operation-feedback
                 (OperationFeedback NoOutcome (get-state &operation-failure-streak))))
          ($outcome (get-state &last-operation-outcome)))
          (case $outcome (
             ((OperationOutcome
                 (OperationDecision (OperationContext $session $cycle $origin) $action $command $ticket)
                 $_attempt $status $_result)
              (let $decision (OperationDecision
                      (OperationContext $session $cycle $origin) $action $command $ticket)
                 (if (and (== (validateOperationOutcome $outcome) OutcomeValid)
                          (and (== $origin $frame)
                               (!= $decision (get-state &applied-operation-decision))))
                     (progn
                        (change-state! &applied-operation-decision $decision)
                        (change-state! &operation-failure-streak
                           (if (== $status Failure) (+ (get-state &operation-failure-streak) 1)
                               (if (== $status Success) 0 (get-state &operation-failure-streak))))
                        (change-state! &operation-feedback
                           (OperationFeedback $status (get-state &operation-failure-streak))))
                     False)))
             ($_ False))))))

;; The model may repeat only the exact selected command. The ticket predates
;; scoring, so final Core checks also reject mutations during/after selection.
(= (dispatchSelectedHostCommand $ticket $command)
   (let* (
      ($decision (get-state &selected-operation-decision))
      ($selectedCommand (selectedHostCommand))
      ($matches (and (== $ticket (selectedHostTicket))
                    (or (== $selectedCommand ()) (== $command $selectedCommand))))
      ($result (if (== $selectedCommand ())
       (DispatchResult Blocked MissingDecision none)
       (if $matches
           (eval (coreDispatchCommand (quote $ticket) (quote $command)))
           (DispatchResult Blocked UnselectedOperation none))))
      ;; Unmatched tickets/commands are rejected attempts, not observations of
      ;; the selected action. Never relabel them with the current decision.
      ;; No selection records canonical empty-command Blocked feedback, so
      ;; arbitrary rejected model attempts cannot overwrite that observation.
      ($_ (if (and $matches (!= $decision ()))
              (ingestOperationOutcome
                 (OperationOutcome $decision (attempted-command $selectedCommand)
                    (operationOutcomeStatus $command $result) $result)) True)))
      $result))
