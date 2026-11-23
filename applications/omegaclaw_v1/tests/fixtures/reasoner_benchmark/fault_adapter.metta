;; Bounded test doubles for failed advisory intake and uncertain host service execution.
;; Core admission, dispatch, receipts, deduplication and coordinator feedback remain real.
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_proposals))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_outcome_assessment))
!(import! &self rule_adapter)
!(import! &self fault_adapter.py)
!(import_prolog_function sleep)
!(import_prolog_functions_from_file
    (library MetaMo applications/omegaclaw_v1/tests/fixtures/dispatch.pl) (hostBudgetFixturePartialExecute))
!(import_prolog_functions_from_file
    (library MetaMo applications/omegaclaw_v1/tests/fixtures/reasoner_benchmark/fault_adapter.pl)
    (benchmarkFaultLoseResult benchmarkFaultCountResult benchmarkFaultRestore))
!(bind! &benchmark-fault-evidence (new-state ()))
!(bind! &budget-test-effects (new-state 0))

;; Example: the selected registered adapter installs collection and supported feedback callbacks.
(= (benchmarkFaultLoad)
    (configureHostReasonerRuntime (repr (argk "reasoner"))
        (quote (HostReasonerRuntime "fault-fixture-1" benchmarkFaultCollect benchmarkFaultNotify () 0.8))))

;; Example: record the automatic admitted view before returning advice or simulating a timeout.
(= (benchmarkFaultCollect $invocation $view $actions)
    (progn
        (benchmarkFaultAudit Collect $invocation (quote ($view $actions)))
        (case (mrcValue $invocation 2) (
            ("benchmark-empty" (benchmarkFaultEmpty $invocation))
            ("benchmark-timeout" (progn (sleep 0.15) (benchmarkRuleCollect $invocation $view $actions)))
            ("benchmark-stale" (benchmarkFaultStale $invocation $view $actions))
            ($_ (benchmarkRuleCollect $invocation $view $actions))))))

;; Example: an explicit empty conclusion still preserves native selection and callbacks.
(= (benchmarkFaultEmpty $invocation)
    (let* (($id (mrcValue $invocation 1)) ($adapter (mrcValue $invocation 2)))
        (quote (ReasonerIntakeResult (invocation-id $id) (adapter $adapter)
            (status NoConclusion) (proposals ()) (diagnostics ())))))

;; Example: later invocations reuse the previous publication's references, never mutate host ownership.
(= (benchmarkFaultStale $invocation $view $actions)
    (let* (
        ($refs (mrcValue $invocation 13))
        ($_ (if (== (get-state &benchmark-fault-evidence) ())
            (change-state! &benchmark-fault-evidence $refs) True))
        ($id (mrcValue $invocation 1))
        ($adapter (mrcValue $invocation 2))
        ($old (get-state &benchmark-fault-evidence)))
        (quote (ReasonerIntakeResult (invocation-id $id) (adapter $adapter) (status Proposals)
            (proposals ((ReasonerMotivationalProposal stale-advice rule-engine propose-candidate current-frame respond
                rule support 0.8 (EvidenceReferences $old) (ExpectedCandidateOutcome respond)))) (diagnostics ())))))

;; Example: supported feedback is observed once; duplicate delivery stays on the original ticket.
(= (benchmarkFaultNotify $stage $invocation $payload)
    (progn
        (benchmarkFaultService $stage $invocation $payload)
        (benchmarkFaultAudit $stage $invocation $payload)
        (if (== $stage Observation)
            (progn
                (if (== (mrcValue $invocation 2) "benchmark-duplicate")
                    (benchmarkFaultDuplicate $invocation $payload) True)
                (benchmarkFaultAssess $invocation)) True)))

;; Example: simulate a lost response only after normal native selection has retained its ticket.
(= (benchmarkFaultService $stage $invocation $payload)
    (if (tpContains ("benchmark-uncertain" "benchmark-duplicate") (mrcValue $invocation 2))
        (case $stage (
            (Decision (if (== (index-atom $payload 3) ()) True
                (if (== (mrcValue $invocation 2) "benchmark-uncertain")
                    (benchmarkFaultLoseResult) (benchmarkFaultCountResult))))
            (Observation (benchmarkFaultRestore))
            ($_ True))) True))

;; Example: duplicate outcome and dispatch delivery cannot allocate a replacement ticket or repeat effects.
(= (benchmarkFaultDuplicate $invocation $outcome)
    (let* (
        ($decision (index-atom $outcome 1))
        ($duplicate (ingestOperationOutcome $outcome))
        ($cached (coreLoopDispatchCommand (index-atom $decision 4) (index-atom $decision 3))))
        (progn
            (benchmarkFaultAudit Duplicate $invocation $duplicate)
            (benchmarkFaultAudit Redispatch $invocation $cached)
            True)))

;; Example: unsupported or uncertain predictions explicitly defer without reliability/native learning updates.
(= (benchmarkFaultAssess $invocation)
    (let* (($receipt (car-atom (hostReasonerReceipts))) ($primary (index-atom (index-atom $receipt 2) 4)))
        (let $result (case $primary (
            ((HostReasonerPrimary $envelope $_ $_)
                (assessHostReasonerProposalOutcomeRetained $envelope (index-atom $receipt 1)))
            ($_ (ReasonerAssessmentDeferred NoPrimary))))
            (progn (benchmarkFaultAudit Assessment $invocation $result) True))))

;; Example: snapshots inspect actual native stores without fabricating a grade or outcome.
(= (benchmarkFaultAudit $stage $invocation $payload)
    (let* (
        ($receipts (hostReasonerReceipts)) ($selections (hostReasonerSelections))
        ($assessments (hostReasonerAssessments)) ($learning (hostReasonerLearning))
        ($budgets (benchmarkInitialHost)))
        (py-call (fault_adapter.record $stage (quote $invocation) (quote $payload)
            (reasonerSourceReliability rule-engine) (quote $receipts) (quote $selections)
            (quote $assessments) (quote $learning) (get-state &budget-test-effects) (quote $budgets)))))

;; Example: each fixture identity uses the same public registration contract and scenario limits.
!(let* (($id (repr (argk "reasoner"))) ($limits (benchmarkIntakeLimits)))
    (registerHostReasoner
        (quote (ReasonerAdapterRegistration (adapter $id) (contract-version 1)
            (configuration-version "fault-config-1") (source rule-engine)
            (capabilities (ReasonerCapabilities (proposal-kinds (propose-candidate)) (candidates (respond))
                (prediction-schemas ("ExpectedCandidateOutcome")) (feedback (Decision Observation))))
            (limits $limits)))
        (quote benchmarkFaultLoad)))
