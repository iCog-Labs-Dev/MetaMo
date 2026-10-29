;; Signal extraction and signal-to-appraisal conversion.
;; R2 / 2.2: production emits typed facts with host-resolved observation support.
;; The legacy read projection remains until appraisal and trigger migration.
!(import_prolog_function string_length)

;; Example: (fsContains (True False) True) -> True.
(= (fsContains $items $value)
    (!= (filter-atom $items $item (== $item $value)) ())
)

;; Example: (fsNumberIn 0.9 0 1) -> True; strings/booleans/nonfinite reject.
(= (fsNumberIn $value $lower $upper)
    (if (== (get-type $value) Number)
        (== (catch (and (>= $value $lower) (<= $value $upper))) True)
        False
    )
)

;; Example: (fsCount 2) -> True; a fractional count is invalid.
(= (fsCount $value)
    (if (fsNumberIn $value 0 9007199254740991)
        (== (floor-math $value) $value)
        False
    )
)

;; Example: (fsSession "session-A") -> True. Host ownership is checked in 2.2.
(= (fsSession $session)
    (if (== (get-type $session) String)
        (and (> (string_length $session) 0) (<= (string_length $session) 256))
        False
    )
)

;; Example: (fsReference (quote (SessionObservationRef "session-A" 17))) -> True.
(= (fsReference $reference)
    (case $reference (
        ((SessionObservationRef $session $sequence)
            (and (fsSession $session) (fsCount $sequence)))
        ($_ False)
    ))
)

;; Example: duplicate or mixed-session references cannot form one provenance set.
(= (fsReferencesAgree $references)
    (let* (
        ($session (index-atom (index-atom $references 0) 1))
        ($invalid (filter-atom $references $ref
            (or (!= (index-atom $ref 1) $session)
                (!= (size-atom (filter-atom $references $other (== $other $ref))) 1))))
    )
        (== $invalid ())
    )
)

;; Example: a signal cites 1..16 unique references, all from one session.
(= (fsReferenceList $references)
    (if (!= (get-metatype $references) Expression)
        False
        (let $count (size-atom $references)
            (if (and (> $count 0) (<= $count 16))
                (if (== (filter-atom $references $ref (fsReference $ref)) $references)
                    (fsReferencesAgree $references)
                    False
                )
                False
            )
        )
    )
)

;; Example: numeric ranges must be unique; boolean kinds have no numeric range.
(= (fsRangeValid $kind $type)
    (let $ranges (collapse (match &self (FactualSignalRange $kind $low $high) ($low $high)))
        (case ($type $ranges) (
            ((Boolean ()) True)
            ((Ratio ((0 1))) True)
            ((Quantity (($low $high)))
                (if (and (fsCount $low) (fsCount $high)) (<= $low $high) False))
            ($_ False)
        ))
    )
)

;; Example: estimate is reserved for classifier ratios in the initial inventory.
(= (fsSpecValid $spec)
    (let (FactualSignalSpec $kind $type $unit $source) $spec
        (and (== (get-metatype $kind) Symbol)
            (and (fsContains
                    ((Boolean None observation) (Quantity count observation)
                     (Ratio classifier-score estimate)) ($type $unit $source))
                (fsRangeValid $kind $type)))
    )
)

;; Example: (factualSignalSpec danger) returns the unique declared classifier domain.
(= (factualSignalSpec $kind)
    (let $specs (collapse (match &self
            (FactualSignalSpec $kind $type $unit $source)
            (FactualSignalSpec $kind $type $unit $source)))
        (case $specs (
            (() (FactualSignalRejected UnknownSignalKind))
            (($spec) (if (fsSpecValid $spec) $spec (FactualSignalRejected InvalidSignalSpec)))
            ($_ (FactualSignalRejected InvalidSignalSpec))
        ))
    )
)

;; Example: numeric facts use the declared range and exact unit; no coercions.
(= (fsValueValid $kind $type $unit $value)
    (case ($type $value) (
        ((Boolean (BooleanFact $boolean)) (fsContains (True False) $boolean))
        ((Ratio (RatioFact $number $actual))
            (and (== $actual $unit) (fsNumberIn $number 0 1)))
        ((Quantity (QuantityFact $number $actual))
            (let ($low $high) (match &self (FactualSignalRange $kind $low $high) ($low $high))
                (and (== $actual $unit)
                    (and (fsCount $number) (fsNumberIn $number $low $high)))
            ))
        ($_ False)
    ))
)

;; Example: a well-formed reference is not proof that an observation exists.
(= (fsValidateFields $kind $value $references)
    (case (factualSignalSpec $kind) (
        ((FactualSignalSpec $kind $type $unit $source)
            (case ((fsValueValid $kind $type $unit $value) (fsReferenceList $references)) (
                ((False $_) (FactualSignalRejected InvalidSignalValue))
                ((True False) (FactualSignalRejected InvalidSignalProvenance))
                ((True True) (FactualSignalValid $type $unit $source))
            )))
        ($rejection $rejection)
    ))
)

;; Example: validateFactualSignal consumes quoted data with exact ordered fields.
;; It neither inserts into &signal-space nor resolves/authenticates provenance.
(= (validateFactualSignal $record)
    (if (not (is-ground $record))
        (FactualSignalRejected NonGroundSignal)
        (case $record (
            ((FactualSignal (kind $kind) (value $value) (provenance $references))
                (fsValidateFields $kind $value $references))
            ($_ (FactualSignalRejected InvalidSignalRecord))
        ))
    )
)

;; Example: (makeFactualSignal failure (quote (BooleanFact False)) refs).
;; Explicit False remains a record, while malformed data returns a rejection.
(= (makeFactualSignal $kind $value $references)
    (let* (
        ($record (FactualSignal (kind $kind) (value $value) (provenance $references)))
        ($validation (validateFactualSignal $record))
    )
        (case $validation (
            ((FactualSignalValid $_ $_ $_) $record)
            ($_ $validation)
        ))
    )
)

;; Example: field value returns (BooleanFact False), distinct from no record ().
;; Rejected records never expose partially validated fields.
(= (factualSignalField $field $record)
    (case (validateFactualSignal $record) (
        ((FactualSignalValid $_ $_ $_)
            (let (FactualSignal (kind $kind) (value $value) (provenance $refs)) $record
                (case $field (
                    (kind $kind)
                    (value $value)
                    (provenance $refs)
                    ($_ (FactualSignalRejected UnknownSignalField))
                ))
            ))
        ($rejection $rejection)
    ))
)

!(bind! &signal-space    (new-space))
!(bind! &appraisal-space (new-space))
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
        ((SignalRefreshReady $_) True)
        (LegacySignalCycle True)
        ($_ False))))

;; Example: clearing a cycle does not erase its retained factual diagnostics.
(= (clearSignals) (clearSpace &signal-space))

;; Temporary 2.3/2.4 adapter: old names/weights exist only in this read view.
;; Example: message-differs-from-task still appears as task-drift to old readers.
(= (legacySignalKind $kind)
    (case (collapse (match &self (FactualSignalLegacyKind $old $kind) $old)) (
        (() $kind)
        (($only) $only)
        ($_ InvalidSignalKind))))

;; Example: a false fact contributes no legacy presence; counts have no old reader.
(= (legacySignalView $record)
    (case $record (
        ((signal $_ $_) $record)
        ((FactualSignal (kind $kind) (value (BooleanFact True)) $_)
            (let $old (legacySignalKind $kind)
                (case (collapse (match &self (SignalStrength $old $weight) $weight)) (
                    (($weight) (signal $old $weight))
                    ($_ (empty))))))
        ((FactualSignal (kind $kind) (value (RatioFact $score classifier-score)) $_)
            (if (> $score 0) (signal $kind $score) (empty)))
        ($_ (empty)))))

;; Example: modes/appraisal consume a projection, never weighted producer records.
(= (getSignals)
    (collapse (let $record (match &signal-space $entry $entry)
        (legacySignalView $record))))

;; Legacy fixture API only; refreshSignals never calls it.
(= (addSignal $kind $strength)
    (progn
        (collapse (let $entry (match &signal-space $entry $entry)
            (case $entry (
                ((signal $kind $_) (remove-atom &signal-space $entry))
                ((FactualSignal (kind $actual) $_ $_)
                    (if (== (legacySignalKind $actual) $kind)
                        (remove-atom &signal-space $entry) (empty)))
                ($_ (empty))))))
        (add-atom &signal-space (signal $kind $strength))))

(= (hasSignal $kind)
    (!= (filter-atom (getSignals) $row (== (index-atom $row 1) $kind)) ()))
(= (hasErrors) (or (hasSignal failure) (hasSignal repeated-failure)))
(= (hasResults) (or (hasSignal progress-made) (hasSignal verified-success)))

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
                ($others (filter-atom $rows $row (!= (index-atom $row 1) execution-request)))
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
        (case (eval (hostSignalInput (quote $bundle))) (
            ((FactualSignalRejected $reason) (rejectSignalRefresh (FactualSignalRejected $reason)))
            ($admitted (refreshSignalsForObservation $admitted))))))

;; Convert the current signals into the six appraisal dimensions.
(= (signalDimContrib $kind $strength $dim)
   (let $weights (collapse (match &self (SignalAppraisal $kind $dim $w) $w))
      (if (== $weights ()) 0.0 (* $strength (car-atom $weights)))))

(= (sumDimFromSignals $dim () $acc) $acc)
(= (sumDimFromSignals $dim $signals $acc)
   (let* (
      (($head $tail) (decons-atom $signals))
      ((signal $kind $strength) $head)
      ($contrib (signalDimContrib $kind $strength $dim))
   )
      (sumDimFromSignals $dim $tail (+ $acc $contrib))))

(= (computeDimension $dim)
   (let $signals (getSignals)
      (clampValue (sumDimFromSignals $dim $signals 0.0))))

(= (computeAllDimensions)
   (let* (
      ($novelty (computeDimension novelty))
      ($risk (computeDimension risk))
      ($importance (computeDimension importance))
      ($uncertainty (computeDimension uncertainty))
      ($opportunity (computeDimension opportunity))
      ($progress (computeDimension progress))
      ($_ (add-atom &appraisal-space (appraisal novelty $novelty)))
      ($_ (add-atom &appraisal-space (appraisal risk $risk)))
      ($_ (add-atom &appraisal-space (appraisal importance $importance)))
      ($_ (add-atom &appraisal-space (appraisal uncertainty $uncertainty)))
      ($_ (add-atom &appraisal-space (appraisal opportunity $opportunity)))
      ($_ (add-atom &appraisal-space (appraisal progress $progress)))
   ) True))
