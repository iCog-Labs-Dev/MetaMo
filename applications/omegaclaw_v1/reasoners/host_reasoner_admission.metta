;; Admission reuses native availability, concrete dispatch policy and scoring.
;; No command, ticket, attribution, source weighting or learning is created here.
(: HostReasonerProposalAdmissionType Type)
(: HostReasonerProposalAdmission (-> Expression Expression HostReasonerProposalAdmissionType))
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
    ) (quote (HostReasonerProposalAdmission $envelope $decision)))
)

;; Keep native actions and ties intact; repeated advice contributes one candidate.
;; Example: ten admitted respond proposals do not add ten respond actions.
(= (hostReasonerMergeActions $native $decisions)
    (if (== $decisions ()) $native
        (let* (
            (($head $tail) (decons-atom $decisions))
            ((HostReasonerProposalAdmission $_ $decision) $head)
            ($candidate (getCandidate $decision))
            ($present (!= (filter-atom $native $action (== (actionId $action) $candidate)) ()))
            ($next (if (and (== (getStatus $decision) Accepted) (not $present))
                (append $native ((candidateToAction $candidate))) $native))
        ) (hostReasonerMergeActions $next $tail)))
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
                                (hostReasonerMergeActions $native $decisions)) $native)))
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
