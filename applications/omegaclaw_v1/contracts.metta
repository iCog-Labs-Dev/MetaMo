;; Explicit v1 wire boundary. Callers supply IDs and committed host metadata;
;; this module never invents revisions or upgrades legacy v0 records implicitly.
;; The composition/context facade owns this import once.
!(import_prolog_functions_from_file
   (library MetaMo applications/omegaclaw_v1/contracts.pl)
   (integrationValidateRecord integrationMakeRecord integrationConsumeRecord
    integrationRecordReference integrationStartupPolicy integrationStartupAttention
    integrationPolicyRecord integrationAttentionFromPolicy))

;; The six publication entry points share the same strict envelope constructor.
(= (publishFrameStateBundle $id $host $context $payload)
   (integrationMakeRecord FrameStateBundle $id $host $context $payload))
(= (publishMetaMoPolicyOutput $id $producer $context $payload)
   (integrationMakeRecord MetaMoPolicyOutput $id $producer $context $payload))
(= (publishAttentionDirective $id $producer $context $payload)
   (integrationMakeRecord AttentionDirective $id $producer $context $payload))
(= (publishReasonerProposal $id $producer $context $payload)
   (integrationMakeRecord ReasonerMotivationalProposal $id $producer $context $payload))
(= (publishExecutionOutcome $id $producer $context $payload)
   (integrationMakeRecord ExecutionOutcome $id $producer $context $payload))
(= (publishFrameVerificationEvidence $id $producer $context $payload)
   (integrationMakeRecord FrameVerificationEvidence $id $producer $context $payload))

;; Legacy local constructors remain explicitly v0 until the host supplies v1
;; metadata. Startup/reset/runtime use identical field lists within that path.
(= (legacyStartupPolicyOutput $mode)
   (MetaMoPolicyOutput (mode $mode) (operation-class none)
      (feasibility Rejected) (priority 0)))
(= (legacyStartupAttentionDirective)
   (AttentionDirective (target ()) (slice None) (task none)
      (admission Rejected) (reason NotInitialized) (priority 0) (source MetaMo)))
