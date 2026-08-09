(: QwestorPendingOutcome Type)
(: qwestorPendingOutcome (-> Symbol Expression QwestorPendingOutcome))

(: QwestorStateSnapshot Type)
(: qwestorStateSnapshotRecord (-> Symbol Expression Expression Expression QwestorStateSnapshot))

(: QwestorRestoredState Type)
(: qwestorRestoredState (-> MotivationState Expression QwestorRestoredState))

;; Test whether every numeric list item lies in the inclusive interval
(= (qwestorListInRange $items $minimum $maximum)
    (if (== $items ())
        True
        (let* (
            (($head $tail) (decons $items))
        )
            (if (and (>= $head $minimum) (<= $head $maximum))
                (qwestorListInRange $tail $minimum $maximum)
                False
            )
        )
    )
)

;; Validate schema identity, vector dimensions, and unit-interval values
(= (qwestorValidateState $state)
    (if (== (stateSchema $state) (qwestorSchema))
        (let* (
            ($shapeResult (validateMotivationState $state))
        )
            (if (validationIsOk $shapeResult)
                (if (qwestorListInRange (stateGoals $state) 0.0 1.0)
                    (if (qwestorListInRange (stateModulators $state) 0.0 1.0)
                        (validationOk $state)
                        (validationError qwestor-modulator-out-of-range (stateModulators $state))
                    )
                    (validationError qwestor-goal-out-of-range (stateGoals $state))
                )
                $shapeResult
            )
        )
        (validationError wrong-qwestor-state-schema (stateSchema $state))
    )
)

;; Build the documented canonical Qwestor starting state
(= (qwestorDefaultState)
    (motivationState
        (qwestorSchema)
        (qwestorDefaultGoals)
        (qwestorDefaultModulators)
    )
)

;; Build and validate a Qwestor state from complete coordinate vectors
(= (qwestorStateFromVectors $goals $modulators)
    (qwestorValidateState
        (motivationState (qwestorSchema) $goals $modulators)
    )
)

;; Construct the opaque outcome token that may be consumed by the next cycle.
(= (qwestorMakePendingOutcome $outcomeId $payload)
    (qwestorPendingOutcome $outcomeId $payload)
)

;; Validate that pending outcome data is either none or a tagged Qwestor record.
(= (qwestorValidatePendingOutcome $pendingOutcome)
    (case $pendingOutcome (
        (none (validationOk none))
        ((qwestorPendingOutcome
                $outcomeId (qwestorOutcome $payloadId $pairs))
            (if (== $outcomeId $payloadId)
                (let* (
                    ($outcomeResult
                        (eval
                            (qwestorValidateOutcome
                                (qwestorOutcome $payloadId $pairs))))
                )
                    (if (validationIsOk $outcomeResult)
                        (validationOk $pendingOutcome)
                        $outcomeResult
                    )
                )
                (validationError
                    mismatched-qwestor-pending-outcome-id
                    (($outcomeId $payloadId)))))
        ($_ (validationError invalid-qwestor-pending-outcome $pendingOutcome))
    ))
)

;; Serialize a validated state and pending outcome into the sole Qwestor format.
(= (qwestorStateSnapshot $state $pendingOutcome)
    (let* (
        ($stateResult (qwestorValidateState $state))
        ($outcomeResult (qwestorValidatePendingOutcome $pendingOutcome))
    )
        (if (validationIsOk $stateResult)
            (if (validationIsOk $outcomeResult)
                (validationOk
                    (qwestorStateSnapshotRecord
                        (motivationSchemaId (stateSchema $state))
                        (stateGoals $state)
                        (stateModulators $state)
                        $pendingOutcome
                    )
                )
                $outcomeResult
            )
            $stateResult
        )
    )
)

;; Restore and validate the sole Qwestor snapshot representation
(= (qwestorStateFromSnapshot
        (qwestorStateSnapshotRecord $schemaId $goals $modulators $pendingOutcome))
    (if (== $schemaId (motivationSchemaId (qwestorSchema)))
        (let* (
            ($stateResult (qwestorStateFromVectors $goals $modulators))
            ($outcomeResult (qwestorValidatePendingOutcome $pendingOutcome))
        )
            (if (validationIsOk $stateResult)
                (if (validationIsOk $outcomeResult)
                    (validationOk
                        (qwestorRestoredState
                            (validationValue $stateResult)
                            $pendingOutcome
                        )
                    )
                    $outcomeResult
                )
                $stateResult
            )
        )
        (validationError wrong-qwestor-snapshot-schema $schemaId)
    )
)

;; Return the canonical motivation state from a restored-state record
(= (qwestorRestoredMotivationState
        (qwestorRestoredState $state $pendingOutcome))
    $state
)

;; Return the pending outcome from a restored-state record
(= (qwestorRestoredPendingOutcome
        (qwestorRestoredState $state $pendingOutcome))
    $pendingOutcome
)

;; Return named values needed for state inspection without exposing indices
(= (qwestorStateSummary $state)
    (
        (individuation (stateGoal $state individuation))
        (transcendence (stateGoal $state transcendence))
        (beneficial (stateGoal $state beneficial))
        (honesty (stateGoal $state honesty))
        (safety (stateGoal $state safety))
        (valence (stateModulator $state valence))
        (arousal (stateModulator $state arousal))
        (threshold (stateModulator $state threshold))
        (securing (stateModulator $state securing))
    )
)
