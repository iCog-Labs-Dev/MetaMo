;; Optional host coordinator: bounded shadow advice, never execution authority.
;; Loaded only after explicit reasoner startup; requires the contract facade.
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_fact_translation))
!(import_prolog_functions_from_file
    (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_runtime.pl)
    (reasonerRuntimeIdentity reasonerRuntimeCall))
(: HostReasonerRuntimeType Type)
(: HostReasonerRuntime (-> String Symbol Symbol Expression Number HostReasonerRuntimeType))
(: HostReasonerRuntimeBindingType Type)
(: HostReasonerRuntimeBinding (-> String Expression HostReasonerRuntimeBindingType))
(: HostReasonerCycleType Type)
(: HostReasonerCycle (-> Expression Expression Expression Expression Expression Expression HostReasonerCycleType))
(: HostReasonerRuntimeResultType Type)
(: ReasonerRuntimeError (-> Symbol HostReasonerRuntimeResultType))
(: ReasonerRuntimeIdentityType Type)
(: ReasonerRuntimeIdentity (-> String Number ReasonerRuntimeIdentityType))
!(bind! &host-reasoner-runtimes (new-state ()))
!(bind! &host-reasoner-cycles (new-state ()))

;; Read a trusted callback binding; missing runtime support means no advice.
;; Example: (hostReasonerRuntimeBinding "unconfigured") -> ().
(= (hostReasonerRuntimeBinding $id)
    (let $rows (filter-atom (get-state &host-reasoner-runtimes) $row
        (== (index-atom $row 1) $id))
        (case $rows (((($tag $_ $runtime)) $runtime) ($_ ())))
    )
)

;; Bind callbacks and engine facts from trusted host configuration, not model output.
;; Example: a non-symbol collector rejects without changing previous configuration.
(= (configureHostReasonerRuntime $id $runtime)
    (case $runtime (
        ((HostReasonerRuntime $version $collect $notify $native $confidence)
            (if (tpAllTrue ((mrcText $id) (mrcText $version)
                    (!= (collapse (translatePredicate (atom $collect))) ())
                    (!= (collapse (translatePredicate (atom $notify))) ())
                    (is-ground $runtime) (fsNumberIn $confidence 0 1)
                    (== (get-metatype $native) Expression)
                    (>= (reasonerProposalDataRemaining (quote $native) 16 4096) 0)))
                (if (and (< (size-atom (get-state &host-reasoner-runtimes)) 128)
                         (== (filter-atom (hostReasonerCycles) $cycle
                             (== (mrcValue (index-atom $cycle 2) 2) $id)) ()))
                    (progn
                        (change-state! &host-reasoner-runtimes
                            (cons-atom (quote (HostReasonerRuntimeBinding $id $runtime))
                                (filter-atom (get-state &host-reasoner-runtimes) $row
                                    (!= (index-atom $row 1) $id)))) True)
                    (ReasonerRuntimeError Capacity))
                (ReasonerRuntimeError InvalidConfiguration)))
        ($_ (ReasonerRuntimeError InvalidConfiguration))
    ))
)

;; Built-ins expose collection only; native learning/feedback is not fabricated.
;; Example: explicitly selected NARS with no configured rules may return NoConclusion.
(= (ensureBuiltinHostReasonerRuntime $id)
    (if (== (hostReasonerRuntimeBinding $id) ())
        (configureHostReasonerRuntime $id
            (quote (HostReasonerRuntime "local-libraries" collectBuiltinHostReasoner
                noHostReasonerFeedback () 0.9))) True)
)

;; Public retained diagnostics are bounded session-correlated shadow records.
;; Example: (hostReasonerCycles) contains no numerical outcome grades.
(= (hostReasonerCycles) (get-state &host-reasoner-cycles))

;; Correlate to the exact operation context, never just a candidate label.
;; Example: another session's cycle number cannot match this row.
(= (hostReasonerCycleFor $context)
    (let $rows (filter-atom (hostReasonerCycles) $row (== (index-atom $row 1) $context))
        (if (== (size-atom $rows) 1) (car-atom $rows) ()))
)

;; Update an existing identity without allocating a replacement invocation.
;; Example: notification failures still leave the retained decision available.
(= (retainHostReasonerCycle $row)
    (change-state! &host-reasoner-cycles
        (cons-atom (quote $row) (filter-atom (hostReasonerCycles) $old
            (!= (index-atom $old 1) (index-atom $row 1)))))
)

;; Reuse stable observation stamps; no numeric truth conversion happens here.
;; Example: explicit False retains its reference and missing observations add none.
(= (hostReasonerReferences $signals $native)
    (hostReasonerDistinctReferences (append (hostReasonerGatherReferences $signals True)
        (hostReasonerGatherReferences $native False)))
)

;; Traverse only the supplied bounded facts; preserve exact typed reference identity.
;; Example: two facts citing one observation contribute that reference once.
(= (hostReasonerGatherReferences $facts $signals)
    (if (== $facts ()) ()
        (let* (
            (($head $tail) (decons-atom $facts))
            ($refs (if $signals (factualSignalField provenance $head)
                (index-atom (index-atom $head 2) 2)))
        )
            (append $refs (hostReasonerGatherReferences $tail $signals))))
)

;; Supply the current commitment revision beside advice rather than inside it.
;; Example: no host commitment is represented explicitly as NoCommitment.
(= (hostReasonerCommitment)
    (case (commitmentSnapshot) (
        ((CommitmentSnapshot $id $_ $revision Open $_) (ReasonerCommitmentRef $id $revision))
        ($_ NoCommitment)))
)

;; Invocation identity is allocated once, after validating the published snapshot.
;; Example: candidates and mode appraisal share this already published bundle.
(= (hostReasonerInvocation $registration $bundle $signals $native)
    (let* (
        ((OperationContext $session $cycle $frame) (get-state &operation-context))
        ((SignalObservationView $snapshot $_ $_) (frameRuntimeSignalObservations $bundle))
        ($limits (mrcValue $registration 6))
        ((ReasonerRuntimeIdentity $id $deadline) (reasonerRuntimeIdentity (mrcValue $limits 9)))
        ($adapter (mrcValue $registration 1))
        ($version (mrcValue $registration 3))
        ($caps (mrcValue $registration 5))
        ($refs (hostReasonerReferences $signals $native))
        ($commitment (hostReasonerCommitment))
        ($publication (repr $snapshot))
    )
        (quote (ReasonerInvocation (invocation-id $id) (adapter $adapter) (contract-version 1)
            (configuration-version $version) (session $session) (cycle $cycle) (frame $frame)
            (publication (ReasonerPublicationRef $publication)) (commitment $commitment)
            (phase CandidateIntake) (capabilities $caps) (limits $limits)
            (evidence $refs) (deadline-ms $deadline)))
    )
)

;; Check exact proposal representation, source, declared kinds/candidates and evidence membership.
;; This is shadow intake, not policy admission, selection attribution or grading.
;; Example: a proposal citing another invocation's evidence is rejected.
(= (hostReasonerProposalValid $registration $invocation $proposal)
    (if (reasonerProposalValid $proposal)
        (let* (
            ($caps (mrcValue $registration 5))
            ((EvidenceReferences $refs) (getProposalEvidence $proposal))
        )
            (tpAllTrue (
                (== (getProposalSource $proposal) (mrcValue $registration 4))
                (tpContains (mrcValue $caps 1) (getProposalKind $proposal))
                (tpContains (mrcValue $caps 2) (getProposalCandidate $proposal))
                (== (filter-atom $refs $ref (not (tpContains (mrcValue $invocation 13) $ref))) ())
                (or (== (getProposalTarget $proposal) current-frame)
                    (== (getProposalTarget $proposal) (FrameTarget (mrcValue $invocation 7))))
            ))) False)
)

;; Invalid or mismatched adapter output is retained as an empty error result.
;; Example: changing invocation-id in an otherwise valid result cannot publish advice.
(= (hostReasonerCheckedIntake $registration $invocation $result)
    (let* (
        ($id (mrcValue $invocation 1))
        ($adapter (mrcValue $invocation 2))
        ($limits (mrcValue $invocation 12))
        ($valid (if (>= (reasonerProposalDataRemaining (quote $result) 16 (mrcValue $limits 2)) 0)
            (== (validateReasonerIntakeResult $result) (ReasonerContractValid ReasonerIntakeResult 1)) False))
    )
        (if $valid
            (if (tpAllTrue (
                    (== (mrcValue $result 1) $id) (== (mrcValue $result 2) $adapter)
                    (<= (size-atom (mrcValue $result 4)) (mrcValue $limits 3))
                    (== (filter-atom (mrcValue $result 4) $proposal
                        (!= (size-atom (filter-atom (mrcValue $result 4) $other
                            (== (getProposalId $proposal) (getProposalId $other)))) 1)) ())
                    (== (filter-atom (mrcValue $result 4) $proposal
                        (not (hostReasonerProposalValid $registration $invocation $proposal))) ())
                )) $result (hostReasonerEmptyIntake $invocation InvalidOutput))
            (hostReasonerEmptyIntake $invocation
                (case $result (((ReasonerRuntimeError Timeout) Timeout) ($_ InvalidOutput))))
        )
    )
)

;; Empty output is not negative evidence and never changes source reliability.
;; Example: (hostReasonerEmptyIntake invocation Timeout) has no proposals.
(= (hostReasonerEmptyIntake $invocation $status)
    (let* (($id (mrcValue $invocation 1)) ($adapter (mrcValue $invocation 2)))
        (quote (ReasonerIntakeResult (invocation-id $id) (adapter $adapter)
            (status $status) (proposals ()) (diagnostics ()))))
)

;; Call outside dispatch locking, retain once, and preserve exact proposal envelopes.
;; Example: identical cycle redelivery neither invokes the adapter nor duplicates its audit.
(= (collectHostReasonerCycle $bundle $actions)
    (let* (
        ($context (get-state &operation-context))
        ($registration (hostReasonerRegistration))
        ($runtime (hostReasonerRuntimeBinding (hostReasonerSelection)))
        ($signals (getSignals))
    )
        (case ($context $runtime (hostReasonerCycleFor $context)) (
            (((OperationContext $session $cycle $frame)
                (HostReasonerRuntime $version $collect $_ $native $_) ())
                (if (and (hostReasonerPublishedSignalsValid $bundle $signals)
                         (and (== $frame (frameBundleCurrentId $bundle))
                         (< (size-atom (hostReasonerCycles)) (mrcValue (mrcValue $registration 6) 4))))
                    (let* (
                        ($invocation (hostReasonerInvocation $registration $bundle $signals $native))
                        ($view (quote (ReasonerAdmittedView (invocation $invocation)
                            (signals $signals) (native-facts $native))))
                    )
                        (if (and (== (validateReasonerInvocation $invocation) (ReasonerContractValid ReasonerInvocation 1))
                                 (reasonerAdmittedPayloadBounded $invocation $signals $native))
                            (let* (
                                ($raw (reasonerRuntimeCall (mrcValue (mrcValue $invocation 12) 9)
                                    $collect ($invocation $view $actions)))
                                ($intake (hostReasonerCheckedIntake $registration $invocation $raw))
                                ($envelopes (map-atom (mrcValue $intake 4) $proposal
                                    (bindReasonerProposalInvocation $registration $invocation $version $proposal)))
                            )
                                (if (and (== $context (get-state &operation-context)) (== $bundle (activeFrameBundle)))
                                    (retainHostReasonerCycle (quote (HostReasonerCycle $context $invocation
                                        $intake $envelopes () ()))) (ReasonerRuntimeError StaleInvocation)))
                            (ReasonerRuntimeError InvalidView)))
                    (ReasonerRuntimeError Capacity)))
            ($_ True)
        ))
    )
)

;; Notify only declared adapter capabilities; callback failures do not affect native state.
;; Example: built-ins with empty feedback receive no Observation call.
(= (notifyHostReasoner $stage $invocation $payload)
    (if (tpContains (mrcValue (mrcValue $invocation 11) 4) $stage)
        (case (hostReasonerRuntimeBinding (mrcValue $invocation 2)) (
            ((HostReasonerRuntime $_ $_ $notify $_ $_)
                (reasonerRuntimeCall (mrcValue (mrcValue $invocation 12) 9)
                    $notify ($stage $invocation $payload)))
            ($_ True))) True)
)

;; Retained native decisions are reported as observations of selection, not causal attribution.
;; Example: shadow agreement never becomes an accepted/executed proposal event.
(= (retainHostReasonerDecision $decision)
    (case (hostReasonerCycleFor (get-state &operation-context)) (
        ((HostReasonerCycle $context $invocation $intake $proposals () $outcome)
            (progn
                (retainHostReasonerCycle (quote (HostReasonerCycle $context $invocation $intake $proposals $decision $outcome)))
                (notifyHostReasoner Decision $invocation $decision)))
        ($_ True)))
)

;; Receive only the immutable outcome accepted by the existing host callback boundary.
;; Example: duplicate observations cause no repeated adapter feedback.
(= (observeHostReasonerOutcome $outcome)
    (case $outcome (
        ((OperationOutcome $decision $_ $_ $_)
            (case (hostReasonerCycleFor (get-state &operation-context)) (
                ((HostReasonerCycle $context $invocation $intake $proposals $decision ())
                    (progn
                        (retainHostReasonerCycle (quote (HostReasonerCycle $context $invocation $intake $proposals $decision $outcome)))
                        (notifyHostReasoner Observation $invocation $outcome)))
                ($_ True))))
        ($_ True)))
)

;; One entry point serves normal collection, retained selection and observed callbacks.
;; Example: Collect does not append its advice to the native candidate list.
(= (hostReasonerRuntime $stage $payload)
    (if (== (hostReasonerSelection) disabled) True
        (case ($stage $payload) (
            ((Collect ($bundle $actions)) (collectHostReasonerCycle $bundle $actions))
            ((Decision $decision) (retainHostReasonerDecision $decision))
            ((Observation $outcome) (observeHostReasonerOutcome $outcome))
            ($_ (ReasonerRuntimeError UnknownStage)))))
)

;; Stable set construction preserves first occurrence and exact reference identity.
;; Example: (hostReasonerDistinctReferences (quote (a a b))) -> (a b).
(= (hostReasonerDistinctReferences $refs)
    (if (== $refs ()) ()
        (let ($head $tail) (decons-atom $refs)
            (cons-atom $head (hostReasonerDistinctReferences
                (filter-atom $tail $ref (!= $ref $head))))))
)

;; Validate each fact before checking its references against the retained owner.
;; Example: malformed facts and references from another owner both return False.
(= (hostReasonerSignalOwnedBy $fact $owner)
    (case (validateFactualSignal $fact) (
        ((FactualSignalValid $_ $_ $_)
            (== (filter-atom (factualSignalField provenance $fact) $ref
                (!= (hostSignalReferenceForOwner $ref $owner) $ref)) ()))
        ($_ False)
    ))
)

;; Resolve ownership once, then require every supplied fact to match it.
;; Example: an unavailable source observation rejects even an empty signal list.
(= (hostReasonerSourceSignalsValid $source $signals)
    (case $source (
        ((SourceObservation $_ $owner $_ $_)
            (== (filter-atom $signals $fact
                (not (hostReasonerSignalOwnedBy $fact $owner))) ()))
        ($_ False)
    ))
)

;; Resolve provenance only after the snapshot has matched the supplied bundle.
;; Example: a mismatched bundle returns False without resolving its source.
(= (hostReasonerSnapshotSignalsValid $bundle $snapshot $signals)
    (if (signalObservationBundleValid $bundle $snapshot)
        (hostReasonerSourceSignalsValid (resolveSignalObservation $snapshot) $signals)
        False
    )
)

;; Authenticate supplied signal references against the retained publication and owner.
;; No producer, classifier or raw frame reader is rerun at this boundary.
;; Example: a signal from another frame/session never reaches a collector.
(= (hostReasonerPublishedSignalsValid $bundle $signals)
    (case (frameRuntimeSignalObservations $bundle) (
        ((SignalObservationView $snapshot $_ $_)
            (hostReasonerSnapshotSignalsValid $bundle $snapshot $signals))
        ($_ False)
    ))
)
