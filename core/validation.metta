;; Shared validation and list helpers for the canonical MetaMo port.

(: ValidationResult Type)
(: validationOk (-> Expression ValidationResult))
(: validationError (-> Symbol Expression ValidationResult))

;; Return the payload from a successful validation result.
;; Example: (validationValue (validationOk ready)) -> ready
(= (validationValue (validationOk $value))
    $value
)

;; Return the code from a validation error.
;; Example: (validationErrorCode (validationError missing-name help)) -> missing-name
(= (validationErrorCode (validationError $code $details))
    $code
)

;; Return the details from a validation error.
;; Example: (validationErrorDetails (validationError missing-name help)) -> help
(= (validationErrorDetails (validationError $code $details))
    $details
)

;; Test whether a validation result is successful.
;; Example: (validationIsOk (validationOk 1)) -> True
(= (validationIsOk (validationOk $value))
    True
)

(= (validationIsOk (validationError $code $details))
    False
)

;; Test whether a list contains a value.
;; Example: (listContains (a b c) b) -> True
(= (listContains $items $needle)
    (if (== $items ())
        False
        (let* (
            (($head $tail) (decons $items))
        )
            (if (== $head $needle)
                True
                (listContains $tail $needle)
            )
        )
    )
)

;; Test whether all list elements are unique.
;; Example: (listUnique (a b c)) -> True
(= (listUnique $items)
    (if (== $items ())
        True
        (let* (
            (($head $tail) (decons $items))
        )
            (if (listContains $tail $head)
                False
                (listUnique $tail)
            )
        )
    )
)

;; Test whether two lists have no shared elements.
;; Example: (listsDisjoint (a b) (c d)) -> True
(= (listsDisjoint $left $right)
    (if (== $left ())
        True
        (let* (
            (($head $tail) (decons $left))
        )
            (if (listContains $right $head)
                False
                (listsDisjoint $tail $right)
            )
        )
    )
)

;; Append two expression lists.
;; Example: (listAppend (a b) (c)) -> (a b c)
(= (listAppend $left $right)
    (if (== $left ())
        $right
        (let* (
            (($head $tail) (decons $left))
        )
            (cons-atom $head (listAppend $tail $right))
        )
    )
)

;; Return the maximum of two numeric values.
;; Example: (maxNumber 0.2 0.7) -> 0.7
(= (maxNumber $left $right)
    (if (> $left $right)
        $left
        $right
    )
)

;; Return the minimum of two numeric values.
;; Example: (minNumber 0.2 0.7) -> 0.2
(= (minNumber $left $right)
    (if (< $left $right)
        $left
        $right
    )
)

;; Return the maximum value in a numeric list.
;; Example: (listMax (0.2 0.7 0.1)) -> 0.7
(= (listMax $items)
    (if (== $items ())
        0.0
        (let* (
            (($head $tail) (decons $items))
        )
            (maxNumber $head (listMax $tail))
        )
    )
)

;; Find a value in a list and return a validation result containing its index.
;; Example: (listIndexResult (a b c) b 0) -> (validationOk 1)
(= (listIndexResult $items $needle $index)
    (if (== $items ())
        (validationError missing-name $needle)
        (let* (
            (($head $tail) (decons $items))
        )
            (if (== $head $needle)
                (validationOk $index)
                (listIndexResult $tail $needle (+ $index 1))
            )
        )
    )
)

;; Replace one list value by index and return a new list.
;; Example: (listSetAt (a b c) 1 z) -> (a z c)
(= (listSetAt $items $index $value)
    (if (== $items ())
        ()
        (let* (
            (($head $tail) (decons $items))
        )
            (if (== $index 0)
                (cons-atom $value $tail)
                (cons-atom $head (listSetAt $tail (- $index 1) $value))
            )
        )
    )
)

;; Add a delta to a numeric list value by index.
;; Example: (listAddAt (0.1 0.2) 1 0.3) -> (0.1 0.5)
(= (listAddAt $items $index $delta)
    (let* (
        ($current (index-atom $items $index))
    )
        (listSetAt $items $index (+ $current $delta))
    )
)

;; Clamp a numeric value into the unit interval.
;; Example: (clipUnit 1.2) -> 1.0
(= (clipUnit $value)
    (if (< $value 0.0)
        0.0
        (if (> $value 1.0)
            1.0
            $value
        )
    )
)

;; Clamp a numeric value into a provided interval.
;; Example: (clipRange 2.0 -1.0 1.0) -> 1.0
(= (clipRange $value $minimum $maximum)
    (if (< $value $minimum)
        $minimum
        (if (> $value $maximum)
            $maximum
            $value
        )
    )
)
