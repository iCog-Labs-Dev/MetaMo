;; Registered adapter double: emits a direct rule recommendation; no native inference or learning.
!(bind! &benchmark-rule-notifications (new-state ()))
(: ExpectedCandidateOutcomeType Type)
(: ExpectedCandidateOutcome (-> Symbol ExpectedCandidateOutcomeType))

;; Example: the trusted loader installs callbacks without executing an operation.
(= (benchmarkRuleLoad)
   (configureHostReasonerRuntime "benchmark-rule"
      (quote (HostReasonerRuntime "rule-fixture-1" benchmarkRuleCollect benchmarkRuleNotify () 0.8))))

;; Example: evidence references come from the coordinator's admitted invocation.
(= (benchmarkRuleCollect $invocation $view $actions)
   (let* (($id (mrcValue $invocation 1)) ($adapter (mrcValue $invocation 2))
          ($refs (mrcValue $invocation 13)))
      (quote (ReasonerIntakeResult (invocation-id $id) (adapter $adapter) (status Proposals)
         (proposals ((ReasonerMotivationalProposal recommendation rule-engine propose-candidate
            current-frame respond rule support 0.8 (EvidenceReferences $refs) (ExpectedCandidateOutcome respond))))
         (diagnostics ())))))

;; Example: retain actual supported notifications without pretending to train an engine.
(= (benchmarkRuleNotify $stage $invocation $payload)
   (progn (change-state! &benchmark-rule-notifications
      (cons-atom (quote ($stage $payload)) (get-state &benchmark-rule-notifications))) True))

!(let $limits (benchmarkIntakeLimits)
   (registerHostReasoner
      (quote (ReasonerAdapterRegistration (adapter "benchmark-rule") (contract-version 1)
         (configuration-version "rule-config-1") (source rule-engine)
         (capabilities (ReasonerCapabilities (proposal-kinds (propose-candidate)) (candidates (respond))
            (prediction-schemas ("ExpectedCandidateOutcome")) (feedback (Decision Observation))))
         (limits $limits)))
      (quote benchmarkRuleLoad)))
