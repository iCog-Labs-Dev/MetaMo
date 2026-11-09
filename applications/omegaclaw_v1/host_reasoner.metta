;; Optional trusted startup. Validate before any adapter loading is added here.
!(import! &self (library MetaMo applications/omegaclaw_v1/host_reasoner_contracts))
!(bind! &host-reasoner-registration (new-state ()))

;; Retain the validated registration, including its configuration version.
;; Example: (prepareHostReasoner (quote (ReasonerAdapterRegistration broken))) -> rejection.
(= (prepareHostReasoner $registration)
    (let $validation (validateReasonerAdapterRegistration $registration)
        (case $validation (
            ((ReasonerContractValid ReasonerAdapterRegistration 1)
                (progn
                    (change-state! &host-reasoner-registration (quote $registration))
                    $validation))
            ($_ $validation)
        ))
    )
)

;; Read startup provenance; () means no adapter has been configured.
;; Example: (hostReasonerRegistration) -> () before successful preparation.
(= (hostReasonerRegistration)
    (get-state &host-reasoner-registration)
)
