;; Pure, optional host adapter contracts. Importing this file starts no engine,
;; allocates no state and installs no callbacks. Quote literal records as data.
!(import! &self (library MetaMo applications/omegaclaw_v1/factual_signals))
!(import! &self (library MetaMo applications/omegaclaw_v1/contexts/typed_policy))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_proposal_helpers))

;; Exact ordered tagged fields are checked by the validators, not these broad
;; constructor signatures. Example records and bounds are in the reasoner guide.
(: ReasonerAdapterRegistrationType Type)
(: ReasonerAdapterRegistration
    (-> Expression Expression Expression Expression Expression Expression
        ReasonerAdapterRegistrationType))

(: ReasonerCapabilitiesType Type)
(: ReasonerCapabilities
    (-> Expression Expression Expression Expression ReasonerCapabilitiesType))

(: ReasonerIntakeLimitsType Type)
(: ReasonerIntakeLimits
    (-> Expression Expression Expression Expression Expression Expression
        Expression Expression Expression ReasonerIntakeLimitsType))

(: ReasonerProviderCostLimitType Type)
(: ReasonerProviderCostLimit
    (-> Expression Expression ReasonerProviderCostLimitType))

(: ReasonerInvokedProposalType Type)
(: ReasonerInvokedProposal
    (-> Expression Expression Expression Expression ReasonerInvokedProposalType))

(: ReasonerInvocationType Type)
(: ReasonerInvocation
    (-> Expression Expression Expression Expression Expression Expression
        Expression Expression Expression Expression Expression Expression
        Expression Expression ReasonerInvocationType))

(: ReasonerPublicationRefType Type)
(: ReasonerPublicationRef (-> String ReasonerPublicationRefType))

(: ReasonerCommitmentRefType Type)
(: ReasonerCommitmentRef (-> String Number ReasonerCommitmentRefType))
(: NoCommitment ReasonerCommitmentRefType)

(: ReasonerIntakeResultType Type)
(: ReasonerIntakeResult
    (-> Expression Expression Expression Expression Expression ReasonerIntakeResultType))

(: ReasonerIntakeDiagnosticType Type)
(: ReasonerIntakeDiagnostic
    (-> Symbol String ReasonerIntakeDiagnosticType))

(: ReasonerContractValidationType Type)
(: ReasonerContractValid (-> Symbol Number ReasonerContractValidationType))
(: ReasonerContractRejected (-> Symbol ReasonerContractValidationType))

;; Internal schema descriptors are inert data, not executable operations.
(: ReasonerContractDomain Type)
(: ReasonerLimitDomain (-> Number ReasonerContractDomain))
(: ReasonerPositiveDomain (-> Number ReasonerContractDomain))
(: ReasonerRecordDomain (-> Symbol ReasonerContractDomain))
(: ReasonerSetDomain (-> Expression Number ReasonerContractDomain))
(: ReasonerListDomain (-> Expression Number ReasonerContractDomain))

;; Return exact ordered fields; unknown schema names have no valid fields.
;; Example: (mrcFields ReasonerProviderCostLimit) -> ((unit text) (amount amount)).
(= (mrcFields $tag)
    (case $tag (
        (ReasonerInvokedProposal (quote (
            (registration (ReasonerRecordDomain ReasonerAdapterRegistration))
            (invocation (ReasonerRecordDomain ReasonerInvocation))
            (engine-version text) (proposal proposal))))
        (ReasonerAdapterRegistration (quote (
            (adapter text) (contract-version version) (configuration-version text)
            (source source) (capabilities (ReasonerRecordDomain ReasonerCapabilities))
            (limits (ReasonerRecordDomain ReasonerIntakeLimits)))))
        (ReasonerCapabilities (quote (
            (proposal-kinds (ReasonerSetDomain kind 4)) (candidates (ReasonerSetDomain candidate 14))
            (prediction-schemas (ReasonerSetDomain text 32)) (feedback (ReasonerSetDomain feedback 3)))))
        (ReasonerIntakeLimits (quote (
            (max-facts (ReasonerLimitDomain 4096)) (max-payload-nodes (ReasonerPositiveDomain 65536))
            (max-proposals (ReasonerLimitDomain 128)) (max-session-records (ReasonerPositiveDomain 4096))
            (max-engine-steps (ReasonerLimitDomain 1000000)) (max-engine-queue (ReasonerLimitDomain 65536))
            (max-provider-calls (ReasonerLimitDomain 128)) (provider-cost (ReasonerRecordDomain ReasonerProviderCostLimit))
            (timeout-ms (ReasonerPositiveDomain 3600000)))))
        (ReasonerProviderCostLimit (quote ((unit text) (amount amount))))
        (ReasonerInvocation (quote (
            (invocation-id text) (adapter text) (contract-version version)
            (configuration-version text) (session text) (cycle natural) (frame frame)
            (publication publication) (commitment commitment) (phase phase)
            (capabilities (ReasonerRecordDomain ReasonerCapabilities)) (limits (ReasonerRecordDomain ReasonerIntakeLimits))
            (evidence (ReasonerSetDomain reference 128)) (deadline-ms natural))))
        (ReasonerIntakeResult (quote (
            (invocation-id text) (adapter text) (status intake-status)
            (proposals (ReasonerListDomain proposal 128)) (diagnostics (ReasonerListDomain diagnostic 16)))))
        ($_ ())
    ))
)

;; Fixed protocol vocabulary; prediction schema names stay adapter-specific.
;; Example: (mrcEnum phase) -> (ModeIntake CandidateIntake).
(= (mrcEnum $kind)
    (case $kind (
        (source (nars pln llm rule-engine human-adapter))
        (kind (propose-candidate request-frame-switch request-mode-change request-attention))
        (candidate (respond retrieve-memory search-knowledge execute-skill learn
            self-improve background-work recall-goals invent-goal plan-goal
            repair-failure defer verify-frame-state ask-clarification))
        (feedback (Decision Observation Assessment))
        (phase (ModeIntake CandidateIntake))
        (intake-status (Proposals NoConclusion Unavailable Timeout InvalidOutput))
        (diagnostic-code (NoSupportedConclusion AdapterUnavailable DeadlineExceeded
            MalformedOutput LimitExceeded AdapterError))
        ($_ ())
    ))
)

;; Preserve integer representation, rejecting numeric strings and float counts.
;; Example: (mrcIntegerIn 1.0 0 10) -> False.
(= (mrcIntegerIn $value $lower $upper)
    (if (fsNumberIn $value $lower $upper)
        (!= (collapse (translatePredicate (integer $value))) ())
        False
    )
)

;; Require bounded nonblank strings without controls, using existing text helpers.
;; Example: (mrcText "adapter-A") -> True.
(= (mrcText $value)
    (if (== (get-type $value) String)
        (reasonerProposalTextValid $value 256)
        False
    )
)

;; Match every field name, position and value without accepting extras.
;; Example: (mrcValues (quote ((unit text))) (quote ((unit "USD")))) -> True.
(= (mrcValues $spec $fields)
    (case ((get-metatype $spec) (get-metatype $fields) (== $spec ()) (== $fields ())) (
        ((Expression Expression True True) True)
        ((Expression Expression False False)
            (let* (
                (($expected $specTail) (decons-atom $spec))
                (($actual $fieldTail) (decons-atom $fields))
            )
                (if (eval (mrcFieldValid (quote $expected) (quote $actual)))
                    (mrcValues $specTail $fieldTail)
                    False
                )
            ))
        ($_ False)
    ))
)

;; Match the exact field pair before inspecting its typed inert value.
;; Example: (mrcFieldValid (quote (unit text)) (quote (unit "USD"))) -> True.
(= (mrcFieldValid $spec $field)
    (case ($spec $field) (
        ((($key $type) ($actual $value))
            (if (== $key $actual)
                (== (eval (mrcType (quote $type) (quote $value))) True)
                False
            ))
        ($_ False)
    ))
)

;; Validate a known exact record; supplied contents remain inert.
;; Example: (mrcRecord ReasonerProviderCostLimit (quote (ReasonerProviderCostLimit (unit "USD") (amount 0)))) -> True.
(= (mrcRecord $tag $value)
    (if (== (get-metatype $value) Expression)
        (if (== $value ()) False
            (let ($actual $fields) (decons-atom $value)
                (if (and (== $tag $actual) (!= (mrcFields $tag) ()))
                    (mrcValues (mrcFields $tag) $fields)
                    False
                )
            )
        )
        False
    )
)

;; Check each list member once with capacity and optional uniqueness guards.
;; Example: (mrcItems feedback (Decision Decision) 3 True ()) -> False.
(= (mrcItems $type $items $remaining $unique $seen)
    (case ((get-metatype $items) (== $items ())) (
        ((Expression True) True)
        ((Expression False)
            (if (<= $remaining 0) False
                (let ($head $tail) (decons-atom $items)
                    (if (and $unique (tpContains $seen $head)) False
                        (if (== (eval (mrcType (quote $type) (quote $head))) True)
                            (mrcItems $type $tail (- $remaining 1) $unique (cons-atom $head $seen))
                            False
                        )
                    )
                )
            ))
        ($_ False)
    ))
)

;; Local references carry identity only; they do not resolve host observations.
;; Example: (mrcReference (quote (SessionObservationRef "session-1" 0))) -> True.
(= (mrcReference $value)
    (case $value (
        ((ObservationRef $host $id) (and (mrcText $host) (mrcText $id)))
        ((SessionObservationRef $session $sequence)
            (and (mrcText $session) (mrcIntegerIn $sequence 0 9007199254740991)))
        ($_ False)
    ))
)

;; Diagnostics use a closed code vocabulary and bounded inert text.
;; Example: (mrcDiagnostic (quote (ReasonerIntakeDiagnostic AdapterError "failed"))) -> True.
(= (mrcDiagnostic $value)
    (case $value (
        ((ReasonerIntakeDiagnostic $code $message)
            (if (== (get-type $message) String)
                (and (tpContains (mrcEnum diagnostic-code) $code) (<= (string_length $message) 1200))
                False
            ))
        ($_ False)
    ))
)

;; Reuse the full proposal value contract before accepting transport contents.
;; Example: (mrcProposal (quote (ReasonerMotivationalProposal broken))) -> False.
(= (mrcProposal $value)
    (if (reasonerProposalValid $value)
        (>= (reasonerProposalDataRemaining (quote $value) 16 1024) 0)
        False
    )
)

;; Dispatch schema domains through pure existing numeric, text and data readers.
;; Example: (mrcType (quote (ReasonerLimitDomain 128)) "1") -> False.
(= (mrcType $type $value)
    (case $type (
        (text (mrcText $value))
        (version (and (mrcIntegerIn $value 1 1) (== $value 1)))
        (natural (mrcIntegerIn $value 0 9007199254740991))
        (amount (fsNumberIn $value 0 9007199254740991))
        (frame (reasonerProposalIdValid $value))
        ((ReasonerLimitDomain $max) (mrcIntegerIn $value 0 $max))
        ((ReasonerPositiveDomain $max) (mrcIntegerIn $value 1 $max))
        ((ReasonerRecordDomain $tag) (mrcRecord $tag $value))
        ((ReasonerListDomain $itemType $max) (mrcItems $itemType $value $max False ()))
        ((ReasonerSetDomain $itemType $max) (mrcItems $itemType $value $max True ()))
        (publication (case $value (
            ((ReasonerPublicationRef $id) (mrcText $id)) ($_ False))))
        (commitment (case $value (
            (NoCommitment True)
            ((ReasonerCommitmentRef $id $revision)
                (and (mrcText $id) (mrcIntegerIn $revision 0 9007199254740991)))
            ($_ False))))
        (reference (mrcReference $value))
        (diagnostic (mrcDiagnostic $value))
        (proposal (mrcProposal $value))
        ($_ (tpContains (mrcEnum $type) $value))
    ))
)

;; Session references must agree with their enclosing invocation session.
;; Example: (mrcEvidenceSession "s" (quote ((SessionObservationRef "other" 0)))) -> False.
(= (mrcEvidenceSession $session $refs)
    (== (filter-atom $refs $ref
        (case $ref (
            ((SessionObservationRef $actual $_) (!= $actual $session))
            ($_ False)
        ))) ())
)

;; Only after exact shape validation, inspect invocation/result consistency.
;; Example: a reserved LLM adapter identity requires source llm.
(= (mrcInvariants $tag $value)
    (case $tag (
        (ReasonerInvokedProposal (mrcInvokedProposalConsistent $value))
        (ReasonerAdapterRegistration
            (if (== (mrcValue $value 1) "llm-motivational-proposal")
                (== (mrcValue $value 4) llm) True))
        (ReasonerInvocation
            (mrcEvidenceSession (index-atom (index-atom $value 5) 1)
                (index-atom (index-atom $value 13) 1)))
        (ReasonerIntakeResult
            (let* (
                ($status (index-atom (index-atom $value 3) 1))
                ($proposals (index-atom (index-atom $value 4) 1))
            )
                (if (== $status Proposals) (!= $proposals ()) (== $proposals ()))
            ))
        ($_ False)
    ))
)

;; Ground and shape guards run before semantic readers; never bind missing input.
;; Example: (mrcValidate ReasonerInvocation InvalidInvocation ()) -> rejection.
(= (mrcValidate $tag $reason $value)
    (if (is-ground $value)
        (if (mrcRecord $tag $value)
            (if (mrcInvariants $tag $value)
                (ReasonerContractValid $tag 1)
                (ReasonerContractRejected $reason)
            )
            (ReasonerContractRejected $reason)
        )
        (ReasonerContractRejected $reason)
    )
)

;; Validate representation only, without installing or loading an adapter.
;; Example: (validateReasonerAdapterRegistration ()) -> (ReasonerContractRejected InvalidRegistration).
(= (validateReasonerAdapterRegistration $value)
    (mrcValidate ReasonerAdapterRegistration InvalidRegistration $value)
)

;; Validate invocation shape, integer limits and local evidence-session agreement.
;; Example: (validateReasonerInvocation ()) -> (ReasonerContractRejected InvalidInvocation).
(= (validateReasonerInvocation $value)
    (mrcValidate ReasonerInvocation InvalidInvocation $value)
)

;; Keep empty/error statuses distinct; do not interpret missing output as failure.
;; Example: (validateReasonerIntakeResult ()) -> (ReasonerContractRejected InvalidIntakeResult).
(= (validateReasonerIntakeResult $value)
    (mrcValidate ReasonerIntakeResult InvalidIntakeResult $value)
)

;; Read a field only after its enclosing ordered record has been validated.
;; Example: (mrcValue (quote (Record (id "a"))) 1) -> "a".
(= (mrcValue $record $index)
    (index-atom (index-atom $record $index) 1)
)

;; Keep source/configuration and correlation metadata outside the original proposal.
;; This checks consistency, not host ownership, freshness or evidence authority.
;; Example: a wrapper with a different adapter in its invocation is rejected.
(= (mrcInvokedProposalConsistent $value)
    (let*
        (
            ($registration (mrcValue $value 1))
            ($invocation (mrcValue $value 2))
            ($proposal (mrcValue $value 4))
        )
        (tpAllTrue (
            (mrcInvariants ReasonerAdapterRegistration $registration)
            (mrcInvariants ReasonerInvocation $invocation)
            (== (mrcValue $registration 1) (mrcValue $invocation 2))
            (== (mrcValue $registration 2) (mrcValue $invocation 3))
            (== (mrcValue $registration 3) (mrcValue $invocation 4))
            (== (mrcValue $registration 4) (getProposalSource $proposal))
            (== (mrcValue $registration 5) (mrcValue $invocation 11))
            (== (mrcValue $registration 6) (mrcValue $invocation 12))
        ))
    )
)

;; Validate an inert proposal and its adjacent invocation provenance without audit writes.
;; Example: (validateReasonerInvokedProposal ()) -> InvalidInvokedProposal rejection.
(= (validateReasonerInvokedProposal $value)
    (mrcValidate ReasonerInvokedProposal InvalidInvokedProposal $value)
)

;; Build only validated envelopes, preserving the proposal and invocation exactly.
;; Example: invalid proposal data returns a typed rejection rather than an envelope.
(= (bindReasonerProposalInvocation $registration $invocation $engineVersion $proposal)
    (let $record (quote (ReasonerInvokedProposal
        (registration $registration) (invocation $invocation)
        (engine-version $engineVersion) (proposal $proposal)))
        (case (validateReasonerInvokedProposal $record) (
            ((ReasonerContractValid ReasonerInvokedProposal 1) (quote $record))
            ($rejection $rejection)
        ))
    )
)
