;; Admission reuses native availability, concrete dispatch policy and scoring.
;; Captured commands/tickets remain host-owned; agreement grants no causal credit.
(: HostReasonerProposalAdmissionType Type)
(: HostReasonerProposalAdmission (-> Expression Expression Expression HostReasonerProposalAdmissionType))
(: HostReasonerAdmissionsType Type)
(: HostReasonerAdmissions (-> Expression String Expression HostReasonerAdmissionsType))
(: ReasonerAdmittedActionsType Type)
(: ReasonerAdmittedActions (-> Expression ReasonerAdmittedActionsType))
!(bind! &host-reasoner-admissions (new-state ()))

;; Retain the invocation reference beside admitted/rejected proposal decisions.
;; Example: (hostReasonerAdmissions) does not imply that any proposal was selected.
(= (hostReasonerAdmissions) (get-state &host-reasoner-admissions))

;; Resolve the same exact host binding used by native operation admission.
;; Example: two bindings for one candidate reject as AmbiguousOperation.
(= (hostReasonerProposalGate $bundle $proposal $rows)
    (if (== $rows LegacyCandidateAdmission) (GateDecision Rejected MissingOperationContext)
        (let $matches (hostRowsForCandidate (getProposalCandidate $proposal) $rows)
            (case (size-atom $matches) (
                (0 (GateDecision Rejected UnsupportedOperation))
                (1 (let (HostOperation $_ $_ $operation $global $frame $_) (car-atom $matches)
                    (dispatchOperationGate $bundle $bundle
                        (AdmissionRequest (getProposalKind $proposal) (getProposalTarget $proposal)
                            (getProposalCandidate $proposal)) $operation $global $frame)))
                ($_ (GateDecision Rejected AmbiguousOperation))
            )))
    )
)

;; Score only feasible and natively available work, using the ordinary scorer.
;; Example: maximum-confidence denied advice has score zero and never reaches scoring.
(= (hostReasonerAdmitProposal $bundle $state $envelope $rows $fresh)
    (let* (
        ($proposal (mrcValue $envelope 4))
        ($candidate (getProposalCandidate $proposal))
        ($gate (if $fresh
            (case (feasibilityGate $bundle $candidate) (
                ((GateDecision Admitted Feasible) (hostReasonerProposalGate $bundle $proposal $rows))
                ($rejection $rejection)
            )) (GateDecision Rejected StaleInvocation)))
        ($decision (case $gate (
            ((GateDecision Admitted Feasible)
                (if (candidateIsAvailable $bundle $candidate)
                    (ReasonerMotivationalDecision Accepted Feasible $proposal $candidate
                        (omegaclawScoreForBundle $bundle $state (candidateToAction $candidate)))
                    (ReasonerMotivationalDecision Rejected CandidateUnavailable $proposal $candidate 0.0)))
            ((GateDecision Rejected $reason)
                (ReasonerMotivationalDecision Rejected $reason $proposal $candidate 0.0))
        )))
        ($operation (if (== (getStatus $decision) Accepted)
            (car-atom (hostRowsForCandidate $candidate $rows)) ()))
    ) (quote (HostReasonerProposalAdmission $envelope $decision $operation)))
)

(: HostReasonerSelectionType Type)
(: HostReasonerSelection (-> Expression String Expression Expression HostReasonerSelectionType))
(: HostReasonerPrimaryType Type)
(: HostReasonerPrimary (-> Expression Expression Symbol HostReasonerPrimaryType))
!(bind! &host-reasoner-selections (new-state ()))

;; Separate exact-selection audit from admission, native decisions and outcomes.
;; Example: an empty primary means no eligible proposal matched the native choice.
(= (hostReasonerSelections) (get-state &host-reasoner-selections))

;; Shadow attribution uses intake order; active advice supplies its exact contributor.
;; Example: identical candidates with another command or ticket cannot match.
(= (hostReasonerPrimary $invocation $decision $admissions)
    (let $matches (filter-atom $admissions $entry
        (let (HostReasonerProposalAdmission $envelope $admission $operation) $entry
            (and (== (getStatus $admission) Accepted)
                (and (== (getProposalKind (mrcValue $envelope 4)) propose-candidate)
                    (reasonerRuntimeSelectionCurrent $invocation $operation $decision)))))
        (case $matches (
            (() ())
            ($_ (case (optionalHostReasonerAdvisory Primary ($invocation $decision $matches)) (
                ((HostReasonerPrimary $envelope $operation $attribution)
                    (quote (HostReasonerPrimary $envelope $operation $attribution)))
                (NoPrimaryAttribution ())
                ($_ (let (HostReasonerProposalAdmission $envelope $_ $operation) (car-atom $matches)
                    (quote (HostReasonerPrimary $envelope $operation ShadowAgreement))))))))))
)

;; Retain once before notification/dispatch, including an explicit absent primary.
;; Example: replay cannot replace the first primary or allocate another ticket.
(= (retainHostReasonerSelectionAudit $invocation $decision)
    (let* (
        ($id (mrcValue $invocation 1))
        ($batches (filter-atom (hostReasonerAdmissions) $batch (== (index-atom $batch 2) $id)))
        ($prior (filter-atom (hostReasonerSelections) $row
            (or (== (index-atom $row 2) $id)
                (== (index-atom (index-atom $row 3) 4) (index-atom $decision 4)))))
        ($limits (mrcValue $invocation 12))
    )
        (if (or (!= $prior ()) (== $batches ())) True
            (let* (
                ($context (get-state &operation-context))
                ($primary (hostReasonerPrimary $invocation $decision (index-atom (car-atom $batches) 3)))
                ($row (quote (HostReasonerSelection $context $id $decision $primary)))
            )
                (if (and (< (size-atom (hostReasonerSelections)) (mrcValue $limits 4))
                    (>= (reasonerProposalDataRemaining (quote $row) 32 (* 2 (mrcValue $limits 2))) 0))
                    (progn (change-state! &host-reasoner-selections
                        (cons-atom $row (hostReasonerSelections))) True)
                    (ReasonerRuntimeError AuditLimit)))))
)

;; One bounded admission batch per invocation; duplicate delivery does not rescore.
;; Example: no retained intake returns the native pool unchanged.
(= (admitHostReasonerPhase $phase $bundle $rows $state $native)
    (case (hostReasonerCycleForPhase (get-state &operation-context) $phase) (
        ((HostReasonerCycle $context $invocation $_ $envelopes $_ $_)
            (let* (
                ($id (mrcValue $invocation 1))
                ($prior (filter-atom (hostReasonerAdmissions) $batch (== (index-atom $batch 2) $id)))
                ($fresh (hostReasonerAdmissionCurrent $invocation $bundle))
            )
                (case $prior (
                    ((($tag $_ $_ $_decisions)) $native)
                    (() (let* (
                        ($decisions (map-atom $envelopes $envelope
                            (hostReasonerAdmitProposal $bundle $state $envelope $rows $fresh)))
                        ($batch (quote (HostReasonerAdmissions $context $id $decisions)))
                        ($limits (mrcValue $invocation 12))
                    )
                        (if (and (< (size-atom (hostReasonerAdmissions)) (mrcValue $limits 4))
                                 (>= (reasonerProposalDataRemaining (quote $batch) 32 (* 2 (mrcValue $limits 2))) 0))
                            (progn
                                (change-state! &host-reasoner-admissions (cons-atom $batch (hostReasonerAdmissions)))
                                $native) $native)))
                    ($_ $native)
                ))))
        ($_ $native)
    ))
)

;; Admission must use the publication that produced the retained proposal.
;; Example: republishing within a context cannot relabel an old invocation as current.
(= (hostReasonerAdmissionCurrent $invocation $bundle)
    (case (frameRuntimeSignalObservations $bundle) (
        ((SignalObservationView $snapshot $_ $_)
            (and (== $bundle (activeFrameBundle))
                (and (== (mrcValue $invocation 8) (ReasonerPublicationRef (repr $snapshot)))
                    (reasonerRuntimeCurrent $invocation))))
        ($_ False)
    ))
)
