;; Pure R2 representation validation and typed snapshot readers.
;; No state allocation, host publication, appraisal, mode updates or side effects.
;; Composition loads this before mode triggers and host context policy consumers.
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

;; Example: a unique shape-valid record is distinct from absence or corruption.
;; Producer publication authenticates support; these pure readers do not grant it.
(= (signalFactIn $signals $kind)
    (let $matches (filter-atom $signals $record
            (case $record (
                ((FactualSignal (kind $actual) $_ $_) (== $actual $kind))
                ($_ False))))
        (case $matches (
            (() (FactualSignalAbsent $kind))
            (($only) (case (validateFactualSignal $only) (
                ((FactualSignalValid $_ $_ $_) $only)
                ($rejection $rejection))))
            ($_ (FactualSignalRejected DuplicateSignalKind))))))

;; Example: observed False, unavailable data, and invalid data remain distinct.
(= (signalValueIn $signals $kind)
    (case (signalFactIn $signals $kind) (
        ((FactualSignal $_ (value $value) $_) $value)
        ((FactualSignalAbsent $_) NoObservation)
        ($rejection $rejection))))

;; Example: only an accepted record exposes references; absence has none.
(= (signalProvenanceIn $signals $kind)
    (case (signalFactIn $signals $kind) (
        ((FactualSignal $_ $_ (provenance $refs)) $refs)
        ($_ ()))))

;; Example: a false boolean record exists, but cannot trigger recovery.
(= (signalTrueIn $signals $kind)
    (== (signalValueIn $signals $kind) (BooleanFact True)))

;; Example: score 0.4 meets threshold 0.4; missing/invalid/wrong-unit data cannot.
(= (signalRatioAtLeastIn $signals $kind $unit $threshold)
    (case ((fsNumberIn $threshold 0 1) (signalValueIn $signals $kind)) (
        ((True (RatioFact $score $actual))
            (and (== $actual $unit) (>= $score $threshold)))
        ($_ False))))

;; Example: failure-streak count 2 meets count 2, never a different unit.
(= (signalQuantityAtLeastIn $signals $kind $unit $threshold)
    (case ((fsCount $threshold) (signalValueIn $signals $kind)) (
        ((True (QuantityFact $number $actual))
            (and (== $actual $unit) (>= $number $threshold)))
        ($_ False))))

