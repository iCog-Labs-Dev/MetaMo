;; Optional v1 advisory scoring. No inference, provider, policy or parameter mutation.
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_outcome_assessment))
(: HostReasonerInfluenceConfigType Type)
(: HostReasonerInfluenceConfig (-> String String Number Number Expression Expression Expression HostReasonerInfluenceConfigType))
(: HostReasonerInfluenceSettingType Type)
(: HostReasonerInfluenceSetting (-> String Expression Expression HostReasonerInfluenceSettingType))
(: HostReasonerInfluenceEvidenceType Type)
(: HostReasonerInfluenceEvidence (-> Number Expression HostReasonerInfluenceEvidenceType))
(: HostReasonerAdviceWeightType Type)
(: HostReasonerAdviceWeight (-> Symbol Number Expression Expression HostReasonerAdviceWeightType))
(: HostReasonerInfluenceViewType Type)
(: HostReasonerInfluenceView (-> Expression Expression Expression Expression HostReasonerInfluenceViewType))
(: HostReasonerInfluenceScoreType Type)
(: HostReasonerInfluenceScore (-> Expression Number Number Number Expression HostReasonerInfluenceScoreType))
(: HostReasonerInfluenceTraceType Type)
(: HostReasonerInfluenceTrace (-> Expression Expression Expression Expression Expression Expression Expression HostReasonerInfluenceTraceType))
(: HostReasonerInfluenceDecisionType Type)
(: HostReasonerInfluenceDecision (-> Expression Expression HostReasonerInfluenceDecisionType))
!(bind! &host-reasoner-influence-settings (new-state ()))
!(bind! &host-reasoner-influence-view (new-state ()))
!(bind! &host-reasoner-influence-trace (new-state ()))
!(bind! &host-reasoner-influence-decisions (new-state ()))
!(bind! &host-reasoner-influence-context (new-state ()))

;; Expose the bounded operation/counterfactual audit without replaying a decision.
;; Example: each row retains the exact selected operation and first decision trace.
(= (hostReasonerInfluenceDecisions) (get-state &host-reasoner-influence-decisions))

;; Read one adapter's active and pending settings without inventing an influence cap.
;; Example: an unconfigured adapter has neither active nor pending influence.
(= (hostReasonerInfluenceSettingFor $adapter)
    (let $rows (filter-atom (get-state &host-reasoner-influence-settings) $row (== (index-atom $row 1) $adapter))
        (case $rows ((($row) $row) ($_ (HostReasonerInfluenceSetting $adapter () ())))))
)

;; Controls may authorize zero influence, but cannot enable an undeclared positive cap.
;; Example: source reliability priors alone never satisfy this check.
(= (hostReasonerInfluenceReady $adapter)
    (let (HostReasonerInfluenceSetting $_ $active $pending) (hostReasonerInfluenceSettingFor $adapter)
        (or (!= $active ()) (!= $pending ()))))

;; Only matching, resolved, finite grades from the original configuration are eligible.
;; Example: another adapter or schema cannot lend its successful predictions.
(= (hostReasonerInfluenceAssessmentValid $adapter $configuration $assessment)
    (case $assessment (
        ((HostReasonerAssessment $_ $envelope $route (ReasonerPredictionComparison $conclusion $grade))
            (and (and (== (mrcValue (mrcValue $envelope 2) 2) $adapter)
                      (== (mrcValue (mrcValue $envelope 2) 4) $configuration))
                (and (tpContains (Confirmed Refuted) $conclusion) (fsNumberIn $grade 0 1))))
        ($_ False)))
)

;; Resolve distinct immutable receipts and require one comparator/schema identity.
;; Example: repeating one successful outcome three times still counts as one sample.
(= (hostReasonerInfluenceEvidence $adapter $configuration $ids $minimum $threshold)
    (let* (
        ($unique (hostReasonerDistinctReferences $ids))
        ($rows (map-atom $unique $id
            (let $matches (filter-atom (hostReasonerAssessments) $row (== (index-atom $row 1) $id))
                (if (== (size-atom $matches) 1) (car-atom $matches) ()))))
        ($valid (and (>= (size-atom $rows) $minimum)
            (== (filter-atom $rows $row (not (hostReasonerInfluenceAssessmentValid $adapter $configuration $row))) ())))
    )
        (if $valid
            (let* (
                ($route (index-atom (car-atom $rows) 3))
                ($same (== (filter-atom $rows $row (!= (index-atom $row 3) $route)) ()))
                ($quality (/ (sum (map-atom $rows $row (index-atom (index-atom $row 4) 2))) (size-atom $rows)))
            )
                (if (and $same (>= $quality $threshold)) (HostReasonerInfluenceEvidence $quality $route)
                    (ReasonerRuntimeError MissingPredictiveEvidence)))
            (ReasonerRuntimeError MissingPredictiveEvidence)))
)

;; Explicit cap changes require registry policy and retained predictive evidence.
;; Example: (configureHostReasonerInfluence "adapter" 0.05 (OUTCOME-A OUTCOME-B OUTCOME-C)).
(= (configureHostReasonerInfluence $adapter $cap $ids)
    (case ((registeredHostReasoner $adapter)
            (collapse (match &self (ReasonerInfluencePolicy $a $b $c $d) (ReasonerInfluencePolicy $a $b $c $d)))) (
        (((HostReasonerAdapter $registration $_)
            ((ReasonerInfluencePolicy (max-cap $limit) (min-samples $minimum)
                (min-mean-grade $threshold) (formula NormalizedMaxConfidence))))
            (if (and (fsNumberIn $cap 0 $limit)
                    (and (== (get-metatype $ids) Expression)
                        (>= (reasonerProposalDataRemaining (quote $ids) 16 (mrcValue (mrcValue $registration 6) 2)) 0)))
                (let* (
                    ($configuration (mrcValue $registration 3))
                    ($evidence (if (== $cap 0) (HostReasonerInfluenceEvidence 0 ())
                        (hostReasonerInfluenceEvidence $adapter $configuration $ids $minimum $threshold)))
                )
                    (case $evidence (
                        ((HostReasonerInfluenceEvidence $quality $route)
                            (let* (
                                ($refs (if (== $cap 0) () (hostReasonerDistinctReferences $ids)))
                                ($context (get-state &operation-context))
                                ($config (quote (HostReasonerInfluenceConfig $adapter $configuration $cap $quality $route $refs $context)))
                            ) (retainHostReasonerInfluenceConfig $adapter $config)))
                        ($error $error))))
                (ReasonerRuntimeError InvalidInfluenceConfig)))
        ($_ (ReasonerRuntimeError InvalidInfluenceConfig))))
)

;; Replace only pending configuration; a decision already underway retains its snapshot.
;; Example: raising or disabling a cap takes effect on the following cycle.
(= (retainHostReasonerInfluenceConfig $adapter $config)
    (let (HostReasonerInfluenceSetting $_ $active $_) (hostReasonerInfluenceSettingFor $adapter)
        (progn
            (change-state! &host-reasoner-influence-settings
                (cons-atom (HostReasonerInfluenceSetting $adapter $active $config)
                    (filter-atom (get-state &host-reasoner-influence-settings) $row (!= (index-atom $row 1) $adapter))))
            (change-state! &selection-advice-hook hostReasonerAdvisory)
            (change-state! &host-reasoner-advisory-hook hostReasonerAdvisory) True)))

;; Promote a pending setting only at a later native cycle in the same session.
;; Example: an initial zero cap may be declared before a session exists.
(= (activateHostReasonerInfluence $context)
    (if (or (== (get-state &host-reasoner-influence-context) $context)
            (hostReasonerModeAlreadyObserved $context)) True
        (progn
            (change-state! &host-reasoner-influence-context $context)
            (change-state! &host-reasoner-influence-settings
                (map-atom (get-state &host-reasoner-influence-settings) $setting
                    (let (HostReasonerInfluenceSetting $adapter $active $pending) $setting
                        (if (== $pending ()) $setting
                            (case ($context (index-atom $pending 7)) (
                                (((OperationContext $session $cycle $_) (OperationContext $session $queued $_))
                                    (if (> $cycle $queued) (HostReasonerInfluenceSetting $adapter $pending ()) $setting))
                                (($_ ()) (HostReasonerInfluenceSetting $adapter $pending ()))
                                ($_ $setting)))))))
            (change-state! &host-reasoner-influence-view ())
            (change-state! &host-reasoner-influence-trace ()) True))
)

;; Match prediction syntax without interpreting an opaque prediction as an expression.
;; Example: an atom or empty prediction cannot match a calibrated constructor.
(= (hostReasonerPredictionSchemaMatches $prediction $schema)
    (if (and (== (get-metatype $prediction) Expression) (!= $prediction ()))
        (== (repr (car-atom $prediction)) $schema) False))

;; Retain one maximum-confidence proposal per native candidate and calibrated schema.
;; Example: repeated agreeing proposals cannot accumulate voting weight.
(= (hostReasonerBestAdvice $candidate $entries $schema)
    (let $matches (filter-atom $entries $entry
        (let (HostReasonerProposalAdmission $envelope $decision $_) $entry
            (tpAllTrue (
                (== (getStatus $decision) Accepted)
                (== (getCandidate $decision) $candidate)
                (== (getProposalKind (mrcValue $envelope 4)) propose-candidate)
                (hostReasonerPredictionSchemaMatches
                    (getProposalPrediction (mrcValue $envelope 4)) $schema)))))
        (hostReasonerBestAdviceLoop $matches ()))
)

;; Stable maximum preserves the original proposal when confidences tie.
;; Example: two identical proposals have exactly the first proposal's contribution.
(= (hostReasonerBestAdviceLoop $entries $best)
    (if (== $entries ()) $best
        (let* (
            (($head $tail) (decons-atom $entries))
            ($confidence (getProposalConfidence (mrcValue (index-atom $head 1) 4)))
            ($replace (if (== $best ()) True
                (> $confidence (getProposalConfidence (mrcValue (index-atom $best 1) 4)))))
        ) (hostReasonerBestAdviceLoop $tail (if $replace $head $best)))))

;; Freeze advice only after native scheduling has fixed the winning class.
;; Example: advice for a lower class or a non-native candidate receives no weight.
(= (prepareHostReasonerInfluence $bundle $actions)
    (let $adapter (hostReasonerSelection)
        (case ((hostReasonerCycleFor (get-state &operation-context))
                (hostReasonerInfluenceSettingFor $adapter)) (
            (((HostReasonerCycle $context $invocation $_ $_ $_ $_)
                (HostReasonerInfluenceSetting $_ (HostReasonerInfluenceConfig $_ $configuration $cap $_ $route $_ $_) $_))
                (if (and (hostReasonerStageEnabledFor $adapter influence)
                        (and (> $cap 0) (and (== $configuration (mrcValue $invocation 4))
                            (hostReasonerAdmissionCurrent $invocation $bundle))))
                    (let* (
                        ($batches (filter-atom (hostReasonerAdmissions) $row (== (index-atom $row 2) (mrcValue $invocation 1))))
                        ($entries (if (== $batches ()) () (index-atom (car-atom $batches) 3)))
                        ($names (hostReasonerDistinctReferences (map-atom $actions $action (actionId $action))))
                        ($weights (map-atom $names $candidate
                            (let $best (hostReasonerBestAdvice $candidate $entries (mrcValue $route 3))
                                (if (== $best ()) ()
                                    (let (HostReasonerProposalAdmission $e $_ $op) $best
                                        (HostReasonerAdviceWeight $candidate (getProposalConfidence (mrcValue $e 4)) $e $op))))))
                        ($present (filter-atom $weights $row (!= $row ())))
                        ($setting (hostReasonerInfluenceSettingFor $adapter))
                        ($profile (index-atom $setting 2))
                    )
                        (progn (change-state! &host-reasoner-influence-view
                            (HostReasonerInfluenceView $context $invocation $profile $present)) True))
                    True))
            ($_ True))))
)

;; Snapshot ownership/freshness must still match; absent or stale advice is native behavior.
;; Example: publishing a different bundle cannot reuse an earlier contribution.
(= (hostReasonerInfluenceViewFor $bundle)
    (case (get-state &host-reasoner-influence-view) (
        ((HostReasonerInfluenceView $context $invocation $profile $weights)
            (if (and (== $context (get-state &operation-context)) (hostReasonerAdmissionCurrent $invocation $bundle))
                (HostReasonerInfluenceView $context $invocation $profile $weights) ()))
        ($_ ()))))

;; Allocate one aggregate cap across distinct candidates; confidence never counts votes.
;; Example: two unit-confidence candidates receive at most half the cap each.
(= (hostReasonerInfluenceBonus $view $candidate)
    (case $view (
        ((HostReasonerInfluenceView $_ $_ $profile $weights)
            (let* (
                ($rows (filter-atom $weights $row (== (index-atom $row 1) $candidate)))
                ($sum (sum (map-atom $weights $row (index-atom $row 2))))
                ($denominator (if (> $sum 1) $sum 1))
            )
                (if (== $rows ()) 0
                    (/ (* (index-atom $profile 3) (* (index-atom $profile 4) (index-atom (car-atom $rows) 2)))
                        $denominator))))
        ($_ 0)))
)

;; Keep zero exact; positive scores remain in the native normalized domain.
;; Example: a saturated native score cannot be inflated above one.
(= (hostReasonerInfluencedScore $bundle $action $native)
    (let $bonus (hostReasonerInfluenceBonus (hostReasonerInfluenceViewFor $bundle) (actionId $action))
        (if (== $bonus 0) $native (clampValue (+ $native $bonus)))))

;; Score only the already admitted class and preserve strict greater-than tie breaking.
;; Example: equal adjusted scores leave the first native action selected.
(= (hostReasonerInfluenceWinner $rows $best)
    (if (== $rows ()) (index-atom $best 1)
        (let ($head $tail) (decons-atom $rows)
            (hostReasonerInfluenceWinner $tail
                (if (> (index-atom $head 4) (index-atom $best 4)) $head $best)))))

;; First decision call is the actual transition; later bimonad probes cannot overwrite it.
;; Example: native and advised winners are compared at the same state before counter updates.
(= (chooseHostReasonerInfluencedAction $bundle $state $actions $native)
    (let $view (hostReasonerInfluenceViewFor $bundle)
        (if (== $view ()) $native
            (let* (
                ($scores (map-atom $actions $action
                    (let* (
                        ($score (omegaclawScoreForBundle $bundle $state $action))
                        ($total (hostReasonerInfluencedScore $bundle $action $score))
                    ) (HostReasonerInfluenceScore $action $score (- $total $score) $total
                        (filter-atom (index-atom $view 4) $row (== (index-atom $row 1) (actionId $action)))))))
                ($chosen (hostReasonerInfluenceWinner (cdr-atom $scores) (car-atom $scores)))
                ((HostReasonerInfluenceView $context $invocation $profile $_) $view)
            )
                (progn
                    (if (== (get-state &host-reasoner-influence-trace) ())
                        (change-state! &host-reasoner-influence-trace
                            (HostReasonerInfluenceTrace $context $invocation $profile $scores $native $chosen $state)) True)
                    $chosen))))
)

;; Retain exact operation/ticket attribution once; diagnostics are bounded by intake limits.
;; Example: an unrelated final decision cannot adopt a bimonad probe's trace.
(= (retainHostReasonerInfluenceDecision $decision)
    (case (get-state &host-reasoner-influence-trace) (
        ((HostReasonerInfluenceTrace $context $invocation $_ $_ $_ $chosen $_)
            (if (and (== (index-atom $decision 1) $context) (== (index-atom $decision 2) (actionId $chosen)))
                (let* (
                    ($prior (filter-atom (get-state &host-reasoner-influence-decisions) $row (== (index-atom $row 1) $decision)))
                    ($trace (get-state &host-reasoner-influence-trace))
                    ($record (quote (HostReasonerInfluenceDecision $decision $trace)))
                    ($limits (mrcValue $invocation 12))
                )
                    (if (!= $prior ()) True
                        (if (and (< (size-atom (get-state &host-reasoner-influence-decisions)) (mrcValue $limits 4))
                                (>= (reasonerProposalDataRemaining (quote $record) 32 (* 2 (mrcValue $limits 2))) 0))
                            (progn (change-state! &host-reasoner-influence-decisions
                                (cons-atom $record (get-state &host-reasoner-influence-decisions))) True)
                            (ReasonerRuntimeError AuditLimit))))
                (ReasonerRuntimeError SelectionMismatch)))
        ($_ True)))
)

;; Link the actual maximum contributor; agreement alone never becomes changed-selection credit.
;; Example: influence that preserves the native winner is explicitly AdvisoryAgreement.
(= (hostReasonerInfluencePrimary $invocation $decision $matches)
    (let $records (filter-atom (get-state &host-reasoner-influence-decisions) $row (== (index-atom $row 1) $decision))
        (case $records (
            (((HostReasonerInfluenceDecision $_ (HostReasonerInfluenceTrace $_ $retained $_ $scores $native $chosen $_)))
                (let* (
                    ($rows (filter-atom $scores $row (== (actionId (index-atom $row 1)) (index-atom $decision 2))))
                    ($contributors (index-atom (car-atom $rows) 5))
                )
                    (if (== $contributors ()) True
                        (let* (
                            ((HostReasonerAdviceWeight $_ $_ $envelope $op) (car-atom $contributors))
                            ($eligible (filter-atom $matches $entry (== (index-atom $entry 1) $envelope)))
                            ($label (if (== $native $chosen) AdvisoryAgreement AdvisoryChangedSelection))
                        )
                            (if (or (!= $retained $invocation) (== $eligible ())) NoPrimaryAttribution
                                (quote (HostReasonerPrimary $envelope $op $label)))))))
            (() (if (== (get-state &host-reasoner-influence-trace) ()) True NoPrimaryAttribution))
            ($_ NoPrimaryAttribution))))
)

;; One optional host/application hook owns lifecycle, scoring and retained attribution.
;; Example: zero/disabled influence needs no separate selector or dispatcher.
(= (hostReasonerAdvisory $stage $payload)
    (case ($stage $payload) (
        ((Begin $context) (activateHostReasonerInfluence $context))
        ((Prepare ($bundle $actions)) (prepareHostReasonerInfluence $bundle $actions))
        ((Choice ($bundle $state $actions $native)) (chooseHostReasonerInfluencedAction $bundle $state $actions $native))
        ((Score ($bundle $action $native)) (hostReasonerInfluencedScore $bundle $action $native))
        ((Retain $decision) (retainHostReasonerInfluenceDecision $decision))
        ((Primary ($invocation $decision $matches)) (hostReasonerInfluencePrimary $invocation $decision $matches))
        ($_ True)))
)
