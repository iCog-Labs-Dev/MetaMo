;; Standalone contract import must not require composition, engines or services.
!(import! &self (library lib_import))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_contracts))
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_contracts))

!(test (validateReasonerAdapterRegistration (reasonerContractFixture registration))
    (ReasonerContractValid ReasonerAdapterRegistration 1))

!(test (validateReasonerInvocation (reasonerContractFixture invocation))
    (ReasonerContractValid ReasonerInvocation 1))

!(test (validateReasonerIntakeResult (reasonerContractFixture result))
    (ReasonerContractValid ReasonerIntakeResult 1))

!(test (validateReasonerIntakeResult (reasonerContractEmpty NoConclusion))
    (ReasonerContractValid ReasonerIntakeResult 1))

!(test (validateReasonerIntakeResult (reasonerContractEmpty Unavailable))
    (ReasonerContractValid ReasonerIntakeResult 1))

!(test (validateReasonerIntakeResult (reasonerContractEmpty Timeout))
    (ReasonerContractValid ReasonerIntakeResult 1))

!(test (validateReasonerIntakeResult (reasonerContractEmpty InvalidOutput))
    (ReasonerContractValid ReasonerIntakeResult 1))

!(test (validateReasonerAdapterRegistration
    (quote (ReasonerAdapterRegistration broken)))
    (ReasonerContractRejected InvalidRegistration))

!(test (validateReasonerInvocation
    (reasonerContractSet (quote (frame)) "Frame-A" (reasonerContractFixture invocation)))
    (ReasonerContractValid ReasonerInvocation 1))

!(test (validateReasonerInvocation
    (reasonerContractSet (quote (frame)) True (reasonerContractFixture invocation)))
    (ReasonerContractRejected InvalidInvocation))

!(test (validateReasonerAdapterRegistration
    (reasonerContractSet (quote (limits max-provider-calls)) "0"
        (reasonerContractFixture registration)))
    (ReasonerContractRejected InvalidRegistration))

!(test (validateReasonerAdapterRegistration
    (reasonerContractSet (quote (capabilities feedback)) (quote (Decision Decision))
        (reasonerContractFixture registration)))
    (ReasonerContractRejected InvalidRegistration))

!(test (validateReasonerInvocation
    (reasonerContractSet (quote (evidence))
        (quote ((SessionObservationRef "other-session" 0)))
        (reasonerContractFixture invocation)))
    (ReasonerContractRejected InvalidInvocation))

!(test (validateReasonerIntakeResult
    (quote (ReasonerIntakeResult (invocation-id "i") (adapter "a")
        (status Timeout) (proposals ())
        (diagnostics ((ReasonerIntakeDiagnostic DeadlineExceeded "deadline exceeded"))))))
    (ReasonerContractValid ReasonerIntakeResult 1))

!(test (validateReasonerIntakeResult
    (reasonerContractSet (quote (status)) Timeout (reasonerContractFixture result)))
    (ReasonerContractRejected InvalidIntakeResult))

!(test (validateReasonerIntakeResult
    (quote (ReasonerIntakeResult (invocation-id "i") (adapter "a")
        (status NoConclusion) (proposals ()) (diagnostics ()) (extra (send "bad")))))
    (ReasonerContractRejected InvalidIntakeResult))

;; Expression contents remain inert even in a shape-valid proposal payload.
!(bind! &contract-test-sentinel (new-state preserved))
!(test (validateReasonerIntakeResult
    (quote (ReasonerIntakeResult (invocation-id "i") (adapter "a")
        (status Proposals)
        (proposals ((ReasonerMotivationalProposal p nars propose-candidate
            current-frame respond (change-state! &contract-test-sentinel changed)
            support 0.9 (EvidenceReferences (e1)) (ExpectedOperationResult "answer"))))
        (diagnostics ()))))
    (ReasonerContractValid ReasonerIntakeResult 1))

!(test (get-state &contract-test-sentinel) preserved)

;; Dispatch a fixture kind to its public representation validator.
;; Example: (contractValidate registration ()) -> InvalidRegistration rejection.
(= (contractValidate $kind $record)
    (case $kind (
        (registration (validateReasonerAdapterRegistration $record))
        (invocation (validateReasonerInvocation $record))
        (result (validateReasonerIntakeResult $record))
    ))
)

;; Expected failures remain typed and specific to the public entry point.
;; Example: (contractRejection invocation) -> (ReasonerContractRejected InvalidInvocation).
(= (contractRejection $kind)
    (case $kind (
        (registration (ReasonerContractRejected InvalidRegistration))
        (invocation (ReasonerContractRejected InvalidInvocation))
        (result (ReasonerContractRejected InvalidIntakeResult))
    ))
)

;; Every supplied adversarial value must reject when inserted into a valid fixture.
;; Example: (contractRejectsFields registration (quote (adapter)) (quote ("" " "))) -> True.
(= (contractRejectsFields $kind $path $values)
    (== (filter-atom $values $value
        (!= (contractValidate $kind
                (reasonerContractSet $path (quote $value) (reasonerContractFixture $kind)))
            (contractRejection $kind))) ())
)

;; Reject malformed top-level records without evaluating supplied data.
;; Example: (contractRejectsRecords invocation (quote (() unknown))) -> True.
(= (contractRejectsRecords $kind $records)
    (== (filter-atom $records $value
        (!= (contractValidate $kind (quote $value)) (contractRejection $kind))) ())
)

;; Mutate constructor, field order, arity and duplicates for each public record.
;; Example: (contractRejectsShapes registration) -> True.
(= (contractRejectsShapes $kind)
    (let* (
        (($tag $fields) (decons-atom (reasonerContractFixture $kind)))
        (($first $tail) (decons-atom $fields))
        (($second $rest) (decons-atom $tail))
        ($swapped (cons-atom $tag (cons-atom $second (cons-atom $first $rest))))
        ($missing (cons-atom $tag $tail))
        ($duplicate (cons-atom $tag (cons-atom $first $fields)))
        ($extra (cons-atom $tag (cons-atom (quote (extra 1)) $fields)))
        ($wrong (cons-atom WrongTag $fields))
    )
        (contractRejectsRecords $kind ($swapped $missing $duplicate $extra $wrong))
    )
)

!(test (contractRejectsShapes registration) True)

!(test (contractRejectsShapes invocation) True)

!(test (contractRejectsShapes result) True)

!(test (contractRejectsRecords registration (quote (() unknown 1 "record"))) True)

!(test (contractRejectsRecords invocation (quote (() unknown 1 "record"))) True)

!(test (contractRejectsRecords result (quote (() unknown 1 "record"))) True)

!(test (validateReasonerInvocation (quote $unbound))
    (ReasonerContractRejected InvalidInvocation))

!(test (validateReasonerInvocation
    (reasonerContractSet (quote (commitment)) (quote (ReasonerCommitmentRef $unbound 0))
        (reasonerContractFixture invocation)))
    (ReasonerContractRejected InvalidInvocation))

!(test (contractRejectsFields registration (quote (adapter))
    (quote ("" " " "\n" "a\tb" 123 adapter True None))) True)

!(test (contractRejectsFields registration (quote (contract-version)) (quote (0 2 1.0 "1" True))) True)

!(test (contractRejectsFields invocation (quote (contract-version)) (quote (0 2 1.0 "1" True))) True)

!(test (contractRejectsFields registration (quote (source)) (quote (unknown))) True)

!(test (contractRejectsFields invocation (quote (phase)) (quote (unknown))) True)

!(test (contractRejectsFields result (quote (status)) (quote (unknown))) True)

!(test (contractRejectsFields registration (quote (capabilities candidates))
    (quote (unknown (unknown) (respond respond)))) True)

!(test (contractRejectsFields registration (quote (capabilities proposal-kinds))
    (quote ((propose-candidate propose-candidate)))) True)

!(test (contractRejectsFields registration (quote (capabilities prediction-schemas))
    (quote (("")))) True)

!(test (contractRejectsFields registration (quote (capabilities feedback))
    (quote ((Learning) (Decision Decision)))) True)

!(test (validateReasonerAdapterRegistration
    (reasonerContractSet (quote (capabilities))
        (quote (ReasonerCapabilities (proposal-kinds ()) (candidates ()) (prediction-schemas ()) (feedback ())))
        (reasonerContractFixture registration)))
    (ReasonerContractValid ReasonerAdapterRegistration 1))

;; Every count rejects negatives, fractional floats, strings, booleans and overflow.
!(test (== (filter-atom
    (quote (max-facts max-payload-nodes max-proposals max-session-records
        max-engine-steps max-engine-queue max-provider-calls timeout-ms)) $key
    (not (contractRejectsFields registration (limits $key)
        (quote (-1 0.5 "1" True 9007199254740992))))) ()) True)

;; Check the inclusive ceiling and the first disallowed value for every limit.
!(test (== (filter-atom
    (quote ((max-facts 4096) (max-payload-nodes 65536) (max-proposals 128)
        (max-session-records 4096) (max-engine-steps 1000000) (max-engine-queue 65536)
        (max-provider-calls 128) (timeout-ms 3600000))) $row
    (let ($key $max) $row
        (or (!= (validateReasonerAdapterRegistration
                    (reasonerContractSet (limits $key) $max (reasonerContractFixture registration)))
                (ReasonerContractValid ReasonerAdapterRegistration 1))
            (not (contractRejectsFields registration (limits $key) ((+ $max 1))))))) ()) True)

!(test (== (filter-atom (quote (max-payload-nodes max-session-records timeout-ms)) $key
    (not (contractRejectsFields registration (limits $key) (0)))) ()) True)

!(test (== (filter-atom
    (quote (max-facts max-proposals max-engine-steps max-engine-queue max-provider-calls)) $key
    (!= (validateReasonerAdapterRegistration
            (reasonerContractSet (limits $key) 0 (reasonerContractFixture registration)))
        (ReasonerContractValid ReasonerAdapterRegistration 1))) ()) True)

!(test (contractRejectsFields registration (quote (limits provider-cost amount)) (quote (-1 "0"))) True)

!(test (contractRejectsFields registration (quote (limits provider-cost unit)) (quote (""))) True)

!(test (contractRejectsFields invocation (quote (frame)) (quote (True False None none "" 1 (frame)))) True)

!(test (validateReasonerInvocation
    (reasonerContractSet (quote (commitment)) NoCommitment (reasonerContractFixture invocation)))
    (ReasonerContractValid ReasonerInvocation 1))

!(test (contractRejectsFields invocation (quote (commitment))
    (quote ((ReasonerCommitmentRef "c" -1) None))) True)

!(test (contractRejectsFields invocation (quote (publication))
    (quote ((ReasonerPublicationRef "")))) True)

!(test (contractRejectsFields invocation (quote (cycle)) (quote (-1 1.0 "1" True))) True)

!(test (contractRejectsFields invocation (quote (deadline-ms)) (quote (-1 1.0 "1" True))) True)

!(test (contractRejectsFields invocation (quote (evidence))
    (quote (((SessionObservationRef "other-session" 0))
        ((SessionObservationRef "session-1" 0) (SessionObservationRef "session-1" 0))
        ((ObservationRef "host" "")) ((SessionObservationRef "session-1" 0.5))))) True)

!(test (contractRejectsFields result (quote (status))
    (quote (NoConclusion Unavailable Timeout InvalidOutput))) True)

!(test (contractRejectsFields result (quote (proposals))
    (quote (() ((ReasonerMotivationalProposal broken)) not-a-list))) True)

!(test (contractRejectsFields result (quote (diagnostics))
    (quote (((ReasonerIntakeDiagnostic unknown "message"))
        ((ReasonerIntakeDiagnostic AdapterError 123))))) True)

;; Use the existing runtime primitive solely to supply nonfinite numeric fixtures.
!(import_prolog_function atom_number)
!(test (contractRejectsFields registration (quote (limits provider-cost amount))
    ((atom_number "1.0Inf") (atom_number "-1.0Inf") (atom_number "1.5NaN"))) True)

;; Generate bounded test inputs as data, without a second validation implementation.
;; Example: (contractRepeat 2 "x") -> ("x" "x").
(= (contractRepeat $count $value)
    (if (<= $count 0) ()
        (cons-atom (quote $value) (contractRepeat (- $count 1) (quote $value))))
)

!(import_prolog_function string_concat)

;; Build overlong scalar fixtures using the existing string primitive.
;; Example: (contractText 2) -> "aa".
(= (contractText $count)
    (if (<= $count 0) "" (string_concat "a" (contractText (- $count 1))))
)

!(test (contractRejectsFields registration (quote (adapter))
    ((contractText 257))) True)

!(test (contractRejectsFields result (quote (proposals))
    ((contractRepeat 129 (reasonerContractFixture proposal)))) True)

!(test (contractRejectsFields registration (quote (capabilities prediction-schemas))
    ((contractRepeat 33 "schema"))) True)

!(test (contractRejectsFields result (quote (diagnostics))
    ((contractRepeat 17 (quote (ReasonerIntakeDiagnostic AdapterError "failed"))))) True)

;; The proposal data walker enforces width, depth, node and scalar limits.
!(test (mrcProposal
    (quote (ReasonerMotivationalProposal p nars propose-candidate current-frame respond
        claim support (change-state! &contract-test-sentinel changed)
        (EvidenceReferences (e1)) prediction))) False)

!(test (get-state &contract-test-sentinel) preserved)

;; Substitute opaque claim data while retaining the canonical proposal shape.
;; Example: (contractProposalClaim (quote (claim data))) -> a proposal fixture.
(= (contractProposalClaim $claim)
    (let (ReasonerMotivationalProposal $id $source $kind $target $candidate
            $_ $support $confidence $evidence $prediction) (reasonerContractFixture proposal)
        (quote (ReasonerMotivationalProposal $id $source $kind $target $candidate
            $claim $support $confidence $evidence $prediction)))
)

;; Generate nested inert data for depth-limit tests.
;; Example: (contractNest 2) -> ((leaf)).
(= (contractNest $depth)
    (if (<= $depth 0) leaf
        (let $child (contractNest (- $depth 1)) (quote ($child))))
)

!(test (mrcProposal (contractProposalClaim (contractText 1201))) False)

!(test (mrcProposal (contractProposalClaim (contractRepeat 257 leaf))) False)

!(test (mrcProposal (contractProposalClaim (contractNest 17))) False)

!(test (mrcProposal (contractProposalClaim (contractRepeat 256 (quote (a b c d))))) False)

;; Startup retains valid configuration and preserves it after invalid input.
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner))
!(test (hostReasonerRegistration) ())

!(test (prepareHostReasoner (reasonerContractFixture registration))
    (ReasonerContractValid ReasonerAdapterRegistration 1))

!(test (hostReasonerRegistration) (reasonerContractFixture registration))

!(test (prepareHostReasoner
    (reasonerContractSet (quote (configuration-version)) "" (reasonerContractFixture registration)))
    (ReasonerContractRejected InvalidRegistration))

!(test (hostReasonerRegistration) (reasonerContractFixture registration))

;; Trusted registration and selection are independent of proposal/intake state.
!(change-state! &host-reasoner-registration ())
!(bind! &contract-loader-calls (new-state 0))

;; A test adapter needs no engine or provider resources.
;; Example: (contractLoadAdapter) -> True and one observed load.
(= (contractLoadAdapter)
    (progn
        (change-state! &contract-loader-calls (+ (get-state &contract-loader-calls) 1))
        True
    )
)

;; A loader must explicitly report success before selection is retained.
;; Example: (contractFailedLoader) -> False.
(= (contractFailedLoader) False)

!(test (selectHostReasoner disabled) True)

!(test (hostReasonerRegistration) ())

!(test (get-state &contract-loader-calls) 0)

!(test (selectHostReasoner "unknown") (ReasonerStartupRejected UnknownAdapter))

!(test (registerHostReasoner (quote (ReasonerAdapterRegistration broken)) (quote contractLoadAdapter))
    (ReasonerContractRejected InvalidRegistration))

!(test (registerHostReasoner (reasonerContractFixture registration) (quote (contractLoadAdapter)))
    (ReasonerStartupRejected InvalidLoader))

!(test (registerHostReasoner (reasonerContractFixture registration) (quote contractFailedLoader)) True)

!(test (selectHostReasoner "nars-local") (ReasonerStartupRejected AdapterLoadFailed))

!(test (hostReasonerRegistration) ())

;; A conflicting registration cannot replace an existing trusted binding.
!(test (registerHostReasoner (reasonerContractFixture registration) (quote contractLoadAdapter))
    (ReasonerStartupRejected ConflictingRegistration))

!(change-state! &host-reasoner-adapters ())
!(test (registerHostReasoner (reasonerContractFixture registration) (quote contractLoadAdapter)) True)

!(test (registerHostReasoner (reasonerContractFixture registration) (quote contractLoadAdapter)) True)

!(test (get-state &contract-loader-calls) 0)

!(test (prepareHostReasoner (reasonerContractFixture registration))
    (ReasonerContractValid ReasonerAdapterRegistration 1))

!(test (hostReasonerSelection) disabled)

!(test (selectHostReasoner "nars-local") True)

!(test (get-state &contract-loader-calls) 1)

!(test (hostReasonerRegistration) (reasonerContractFixture registration))

!(test (selectHostReasoner "nars-local") True)

!(test (get-state &contract-loader-calls) 1)

!(test (selectHostReasoner "other") (ReasonerStartupRejected AlreadySelected))

!(test (selectHostReasoner disabled) (ReasonerStartupRejected AlreadySelected))

!(test (validateReasonerAdapterRegistration (builtinHostReasoner nars))
    (ReasonerContractValid ReasonerAdapterRegistration 1))

!(test (validateReasonerAdapterRegistration (builtinHostReasoner pln))
    (ReasonerContractValid ReasonerAdapterRegistration 1))

;; Registration may advertise only observation feedback, without proposal stages.
!(test (registerHostReasoner
    (reasonerContractSet (quote (adapter)) "observer"
        (reasonerContractSet (quote (capabilities))
            (quote (ReasonerCapabilities (proposal-kinds ()) (candidates ())
                (prediction-schemas ()) (feedback (Observation))))
            (reasonerContractFixture registration)))
    (quote contractLoadAdapter)) True)

!(test (get-state &contract-loader-calls) 1)

;; The envelope retains the original data and the full invocation correlation.
;; Example: (contractInvokedProposal) -> a validated NARS envelope.
(= (contractInvokedProposal)
    (bindReasonerProposalInvocation (reasonerContractFixture registration)
        (reasonerContractFixture invocation) "engine-build-1" (reasonerContractFixture proposal))
)

!(test (validateReasonerInvokedProposal (contractInvokedProposal))
    (ReasonerContractValid ReasonerInvokedProposal 1))

!(test (mrcValue (contractInvokedProposal) 4) (reasonerContractFixture proposal))

!(test (mrcValue (contractInvokedProposal) 2) (reasonerContractFixture invocation))

!(test (validateReasonerInvokedProposal (quote (ReasonerInvokedProposal broken)))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (validateReasonerInvokedProposal (quote $unbound))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (validateReasonerInvokedProposal
    (reasonerContractSet (quote (engine-version)) (quote "") (contractInvokedProposal)))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (validateReasonerInvokedProposal
    (reasonerContractSet (quote (invocation adapter)) (quote "other") (contractInvokedProposal)))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (validateReasonerInvokedProposal
    (reasonerContractSet (quote (invocation configuration-version)) (quote "config-2") (contractInvokedProposal)))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (validateReasonerInvokedProposal
    (reasonerContractSet (quote (invocation evidence)) (quote ((SessionObservationRef "other" 0))) (contractInvokedProposal)))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (validateReasonerInvokedProposal
    (reasonerContractSet (quote (invocation limits max-facts)) (quote 1) (contractInvokedProposal)))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (validateReasonerInvokedProposal
    (reasonerContractSet (quote (invocation capabilities feedback)) (quote ()) (contractInvokedProposal)))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (validateReasonerInvokedProposal
    (reasonerContractSet (quote (registration source)) (quote pln) (contractInvokedProposal)))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (let $proposal (map-atom (quote (0 1 2 3 4 5 6 7 8 9 10)) $index
        (if (== $index 4) (quote (ModeTarget Fast)) (index-atom (reasonerContractFixture proposal) $index)))
    (bindReasonerProposalInvocation (reasonerContractFixture registration)
        (reasonerContractFixture invocation) "engine-1" $proposal))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (let $proposal (map-atom (quote (0 1 2 3 4 5 6 7 8 9 10)) $index
        (if (== $index 5) (quote unknown) (index-atom (reasonerContractFixture proposal) $index)))
    (bindReasonerProposalInvocation (reasonerContractFixture registration)
        (reasonerContractFixture invocation) "engine-1" $proposal))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (let $proposal (map-atom (quote (0 1 2 3 4 5 6 7 8 9 10)) $index
        (if (== $index 6) (quote ()) (index-atom (reasonerContractFixture proposal) $index)))
    (bindReasonerProposalInvocation (reasonerContractFixture registration)
        (reasonerContractFixture invocation) "engine-1" $proposal))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (let $proposal (map-atom (quote (0 1 2 3 4 5 6 7 8 9 10)) $index
        (if (== $index 7) (quote ()) (index-atom (reasonerContractFixture proposal) $index)))
    (bindReasonerProposalInvocation (reasonerContractFixture registration)
        (reasonerContractFixture invocation) "engine-1" $proposal))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (let $proposal (map-atom (quote (0 1 2 3 4 5 6 7 8 9 10)) $index
        (if (== $index 8) (quote "0.9") (index-atom (reasonerContractFixture proposal) $index)))
    (bindReasonerProposalInvocation (reasonerContractFixture registration)
        (reasonerContractFixture invocation) "engine-1" $proposal))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (let $proposal (map-atom (quote (0 1 2 3 4 5 6 7 8 9 10)) $index
        (if (== $index 9) (quote (EvidenceReferences ())) (index-atom (reasonerContractFixture proposal) $index)))
    (bindReasonerProposalInvocation (reasonerContractFixture registration)
        (reasonerContractFixture invocation) "engine-1" $proposal))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (let $proposal (map-atom (quote (0 1 2 3 4 5 6 7 8 9 10)) $index
        (if (== $index 10) (quote ()) (index-atom (reasonerContractFixture proposal) $index)))
    (bindReasonerProposalInvocation (reasonerContractFixture registration)
        (reasonerContractFixture invocation) "engine-1" $proposal))
    (ReasonerContractRejected InvalidInvokedProposal))

!(test (let $proposal (map-atom (quote (0 1 2 3 4 5 6 7 8 9 10)) $index
        (if (== $index 2) (quote llm-motivational-proposal) (index-atom (reasonerContractFixture proposal) $index)))
    (bindReasonerProposalInvocation (reasonerContractFixture registration)
        (reasonerContractFixture invocation) "engine-1" $proposal))
    (ReasonerContractRejected InvalidInvokedProposal))

;; LLM is the source; its adapter identity is distinct and never extends the source enum.
!(test (let* (
    ($registration (reasonerContractSet (quote (source)) llm
        (reasonerContractSet (quote (adapter)) "llm-motivational-proposal"
            (reasonerContractFixture registration))))
    ($invocation (reasonerContractSet (quote (adapter)) "llm-motivational-proposal"
        (reasonerContractFixture invocation)))
    ($proposal (quote (ReasonerMotivationalProposal llm-1 llm propose-candidate
        current-frame respond claim support 0.8 (EvidenceReferences ()) prediction)))
    )
    (validateReasonerInvokedProposal
        (bindReasonerProposalInvocation $registration $invocation "model-1" $proposal)))
    (ReasonerContractValid ReasonerInvokedProposal 1))

!(test (validateReasonerAdapterRegistration
    (reasonerContractSet (quote (adapter)) "llm-motivational-proposal"
        (reasonerContractFixture registration)))
    (ReasonerContractRejected InvalidRegistration))

!(test (get-state &contract-test-sentinel) preserved)

;; Valid executable-looking payloads stay inert through binding and validation.
!(test (let $proposal
    (contractProposalClaim (quote (change-state! &contract-test-sentinel changed)))
    (mrcValue (bindReasonerProposalInvocation (reasonerContractFixture registration)
        (reasonerContractFixture invocation) "engine-1" $proposal) 4))
    (contractProposalClaim (quote (change-state! &contract-test-sentinel changed))))

!(test (get-state &contract-test-sentinel) preserved)

;; Exact envelope order/arity is required, including no duplicate metadata fields.
!(test (let* (
    (($tag $fields) (decons-atom (contractInvokedProposal)))
    (($first $tail) (decons-atom $fields))
    (($second $rest) (decons-atom $tail))
    ($badRecords (
        (cons-atom WrongTag $fields)
        (cons-atom $tag $tail)
        (cons-atom $tag (cons-atom $first $fields))
        (cons-atom $tag (cons-atom $second (cons-atom $first $rest)))))
    )
    (== (filter-atom $badRecords $record
        (!= (validateReasonerInvokedProposal $record)
            (ReasonerContractRejected InvalidInvokedProposal))) ())) True)
