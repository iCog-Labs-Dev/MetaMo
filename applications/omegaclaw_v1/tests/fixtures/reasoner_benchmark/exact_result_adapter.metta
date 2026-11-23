;; Test-only exact-result predictions. No claim of real engine inference or learning.
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_proposals))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_outcome_assessment))

;; Example: select the fixture through normal registered loading.
(= (benchmarkExactLoad)
    (configureHostReasonerRuntime "benchmark-exact"
        (quote (HostReasonerRuntime "exact-fixture-1" benchmarkExactCollect noHostReasonerFeedback () 0.8))))

;; Example: the selected prediction and unobserved alternative must receive different coverage.
(= (benchmarkExactCollect $invocation $view $actions)
    (let* (($id (mrcValue $invocation 1)) ($refs (mrcValue $invocation 13)))
        (quote (ReasonerIntakeResult (invocation-id $id) (adapter "benchmark-exact") (status Proposals)
            (proposals (
                (ReasonerMotivationalProposal recommendation rule-engine propose-candidate current-frame respond
                    rule support 0.8 (EvidenceReferences $refs) (ExpectedOperationResult "observed local file content"))
                (ReasonerMotivationalProposal alternative rule-engine propose-candidate current-frame search-knowledge
                    rule support 0.8 (EvidenceReferences $refs) (ExpectedOperationResult "unobserved alternative"))))
            (diagnostics ())))))

;; Example: declare the exact schema and candidates without enabling assessment or learning.
!(let $limits (benchmarkIntakeLimits)
    (registerHostReasoner
        (quote (ReasonerAdapterRegistration (adapter "benchmark-exact") (contract-version 1)
            (configuration-version "exact-config-1") (source rule-engine)
            (capabilities (ReasonerCapabilities (proposal-kinds (propose-candidate)) (candidates (respond search-knowledge))
                (prediction-schemas ("ExpectedOperationResult")) (feedback ())))
            (limits $limits)))
        (quote benchmarkExactLoad)))
