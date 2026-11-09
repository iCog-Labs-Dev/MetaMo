;; Inert fixture definitions; importing them performs no setup or assertions.
;; Example: (reasonerContractFixture capabilities) -> a capability declaration.
(= (reasonerContractFixture $kind)
    (case $kind (
        (capabilities (quote (ReasonerCapabilities
            (proposal-kinds (propose-candidate)) (candidates (respond))
            (prediction-schemas ("ExpectedOperationResult"))
            (feedback (Decision Observation Assessment)))))
        (limits (quote (ReasonerIntakeLimits
            (max-facts 128) (max-payload-nodes 4096) (max-proposals 16)
            (max-session-records 128) (max-engine-steps 100) (max-engine-queue 40)
            (max-provider-calls 0)
            (provider-cost (ReasonerProviderCostLimit (unit "USD") (amount 0)))
            (timeout-ms 1000))))
        (registration (let* (
            ($caps (reasonerContractFixture capabilities))
            ($limits (reasonerContractFixture limits))
        )
            (quote (ReasonerAdapterRegistration
                (adapter "nars-local") (contract-version 1) (configuration-version "config-1")
                (source nars) (capabilities $caps) (limits $limits)))))
        (invocation (let* (
            ($caps (reasonerContractFixture capabilities))
            ($limits (reasonerContractFixture limits))
        )
            (quote (ReasonerInvocation
                (invocation-id "invocation-1") (adapter "nars-local") (contract-version 1)
                (configuration-version "config-1") (session "session-1") (cycle 0)
                (frame Frame-A) (publication (ReasonerPublicationRef "publication-1"))
                (commitment (ReasonerCommitmentRef "commitment-1" 0)) (phase CandidateIntake)
                (capabilities $caps) (limits $limits)
                (evidence ((SessionObservationRef "session-1" 0))) (deadline-ms 1000)))))
        (proposal (quote (ReasonerMotivationalProposal p1 nars propose-candidate current-frame
            respond claim support 0.9 (EvidenceReferences ((SessionObservationRef "session-1" 0)))
            (ExpectedOperationResult "answer"))))
        (result (let $proposal (reasonerContractFixture proposal)
            (quote (ReasonerIntakeResult (invocation-id "invocation-1") (adapter "nars-local")
                (status Proposals) (proposals ($proposal)) (diagnostics ())))))
        ($_ ())
    ))
)

;; Replace a fixture's known nested field without evaluating its contents.
;; Example: (reasonerContractSet (quote (frame)) "Frame-A" (reasonerContractFixture invocation)).
(= (reasonerContractSet $path $value $record)
    (let* (
        (($key $rest) (decons-atom $path))
        (($tag $fields) (decons-atom $record))
        ($next (map-atom $fields $field
            (let ($actual $old) $field
                (if (== $actual $key)
                    (let $replacement (if (== $rest ()) $value
                        (reasonerContractSet $rest (quote $value) (quote $old)))
                        (quote ($key $replacement)))
                    (quote $field)
                ))))
    )
        (cons-atom $tag $next)
    )
)

;; Produce a distinct empty intake status using the same result shape.
;; Example: (reasonerContractEmpty Timeout) -> an empty Timeout result.
(= (reasonerContractEmpty $status)
    (reasonerContractSet (quote (proposals)) ()
        (reasonerContractSet (quote (status)) $status (reasonerContractFixture result)))
)
