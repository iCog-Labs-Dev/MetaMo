;; Real bridge selection through concrete policy to real Core frame inspection.
;; Only external provider/memory services are doubled. No scoring replacement.
!(import! &self fixtures/offline_services/offline_guard.py)
!(py-call (offline_guard.install))
!(import! &self fixtures/offline_services/frame_relation.py)
!(import! &self fixtures/offline_services/lib_llm_ext.py)
(= (provider) "Offline")
(= (embeddingprovider) "Offline")
(= (maxOutputToken) 256)
(= (wakeupInterval) 1)
(= (getFrameSkillsCompact) (send query))
(= (query $key) "")
(= (remember $payload) True)
!(import! &self (library OmegaClaw-Core src/helper.py))
!(import! &self (library OmegaClaw-Core src/utils))
!(import! &self (library OmegaClaw-Core src/context))
!(import! &self (library OmegaClaw-Core src/skills))
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))
!(import! &self (library OmegaClaw-Core src/dispatch))
;; Standalone Core still delegates through its original dispatcher.
!(bind! &hook-probe-count (new-state 0))
(= (hook-probe)
   (progn (change-state! &hook-probe-count (+ (get-state &hook-probe-count) 1)) True))
!(test (coreLoopDispatchBegin) LegacyDispatch)
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (quote (hook-probe))) True)
!(test (get-state &hook-probe-count) 1)
!(import! &self (library MetaMo applications/omegaclaw_v1/dispatch))
!(import! &self (library MetaMo applications/omegaclaw_v1/host_dispatch_config.py))
!(import! &self fixtures/host_config_fixture.py)
!(import_prolog_functions_from_file
   (library MetaMo applications/omegaclaw_v1/tests/fixtures/commitments.pl)
   (commitmentFixtureReset commitmentFixtureOpen commitmentFixtureOutcome commitmentFixtureApply))
!(commitmentFixtureReset)
!(bind! &prevmsg (new-state ""))
!(bind! &lastresults (new-state ""))
!(bind! &error (new-state ""))
!(bind! &loops (new-state 1))
!(bind! &nextWakeAt (new-state 0))
!(initContextFrame)
!(initOmegaClawMotivation)
!(ctx-ingest-user-message "Inspect the project context")
!(cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
;; Existing typed dispatch contract; native symbol-ID migration is separate.
!(change-state! &cfv2-current-frame-id "configured-frame")
!(change-state! &active-task "Inspect the project context")
!(change-state! &task-open True)
!(change-state! &new-msg-flag False)
!(initMetaMoDispatch)
!(bind! &config-path (new-state (py-call (host_config_fixture.setup))))

;; No trusted configuration: no candidate reaches scheduling/scoring.
!(test (policyOutputOperation (motivationContextBlock)) none)
!(bind! &first-context (new-state (get-state &operation-context)))
!(test (let (OperationContext $session $cycle $frame) (get-state &first-context)
   ((get-type $session) $cycle $frame)) (String 1 "configured-frame"))
!(test (get-state &selected-operation-decision)
   (OperationDecision (get-state &first-context) none () (DispatchUnavailable MissingDecision)))
!(test (policyOutputFeasibility (get-state &last-meta-mo-policy-output)) Rejected)
!(test (policyOutputPriority (get-state &last-meta-mo-policy-output)) 0)
!(test (lastAttentionDirective)
   (AttentionDirective (target "configured-frame") (slice CurrentFrameSummary)
      (task none) (admission Rejected) (reason NoAction) (priority 0) (source MetaMo)))
!(test (get-state &operation-admitted-actions) ())
!(test (selectedHostCommand) ())
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (quote (show-current-frame)))
   (DispatchResult Blocked MissingDecision none))
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (quote (hook-probe)))
   (DispatchResult Blocked MissingDecision none))
!(test (get-state &hook-probe-count) 1)
!(test (get-state &last-operation-outcome)
   (OperationOutcome (get-state &selected-operation-decision)
      (attempted-command ()) Blocked
      (DispatchResult Blocked MissingDecision none)))

!(py-call (host_dispatch_config.provision (get-state &config-path)))
!(test (policyOutputOperation (motivationContextBlock)) search-knowledge)
!(test (get-state &operation-context)
   (let (OperationContext $session $_ $_) (get-state &first-context)
      (OperationContext $session 2 "configured-frame")))
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback Blocked 0))
!(test (signalTrue progress-made) False)
!(test (hasErrors) False)
!(bind! &selected-decision (new-state (get-state &selected-operation-decision)))
!(bind! &prior-outcome (new-state (get-state &last-operation-outcome)))
!(test (map-atom (get-state &operation-admitted-actions) $a (actionId $a)) (search-knowledge))
!(test (selectedHostCommand) (quote (show-current-frame)))
!(test (tpContains (candidateRejections) (CandidateRejection respond UnsupportedOperation)) True)
!(bind! &chosen-ticket (new-state (coreLoopDispatchBegin)))
;; Even another registered operation cannot replace the selected command.
!(test (coreLoopDispatchCommand (get-state &chosen-ticket)
         (sread (py-call (host_config_fixture.command))))
   (DispatchResult Blocked UnselectedOperation none))
!(test (get-state &last-operation-outcome) (get-state &prior-outcome))
!(test (coreLoopDispatchCommand (get-state &chosen-ticket) (selectedHostCommand))
   (DispatchResult Executed Feasible (cfv2-current-frame)))
!(test (get-state &last-operation-outcome)
   (OperationOutcome (get-state &selected-decision)
      (attempted-command (quote (show-current-frame))) Success
      (DispatchResult Executed Feasible (cfv2-current-frame))))
!(bind! &first-outcome (new-state (get-state &last-operation-outcome)))
!(test (coreLoopDispatchCommand (get-state &chosen-ticket) (selectedHostCommand))
   (DispatchResult Executed Feasible (cfv2-current-frame)))
!(test (get-state &last-operation-outcome) (get-state &first-outcome))

;; Feedback is visible in the next published snapshot and does not complete
;; the task. Successful inspection makes a response eligible, but no response
;; handler is configured, so this cycle explicitly selects no action.
!(test (policyOutputOperation (motivationContextBlock)) none)
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback Success 0))
!(refreshSignals (activeFrameBundle))
!(test (signalTrue progress-made) True)
!(test (frameRuntimeTaskOpen (activeFrameBundle)) True)

;; Current host frame can move after selection; the blocked observation still
;; belongs to the original frame/cycle, never to the new current frame.
!(test (policyOutputOperation (motivationContextBlock)) search-knowledge)
!(test (coreLoopDispatchCommand (get-state &chosen-ticket) (selectedHostCommand))
   (DispatchResult Blocked UnselectedOperation none))
!(test (get-state &last-operation-outcome) (get-state &first-outcome))
!(test (frameRuntimeOperationFeedback (activeFrameBundle)) (OperationFeedback NoOutcome 0))
!(test (signalTrue progress-made) False)
!(bind! &origin-decision (new-state (get-state &selected-operation-decision)))
!(change-state! &cfv2-current-frame-id "different-frame")
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Blocked StaleSnapshot none))
!(test (get-state &last-operation-outcome)
   (OperationOutcome (get-state &origin-decision)
      (attempted-command (quote (show-current-frame))) Blocked
      (DispatchResult Blocked StaleSnapshot none)))
!(change-state! &cfv2-current-frame-id "configured-frame")

;; Host mutations use Core's existing mutex/revision API. Even changing and
;; restoring the same frame invalidates a decision whose snapshot looks equal.
!(test (policyOutputOperation (motivationContextBlock)) search-knowledge)
!(bind! &before-mutation (new-state (frameStateForMetaMo)))
!(test (py-call (host_config_fixture.set_frame_status "Blocked")) 1)
!(test (py-call (host_config_fixture.set_frame_status "Active")) 1)
!(test (frameStateForMetaMo) (get-state &before-mutation))
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Blocked StaleSnapshot none))

;; Explicit revocation after selection rejects the original ticket. Restoring
;; the grant cannot revive it; only a new motivational cycle may select again.
!(test (policyOutputOperation (motivationContextBlock)) search-knowledge)
!(test (py-call (host_config_fixture.revoke_frame_command)) 1)
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Blocked StaleSnapshot none))
!(py-call (host_dispatch_config.provision (get-state &config-path)))
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Blocked StaleSnapshot none))

;; Mutation after scoring but BEFORE Core begins dispatch cannot refresh the
;; ticket. The original pre-scoring ticket must become stale.
!(test (policyOutputOperation (motivationContextBlock)) search-knowledge)
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "frame-denied"))))
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Blocked StaleSnapshot none))
!(test (policyOutputOperation (motivationContextBlock)) none)
!(test (get-state &operation-admitted-actions) ())
!(test (tpContains (candidateRejections) (CandidateRejection search-knowledge PermissionDenied)) True)
!(test (selectedHostCommand) ())
!(test (policyOutputFeasibility (get-state &last-meta-mo-policy-output)) Rejected)
!(test (policyOutputPriority (get-state &last-meta-mo-policy-output)) 0)
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (quote (hook-probe)))
   (DispatchResult Blocked MissingDecision none))
!(test (get-state &hook-probe-count) 1)

;; Argument expressions remain inert until the exact selected handler runs.
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin)
   (quote (change-state! &error "must-not-run")))
   (DispatchResult Blocked MissingDecision none))
!(test (get-state &error) "")

;; Prospective command cost is checked before scoring, too.
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "budget-denied"))))
!(test (policyOutputOperation (motivationContextBlock)) none)
!(test (tpContains (candidateRejections) (CandidateRejection search-knowledge BudgetExhausted)) True)
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "cost-denied"))))
!(test (policyOutputOperation (motivationContextBlock)) none)
!(test (tpContains (candidateRejections) (CandidateRejection search-knowledge ConstraintDenied)) True)

;; Configured policies with no supported command bindings are also no-action.
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "empty"))))
!(test (policyOutputOperation (motivationContextBlock)) none)
!(test (policyOutputFeasibility (get-state &last-meta-mo-policy-output)) Rejected)
!(test (policyOutputPriority (get-state &last-meta-mo-policy-output)) 0)
!(test (tpContains (candidateRejections) (CandidateRejection search-knowledge UnsupportedOperation)) True)
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (quote (hook-probe)))
   (DispatchResult Blocked MissingDecision none))
!(test (get-state &hook-probe-count) 1)

;; Open an authoritative commitment; operation success must leave it open.
!(test (commitmentFixtureOpen "feedback-task" "configured-frame" "Read the file")
   (CommitmentOpened "feedback-task"))

;; Exercise the other supported handler with its real candidate/scorer and
;; exact quoted filename. Availability is covered by the full bridge above.
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "allowed"))))
!(bind! &file-bundle (new-state (prepareTaskStateForMetaMo)))
!(bind! &file-rows (new-state (captureCandidateOperations (get-state &file-bundle))))
!(bind! &file-pruning (new-state (admitCapturedOperations (get-state &file-bundle)
   ((candidateToAction execute-skill)) (get-state &file-rows))))
!(test (get-state &file-pruning)
   (CandidatePruning (admitted ((candidateToAction execute-skill))) (rejected ())))
!(bind! &file-decision (new-state (omegaclawDecideForBundle (get-state &file-bundle)
   (motivosToMetamoState) ((candidateToAction execute-skill)))))
!(test (let (decisionResult $action $_) (get-state &file-decision) (actionId $action)) execute-skill)
!(retainSelectedOperation execute-skill (get-state &file-rows))
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Executed Feasible "observed local file content"))
!(bind! &file-outcome (new-state (get-state &last-operation-outcome)))
!(test (get-state &file-outcome)
   (OperationOutcome (get-state &selected-operation-decision)
      (attempted-command (selectedHostCommand)) Success
      (DispatchResult Executed Feasible "observed local file content")))
;; A repeated ticket returns the original observation, not a second file read.
!(test (py-call (host_config_fixture.replace_file_content)) 1)
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Executed Feasible "observed local file content"))
!(test (get-state &last-operation-outcome) (get-state &file-outcome))

;; A file absent before opening is a definite native reader failure.
;; A new message must not discard the preceding same-frame observation.
!(change-state! &new-msg-flag True)
!(bind! &uncertain-bundle (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeOperationFeedback (get-state &uncertain-bundle)) (OperationFeedback Success 0))
!(test (frameRuntimeTaskOpen (get-state &uncertain-bundle)) True)
!(retainSelectedOperation execute-skill (captureCandidateOperations (get-state &uncertain-bundle)))
!(test (py-call (host_config_fixture.remove_file)) 1)
!(test (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Executed Feasible (Error read-file FileUnavailable)))
!(test (get-state &last-operation-outcome)
   (OperationOutcome (get-state &selected-operation-decision)
      (attempted-command (selectedHostCommand)) Failure
      (DispatchResult Executed Feasible (Error read-file FileUnavailable))))
!(test (py-call (host_config_fixture.replace_file_content)) 1)
!(change-state! &new-msg-flag False)

;; An explicitly observed handler error is Failure. The handler is a test
;; double; the policy gate, dispatcher, and correlation path remain real.
(= (outcome-test-failure) (quote (Error test-handler failed)))
!(test (py-call (host_config_fixture.install_failure_handler)) 1)
!(bind! &failure-bundle (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeOperationFeedback (get-state &failure-bundle)) (OperationFeedback Failure 1))
!(refreshSignals (get-state &failure-bundle))
!(test (signalTrue progress-made) False)
!(test (hasErrors) True)
;; R2 / 2.2: real consumed outcomes produce booleans with resolvable provenance.
(= (r22Fact $kind)
   (car-atom (filter-atom (getFactualSignals) $fact
      (== (factualSignalField kind $fact) $kind))))
(= (r22FeedbackReference $bundle)
   (let (SignalObservationView $_ $feedback $_) (frameRuntimeSignalObservations $bundle) $feedback))
(= (r22SnapshotReference $bundle)
   (let (SignalObservationView $snapshot $_ $_) (frameRuntimeSignalObservations $bundle) $snapshot))

!(test (factualSignalField value (r22Fact failure)) (quote (BooleanFact True)))
!(test (factualSignalField value (r22Fact progress-made)) (quote (BooleanFact False)))
!(test (factualSignalField value (r22Fact failure-streak)) (quote (QuantityFact 1 count)))
!(test (collapse (match &signal-space (signal $kind $strength) (signal $kind $strength))) ())
!(test (let (SourceObservation $_ $_ (ConsumedOutcome $decision $status $streak) $_)
   (resolveSignalObservation (r22FeedbackReference (get-state &failure-bundle)))
   ($decision $status $streak)) ((get-state &applied-operation-decision) Failure 1))
!(test (hostSignalFactSupported (get-state &failure-bundle) (r22Fact failure)) True)
!(retainSelectedOperation execute-skill (captureCandidateOperations (get-state &failure-bundle)))
;; Compare as data so expected Error records are not interpreter diagnostics.
!(test (== (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Executed Feasible (Error test-handler failed))) True)
!(test (== (get-state &last-operation-outcome)
   (OperationOutcome (get-state &selected-operation-decision)
      (attempted-command (quote (outcome-test-failure))) Failure
      (DispatchResult Executed Feasible (Error test-handler failed)))) True)
!(test (operationOutcomeStatus (quote (unknown-handler))
   (DispatchResult Executed Feasible "returned")) Unobserved)

;; Multiple exact argument bindings cannot collapse into one candidate score.
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "ambiguous"))))
!(bind! &bundle (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeOperationFeedback (get-state &bundle)) (OperationFeedback Failure 2))
!(refreshSignals (get-state &bundle))
!(test (signalTrue repeated-failure) True)
!(test (signalTrue progress-made) False)
;; Rereading the same snapshot must not increment its failure streak.
!(bind! &r22-before-source-store (new-state (get-state &signal-observation-state)))
!(bind! &r22-before-facts (new-state (getFactualSignals)))
!(refreshSignals (get-state &bundle))
!(test (getFactualSignals) (get-state &r22-before-facts))
!(test (get-state &signal-observation-state) (get-state &r22-before-source-store))
!(test (get-state &failure-streak) 2)
!(test (frameRuntimeTaskOpen (get-state &bundle)) True)
!(bind! &rows (new-state (captureCandidateOperations (get-state &bundle))))
!(test (hostOperationGate (get-state &bundle) execute-skill (get-state &rows))
   (GateDecision Rejected AmbiguousOperation))
!(test (hostOperationGate (get-state &bundle) search-knowledge (get-state &rows))
   (GateDecision Admitted Feasible))

;; F3.6: exact filtering preserves other candidates and never hides duplicate matches.
!(bind! &pending-row (new-state (car-atom (hostRowsForCandidate execute-skill (get-state &rows)))))
!(change-state! &task-continuation-view
   (ContinuationView "filter-plan" "1" Ready (repr (index-atom (get-state &pending-row) 2))))
!(bind! &pending-bundle (new-state (frameStateForMetaMo)))
!(bind! &pending-rows (new-state (continuationOperationRows (get-state &pending-bundle) (get-state &rows))))
!(test (hostRowsForCandidate execute-skill (get-state &pending-rows))
   (cons-atom (get-state &pending-row) ()))
!(test (hostOperationGate (get-state &pending-bundle) execute-skill (get-state &pending-rows))
   (GateDecision Admitted Feasible))
!(test (hostRowsForCandidate search-knowledge (get-state &pending-rows))
   (hostRowsForCandidate search-knowledge (get-state &rows)))
!(test (hostOperationGate (get-state &pending-bundle) execute-skill
   (continuationOperationRows (get-state &pending-bundle)
      (cons-atom (get-state &pending-row) (get-state &rows))))
   (GateDecision Rejected AmbiguousOperation))

;; A missing exact match, Held plan or completed read plan cannot fall back to another read.
!(change-state! &task-continuation-view (ContinuationView "filter-plan" "1" Ready "(read-file missing)"))
!(test (hostRowsForCandidate execute-skill (continuationOperationRows (frameStateForMetaMo) (get-state &rows))) ())
!(change-state! &task-continuation-view (ContinuationView "filter-plan" None Held ()))
!(test (hostRowsForCandidate execute-skill (continuationOperationRows (frameStateForMetaMo) (get-state &rows))) ())
!(change-state! &task-continuation-view (ContinuationView "filter-plan" None AwaitingCompletion ()))
!(test (hostRowsForCandidate execute-skill (continuationOperationRows (frameStateForMetaMo) (get-state &rows))) ())
!(change-state! &task-continuation-view NoContinuation)
!(test (continuationOperationRows (frameStateForMetaMo) (get-state &rows)) (get-state &rows))

;; A distinct invocation returning identical error text still counts once.
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "allowed"))))
!(test (py-call (host_config_fixture.install_failure_handler)) 1)
!(bind! &repeat-failure-bundle (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeOperationFeedback (get-state &repeat-failure-bundle)) (OperationFeedback NoOutcome 2))
;; Pending recovery keeps the original consumed failure reference across idle cycles.
!(refreshSignals (get-state &repeat-failure-bundle))
!(test (factualSignalField value (r22Fact stalled-progress)) (quote (BooleanFact True)))
!(test (let $ref (index-atom (factualSignalField provenance (r22Fact stalled-progress)) 1)
   (let (SourceObservation $_ $_ (ConsumedOutcome $_ $status $streak) $_)
      (resolveSignalObservation $ref) ($status $streak))) (Failure 2))
!(test (factualSignalField value (r22Fact repeated-failure)) (quote (BooleanFact False)))
!(retainSelectedOperation execute-skill (captureCandidateOperations (get-state &repeat-failure-bundle)))
!(test (== (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Executed Feasible (Error test-handler failed))) True)
!(bind! &second-failure (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeOperationFeedback (get-state &second-failure)) (OperationFeedback Failure 3))
!(refreshSignals (get-state &second-failure))
!(test (signalTrue repeated-failure) True)
!(test (frameRuntimeTaskOpen (get-state &second-failure)) True)
;; Stale formatted output cannot manufacture progress or another failure.
!(change-state! &lastresults "Task completed successfully")
!(change-state! &error "old formatted error")
!(bind! &duplicate-bundle (new-state (prepareTaskStateForMetaMo)))
!(test (frameRuntimeOperationFeedback (get-state &duplicate-bundle)) (OperationFeedback NoOutcome 3))
!(refreshSignals (get-state &duplicate-bundle))
!(test (hasResults) False)
!(test (hasErrors) False)
!(test (frameRuntimeExecutionObserved (get-state &duplicate-bundle)) "")
!(test (frameRuntimeTaskOpen (get-state &duplicate-bundle)) True)

;; An observation for a frame that is no longer current is not applied, even
;; if the host later returns to that frame. Its original record is retained.
!(retainSelectedOperation execute-skill (captureCandidateOperations (get-state &duplicate-bundle)))
!(test (== (coreLoopDispatchCommand (coreLoopDispatchBegin) (selectedHostCommand))
   (DispatchResult Executed Feasible (Error test-handler failed))) True)
!(bind! &old-session-outcome (new-state (get-state &last-operation-outcome)))
!(change-state! &cfv2-current-frame-id "other-frame")
!(test (frameRuntimeOperationFeedback (prepareTaskStateForMetaMo)) (OperationFeedback NoOutcome 3))
!(change-state! &cfv2-current-frame-id "configured-frame")
!(test (frameRuntimeOperationFeedback (prepareTaskStateForMetaMo)) (OperationFeedback NoOutcome 3))
!(test (== (get-state &last-operation-outcome) (get-state &old-session-outcome)) True)

;; Only explicit host adjudication closes the commitment in the next snapshot.
!(test (commitmentFixtureApply
   (quote (CommitmentEvent "premature" "feedback-task" 0 (Completed "unconfirmed"))))
   (CommitmentRejected CompletionNotConfirmed))
!(commitmentFixtureOutcome "confirmed" "feedback-task" 0 Completed)
!(test (commitmentFixtureApply
   (quote (CommitmentEvent "finish" "feedback-task" 0 (Completed "confirmed"))))
   (CommitmentApplied "finish" "feedback-task" Completed 1))
!(test (frameRuntimeTaskOpen (prepareTaskStateForMetaMo)) False)

;; A fresh host session rotates identity and clears correlation state.
!(test (initOperationSession) True)
!(test (let (OperationContext $old $_ $_) (get-state &first-context)
   (let (OperationContext $new $cycle $_) (get-state &operation-context)
      ((!= $old $new) $cycle))) (True 0))
!(test (get-state &selected-operation-decision) ())
!(test (get-state &last-operation-outcome) ())
!(test (coreLoopDispatchCommand (get-state &chosen-ticket) (quote (show-current-frame)))
   (DispatchResult Blocked MissingDecision none))
!(test (get-state &last-operation-outcome) ())
;; Even a retained observation reintroduced after session reset is excluded.
!(change-state! &last-operation-outcome (get-state &old-session-outcome))
!(test (frameRuntimeOperationFeedback (prepareTaskStateForMetaMo)) (OperationFeedback NoOutcome 0))
!(test (get-state &applied-operation-decision) ())
;; Session reset invalidates old provenance, independently of unchanged frame IDs.
!(test (resolveSignalObservation (r22SnapshotReference (get-state &failure-bundle)))
   (FactualSignalRejected MissingObservation))

;; A managed cycle cannot adopt missing, fabricated or mismatched provenance.
!(bind! &r22-current (new-state (prepareTaskStateForMetaMo)))
!(refreshSignals (get-state &r22-current))
!(test (signalCycleReady) True)
!(test (refreshSignals (signalBundleWithView (get-state &r22-current) NoSignalObservations))
   (FactualSignalRejected MissingObservation))
!(test (signalCycleReady) False)
!(test (getFactualSignals) ())
!(bind! &r22-forged (new-state (signalBundleWithView (get-state &r22-current)
   (quote (SignalObservationView (SessionObservationRef "not-this-session" 17) None None)))))
!(test (refreshSignals (get-state &r22-forged)) (FactualSignalRejected MismatchedObservation))
!(test (policyOutputOperation (motivationContextBlockForBundle (get-state &r22-forged))) none)
!(test (selectedHostCommand) ())
!(refreshSignals (get-state &r22-current))
!(test (signalCycleReady) True)
!(test (publishFactualSignalFacts (get-state &r22-current)
   ((makeFactualSignal failure (quote (BooleanFact True))
      ((r22SnapshotReference (get-state &r22-current))))))
   (FactualSignalRejected InvalidProducingObservation))
!(test (getFactualSignals) ())
!(refreshSignals (get-state &r22-current))
!(test (publishFactualSignalFacts (get-state &r22-current)
   ((r22Fact failure) (r22Fact failure)))
   (FactualSignalRejected InvalidProducingObservation))

;; Capacity/counter rejection cannot alter retained observation state.
!(bind! &r22-capacity-before (new-state (get-state &signal-observation-state)))
!(test (hostAllocateSignalSource "s" 9007199254740991 () NoOwner ignored ())
   (FactualSignalRejected ObservationCapacity))
!(test (hostAllocateSignalSource "s" "invalid" () NoOwner ignored ())
   (FactualSignalRejected InvalidObservationState))
!(test (get-state &signal-observation-state) (get-state &r22-capacity-before))

;; Bounded rotation expires old references and keeps live publication storage small.
(= (r22PublishMany $remaining)
   (if (== $remaining 0) True
      (progn (prepareTaskStateForMetaMo) (r22PublishMany (- $remaining 1)))))
!(refreshSignals (get-state &r22-current))
!(computeAllDimensions)
!(bind! &r23-host-trace (new-state (lastAppraisalContributions)))
;; A newer factual diagnostic must not release the still-retained appraisal source.
!(bind! &r23-new-facts (new-state (prepareTaskStateForMetaMo)))
!(refreshSignals (get-state &r23-new-facts))
!(bind! &r22-unreviewed (new-state (prepareTaskStateForMetaMo)))
!(r22PublishMany 80)
!(test (resolveSignalObservation (r22SnapshotReference (get-state &r22-unreviewed)))
   (FactualSignalRejected MissingObservation))
!(test (case (resolveSignalObservation (r22SnapshotReference (get-state &r22-current))) (
   ((SourceObservation $_ $_ $_ $_) True) ($_ False))) True)
!(test (let (SignalObservationState $_ $_ $entries) (get-state &signal-observation-state)
   (<= (size-atom $entries) 12)) True)

!(test (lastAppraisalContributions) (get-state &r23-host-trace))
!(test (!= (lastAppraisalContributions) ()) True)
!(test (case (resolveSignalObservation (r22SnapshotReference (get-state &r23-new-facts))) (
   ((SourceObservation $_ $_ $_ $_) True) ($_ False))) True)

;; The spec's blocked-frame example comes from actual captured native status.
!(bind! &r22-native-status (new-state (get-state &cfv2-current-status)))
!(change-state! &cfv2-current-status Blocked)
!(bind! &r22-blocked (new-state (prepareTaskStateForMetaMo)))
!(refreshSignals (get-state &r22-blocked))
!(test (factualSignalField value (r22Fact frame-blocked)) (quote (BooleanFact True)))
!(test (hostSignalFactSupported (get-state &r22-blocked) (r22Fact frame-blocked)) True)

;; A blocked-frame coefficient affects appraisal only: captured facts, trigger
;; evidence, scheduling and the hard command gate preserve their exact values.
!(bind! &r24-blocked-facts (new-state (getSignals)))
!(bind! &r24-blocked-dimension (new-state (computeDimension novelty)))
!(bind! &r24-blocked-mode (new-state (modeEvaluationForContext
   (ModeTransitionState Engaged 0 none 0 0) (getSignals) True)))
!(bind! &r24-blocked-scheduling (new-state
   (schedulingPriorityForCandidate (getSignals) verify-frame-state)))
!(bind! &r24-blocked-gate (new-state (feasibilityGate (get-state &r22-blocked) execute-skill)))
!(add-atom &self (SignalAppraisalRule frame-blocked novelty BooleanIndicator 0.25))
!(test (> (computeDimension novelty) (get-state &r24-blocked-dimension)) True)
!(test (getSignals) (get-state &r24-blocked-facts))
!(test (signalTrue frame-blocked) True)
!(test (modeEvaluationForContext (ModeTransitionState Engaged 0 none 0 0) (getSignals) True)
   (get-state &r24-blocked-mode))
!(test (schedulingPriorityForCandidate (getSignals) verify-frame-state)
   (get-state &r24-blocked-scheduling))
!(test (feasibilityGate (get-state &r22-blocked) execute-skill) (get-state &r24-blocked-gate))
!(remove-atom &self (SignalAppraisalRule frame-blocked novelty BooleanIndicator 0.25))
!(change-state! &cfv2-current-status (get-state &r22-native-status))

;; R2 / 2.4: real bridge mode evidence pins its own source after both factual
;; and appraisal diagnostics advance to a different publication.
!(motivationContextBlockForBundle (prepareTaskStateForMetaMo))
!(bind! &r24-retained-mode (new-state (lastModeObservation)))
!(bind! &r24-mode-source (new-state
   (let (ModeObservation $_ $_ $facts $_ $_ $_) (lastModeObservation)
      (car-atom (signalProvenanceIn $facts failure)))))
!(bind! &r24-new-publication (new-state (prepareTaskStateForMetaMo)))
!(refreshSignals (get-state &r24-new-publication))
!(computeAllDimensions)
!(r22PublishMany 80)
!(test (lastModeObservation) (get-state &r24-retained-mode))
!(test (case (resolveSignalObservation (get-state &r24-mode-source)) (
   ((SourceObservation $_ $_ $_ $_) True) ($_ False))) True)
!(test (let (SignalObservationState $_ $_ $entries) (get-state &signal-observation-state)
   (<= (size-atom $entries) 16)) True)
!(test (initOperationSession) True)
!(test (lastModeObservation) NoModeObservation)
!(test (getSignals) ())
!(test (lastAppraisalContributions) ())
!(test (resolveSignalObservation (get-state &r24-mode-source))
   (FactualSignalRejected MissingObservation))
!(test (py-call (host_config_fixture.cleanup)) 1)

;; Optional proposal attribution uses real host selection, Core tickets and reads.
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_proposals))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_host_evidence))
!(commitmentFixtureReset)
!(initContextFrame)
!(initOmegaClawMotivation)
!(initOperationSession)
!(ctx-ingest-user-message "Inspect evidence input")
!(cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
!(change-state! &cfv2-current-frame-id "configured-frame")
!(change-state! &prevmsg "")
!(change-state! &lastresults "")
!(change-state! &error "")
!(change-state! &new-msg-flag False)
!(commitmentFixtureOpen "reasoner-owner" "configured-frame" "Inspect evidence input")
!(initMetaMoDispatch)
!(bind! &reasoner-host-config (new-state (py-call (host_config_fixture.setup))))
!(py-call (host_dispatch_config.provision (get-state &reasoner-host-config)))

;; Select an actually admitted read and retain the proposal's exact origin.
;; Example: (reasonerHostReadCycle proposal-A) returns a retained Accepted event.
(= (reasonerHostReadCycle $id)
    (let*
        (
            ($bundle (prepareTaskStateForMetaMo))
            ($rows (captureCandidateOperations $bundle))
            ($action (candidateToAction execute-skill))
            ($pruning (admitCapturedOperations $bundle (cons-atom $action ()) $rows))
            ($_ (retainSelectedOperation execute-skill $rows))
            ($proposal (ReasonerMotivationalProposal $id nars propose-candidate
                (FrameTarget (frameBundleCurrentId $bundle)) execute-skill
                inspect-input observed-request 0.9 (EvidenceReferences (input-request))
                (Expected ReadSucceeded)))
            ($decision (reasonerProposalDecision $bundle (motivosToMetamoState) $proposal))
        )
        (if (== $pruning (CandidatePruning (admitted (cons-atom $action ())) (rejected ())))
            (ReasonerProposalEvent (proposal $proposal) (decision $decision) (disposition Accepted))
            NoHostSelection
        )
    )
)

!(bind! &reasoner-host-event (new-state (reasonerHostReadCycle proposal-A)))

;; A proposal-shaped event absent from the retained audit cannot claim selection.
!(test (retainReasonerProposalSelection
    (quote (ReasonerProposalEvent
        (proposal (ReasonerMotivationalProposal unretained nars propose-candidate current-frame
            execute-skill claim support 0.9 (EvidenceReferences (e1)) prediction))
        (decision (ReasonerMotivationalDecision Accepted Feasible
            (ReasonerMotivationalProposal unretained nars propose-candidate current-frame
                execute-skill claim support 0.9 (EvidenceReferences (e1)) prediction)
            execute-skill 0.5))
        (disposition Accepted))))
    (ReasonerOutcomeRejected UnretainedDecision))

!(test (retainReasonerProposalSelection (get-state &reasoner-host-event))
    (ReasonerProposalLinked (get-state &selected-operation-decision)))

!(test (observeReasonerProposalExecution (get-state &reasoner-host-event))
    (ReasonerOutcomeRejected MismatchedObservation))

!(bind! &reasoner-grade-before (new-state (reasonerSourceReliability nars)))
!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event) Completed () Confirmed ())
    (ReasonerOutcomeRejected MissingExecutionEvidence))

!(test (reasonerSourceReliability nars) (get-state &reasoner-grade-before))

!(test (coreLoopDispatchCommand (selectedHostTicket) (selectedHostCommand))
    (DispatchResult Executed Feasible "observed local file content"))

;; Knowing a real ticket is insufficient before trusted observation capture.
!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Completed (ReasonerExecutionEvidence (selectedHostTicket)) Unresolved ())
    (ReasonerOutcomeRejected MissingExecutionEvidence))

;; A new audit event cannot retrospectively adopt an execution that already ran.
!(bind! &reasoner-late-proposal (new-state
    (ReasonerMotivationalProposal late-proposal nars propose-candidate current-frame
        execute-skill claim support 0.9 (EvidenceReferences (e1)) prediction)))
!(bind! &reasoner-late-decision (new-state
    (reasonerProposalDecision (activeFrameBundle) (motivosToMetamoState)
        (get-state &reasoner-late-proposal))))
!(test (retainReasonerProposalSelection
    (ReasonerProposalEvent (proposal (get-state &reasoner-late-proposal))
        (decision (get-state &reasoner-late-decision)) (disposition Accepted)))
    (ReasonerOutcomeRejected StaleDispatch))

;; A structurally valid callback is insufficient when Core retained other data.
!(bind! &reasoner-actual-callback (new-state (get-state &last-operation-outcome)))
!(change-state! &last-operation-outcome
    (OperationOutcome (get-state &selected-operation-decision)
        (attempted-command (selectedHostCommand)) Success
        (DispatchResult Executed Feasible "fabricated observation")))
!(test (observeReasonerProposalExecution (get-state &reasoner-host-event))
    (ReasonerOutcomeRejected MismatchedExecution))
!(change-state! &last-operation-outcome (get-state &reasoner-actual-callback))

!(bind! &reasoner-host-evidence (new-state
    (observeReasonerProposalExecution (get-state &reasoner-host-event))))
!(test (get-state &reasoner-host-evidence)
    (ReasonerExecutionEvidence (selectedHostTicket)))

!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Completed (ReasonerExecutionEvidence (selectedHostTicket) (get-state &last-operation-outcome))
    Unresolved ()) (ReasonerOutcomeRejected MissingExecutionEvidence))

!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Completed (get-state &reasoner-host-evidence) Confirmed ())
    (ReasonerOutcomeRejected MissingVerificationEvidence))

!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Completed (get-state &reasoner-host-evidence) Confirmed (quote (model-says-confirmed)))
    (ReasonerOutcomeRejected UnsupportedVerificationEvidence))

!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Failed (get-state &reasoner-host-evidence) Unresolved ())
    (ReasonerOutcomeRejected ExecutionStatusMismatch))

!(test (reasonerSourceReliability nars) (get-state &reasoner-grade-before))

!(bind! &reasoner-recorded-grade (new-state
    (recordReasonerProposalOutcome (get-state &reasoner-host-event)
        Completed (get-state &reasoner-host-evidence) Unresolved ())))
!(test (case (get-state &reasoner-recorded-grade)
    (((ReasonerProposalOutcomeEvent (outcome-id $_id) $_ $_ $_ $_ $_ (outcome Unresolved) (grade 0.75)) True)
        ($_ False))) True)

!(test (!= (reasonerSourceReliability nars) (get-state &reasoner-grade-before)) True)
!(test (frameRuntimeTaskOpen (activeFrameBundle)) True)

;; Outcome identity comes from the observed execution, never its result text.
!(test (getProposalOutcomeId (get-state &reasoner-recorded-grade))
    (let* (
        ((OperationContext $session $_ $_) (get-state &operation-context))
        ((DispatchTicket $ticket) (selectedHostTicket)))
        (ReasonerOutcomeRef $session $ticket)))

!(bind! &reasoner-once-reliability (new-state (reasonerSourceReliability nars)))
!(bind! &reasoner-once-outcomes (new-state (reasonerProposalOutcomes)))
!(test (map-atom (1 2 3 4 5) $delivery
    (recordReasonerProposalOutcome (get-state &reasoner-host-event)
        Completed (get-state &reasoner-host-evidence) Unresolved ()))
    (map-atom (1 2 3 4 5) $delivery (get-state &reasoner-recorded-grade)))

!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Failed (get-state &reasoner-host-evidence) Unresolved ())
    (ReasonerOutcomeRejected ConflictingReplay))

!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Completed (get-state &reasoner-host-evidence) Confirmed ())
    (ReasonerOutcomeRejected ConflictingReplay))

!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Completed (get-state &reasoner-host-evidence) Unresolved (quote (new-observation)))
    (ReasonerOutcomeRejected ConflictingReplay))

!(test (reasonerSourceReliability nars) (get-state &reasoner-once-reliability))
!(test (reasonerProposalOutcomes) (get-state &reasoner-once-outcomes))

;; A second retained proposal cannot claim the already attributed ticket.
!(bind! &reasoner-alternative (new-state
    (ReasonerMotivationalProposal alternative nars propose-candidate current-frame
        execute-skill claim support 0.9 (EvidenceReferences (e1)) prediction)))
!(bind! &reasoner-alternative-decision (new-state
    (reasonerProposalDecision (activeFrameBundle) (motivosToMetamoState)
        (get-state &reasoner-alternative))))
!(test (recordReasonerProposalOutcome
    (ReasonerProposalEvent (proposal (get-state &reasoner-alternative))
        (decision (get-state &reasoner-alternative-decision)) (disposition Accepted))
    Completed (get-state &reasoner-host-evidence) Unresolved ())
    (ReasonerOutcomeRejected MissingSelectionLink))

;; A later cycle cannot adopt the old proposal or supply its execution evidence.
!(bind! &reasoner-host-next (new-state (reasonerHostReadCycle proposal-B)))
!(test (retainReasonerProposalSelection (get-state &reasoner-host-event))
    (ReasonerOutcomeRejected StaleProposalContext))

!(test (retainReasonerProposalSelection (get-state &reasoner-host-next))
    (ReasonerProposalLinked (get-state &selected-operation-decision)))

!(test (recordReasonerProposalOutcome (get-state &reasoner-host-next)
    Completed (get-state &reasoner-host-evidence) Unresolved ())
    (ReasonerOutcomeRejected MissingExecutionEvidence))

;; An actual failed read has its own exact ticket and immutable observation.
!(py-call (host_config_fixture.remove_file))
!(test (coreLoopDispatchCommand (selectedHostTicket) (selectedHostCommand))
    (quote (DispatchResult Executed Feasible (Error read-file FileUnavailable))))

!(bind! &reasoner-failed-evidence (new-state
    (observeReasonerProposalExecution (get-state &reasoner-host-next))))
!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Completed (get-state &reasoner-failed-evidence) Unresolved ())
    (ReasonerOutcomeRejected MissingExecutionEvidence))

!(test (recordReasonerProposalOutcome (get-state &reasoner-host-next)
    Completed (get-state &reasoner-failed-evidence) Unresolved ())
    (ReasonerOutcomeRejected ExecutionStatusMismatch))

;; An exception after the audit insertion must roll back it and the replay marker.
!(bind! &reasoner-before-failed-commit (new-state (reasonerProposalOutcomes)))
!(bind! &reasoner-reliability-row (new-state
    (ReasonerSourceReliability nars (reasonerSourceReliability nars))))
!(let $row (get-state &reasoner-reliability-row) (remove-atom &reasoner-source-reliability $row))
!(add-atom &reasoner-source-reliability (ReasonerSourceReliability nars "invalid-number"))
!(test (recordReasonerProposalOutcome (get-state &reasoner-host-next)
    Failed (get-state &reasoner-failed-evidence) Unresolved ())
    (ReasonerOutcomeRejected OutcomeCommitFailed))

!(test (reasonerProposalOutcomes) (get-state &reasoner-before-failed-commit))
!(test (reasonerSourceReliability nars) "invalid-number")
!(remove-atom &reasoner-source-reliability (ReasonerSourceReliability nars "invalid-number"))
!(let $row (get-state &reasoner-reliability-row) (add-atom &reasoner-source-reliability $row))

!(test (case (recordReasonerProposalOutcome (get-state &reasoner-host-next)
        Failed (get-state &reasoner-failed-evidence) Unresolved ())
    (((ReasonerProposalOutcomeEvent (outcome-id $_id) $_ $_ $_ $_ $_ (outcome Refuted) (grade 0.0)) True)
        ($_ False))) True)

;; Equal command text and output from distinct executions remain distinct observations.
!(py-call (host_config_fixture.replace_file_content))
!(bind! &reasoner-repeat-event-1 (new-state (reasonerHostReadCycle repeat-1)))
!(test (retainReasonerProposalSelection (get-state &reasoner-repeat-event-1))
    (ReasonerProposalLinked (get-state &selected-operation-decision)))
!(test (coreLoopDispatchCommand (selectedHostTicket) (selectedHostCommand))
    (DispatchResult Executed Feasible "changed after invocation"))
!(bind! &reasoner-repeat-evidence-1 (new-state
    (observeReasonerProposalExecution (get-state &reasoner-repeat-event-1))))
!(bind! &reasoner-repeat-grade-1 (new-state
    (recordReasonerProposalOutcome (get-state &reasoner-repeat-event-1)
        Completed (get-state &reasoner-repeat-evidence-1) Unresolved ())))
!(bind! &reasoner-repeat-event-2 (new-state (reasonerHostReadCycle repeat-2)))
!(test (retainReasonerProposalSelection (get-state &reasoner-repeat-event-2))
    (ReasonerProposalLinked (get-state &selected-operation-decision)))
!(bind! &reasoner-competing-proposal (new-state
    (ReasonerMotivationalProposal competing nars propose-candidate current-frame
        execute-skill claim support 0.9 (EvidenceReferences (e1)) prediction)))
!(bind! &reasoner-competing-decision (new-state
    (reasonerProposalDecision (activeFrameBundle) (motivosToMetamoState)
        (get-state &reasoner-competing-proposal))))
!(test (retainReasonerProposalSelection
    (ReasonerProposalEvent (proposal (get-state &reasoner-competing-proposal))
        (decision (get-state &reasoner-competing-decision)) (disposition Accepted)))
    (ReasonerOutcomeRejected ConflictingSelection))

!(test (coreLoopDispatchCommand (selectedHostTicket) (selectedHostCommand))
    (DispatchResult Executed Feasible "changed after invocation"))
!(bind! &reasoner-repeat-evidence-2 (new-state
    (observeReasonerProposalExecution (get-state &reasoner-repeat-event-2))))
!(bind! &reasoner-repeat-grade-2 (new-state
    (recordReasonerProposalOutcome (get-state &reasoner-repeat-event-2)
        Completed (get-state &reasoner-repeat-evidence-2) Unresolved ())))
!(test (!= (getProposalOutcomeId (get-state &reasoner-repeat-grade-1))
    (getProposalOutcomeId (get-state &reasoner-repeat-grade-2))) True)

!(bind! &reasoner-after-independent (new-state (reasonerSourceReliability nars)))
!(bind! &reasoner-independent-count (new-state (size-atom (reasonerProposalOutcomes))))
!(test (get-state &reasoner-independent-count) 4)
!(test (recordReasonerProposalOutcome (get-state &reasoner-repeat-event-2)
    Completed (get-state &reasoner-repeat-evidence-1) Unresolved ())
    (ReasonerOutcomeRejected MissingExecutionEvidence))

!(test (recordReasonerProposalOutcome (get-state &reasoner-repeat-event-1)
    Completed (get-state &reasoner-repeat-evidence-1) Unresolved ())
    (get-state &reasoner-repeat-grade-1))
!(test (reasonerSourceReliability nars) (get-state &reasoner-after-independent))
!(test (size-atom (reasonerProposalOutcomes)) (get-state &reasoner-independent-count))

;; Revocation after linking cannot create observed execution or a grade.
!(py-call (host_config_fixture.replace_file_content))
!(bind! &reasoner-revoked-event (new-state (reasonerHostReadCycle proposal-C)))
!(test (retainReasonerProposalSelection (get-state &reasoner-revoked-event))
    (ReasonerProposalLinked (get-state &selected-operation-decision)))
!(py-call (host_dispatch_config.provision (py-call (host_config_fixture.write "permission-denied"))))
!(test (coreLoopDispatchCommand (selectedHostTicket) (selectedHostCommand))
    (DispatchResult Blocked StaleSnapshot none))

!(test (observeReasonerProposalExecution (get-state &reasoner-revoked-event))
    (ReasonerOutcomeRejected NoObservedExecution))

!(test (recordReasonerProposalOutcome (get-state &reasoner-revoked-event)
    Completed (ReasonerExecutionEvidence (selectedHostTicket)) Unresolved ())
    (ReasonerOutcomeRejected MissingExecutionEvidence))

;; An old captured receipt stays historical; later ownership cannot relabel it.
!(commitmentFixtureApply
    (quote (CommitmentEvent "reasoner-replace" "reasoner-owner" 0
        (Superseded "reasoner-successor" "Inspect another input" "Explicit replacement"))))
!(test (observeReasonerProposalExecution (get-state &reasoner-host-event))
    (ReasonerOutcomeRejected OwnerMismatch))

!(test (validateReasonerExecutionEvidence (get-state &reasoner-host-event)
    Completed (get-state &reasoner-host-evidence) Unresolved ()) ReasonerExecutionEvidenceValid)

!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Completed (get-state &reasoner-host-evidence) Unresolved ())
    (get-state &reasoner-recorded-grade))
!(test (reasonerSourceReliability nars) (get-state &reasoner-after-independent))

;; Unknown sessions do not borrow evidence from the old session's ledger.
!(initOperationSession)
!(prepareTaskStateForMetaMo)
!(test (recordReasonerProposalOutcome (get-state &reasoner-host-event)
    Completed (get-state &reasoner-host-evidence) Unresolved ())
    (ReasonerOutcomeRejected MissingSelectionLink))

!(test (py-call (host_config_fixture.cleanup)) 1)
