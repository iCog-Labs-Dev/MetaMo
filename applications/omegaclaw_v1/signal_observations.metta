;; Trusted, session-only observation publication. No execution or policy grants.
;; Loaded after operation_selection; functions inspect command-bearing data quoted.
!(bind! &signal-observation-state (new-state (SignalObservationState "local-signals" 0 ())))
!(bind! &signal-feedback-reference (new-state None))
!(bind! &signal-recovery-reference (new-state None))
!(bind! &signal-previous-view (new-state NoSignalObservations))
!(bind! &signal-classifications (new-state ()))

;; Example: initOperationSession supplies its fresh UUID, never a reused counter.
(= (resetSignalObservations $session)
    (progn
        (clearSignals)
        (clearSpace &appraisal-space)
        (change-state! &signal-observation-state (SignalObservationState $session 0 ()))
        (change-state! &signal-observation-view NoSignalObservations)
        (change-state! &signal-previous-view NoSignalObservations)
        (change-state! &signal-feedback-reference None)
        (change-state! &signal-recovery-reference None)
        (change-state! &signal-classifications ())
        (change-state! &last-factual-signals ())
        (change-state! &last-mode-observation NoModeObservation)
        (change-state! &last-appraisal-contributions ())
        (change-state! &appraisal-status AppraisalReady)
        (change-state! &signal-last-legacy-reference None)
        (change-state! &signal-refresh-status LegacySignalCycle)
        True))

;; Example: changing current frame state cannot alter an already recorded owner.
(= (hostSignalOwner)
    (let (SignalObservationState $session $_ $_) (get-state &signal-observation-state)
        (SignalOwner $session (get-state &cfv2-current-frame-id) (commitmentSnapshot))))

;; Example: resolution preserves exact reference identity, including session.
(= (resolveSignalObservation $reference)
    (let* (
        ((SignalObservationState $_ $_ $entries) (get-state &signal-observation-state))
        ($matches (filter-atom $entries $entry (== (index-atom $entry 1) $reference)))
    )
        (case $matches (
            (($only) $only)
            ($_ (FactualSignalRejected MissingObservation))
        ))))

;; Example: capacity/counter failure changes no store entries or sequence.
(= (hostAllocateSignalSource $session $next $entries $owner $source $support)
    (if (not (and (fsSession $session) (fsCount $next)))
        (FactualSignalRejected InvalidObservationState)
        (if (and (< $next 9007199254740991) (< (size-atom $entries) 512))
        (let* (
            ($reference (SessionObservationRef $session $next))
            ($entry (SourceObservation $reference $owner $source $support))
            ($_ (change-state! &signal-observation-state
                (SignalObservationState $session (+ $next 1) (cons-atom $entry $entries))))
        ) $reference)
        (FactualSignalRejected ObservationCapacity))))

;; Example: attach provenance without changing the five-field bundle shape.
(= (signalBundleWithView $bundle $view)
    (let (FrameStateBundle $root $current $index $relations (runtime $runtime)) $bundle
        (let $fields (filter-atom (cdr-atom $runtime) $field
                (!= (car-atom $field) signal-observations))
            (FrameStateBundle $root $current $index $relations
                (runtime (cons-atom FrameStateRuntime
                    (cons-atom (signal-observations $view) $fields)))))))

;; Example: current and previous publications retain their own source roots.
(= (signalViewReferences $view)
    (case $view (
        ((SignalObservationView $snapshot $feedback $recovery)
            (filter-atom ($snapshot $feedback $recovery) $ref (fsReference $ref)))
        ($_ ()))))

;; Example: classifier scores are validated estimates, never executable atoms.
(= (hostSemanticRowValid $row)
    (case $row (
        ((signal $kind $score)
            (and (fsContains (danger user-angry execution-request) $kind)
                (fsNumberIn $score 0 1)))
        ($_ False))))

;; Example: duplicate publication returns the original reference without allocation.
(= (hostRecordSignalSource $owner $source $support)
    (let* (
        ((SignalObservationState $session $next $entries) (get-state &signal-observation-state))
        ($same (filter-atom $entries $entry
            (let (SourceObservation $_ $actualOwner $actualSource $actualSupport) $entry
                (== ($owner $source $support) ($actualOwner $actualSource $actualSupport)))))
    )
        (case $same (
            (($only) (index-atom $only 1))
            (() (hostAllocateSignalSource $session $next $entries $owner $source $support))
            ($_ (FactualSignalRejected ConflictingObservation))
        ))))

;; Example: the base value is stable across projection and source resolution.
(= (signalBundleBase $bundle) (signalBundleWithView $bundle NoSignalObservations))

;; Example: retain only bounded live roots; old session observations expire explicitly.
(= (pruneSignalObservations)
    (let* (
        ((SignalObservationState $session $next $entries) (get-state &signal-observation-state))
        ($views ((get-state &signal-observation-view) (get-state &signal-previous-view)))
        ($viewRoots (collapse (let* (
            ($view (superpose $views)) ($refs (signalViewReferences $view)))
            (superpose $refs))))
        ($facts (lastFactualSignals))
        ($diagnosticRoots (collapse (let* (
            ($fact (superpose $facts)) ($refs (factualSignalField provenance $fact)))
            (superpose $refs))))
        ($trace (lastAppraisalContributions))
        ($traceRoots (collapse (let* (
            ($row (superpose $trace)) ($refs (index-atom (index-atom $row 6) 1)))
            (superpose $refs))))
        ($modeFacts (case (get-state &last-mode-observation) (
            ((ModeObservation $_ $_ $signals $_ $_ $_) $signals)
            ($_ ()))))
        ($modeRoots (collapse (let* (
            ($fact (superpose $modeFacts)) ($refs (factualSignalField provenance $fact)))
            (superpose $refs))))
        ($roots (union-atom $viewRoots
            (union-atom $diagnosticRoots (union-atom $traceRoots $modeRoots))))
        ($pins (cons-atom (get-state &signal-feedback-reference)
            (cons-atom (get-state &signal-recovery-reference) $roots)))
        ($kept (filter-atom $entries $entry
            (or (fsContains $pins (index-atom $entry 1))
                (case (index-atom $entry 3) (
                    ((ClassifierObservation $snapshot $_ $_ $_) (fsContains $roots $snapshot))
                    ($_ False))))))
    )
        (change-state! &signal-observation-state (SignalObservationState $session $next $kept))))

;; Example: outcome support must belong to the publication's exact current owner.
(= (hostSignalReferenceForOwner $reference $owner)
    (case (resolveSignalObservation $reference) (
        ((SourceObservation $reference $actual $_ $_)
            (if (== $actual $owner) $reference None))
        ($_ None))))

;; Example: Failure must resolve to the consumed failure, not formatted results.
(= (hostSignalFeedbackValid $bundle)
    (let (SignalObservationView $_ $feedback $recovery) (frameRuntimeSignalObservations $bundle)
        (and
            (case (frameRuntimeOperationFeedback $bundle) (
                (LegacyFeedback True)
                ((OperationFeedback NoOutcome $streak) (and (== $feedback None) (fsCount $streak)))
                ((OperationFeedback $status $streak)
                    (case (resolveSignalObservation $feedback) (
                        ((SourceObservation $_ $_ (ConsumedOutcome $_ $status $streak) $_) True)
                        ($_ False))))
                ($_ False)))
            (if (!= (frameRuntimeRecovery $bundle) RecoveryPending) True
                (case (resolveSignalObservation $recovery) (
                    ((SourceObservation $_ $_ (ConsumedOutcome $_ Failure $_) $_) True)
                    ($_ False)))))))

;; Example: unknown kinds, duplicate kinds or malformed lists reject the entire response.
(= (hostSemanticListValid $rows)
    (if (!= (get-metatype $rows) Expression) False
        (if (> (size-atom $rows) 3) False
            (if (== (filter-atom $rows $row (hostSemanticRowValid $row)) $rows)
                (== (filter-atom $rows $row
                    (!= (size-atom (filter-atom $rows $other
                        (== (index-atom $row 1) (index-atom $other 1)))) 1)) ())
                False))))

;; Example: legacy predicates reuse publication-time inputs on a snapshot reread.
(= (hostSignalLegacyPrior $bundle)
    (let (SignalObservationView $snapshot $_ $_) (frameRuntimeSignalObservations $bundle)
        (case (resolveSignalObservation $snapshot) (
            ((SourceObservation $_ $_ (LegacyTextObservation $_ $results $streak) $_)
                (LegacyPrior $results $streak))
            ($_ (LegacyPrior "" 0))))))

;; Example: a cached score cannot borrow another publication's classifier record.
(= (hostCheckedClassifications $snapshot $result)
    (case $result (
        ((FactualSignalRejected $_) $result)
        ((ClassifierResults $ref $confirmation $semantics)
            (case (resolveSignalObservation $ref) (
                ((SourceObservation $ref $_
                    (ClassifierObservation $snapshot $_ $confirmation $semantics) ($snapshot)) $result)
                ($_ (FactualSignalRejected MismatchedClassifierObservation)))))
        ($_ (FactualSignalRejected InvalidClassifierObservation)))))

;; Example: only the existing validated, one-shot consumption path calls this.
;; Preserve exact decision/ticket/status, not a copy of potentially unbounded file data.
(= (recordSignalOutcome $outcome)
    (let* (
        ((OperationOutcome $decision $_ $status $_) $outcome)
        ($reference (hostRecordSignalSource (get-state &selected-signal-owner)
            (ConsumedOutcome $decision $status (get-state &operation-failure-streak)) ()))
        ($_ (change-state! &signal-feedback-reference $reference))
    )
        (case $status (
            (Failure (change-state! &signal-recovery-reference $reference))
            ($_ True)
        ))))

;; Example: publication happens after feedback bookkeeping and before mode regulation.
(= (publishSignalObservations $bundle)
    (let* (
        ($owner (hostSignalOwner))
        ($_ (if (== (frameRuntimeRecovery $bundle) RecoveryPending) True
            (change-state! &signal-recovery-reference None)))
        ($_ (pruneSignalObservations))
        ($feedback (hostSignalReferenceForOwner (get-state &signal-feedback-reference) $owner))
        ($recovery (hostSignalReferenceForOwner (get-state &signal-recovery-reference) $owner))
        ($base (signalBundleBase $bundle))
        ($source (if (operationFeedbackEnabled)
            (HostBundleObservation (get-state &operation-context) $base)
            (LegacyTextObservation $base (get-state &last-results-seen) (get-state &failure-streak))))
        ($support (filter-atom ($feedback $recovery) $ref (fsReference $ref)))
        ($snapshot (hostRecordSignalSource $owner $source $support))
    )
        (if (fsReference $snapshot)
            (let* (
                ($view (SignalObservationView $snapshot $feedback $recovery))
                ($_ (change-state! &signal-previous-view (get-state &signal-observation-view)))
                ($_ (change-state! &signal-observation-view $view))
            ) (signalBundleWithView $bundle $view))
            (signalBundleWithView $bundle $snapshot))))

;; Example: a changed bundle cannot reuse another publication's provenance.
(= (signalObservationBundleValid $bundle $reference)
    (let* (
        ((SignalObservationView $_ $feedback $recovery) (frameRuntimeSignalObservations $bundle))
        ($support (filter-atom ($feedback $recovery) $ref (fsReference $ref)))
    )
        (case (resolveSignalObservation $reference) (
            ((SourceObservation $reference $_ (HostBundleObservation $_ $base) $actual)
                (and (== $base (signalBundleBase $bundle)) (== $support $actual)))
            ((SourceObservation $reference $_ (LegacyTextObservation $base $_ $_) $actual)
                (and (== $base (signalBundleBase $bundle)) (== $support $actual)))
            ($_ False)))))

;; Example: classifier provenance records the actual scores and producing snapshot.
(= (hostRecordClassifications $bundle $snapshot $provider $confirmation $semantics)
    (if (and (fsNumberIn $confirmation 0 1) (hostSemanticListValid $semantics))
        (let* (
            ((SourceObservation $_ $owner $_ $_) (resolveSignalObservation $snapshot))
            ($reference (hostRecordSignalSource $owner
                (ClassifierObservation $snapshot $provider $confirmation $semantics) ($snapshot)))
        )
            (if (fsReference $reference)
                (ClassifierResults $reference $confirmation $semantics)
                $reference))
        (FactualSignalRejected InvalidClassifierObservation)))
;; Example: only unmanaged legacy fixtures may explicitly adopt a bare text bundle.
(= (hostSignalInput $bundle)
    (case (frameRuntimeSignalObservations $bundle) (
        (NoSignalObservations
            (if (operationFeedbackEnabled) (FactualSignalRejected MissingObservation)
                (publishSignalObservations $bundle)))
        ((SignalObservationView $snapshot $_ $_)
            (if (and (signalObservationBundleValid $bundle $snapshot)
                     (hostSignalFeedbackValid $bundle)) $bundle
                (FactualSignalRejected MismatchedObservation)))
        ($_ (FactualSignalRejected InvalidSignalProvenance)))))

;; Example: classifier data stays inert; the configured provider is recorded.
(= (hostCaptureClassifications $bundle $snapshot)
    (let* (
        ($provider (provider))
        ($input (frameRuntimeText (frameRuntimeMessage $bundle)))
        ($task (frameRuntimeText (frameRuntimeActiveTask $bundle)))
        ($new (frameRuntimeNewMessage $bundle))
        ($confirmation (if $new (catch (py-call
            (lib_llm_ext.executionConfirmationScore $provider $input $task))) 0))
        ($semantics (if $new (catch (sread (py-call
            (lib_llm_ext.extractSemantics $provider $input)))) ()))
        ($result (hostRecordClassifications $bundle $snapshot $provider $confirmation $semantics))
        ($retained (filter-atom (get-state &signal-classifications) $row
            (fsReference (index-atom $row 1))))
        ;; Two retained publications, bounded independently of request count.
        ($_ (change-state! &signal-classifications
            (cons-atom (SignalClassifications $snapshot $result)
                (if (== $retained ()) () ((car-atom $retained))))))
    ) $result))

;; Example: retained diagnostic sources can be read after the small call cache rotates.
(= (hostExistingClassifications $bundle $snapshot)
    (let* (
        ((SignalObservationState $_ $_ $entries) (get-state &signal-observation-state))
        ($matches (filter-atom $entries $entry
            (case (index-atom $entry 3) (
                ((ClassifierObservation $snapshot $_ $_ $_) True)
                ($_ False)))))
    )
        (case $matches (
            (($only) (let (SourceObservation $ref $_ (ClassifierObservation $_ $_ $score $rows) $_) $only
                (ClassifierResults $ref $score $rows)))
            (() (if (== (frameRuntimeSignalObservations $bundle) (get-state &signal-observation-view))
                (hostCaptureClassifications $bundle $snapshot)
                (FactualSignalRejected ExpiredClassifierObservation)))
            ($_ (FactualSignalRejected ConflictingObservation))))))

;; Example: providers are queried once for a retained publication, including idle.
(= (hostSignalClassifications $bundle)
    (let* (
        ((SignalObservationView $snapshot $_ $_) (frameRuntimeSignalObservations $bundle))
        ($cached (filter-atom (get-state &signal-classifications) $row
            (== (index-atom $row 1) $snapshot)))
    )
        (case $cached (
            (($only) (hostCheckedClassifications $snapshot (index-atom $only 2)))
            ($_ (hostExistingClassifications $bundle $snapshot))
        ))))

;; Example: provenance resolves to retained sources in the publication's owner.
(= (hostSignalFactSupported $bundle $fact)
    (let* (
        ((SignalObservationView $snapshot $_ $_) (frameRuntimeSignalObservations $bundle))
        ((SourceObservation $_ $owner $_ $_) (resolveSignalObservation $snapshot))
        ((FactualSignal $_ $_ (provenance $references)) $fact)
        ($invalid (filter-atom $references $ref
            (!= (hostSignalReferenceForOwner $ref $owner) $ref)))
        ($expected (union-atom (produceRuntimeSignalFacts $bundle)
            (produceClassifierSignalFacts (hostSignalClassifications $bundle))))
    )
        (and (== $invalid ()) (fsContains $expected $fact))))
