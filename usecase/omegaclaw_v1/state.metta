
(= (omegaClawDefaultGoals)
    (0.70 0.40 0.60 0.45 0.50 0.60 0.55
     0.50 0.60 0.50 0.45 0.00 0.00 0.00))

(= (omegaClawDefaultModulators)
    (0.50 0.50 0.50 0.50 0.40 0.30
     0.50 0.55 0.50 0.40 0.55))

(= (omegaClawDefaultState)
    (motivationState
        (omegaClawSchema)
        (omegaClawDefaultGoals)
        (omegaClawDefaultModulators)))

;; Keep bounded state lists in chronological order.
(= (omegaClawTrimToLimit $items $limit)
    (if (<= $limit 0)
        ()
        (if (> (size-atom $items) $limit)
            (omegaClawTrimToLimit (cdr-atom $items) $limit)
            $items)))

(= (omegaClawBoundedAppend $items $item $limit)
    (omegaClawTrimToLimit
        (listAppend $items ($item))
        $limit))

(= (omegaClawCollectionWithinLimit $items $limit)
    (<= (size-atom $items) $limit))
