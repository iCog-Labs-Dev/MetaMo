;; Optional trusted host adapter. Load composition and reasoner_proposals first,
;; then Core/v1 dispatch. This module starts no provider, channel or execution.
;; Example: retainReasonerProposalSelection runs before the selected command;
;; observeReasonerProposalExecution captures its actual Core result afterward.
!(import_prolog_functions_from_file
    (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_host_evidence.pl)
    (retainReasonerProposalSelection observeReasonerProposalExecution
        validateReasonerExecutionEvidence resolveReasonerOutcomeIdentity
        readReasonerPredictionObservation))

;; Installation is host configuration, never a model skill or permission grant.
!(change-state! &reasoner-evidence-validator validateReasonerExecutionEvidence)
!(change-state! &reasoner-outcome-identity-provider resolveReasonerOutcomeIdentity)
!(change-state! &reasoner-prediction-observer readReasonerPredictionObservation)
