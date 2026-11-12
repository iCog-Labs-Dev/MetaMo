!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/boundary_loop))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner))
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_contracts))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_proposals))
!(bind! &probe-view (new-state ()))
!(bind! &probe-count (new-state 0))
!(bind! &probe-notifications (new-state ()))
(= (probeLoad) True)
(= (probeCollect $invocation $view $actions)
    (let* (
        ($_ (change-state! &probe-view (quote $view)))
        ($_ (change-state! &probe-count (+ (get-state &probe-count) 1)))
        ($id (mrcValue $invocation 1))
        ($adapter (mrcValue $invocation 2))
        ($refs (mrcValue $invocation 13))
        ($proposal (quote (ReasonerMotivationalProposal proposal-1 llm propose-candidate
            current-frame respond claim support 0.8 (EvidenceReferences $refs) prediction)))
    )
        (quote (ReasonerIntakeResult (invocation-id $id) (adapter $adapter)
            (status Proposals) (proposals ($proposal)) (diagnostics ())))))
(= (probeNotify $stage $invocation $payload)
    (progn (change-state! &probe-notifications
        (cons-atom (quote ($stage $payload)) (get-state &probe-notifications))) True))

(: ExpectedModeTransitionType Type)
(: ExpectedModeTransition (-> Symbol Symbol ExpectedModeTransitionType))
!(bind! &probe-phase-inputs (new-state ()))

;; Capture phase ordering from the actual bridge without changing host state.
;; Example: ModeIntake sees no current transition; CandidateIntake sees admitted actions.
(= (phaseProbeCollect $invocation $view $actions)
    (let* (
        ($_ (change-state! &probe-phase-inputs
            (cons-atom ($invocation $view $actions (lastModeObservation)
                (get-state &selected-operation-decision) (get-state &operation-admitted-actions))
                (get-state &probe-phase-inputs))))
        ($id (mrcValue $invocation 1))
        ($adapter (mrcValue $invocation 2))
        ($refs (mrcValue $invocation 13))
    )
        (if (== (mrcValue $invocation 10) ModeIntake)
            (quote (ReasonerIntakeResult (invocation-id $id) (adapter $adapter)
                (status Proposals) (proposals ((ReasonerMotivationalProposal mode-1 llm
                    request-mode-change (ModeTarget Slow) defer claim support 0.8
                    (EvidenceReferences $refs) (ExpectedModeTransition Engaged Engaged))))
                (diagnostics ())))
            (probeCollect $invocation $view $actions)))
)
