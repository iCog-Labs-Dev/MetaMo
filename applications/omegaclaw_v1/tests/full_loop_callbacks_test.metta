;; Mutate callbacks from a real selected/executed Core read, never fabricated selections.
!(import! &self fixtures/boundary_loop)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(test (boundaryCycle callbacks) 1)
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) respond)
!(bind! &callback-ticket (new-state (coreLoopDispatchBegin)))
!(bind! &callback-command (new-state (selectedHostCommand)))
!(test (fullLoopDispatch callbacks (get-state &callback-ticket) (get-state &callback-command))
   (DispatchResult Executed Feasible "observed local file content"))
!(bind! &callback-real (new-state (get-state &last-operation-outcome)))
!(bind! &callback-state (new-state (boundaryObservationState)))

(= (callbackAltersession
      (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
         $action $command $ticket) (attempted-command $attempt) $status
         (DispatchResult $dispatchStatus $reason $value)))
   (OperationOutcome (OperationDecision (OperationContext "different-session" $cycle $frame)
      $action $command $ticket) (attempted-command $attempt) $status
      (DispatchResult $dispatchStatus $reason $value)))

!(test (boundaryCallback session (callbackAltersession (get-state &callback-real)))
   (OutcomeRejected WrongSession))
!(test (boundaryObservationState) (get-state &callback-state))

(= (callbackAltercycle
      (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
         $action $command $ticket) (attempted-command $attempt) $status
         (DispatchResult $dispatchStatus $reason $value)))
   (OperationOutcome (OperationDecision (OperationContext $session (+ $cycle 1) $frame)
      $action $command $ticket) (attempted-command $attempt) $status
      (DispatchResult $dispatchStatus $reason $value)))

!(test (boundaryCallback cycle (callbackAltercycle (get-state &callback-real)))
   (OutcomeRejected StaleCycle))
!(test (boundaryObservationState) (get-state &callback-state))

(= (callbackAlterframe
      (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
         $action $command $ticket) (attempted-command $attempt) $status
         (DispatchResult $dispatchStatus $reason $value)))
   (OperationOutcome (OperationDecision (OperationContext $session $cycle "different-frame")
      $action $command $ticket) (attempted-command $attempt) $status
      (DispatchResult $dispatchStatus $reason $value)))

!(test (boundaryCallback frame (callbackAlterframe (get-state &callback-real)))
   (OutcomeRejected MismatchedDecision))
!(test (boundaryObservationState) (get-state &callback-state))

(= (callbackAlteraction
      (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
         $action $command $ticket) (attempted-command $attempt) $status
         (DispatchResult $dispatchStatus $reason $value)))
   (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
      execute-skill $command $ticket) (attempted-command $attempt) $status
      (DispatchResult $dispatchStatus $reason $value)))

!(test (boundaryCallback action (callbackAlteraction (get-state &callback-real)))
   (OutcomeRejected MismatchedDecision))
!(test (boundaryObservationState) (get-state &callback-state))

(= (callbackAltercommand
      (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
         $action $command $ticket) (attempted-command $attempt) $status
         (DispatchResult $dispatchStatus $reason $value)))
   (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
      $action (quote (read-file "/different")) $ticket) (attempted-command $attempt) $status
      (DispatchResult $dispatchStatus $reason $value)))

!(test (boundaryCallback command (callbackAltercommand (get-state &callback-real)))
   (OutcomeRejected MismatchedDecision))
!(test (boundaryObservationState) (get-state &callback-state))

(= (callbackAlterticket
      (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
         $action $command $ticket) (attempted-command $attempt) $status
         (DispatchResult $dispatchStatus $reason $value)))
   (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
      $action $command (DispatchTicket "different-ticket")) (attempted-command $attempt) $status
      (DispatchResult $dispatchStatus $reason $value)))

!(test (boundaryCallback ticket (callbackAlterticket (get-state &callback-real)))
   (OutcomeRejected MismatchedDecision))
!(test (boundaryObservationState) (get-state &callback-state))

(= (callbackAlterattempt
      (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
         $action $command $ticket) (attempted-command $attempt) $status
         (DispatchResult $dispatchStatus $reason $value)))
   (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
      $action $command $ticket) (attempted-command (quote (read-file "/different"))) $status
      (DispatchResult $dispatchStatus $reason $value)))

!(test (boundaryCallback attempt (callbackAlterattempt (get-state &callback-real)))
   (OutcomeRejected MismatchedCommand))
!(test (boundaryObservationState) (get-state &callback-state))

(= (callbackAlterstatus
      (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
         $action $command $ticket) (attempted-command $attempt) $status
         (DispatchResult $dispatchStatus $reason $value)))
   (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
      $action $command $ticket) (attempted-command $attempt) Failure
      (DispatchResult $dispatchStatus $reason $value)))

!(test (boundaryCallback status (callbackAlterstatus (get-state &callback-real)))
   (OutcomeRejected InconsistentStatus))
!(test (boundaryObservationState) (get-state &callback-state))

(= (callbackAltervalue
      (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
         $action $command $ticket) (attempted-command $attempt) $status
         (DispatchResult $dispatchStatus $reason $value)))
   (OperationOutcome (OperationDecision (OperationContext $session $cycle $frame)
      $action $command $ticket) (attempted-command $attempt) $status
      (DispatchResult $dispatchStatus $reason "conflicting-result")))

!(test (boundaryCallback value (callbackAltervalue (get-state &callback-real)))
   (OutcomeRejected ConflictingReplay))
!(test (boundaryObservationState) (get-state &callback-state))

!(test (boundaryCallback malformed (quote (OperationOutcome broken)))
   (OutcomeRejected MalformedOutcome))
!(test (boundaryObservationState) (get-state &callback-state))
!(test (boundaryCallback duplicate (get-state &callback-real)) OutcomeDuplicate)
!(test (boundaryObservationState) (get-state &callback-state))
;; Ticket replay must return the original result despite changed file contents.
!(test (py-call (host_config_fixture.replace_file_content)) 1)
!(test (fullLoopDispatch callbacks (get-state &callback-ticket) (get-state &callback-command))
   (DispatchResult Executed Feasible "observed local file content"))
!(test (boundaryObservationState) (get-state &callback-state))
!(change-state! &new-msg-flag False)
!(test (boundaryCycle callbacks) 1)
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback Success 0))
!(test (get-state &success-count) 1)
!(test (get-state &failure-count) 0)
!(test (frameRuntimeTaskOpen (activeFrameBundle)) True)
!(test (get-state &applied-operation-decision)
   (let (OperationOutcome $decision $_ $_ $_) (get-state &callback-real) $decision))
!(bind! &callback-after (new-state (boundaryObservationState)))
!(test (boundaryCallback late (get-state &callback-real)) (OutcomeRejected StaleCycle))
!(test (boundaryObservationState) (get-state &callback-after))
!(test (boundaryCycle callbacks) 1)
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback NoOutcome 0))
!(test (get-state &success-count) 1)
;; Session reset rejects the real earlier observation and cannot create feedback.
!(fullLoopStartSession)
!(bind! &callback-reset (new-state (boundaryObservationState)))
!(test (boundaryCallback old-session (get-state &callback-real)) (OutcomeRejected WrongSession))
!(test (boundaryObservationState) (get-state &callback-reset))
!(test (boundaryCycle callbacks) 1)
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback NoOutcome 0))
!(test (py-call (host_config_fixture.cleanup)) 1)
!(fullLoopFinish callbacks)

