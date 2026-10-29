;; Signal extraction and signal-to-appraisal conversion.
;; R2 / 2.1 declares the future factual boundary without changing live producers.
;; Shape validation does not resolve observations or grant execution authority.

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

(= (clearSignals)
   (clearSpace &signal-space))

(= (addSignal $kind $strength)
   (let* (
      ($_ (collapse (let $old (match &signal-space (signal $kind $_) (signal $kind $_)) (remove-atom &signal-space $old))))
   )
   (add-atom &signal-space (signal $kind $strength))))

(= (getSignals)
   (collapse (match &signal-space (signal $kind $strength) (signal $kind $strength))))

(= (hasSignal $kind)
   (let $res (collapse (match &signal-space (signal $kind $_) True))
      (if (== $res ()) False True)))

(= (hasErrors)
   (or (hasSignal failure) (hasSignal repeated-failure)))

(= (hasResults)
   (or (hasSignal progress-made) (hasSignal verified-success)))


;; Returns the registered strength for a signal kind (fallback to default).
(= (signalStrength $kind $default)
   (let $v (collapse (match &self (SignalStrength $kind $s) $s))
      (if (== $v ()) $default (car-atom $v))))

;; Returns the registered threshold for a named check (fallback to default).
(= (signalThreshold $key $default)
   (let $v (collapse (match &self (SignalThreshold $key $t) $t))
      (if (== $v ()) $default (car-atom $v))))


;; refreshSignals
;; Extract typed signals from the bounded adapter projection.
(= (refreshSignals $bundle)
   (let* (
      ($_ (collapse (clearSignals)))
      ;; All OmegaClaw inputs arrive through the adapter projections.
      ($msg        (frameRuntimeText (frameRuntimeMessage $bundle)))
      ($activeTask (frameRuntimeText (frameRuntimeActiveTask $bundle)))
      ($taskOpen   (frameRuntimeTaskOpen $bundle))
      ($results    (frameRuntimeText (frameRuntimeResults $bundle)))
      ($error      (frameRuntimeText (frameRuntimeError $bundle)))
      ($isNewMsg   (frameRuntimeNewMessage $bundle))
      ($hasMsg     (hasTextContent $msg))
      ($hasResults (hasTextContent $results))
      ($feedback (frameRuntimeOperationFeedback $bundle))
      ($legacy (== $feedback LegacyFeedback))
      ($freshResults (if $legacy
                         (and $hasResults (!= $results (get-state &last-results-seen)))
                         (let (OperationFeedback $status $_) $feedback (== $status Success))))
      ($hasError (if $legacy (bundle-runtime-has-error $bundle)
                     (let (OperationFeedback $status $_) $feedback (== $status Failure))))
      ($resultsLen (eval (string_length (eval (string-safe $results)))))
      ($prov       (provider))
      ($confirmScore (if $isNewMsg
                         (py-call (lib_llm_ext.executionConfirmationScore $prov $msg $activeTask))
                         0.0))
      ($executionFollowup (and $isNewMsg (> $confirmScore 0.75)))

      ;; Concrete streaks advance once at publication, never on snapshot rereads.
      ($_ (if $legacy
              (if $hasError
                  (change-state! &failure-streak (+ (get-state &failure-streak) 1))
                  (change-state! &failure-streak 0))
              (let (OperationFeedback $_ $streak) $feedback
                 (change-state! &failure-streak $streak))))
      ($failureStreak (get-state &failure-streak))
      ($repeatThresh  (signalThreshold failure-streak-repeat 1))

      ;; 1. Repeated failure: multiple consecutive errors
      ($_ (if (and (> $failureStreak $repeatThresh) $hasError)
              (addSignal repeated-failure (signalStrength repeated-failure 0.85))
              _))

      ;; 2. Single failure (first error)
      ($_ (if (and $hasError (<= $failureStreak $repeatThresh))
              (addSignal failure (signalStrength failure 0.80))
              _))

      ;; 3. Task drift — only on a new message when topic changed
      ($_ (if (and $isNewMsg (and $taskOpen (and (hasTextContent $activeTask) (!= $msg $activeTask))))
              (addSignal task-drift (signalStrength task-drift 0.45))
              _))

      ;; 4. Ambiguity — new message with no results and no error
      ($_ (if (and $isNewMsg (and (not $freshResults) (not $hasError)))
              (addSignal ambiguity (signalStrength ambiguity 0.60))
              _))

      ;; 5. Progress made — skills executed and returned results without error.
      ($_ (if (and $freshResults (not $hasError))
              (addSignal progress-made (signalStrength progress-made 0.40))
              _))

      ;; 6. Unresolved host recovery keeps the recovery trigger active without
      ;; replaying a failure observation or incrementing the failure count.
      ;; A fresh task with no results is not evidence of stalled execution.
      ($_ (if (and (== (frameRuntimeRecovery $bundle) RecoveryPending) (not $hasError))
              (addSignal stalled-progress (signalStrength stalled-progress 0.35))
              _))

      ;; 7. User waiting — fires when a new message has arrived and awaits reply.
      ($_ (if (and $hasMsg $isNewMsg)
              (addSignal user-waiting (signalStrength user-waiting 0.30))
              _))

      ;; 8. Semantic extraction — only on new messages (skip LLM call on idle)
      ($_ (if $isNewMsg
              (collapse (let* (($semStr (py-call (lib_llm_ext.extractSemantics $prov $msg)))
                               ($semList (catch (sread $semStr))))
                          (if (and (!= $semList ()) (!= $semList (Error)))
                              (let $s (superpose $semList)
                                   (add-atom &signal-space $s))
                              (empty))))
              _))

      ;; Confirmation replies inherit semantic execution intent from the open
      ;; task instead of becoming generic chat.
      ($_ (if $executionFollowup
              (addSignal execution-request $confirmScore)
              _))

      ;; Task lifecycle belongs to ContextFrames. Signals only extract typed
      ;; facts from the bundle and must not update task runtime state.
      ($_ (if $hasResults
              (change-state! &last-results-seen $results)
              _))
   )
   (getSignals)))


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
   (let $signals
         (collapse (match &signal-space (signal $kind $strength)
                                        (signal $kind $strength)))
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
