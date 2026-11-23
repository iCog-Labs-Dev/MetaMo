;; Test-only adaptation probe. Fixed edits verify retention, not predictive learning quality.
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_proposals))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_parameter_updates))
!(import! &self rule_adapter)
!(import! &self learning_probe.py)
!(bind! &benchmark-learning-value (new-state 0))

;; Example: normal registered loading installs the probe's own collect/feedback callbacks.
(= (benchmarkLearningLoad)
    (configureHostReasonerRuntime "benchmark-learning-probe"
        (quote (HostReasonerRuntime "learning-probe-1" benchmarkLearningCollect benchmarkLearningNotify () 0.8))))

;; Example: observe real runtime state, then reuse the rule adapter's valid proposals.
(= (benchmarkLearningCollect $invocation $view $actions)
    (progn
        (benchmarkLearningObserve)
        (benchmarkRuleCollect $invocation $view $actions)))

;; Example: inspect reliability, a writable parameter, pending audit and budgets at intake.
(= (benchmarkLearningObserve)
    (let* (
        ($parameters (hostReasonerParameterRows (AppraisalWeight stalled-progress importance BooleanIndicator)))
        ($pending (hostReasonerCycles))
        ($host (benchmarkInitialHost))
        ($context (get-state &operation-context)))
        (py-call (learning_probe.observe (get-state &benchmark-learning-value)
            (reasonerSourceReliability rule-engine) (quote $parameters) (quote $pending) (quote $host) (quote $context)))))

;; Example: only an enabled learning stage applies the synthetic adaptation on observed feedback.
(= (benchmarkLearningNotify $stage $invocation $payload)
    (progn
        (benchmarkRuleNotify $stage $invocation $payload)
        (if (and (== $stage Observation)
                 (hostReasonerStageEnabledFor "benchmark-learning-probe" learning))
            (benchmarkLearningAdapt) True)))

;; Example: an adapter-local value and its private memory survive an episode boundary.
(= (benchmarkLearningAdapt)
    (progn
        (change-state! &benchmark-learning-value (+ (get-state &benchmark-learning-value) 1))
        (benchmarkLearningWeights)
        (py-call (learning_probe.retain (get-state &benchmark-learning-value)))
        True))

;; Example: trusted probe edits test isolation of actual stores, without claiming graded updates.
(= (benchmarkLearningWeights)
    (progn
        (map-atom (collapse (match &reasoner-source-reliability (ReasonerSourceReliability rule-engine $v)
            (ReasonerSourceReliability rule-engine $v))) $row
            (remove-atom &reasoner-source-reliability $row))
        (add-atom &reasoner-source-reliability (ReasonerSourceReliability rule-engine 0.42))
        (map-atom (hostReasonerParameterRows (AppraisalWeight stalled-progress importance BooleanIndicator)) $row
            (remove-atom &self $row))
        (add-atom &self (SignalAppraisalRule stalled-progress importance BooleanIndicator 0.2))))

;; Example: this probe uses normal registration and scenario-native limits.
!(let $limits (benchmarkIntakeLimits)
    (registerHostReasoner
        (quote (ReasonerAdapterRegistration (adapter "benchmark-learning-probe") (contract-version 1)
            (configuration-version "learning-probe-config-1") (source rule-engine)
            (capabilities (ReasonerCapabilities (proposal-kinds (propose-candidate)) (candidates (respond))
                (prediction-schemas ("ExpectedCandidateOutcome")) (feedback (Decision Observation))))
            (limits $limits)))
        (quote benchmarkLearningLoad)))
