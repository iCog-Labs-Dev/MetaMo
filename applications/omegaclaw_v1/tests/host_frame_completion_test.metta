;; Real Core archival, index/cache updates, and prepare hook; external services doubled.
!(import! &self fixtures/full_loop.metta)
!(import! &self (library MetaMo applications/omegaclaw_v1/runtime_support))
!(import! &self (library MetaMo applications/omegaclaw_v1/host_startup))
!(import! &self fixtures/host_startup_fixture.py)
!(import_prolog_functions_from_file
    (library MetaMo applications/omegaclaw_v1/tests/fixtures/commitments.pl)
    (commitmentFixtureReset commitmentFixtureComplete commitmentFixtureApply commitmentFixtureEpoch))
!(commitmentFixtureReset)
!(py-call (host_config_fixture.setup))
!(initContextFrame)
!(fullLoopStartSession)
!(py-call (host_startup_fixture.configure))
!(initializeHostStartup)

!(test (get-state &last-host-frame-completion) ())

!(coreLoopIngest "Read A and B")
!(cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
!(coreLoopPrepare)
!(bind! &finished-frame (new-state (cfv2-root-current-frame-id)))
!(bind! &finished-owner (new-state (commitmentSnapshot)))
!(bind! &finished-id (new-state (get-state &task-commitment-id)))

!(test (get-state &last-host-frame-completion) (FrameCompletionSkipped NoCompletedCommitment))

;; Example: frameRead retains a read command as data for its cycle and ticket.
(= (frameRead $cycle $path $ticket)
    (OperationDecision
        (OperationContext "session" $cycle (get-state &finished-frame))
        execute-skill
        (sread $path)
        (DispatchTicket $ticket)
    )
)

;; Example: the final answer belongs to cycle 3 of the same frame.
(= (frameAnswer)
    (OperationDecision
        (OperationContext "session" 3 (get-state &finished-frame))
        respond
        (sread "(send \"A and B\")")
        (DispatchTicket "answer")
    )
)

;; Example: completing this task requires both reads and the local answer.
(= (frameRequirements)
    (CompletionRequirements
        (get-state &finished-owner)
        (
            (frameRead 1 "(read-file \"/a\")" "a")
            (frameRead 2 "(read-file \"/b\")" "b")
        )
        (RequiredAnswer (frameAnswer) "local:stdout")
    )
)

;; Example: each successful outcome retains its original commitment owner.
(= (frameEvidenceRow $decision $value)
    (
        (get-state &finished-owner)
        (OperationOutcome
            $decision
            (attempted-command (index-atom $decision 3))
            Success
            (DispatchResult Executed Feasible $value)
        )
    )
)

;; Example: two observed file contents and an Accepted receipt satisfy the fixture.
(= (frameEvidence)
    (
        (frameEvidenceRow (frameRead 1 "(read-file \"/a\")" "a") "A")
        (frameEvidenceRow (frameRead 2 "(read-file \"/b\")" "b") "B")
        (frameEvidenceRow (frameAnswer) (SendObservation "local:stdout" Accepted))
    )
)

;; Example: replay uses the same outcome and event IDs without publishing twice.
(= (publishFrameCompletion)
    (commitmentFixtureComplete
        "frame-outcome"
        "frame-event"
        (frameRequirements)
        (frameEvidence)
    )
)

!(change-state! &operation-context (OperationContext "session" 3 (get-state &finished-frame)))

!(test (publishFrameCompletion) (CommitmentApplied "frame-event" (get-state &finished-id) Completed 1))

;; A string spelling the native frame symbol must not complete that frame.
!(change-state! &cfv2-current-frame-id (repr (get-state &finished-frame)))
!(coreLoopPrepare)

!(test (get-state &last-host-frame-completion) (FrameCompletionHeld FrameMismatch))

!(test (cfv2-frame-refs-by-status Completed) ())

!(change-state! &cfv2-current-frame-id (get-state &finished-frame))
!(bind! &frame-ticket (new-state (coreDispatchCapture
    (AdmissionRequest propose-candidate current-frame execute-skill))))
!(coreLoopPrepare)

!(test (get-state &last-host-frame-completion)
    (FrameCompleted (get-state &finished-id) (get-state &finished-frame)))

!(test (get-state &cfv2-current-frame-id) ())

!(test (get-state &task-open) False)

!(test (cfv2-frame-refs-by-status Active) ())

!(test (size-atom (cfv2-frame-refs-by-status Completed)) 1)

!(test (size-atom (filter-atom (get-state &cfv2-completed-framespace) $frame
    (== (cfv2-check-frame-id $frame (get-state &finished-frame)) True))) 1)

!(test (coreDispatchCommand (get-state &frame-ticket) (sread (py-call (host_config_fixture.command))))
    (DispatchResult Blocked StaleSnapshot none))

!(bind! &completed-space (new-state (get-state &cfv2-completed-framespace)))
!(bind! &completed-index (new-state (get-state &cfv2-frame-indexspace)))
!(bind! &completed-epoch (new-state (commitmentFixtureEpoch)))
!(coreLoopPrepare)

!(test (get-state &last-host-frame-completion)
    (FrameCompletionRetained (get-state &finished-id) (get-state &finished-frame)))

!(test (get-state &cfv2-completed-framespace) (get-state &completed-space))

!(test (get-state &cfv2-frame-indexspace) (get-state &completed-index))

!(test (commitmentFixtureEpoch) (get-state &completed-epoch))

;; A new frame survives repeated old publication and prepare cycles.
!(coreLoopIngest "A new task")
!(cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
!(coreLoopPrepare)
!(bind! &next-frame (new-state (get-state &cfv2-current-frame-id)))
!(bind! &next-owner (new-state (commitmentSnapshot)))

!(test (!= (get-state &next-frame) (get-state &finished-frame)) True)

!(test (publishFrameCompletion) (CommitmentApplied "frame-event" (get-state &finished-id) Completed 1))

!(coreLoopPrepare)

!(test (get-state &cfv2-current-frame-id) (get-state &next-frame))

!(test (get-state &cfv2-current-status) Active)

!(test (commitmentSnapshot) (get-state &next-owner))

!(test (get-state &task-open) True)

!(test (get-state &last-host-task-provisioning) (TaskProvisioning Retained))

!(test (coreDispatchCommand
    (coreDispatchCapture (AdmissionRequest propose-candidate current-frame execute-skill))
    (sread (py-call (host_config_fixture.command))))
    (DispatchResult Executed Feasible "observed local file content"))

;; Abandonment is not successful frame completion.
!(coreLoopIngest "cancel: no longer needed")
!(coreLoopPrepare)

!(test (get-state &last-host-frame-completion) (FrameCompletionSkipped NoCompletedCommitment))

!(test (get-state &cfv2-current-frame-id) (get-state &next-frame))

!(test (size-atom (cfv2-frame-refs-by-status Completed)) 1)

;; Core may select an already queued frame during archival; do not close that frame.
!(commitmentFixtureReset)
!(initContextFrame)
!(fullLoopStartSession)
!(py-call (host_startup_fixture.configure))
!(initializeHostStartup)
!(coreLoopIngest "Read A and B")
!(cfv2-load-frame (get-state &cfv2-last-admitted-frame-id))
!(coreLoopPrepare)
!(change-state! &finished-frame (cfv2-root-current-frame-id))
!(change-state! &finished-owner (commitmentSnapshot))
!(change-state! &finished-id (get-state &task-commitment-id))
;; Trusted fixture admits queued work directly; this is not multi-task ingress support.
!(ctx-ingest-user-message "Queued next task")
!(bind! &queued-frame (new-state (get-state &cfv2-last-admitted-frame-id)))
!(change-state! &operation-context (OperationContext "session" 3 (get-state &finished-frame)))

!(test (publishFrameCompletion) (CommitmentApplied "frame-event" (get-state &finished-id) Completed 1))

!(coreLoopPrepare)

!(test (get-state &cfv2-current-frame-id) (get-state &queued-frame))

!(test (get-state &cfv2-current-status) Active)

!(test (get-state &active-task) "Queued next task")

!(test (get-state &task-open) True)

!(test (size-atom (cfv2-frame-refs-by-status Completed)) 1)

!(test (publishFrameCompletion) (CommitmentApplied "frame-event" (get-state &finished-id) Completed 1))

!(coreLoopPrepare)

!(test (get-state &cfv2-current-frame-id) (get-state &queued-frame))

!(test (size-atom (cfv2-frame-refs-by-status Completed)) 1)

!(py-call (host_config_fixture.cleanup))
