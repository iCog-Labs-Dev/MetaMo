;; Signal extraction and signal-to-appraisal conversion.
;; R2 / 2.3: production facts are appraised directly with explicit registry rules.
;; Mode, scheduling, lifecycle and appraisal consumers all read the same typed facts.
!(bind! &signal-space    (new-space))
!(bind! &appraisal-space (new-space))
;; Shared retained cycle diagnostics are rooted by the session source store.
!(bind! &last-mode-observation (new-state NoModeObservation))
!(bind! &last-appraisal-contributions (new-state ()))
!(bind! &appraisal-status (new-state AppraisalReady))
!(bind! &failure-streak  (new-state 0))

!(bind! &new-msg-flag (new-state False))
!(bind! &last-results-seen (new-state ""))


(= (hasTextContent $value)
   (> (eval (string_length (eval (string-safe $value)))) 2))

;; Producer data occupies the existing signal space. These local slots are diagnostics.
!(bind! &signal-refresh-status (new-state LegacySignalCycle))
!(bind! &last-factual-signals (new-state ()))
!(bind! &signal-last-legacy-reference (new-state None))

;; Example: typed output remains inspectable after the bridge clears transient signals.
(= (getFactualSignals)
    (collapse (match &signal-space
        (FactualSignal (kind $kind) (value $value) (provenance $refs))
        (FactualSignal (kind $kind) (value $value) (provenance $refs)))))

(= (lastFactualSignals) (get-state &last-factual-signals))
(= (signalRefreshStatus) (get-state &signal-refresh-status))
(= (signalCycleReady)
    (case (signalRefreshStatus) (
        ((SignalRefreshReady $_) (== (get-state &appraisal-status) AppraisalReady))
        (LegacySignalCycle (== (get-state &appraisal-status) AppraisalReady))
        ($_ False))))

;; Example: clearing a cycle does not erase its retained factual diagnostics.
(= (clearSignals) (clearSpace &signal-space))

;; Example: explicit False remains in the public typed signal snapshot.
(= (getSignals) (getFactualSignals))

;; Example: (signalFact failure) returns its typed record or explicit absence.
(= (signalFact $kind) (signalFactIn (getSignals) $kind))
(= (signalTrue $kind) (signalTrueIn (getSignals) $kind))
(= (signalRatioAtLeast $kind $threshold)
    (signalRatioAtLeastIn (getSignals) $kind classifier-score $threshold))
(= (signalQuantityAtLeast $kind $unit $threshold)
    (signalQuantityAtLeastIn (getSignals) $kind $unit $threshold))
(= (signalProvenance $kind) (signalProvenanceIn (getSignals) $kind))

;; Example: False failure and progress records do not imply errors or results.
(= (hasErrors) (or (signalTrue failure) (signalTrue repeated-failure)))
(= (hasResults) (or (signalTrue progress-made) (signalTrue verified-success)))

;; Example: a repeat threshold counts actual consumed failures, not importance.
(= (signalThreshold $key $default)
    (case (collapse (match &self (SignalThreshold $key $value) $value)) (
        (($only) $only)
        ($_ $default))))

;; Example: no malformed source can partially publish signals or retain old facts.
(= (rejectSignalRefresh $reason)
    (progn
        (clearSignals)
        (change-state! &last-factual-signals ())
        (change-state! &last-appraisal-contributions ())
        (change-state! &signal-refresh-status $reason)
        $reason))

;; Example: boolean predicate false is explicit data, not an absent observation.
(= (signalBoolean $kind $value $refs)
    (FactualSignal (kind $kind) (value (BooleanFact $value)) (provenance $refs)))

;; Example: a factual reference set preserves the publication and consumed outcome.
(= (signalFactReferences $snapshot $additional)
    (if (fsReference $additional) ($snapshot $additional) ($snapshot)))

;; Example: legacy text errors are recorded predicates, never verified Core outcomes.
;; Re-reading one observation cannot increment the compatibility streak again.
(= (refreshSignalStreak $bundle $snapshot)
    (case (frameRuntimeOperationFeedback $bundle) (
        ((OperationFeedback $_ $streak) (change-state! &failure-streak $streak))
        (LegacyFeedback
            (if (== $snapshot (get-state &signal-last-legacy-reference)) True
                (let (LegacyPrior $_ $priorStreak) (eval (hostSignalLegacyPrior (quote $bundle)))
                (progn
                    (change-state! &failure-streak
                        (if (bundle-runtime-has-error $bundle)
                            (+ $priorStreak 1) 0))
                    (change-state! &signal-last-legacy-reference $snapshot)))))
        ($_ False))))

;; Example: task predicates carry the captured snapshot, never semantic labels.
(= (produceTaskSignalFacts $bundle)
    (let* (
        ((SignalObservationView $snapshot $_ $_) (frameRuntimeSignalObservations $bundle))
        ($new (frameRuntimeNewMessage $bundle))
        ($message (frameRuntimeText (frameRuntimeMessage $bundle)))
        ($task (frameRuntimeText (frameRuntimeActiveTask $bundle)))
    )
        ((signalBoolean message-differs-from-task
            (and $new (and (frameRuntimeTaskOpen $bundle)
                (and (hasTextContent $task) (!= $message $task)))) ($snapshot))
         (signalBoolean user-waiting (and (hasTextContent $message) $new) ($snapshot))
         (signalBoolean frame-blocked (== (frameBundleCurrentStatus $bundle) Blocked) ($snapshot)))))

;; Example: typed outcomes govern progress; legacy text is explicitly identified.
(= (signalOutcomeConditions $bundle)
    (let* (
        ($operation (frameRuntimeOperationFeedback $bundle))
        ($results (frameRuntimeText (frameRuntimeResults $bundle)))
        ((LegacyPrior $priorResults $_) (eval (hostSignalLegacyPrior (quote $bundle))))
        ($success (case $operation (
            (LegacyFeedback (and (hasTextContent $results) (!= $results $priorResults)))
            ((OperationFeedback Success $_) True)
            ($_ False))))
        ($failure (case $operation (
            (LegacyFeedback (bundle-runtime-has-error $bundle))
            ((OperationFeedback Failure $_) True)
            ($_ False))))
    ) (SignalOutcomeConditions $success $failure)))

;; Example: pending recovery cites its original failure without recounting it.
(= (produceOutcomeSignalFacts $bundle)
    (let* (
        ((SignalObservationView $snapshot $feedback $recovery) (frameRuntimeSignalObservations $bundle))
        ((SignalOutcomeConditions $success $failure) (signalOutcomeConditions $bundle))
        ($streak (get-state &failure-streak))
        ($repeated (> $streak (signalThreshold failure-streak-repeat 1)))
        ($refs (signalFactReferences $snapshot $feedback))
    )
        ((signalBoolean repeated-failure (and $failure $repeated) $refs)
         (signalBoolean failure (and $failure (not $repeated)) $refs)
         (signalBoolean new-input-without-outcome
            (and (frameRuntimeNewMessage $bundle) (and (not $success) (not $failure))) ($snapshot))
         (signalBoolean progress-made (and $success (not $failure)) $refs)
         (signalBoolean stalled-progress
            (and (== (frameRuntimeRecovery $bundle) RecoveryPending) (not $failure))
            (signalFactReferences $snapshot $recovery))
         (FactualSignal (kind failure-streak) (value (QuantityFact $streak count)) (provenance $refs)))))

;; Example: runtime producers emit facts only, independent of appraisal weights.
(= (produceRuntimeSignalFacts $bundle)
    (union-atom (produceOutcomeSignalFacts $bundle) (produceTaskSignalFacts $bundle)))

;; Example: two request classifiers contribute once through the declared reducer.
(= (signalExecutionRequestScore $semantic $confirmation)
    (case (collapse (match &self (SignalReduction execution-request $rule) $rule)) (
        ((maximum) (if (> $semantic $confirmation) $semantic $confirmation))
        ($_ (FactualSignalRejected InvalidSignalReduction)))))

;; Example: the common classifier record retains semantic and confirmation scores.
(= (produceClassifierSignalFacts $result)
    (case $result (
        ((ClassifierResults $ref $confirmation $rows)
            (let* (
                ($intent (filter-atom $rows $row (== (index-atom $row 1) execution-request)))
                ($semantic (if (== $intent ()) 0 (index-atom (car-atom $intent) 2)))
                ($confirmed (if (> $confirmation 0.75) $confirmation 0))
                ($score (signalExecutionRequestScore $semantic $confirmed))
                ($others (filter-atom $rows $row
                    (and (!= (index-atom $row 1) execution-request) (> (index-atom $row 2) 0))))
                ($facts (map-atom $others $row
                    (let (signal $kind $value) $row
                        (FactualSignal (kind $kind) (value (RatioFact $value classifier-score))
                            (provenance ($ref))))))
            )
                (if (!= (get-type $score) Number) $score
                (if (> $score 0)
                    (cons-atom (FactualSignal (kind execution-request)
                        (value (RatioFact $score classifier-score)) (provenance ($ref))) $facts)
                    $facts))))
        ($_ $result))))

;; Example: publication validates every fact and resolves every producing reference.
(= (signalFactKindsUnique $facts)
    (== (filter-atom $facts $fact
        (!= (size-atom (filter-atom $facts $other
            (== (factualSignalField kind $fact) (factualSignalField kind $other)))) 1)) ()))

;; Example: the batch cannot duplicate one observation's appraisal influence.
(= (publishFactualSignalFacts $bundle $facts)
    (let $invalid (filter-atom $facts $fact
            (!= (case (validateFactualSignal $fact) (
                ((FactualSignalValid $_ $_ $_)
                    (eval (hostSignalFactSupported (quote $bundle) (quote $fact))))
                ($_ False))) True))
        (if (or (!= $invalid ()) (not (signalFactKindsUnique $facts)))
            (rejectSignalRefresh (FactualSignalRejected InvalidProducingObservation))
            (progn
                (map-atom $facts $fact (add-atom &signal-space $fact))
                (change-state! &last-factual-signals $facts)
                (change-state! &signal-refresh-status
                    (SignalRefreshReady (frameRuntimeSignalObservations $bundle)))
                (getSignals)))))

;; Example: one captured publication produces facts and once-only classifier results.
(= (refreshSignalsForObservation $bundle)
    (let* (
        ((SignalObservationView $snapshot $_ $_) (frameRuntimeSignalObservations $bundle))
        ($_ (refreshSignalStreak $bundle $snapshot))
        ($runtime (produceRuntimeSignalFacts $bundle))
        ($classifications (eval (hostSignalClassifications (quote $bundle))))
        ($semantic (produceClassifierSignalFacts $classifications))
    )
        (case $semantic (
            ((FactualSignalRejected $_) (rejectSignalRefresh $semantic))
            ($_ (let* (
                ($facts (union-atom $runtime $semantic))
                ($result (publishFactualSignalFacts $bundle $facts))
                ($_ (if (hasTextContent (frameRuntimeText (frameRuntimeResults $bundle)))
                    (change-state! &last-results-seen (frameRuntimeText (frameRuntimeResults $bundle))) True))
            ) $result))))))

;; Example: bad/missing managed provenance is a rejected cycle, never a clean idle cycle.
(= (refreshSignals $bundle)
    (progn
        (clearSignals)
        (change-state! &appraisal-status AppraisalReady)
        (case (eval (hostSignalInput (quote $bundle))) (
            ((FactualSignalRejected $reason) (rejectSignalRefresh (FactualSignalRejected $reason)))
            ($admitted (refreshSignalsForObservation $admitted))))))

;; Example: False is an explicit zero; counts have no appraisal rule yet.
(= (appraisalTransform $transform $value)
    (case ($transform $value) (
        ((BooleanIndicator (BooleanFact True)) 1)
        ((BooleanIndicator (BooleanFact False)) 0)
        ((IdentityRatio (RatioFact $score classifier-score)) $score)
        ($_ (AppraisalRejected InvalidAppraisalTransform)))))

;; Example: a negative progress coefficient is valid; duplicate rules reject.
(= (appraisalRuleValid $rule)
    (let (SignalAppraisalRule $kind $dim $transform $coefficient) $rule
        (and (fsContains (novelty risk importance uncertainty opportunity progress) $dim)
            (and (fsNumberIn $coefficient -1 1)
                (== (collapse (match &self
                    (SignalAppraisalRule $kind $dim $t $c)
                    (SignalAppraisalRule $kind $dim $t $c))) ($rule))))))

;; Example: the trace captures the rule by value, including a negative result.
(= (appraiseFactualRule $kind $value $refs $rule)
    (let (SignalAppraisalRule $kind $dim $transform $coefficient) $rule
        (case (appraisalRuleValid $rule) (
            (False (AppraisalRejected InvalidAppraisalRule))
            (True (let $input (appraisalTransform $transform $value)
                (if (== (get-type $input) Number)
                    (let $contribution (* $input $coefficient)
                        (AppraisalContribution (kind $kind) (dimension $dim)
                            (value $value) (rule $rule)
                            (contribution $contribution) (provenance $refs)))
                    $input)))))))

;; Example: failure True contributes 0.56 risk, without a SignalStrength lookup.
;; Publication already authenticates support; this function validates representation.
(= (appraiseFactualSignal $fact)
    (case (validateFactualSignal $fact) (
        ((FactualSignalValid $_ $_ $_)
            (let* (
                ((FactualSignal (kind $kind) (value $value) (provenance $refs)) $fact)
                ($rules (collapse (match &self (SignalAppraisalRule $kind $d $t $c)
                    (SignalAppraisalRule $kind $d $t $c))))
            )
                (map-atom $rules $rule (appraiseFactualRule $kind $value $refs $rule))))
        ($_ ((AppraisalRejected InvalidFactualSignal))))))

;; Example: each typed cycle record produces its declared contributions once.
(= (currentAppraisalContributions)
    (collapse (let* (
        ($entry (match &signal-space $record $record))
        ($rows (appraiseFactualSignal $entry))
    ) (superpose $rows))))

;; Example: diagnostics survive transient signal cleanup until the next appraisal.
(= (lastAppraisalContributions) (get-state &last-appraisal-contributions))
(= (appraisalStatus) (get-state &appraisal-status))

;; Example: sum numeric contributions without clamping each individual row.
(= (sumAppraisalValues () $sum) $sum)
(= (sumAppraisalValues $values $sum)
    (let ($head $tail) (decons-atom $values)
        (sumAppraisalValues $tail (+ $sum $head))))

;; Example: negative and positive contributions sum before the existing clamp.
(= (appraisalDimensionFromTrace $dim $trace)
    (let* (
        ($rows (filter-atom $trace $row (== (index-atom $row 2) (dimension $dim))))
        ($values (map-atom $rows $row (index-atom (index-atom $row 5) 1)))
    ) (clampValue (sumAppraisalValues $values 0.0))))

;; Example: invalid rules reject the whole appraisal, never leave partial weights.
(= (appraisalTraceRejection $trace)
    (filter-atom $trace $row
        (case $row (
            ((AppraisalRejected $_) True)
            ($_ False)))))

;; Example: computeDimension is a pure diagnostic read of the current facts.
(= (computeDimension $dim)
    (let $trace (currentAppraisalContributions)
        (case (appraisalTraceRejection $trace) (
            (() (appraisalDimensionFromTrace $dim $trace))
            ($errors (car-atom $errors))))))

;; Example: one snapshot of rules supplies all six dimensions and its retained trace.
(= (computeAllDimensions)
    (let* (
        ($trace (currentAppraisalContributions))
        ($errors (appraisalTraceRejection $trace))
        ($_ (clearSpace &appraisal-space))
        ($_ (change-state! &last-appraisal-contributions (if (== $errors ()) $trace ())))
        ($_ (change-state! &appraisal-status
            (if (== $errors ()) AppraisalReady (car-atom $errors))))
        ($_ (map-atom (novelty risk importance uncertainty opportunity progress) $dim
            (let $value (if (== $errors ()) (appraisalDimensionFromTrace $dim $trace) 0.0)
                (add-atom &appraisal-space (appraisal $dim $value)))))
    ) (== $errors ())))
