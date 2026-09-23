;; Session callback validation uses the real MeTTa boundary and consumption.
;; Host selections are explicit fixtures; no executor or external service runs.
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
!(import! &self (library MetaMo applications/omegaclaw_v1/host_operations.py))
!(change-state! &operation-provider callback-test-provider)
!(initOperationSession)
!(bind! &callback-session (new-state
   (let (OperationContext $session $_ $_) (get-state &operation-context) $session)))
(= (callbackDecision $session $cycle $frame $action $command $ticket)
   (OperationDecision (OperationContext $session $cycle $frame) $action $command $ticket))
(= (callbackSelect $cycle)
   (progn
      (change-state! &operation-context (OperationContext (get-state &callback-session) $cycle "frame"))
      (change-state! &selected-operation-decision
         (callbackDecision (get-state &callback-session) $cycle "frame" execute-skill
            (quote (read-file "/allowed")) (DispatchTicket $cycle)))))
(= (callbackFailure $decision)
   (OperationOutcome $decision (attempted-command (quote (read-file "/allowed"))) Failure
      (DispatchResult Executed Feasible (Error handler failed))))
(= (callbackState)
   ((get-state &last-operation-outcome) (get-state &applied-operation-decision)
    (get-state &operation-failure-streak) (get-state &operation-feedback)
    (motivosToMetamoState)))
!(initOmegaClawMotivation)
!(callbackSelect 1)
!(bind! &callback-first (new-state (callbackFailure (get-state &selected-operation-decision))))
!(test (ingestOperationOutcome (get-state &callback-first)) OutcomeAccepted)
!(bind! &callback-before (new-state (callbackState)))
!(test (ingestOperationOutcome (get-state &callback-first)) OutcomeDuplicate)
!(test (== (callbackState) (get-state &callback-before)) True)
!(test (ingestOperationOutcome (callbackFailure (callbackDecision "earlier-session" 1 "frame" execute-skill (quote (read-file "/allowed")) (DispatchTicket 1)))) (OutcomeRejected WrongSession))
!(test (== (callbackState) (get-state &callback-before)) True)
!(test (ingestOperationOutcome (callbackFailure (callbackDecision (get-state &callback-session) 0 "frame" execute-skill (quote (read-file "/allowed")) (DispatchTicket 1)))) (OutcomeRejected StaleCycle))
!(test (== (callbackState) (get-state &callback-before)) True)
!(test (ingestOperationOutcome (callbackFailure (callbackDecision (get-state &callback-session) 2 "frame" execute-skill (quote (read-file "/allowed")) (DispatchTicket 1)))) (OutcomeRejected StaleCycle))
!(test (== (callbackState) (get-state &callback-before)) True)
!(test (ingestOperationOutcome (callbackFailure (callbackDecision (get-state &callback-session) 1 "other-frame" execute-skill (quote (read-file "/allowed")) (DispatchTicket 1)))) (OutcomeRejected MismatchedDecision))
!(test (== (callbackState) (get-state &callback-before)) True)
!(test (ingestOperationOutcome (callbackFailure (callbackDecision (get-state &callback-session) 1 "frame" respond (quote (read-file "/allowed")) (DispatchTicket 1)))) (OutcomeRejected MismatchedDecision))
!(test (== (callbackState) (get-state &callback-before)) True)
!(test (ingestOperationOutcome (callbackFailure (callbackDecision (get-state &callback-session) 1 "frame" execute-skill (quote (read-file "/other")) (DispatchTicket 1)))) (OutcomeRejected MismatchedDecision))
!(test (== (callbackState) (get-state &callback-before)) True)
!(test (ingestOperationOutcome (callbackFailure (callbackDecision (get-state &callback-session) 1 "frame" execute-skill (quote (read-file "/allowed")) (DispatchTicket wrong)))) (OutcomeRejected MismatchedDecision))
!(test (== (callbackState) (get-state &callback-before)) True)
!(test (ingestOperationOutcome (quote (OperationOutcome broken))) (OutcomeRejected MalformedOutcome))
!(test (ingestOperationOutcome
   (OperationOutcome (get-state &selected-operation-decision)
      (attempted-command (quote (read-file "/other"))) Failure
      (DispatchResult Executed Feasible (Error handler failed)))) (OutcomeRejected MismatchedCommand))
!(test (ingestOperationOutcome
   (OperationOutcome (get-state &selected-operation-decision)
      (attempted-command (quote (read-file "/allowed"))) Success
      (DispatchResult Executed Feasible (Error handler failed)))) (OutcomeRejected InconsistentStatus))
!(test (ingestOperationOutcome
   (OperationOutcome (get-state &selected-operation-decision)
      (attempted-command (quote (read-file "/allowed"))) Unobserved
      (DispatchResult Unknown reason none))) (OutcomeRejected MalformedOutcome))
!(test (ingestOperationOutcome
   (OperationOutcome (get-state &selected-operation-decision)
      (attempted-command (quote (read-file "/allowed"))) Success
      (DispatchResult Executed Feasible "different observation"))) (OutcomeRejected ConflictingReplay))
!(test (== (callbackState) (get-state &callback-before)) True)
!(applyOperationOutcome "frame")
!(test (get-state &operation-feedback) (OperationFeedback Failure 1))
!(bind! &callback-before (new-state (callbackState)))
!(test (ingestOperationOutcome (get-state &callback-first)) OutcomeDuplicate)
!(test (== (callbackState) (get-state &callback-before)) True)
!(test (ingestOperationOutcome
   (OperationOutcome (get-state &selected-operation-decision)
      (attempted-command (quote (read-file "/allowed"))) Success
      (DispatchResult Executed Feasible "changed after consumption"))) (OutcomeRejected ConflictingReplay))
!(test (== (callbackState) (get-state &callback-before)) True)
!(applyOperationOutcome "frame")
!(test (get-state &operation-feedback) (OperationFeedback NoOutcome 1))
!(test (get-state &operation-failure-streak) 1)
;; Identical returned data from a new decision counts as a new observation.
!(callbackSelect 2)
!(test (ingestOperationOutcome (callbackFailure (get-state &selected-operation-decision))) OutcomeAccepted)
!(bind! &callback-before (new-state (callbackState)))
!(test (ingestOperationOutcome (get-state &callback-first)) (OutcomeRejected StaleCycle))
!(test (== (callbackState) (get-state &callback-before)) True)
!(applyOperationOutcome "frame")
!(test (get-state &operation-feedback) (OperationFeedback Failure 2))
;; Consumption also rejects direct slot corruption with matching context.
!(callbackSelect 3)
!(change-state! &last-operation-outcome
   (callbackFailure (callbackDecision (get-state &callback-session) 3 "frame"
      respond (quote (read-file "/allowed")) (DispatchTicket 3))))
!(applyOperationOutcome "frame")
!(test (get-state &operation-feedback) (OperationFeedback NoOutcome 2))
!(test (get-state &operation-failure-streak) 2)
;; Real reset changes the session, clears consumption, and rejects old callbacks.
!(initOperationSession)
!(bind! &callback-before (new-state (callbackState)))
!(test (ingestOperationOutcome (get-state &callback-first)) (OutcomeRejected WrongSession))
!(test (== (callbackState) (get-state &callback-before)) True)
!(test (get-state &operation-failure-streak) 0)
!(test (get-state &last-operation-outcome) ())

;; Literal callback data must never execute command or result expressions.
!(bind! &callback-effects (new-state 0))
(= (callback-poison)
   (progn (change-state! &callback-effects (+ (get-state &callback-effects) 1)) "effect"))
!(test (ingestOperationOutcome
   (quote (OperationOutcome (callback-poison) (attempted-command (callback-poison))
      Success (DispatchResult Executed Feasible (callback-poison)))))
   (OutcomeRejected MalformedOutcome))
!(test (get-state &callback-effects) 0)

;; The retained decision cannot override the published frame context.
!(change-state! &callback-session
   (let (OperationContext $session $_ $_) (get-state &operation-context) $session))
!(callbackSelect 1)
!(change-state! &operation-context (OperationContext (get-state &callback-session) 1 "changed-frame"))
!(test (ingestOperationOutcome (callbackFailure (get-state &selected-operation-decision)))
   (OutcomeRejected MismatchedDecision))
!(test (get-state &last-operation-outcome) ())
