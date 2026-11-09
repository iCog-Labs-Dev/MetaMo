;; Optional trusted registration and startup selection; not model skills.
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

(: HostReasonerAdapterType Type)
(: HostReasonerAdapter (-> Expression Symbol HostReasonerAdapterType))
(: ReasonerStartupResultType Type)
(: ReasonerStartupRejected (-> Symbol ReasonerStartupResultType))
!(bind! &host-reasoner-adapters (new-state ()))
!(bind! &host-reasoner-selected (new-state disabled))

;; Register only from trusted host code; loader names never come from proposals.
;; Example: (registerHostReasoner registration (quote loadMyReasoner)) -> True.
(= (registerHostReasoner $registration $loader)
    (case (validateReasonerAdapterRegistration $registration) (
        ((ReasonerContractValid ReasonerAdapterRegistration 1)
            (if (!= (collapse (translatePredicate (atom $loader))) ())
                (let* (
                    ($id (index-atom (index-atom $registration 1) 1))
                    ($existing (eval (registeredHostReasoner $id)))
                    ($entry (quote (HostReasonerAdapter $registration $loader)))
                )
                    (case $existing (
                        (() (if (< (size-atom (get-state &host-reasoner-adapters)) 128)
                            (progn
                                (change-state! &host-reasoner-adapters
                                    (cons-atom $entry (get-state &host-reasoner-adapters)))
                                True)
                            (ReasonerStartupRejected RegistrationLimit)))
                        ($_ (if (== $existing $entry) True
                            (ReasonerStartupRejected ConflictingRegistration)))
                    ))
                )
                (ReasonerStartupRejected InvalidLoader)
            ))
        ($rejection $rejection)
    ))
)

;; Exact string identity selects one registered adapter without loading it.
;; Example: (registeredHostReasoner "unknown") -> ().
(= (registeredHostReasoner $id)
    (let $matches (filter-atom (get-state &host-reasoner-adapters) $entry
        (let (HostReasonerAdapter $registration $_loader) $entry
            (== (index-atom (index-atom $registration 1) 1) $id)))
        (if (== $matches ()) () (car-atom $matches))
    )
)

;; Retain provenance only after a loader reports success.
;; Example: (retainHostReasonerSelection "adapter" registration) -> True for valid data.
(= (retainHostReasonerSelection $id $registration)
    (case (prepareHostReasoner $registration) (
        ((ReasonerContractValid ReasonerAdapterRegistration 1)
            (progn (change-state! &host-reasoner-selected $id) True))
        ($rejection $rejection)
    ))
)

;; Invoke only the loader bound by trusted registration.
;; Example: (loadRegisteredHostReasoner "unknown") -> UnknownAdapter rejection.
(= (loadRegisteredHostReasoner $id)
    (case (registeredHostReasoner $id) (
        ((HostReasonerAdapter $registration $loader)
            (case (catch (eval ($loader))) (
                (True (retainHostReasonerSelection $id $registration))
                ($_ (ReasonerStartupRejected AdapterLoadFailed))
            )))
        ($_ (ReasonerStartupRejected UnknownAdapter))
    ))
)

;; A running selection is immutable; repeated selection does not reload engines.
;; Example: (selectHostReasoner disabled) -> True before an adapter is selected.
(= (selectHostReasoner $id)
    (let $selected (get-state &host-reasoner-selected)
        (case ($selected (== $selected $id) (== $id disabled)) (
            ((disabled $_ True) True)
            ((disabled $_ False) (loadRegisteredHostReasoner $id))
            (($_ True $_) True)
            ($_ (ReasonerStartupRejected AlreadySelected))
        ))
    )
)

;; Prepared configuration alone is not a loaded adapter.
;; Example: (hostReasonerSelection) -> disabled before successful selection.
(= (hostReasonerSelection)
    (get-state &host-reasoner-selected)
)

;; Existing optional extension owns engine loading; no provider calls are added.
;; Example: (loadHostReasonerInference) -> True after local engines load.
(= (loadHostReasonerInference)
    (progn
        (import! &self (library MetaMo applications/omegaclaw_v1/reasoner_integration))
        True
    )
)

;; Local adapters currently propose candidates; no feedback implementation is claimed.
;; Example: (builtinHostReasoner nars) -> a registration with empty feedback.
(= (builtinHostReasoner $source)
    (let*
        (
            ($id (repr $source))
            ($capabilities
                (quote (ReasonerCapabilities
                    (proposal-kinds (propose-candidate))
                    (candidates (respond retrieve-memory search-knowledge execute-skill learn
                        self-improve background-work recall-goals invent-goal plan-goal
                        repair-failure defer verify-frame-state ask-clarification))
                    (prediction-schemas ("ExpectedOperationResult"))
                    (feedback ()))))
            ($providerCost
                (quote (ReasonerProviderCostLimit (unit "calls") (amount 0))))
            ($limits
                (quote (ReasonerIntakeLimits
                    (max-facts 128)
                    (max-payload-nodes 4096)
                    (max-proposals 16)
                    (max-session-records 128)
                    (max-engine-steps 8)
                    (max-engine-queue 40)
                    (max-provider-calls 0)
                    (provider-cost $providerCost)
                    (timeout-ms 1000))))
        )
        (quote (ReasonerAdapterRegistration
            (adapter $id)
            (contract-version 1)
            (configuration-version "builtin-1")
            (source $source)
            (capabilities $capabilities)
            (limits $limits)))
    )
)

;; Built-ins use fixed trusted loaders; additional adapters register before startup.
;; Example: (startHostReasoner nars) -> register and select the NARS adapter.
(= (startHostReasoner $name)
    (if (tpContains (nars pln) $name)
        (case (registerHostReasoner (builtinHostReasoner $name) (quote loadHostReasonerInference)) (
            (True (selectHostReasoner (repr $name)))
            ($rejection $rejection)
        ))
        (selectHostReasoner (repr $name))
    )
)
