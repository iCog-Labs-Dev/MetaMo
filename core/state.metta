;; Canonical schema-aware motivational state and action records for MetaMo.

(: MotivationState Type)
(: motivationState (-> MotivationSchema Expression Expression MotivationState))

(: ActionCandidate Type)
(: actionCandidate (-> Symbol MotivationSchema Expression Number Expression Expression ActionCandidate))

;; Return the schema from a canonical motivational state.
;; Example: (stateSchema (motivationState schema (0.5) (0.5))) -> schema
(= (stateSchema (motivationState $schema $goals $modulators))
    $schema
)

;; Return the goal vector from a canonical motivational state.
;; Example: (stateGoals (motivationState schema (0.5) (0.5))) -> (0.5)
(= (stateGoals (motivationState $schema $goals $modulators))
    $goals
)

;; Return the modulator vector from a canonical motivational state.
;; Example: (stateModulators (motivationState schema (0.5) (0.5))) -> (0.5)
(= (stateModulators (motivationState $schema $goals $modulators))
    $modulators
)

;; Validate a canonical state against its schema dimensions.
;; Example: (validationIsOk (validateMotivationState (motivationState schema goals mods))) -> True
(= (validateMotivationState $state)
    (let* (
        ($schema (stateSchema $state))
        ($goals (stateGoals $state))
        ($modulators (stateModulators $state))
    )
        (if (== (size-atom $goals) (schemaGoalCount $schema))
            (if (== (size-atom $modulators) (schemaModulatorCount $schema))
                (validationOk $state)
                (validationError modulator-length-mismatch ($modulators $schema))
            )
            (validationError goal-length-mismatch ($goals $schema))
        )
    )
)

;; Read a goal by schema name, returning validationError when absent.
;; Example: (stateGoal state help) -> 0.8
(= (stateGoal $state $goalName)
    (let* (
        ($schema (stateSchema $state))
        ($idxResult (schemaGoalIndex $schema $goalName))
    )
        (case $idxResult (
            ((validationOk $idx) (index-atom (stateGoals $state) $idx))
            ($_ $idxResult)
        ))
    )
)

;; Set a goal by schema name and return a new state.
;; Example: (stateSetGoal state help 0.9) -> updated-state
(= (stateSetGoal $state $goalName $value)
    (let* (
        ($schema (stateSchema $state))
        ($idxResult (schemaGoalIndex $schema $goalName))
    )
        (case $idxResult (
            ((validationOk $idx)
                (motivationState
                    $schema
                    (listSetAt (stateGoals $state) $idx $value)
                    (stateModulators $state)
                )
            )
            ($_ $idxResult)
        ))
    )
)

;; Read an anti-goal by name with schema membership validation.
;; Example: (stateAntiGoal state misinformation) -> 0.2
(= (stateAntiGoal $state $goalName)
    (let* (
        ($schema (stateSchema $state))
    )
        (if (schemaIsAntiGoal $schema $goalName)
            (stateGoal $state $goalName)
            (validationError not-an-anti-goal $goalName)
        )
    )
)

;; Read a modulator by schema name, returning validationError when absent.
;; Example: (stateModulator state valence) -> 0.5
(= (stateModulator $state $modulatorName)
    (let* (
        ($schema (stateSchema $state))
        ($idxResult (schemaModulatorIndex $schema $modulatorName))
    )
        (case $idxResult (
            ((validationOk $idx) (index-atom (stateModulators $state) $idx))
            ($_ $idxResult)
        ))
    )
)

;; Set a modulator by schema name and return a new state.
;; Example: (stateSetModulator state valence 0.7) -> updated-state
(= (stateSetModulator $state $modulatorName $value)
    (let* (
        ($schema (stateSchema $state))
        ($idxResult (schemaModulatorIndex $schema $modulatorName))
    )
        (case $idxResult (
            ((validationOk $idx)
                (motivationState
                    $schema
                    (stateGoals $state)
                    (listSetAt (stateModulators $state) $idx $value)
                )
            )
            ($_ $idxResult)
        ))
    )
)

;; Add a bounded delta to a modulator by name and return a new state.
;; Example: (stateApplyModulatorDelta state valence 0.2) -> updated-state
(= (stateApplyModulatorDelta $state $modulatorName $delta)
    (let* (
        ($current (stateModulator $state $modulatorName))
    )
        (stateSetModulator $state $modulatorName (clipUnit (+ $current $delta)))
    )
)

;; Return the action id from a canonical candidate.
;; Example: (candidateId (actionCandidate act schema (0.1) 0.2 (0.0) ())) -> act
(= (candidateId (actionCandidate $id $schema $correlations $risk $deltaG $metadata))
    $id
)

;; Return the candidate schema.
;; Example: (candidateSchema (actionCandidate act schema (0.1) 0.2 (0.0) ())) -> schema
(= (candidateSchema (actionCandidate $id $schema $correlations $risk $deltaG $metadata))
    $schema
)

;; Return candidate goal correlations.
;; Example: (candidateGoalCorrelations (actionCandidate act schema (0.1) 0.2 (0.0) ())) -> (0.1)
(= (candidateGoalCorrelations (actionCandidate $id $schema $correlations $risk $deltaG $metadata))
    $correlations
)

;; Return candidate risk estimate.
;; Example: (candidateRiskEstimate (actionCandidate act schema (0.1) 0.2 (0.0) ())) -> 0.2
(= (candidateRiskEstimate (actionCandidate $id $schema $correlations $risk $deltaG $metadata))
    $risk
)

;; Return candidate Delta G hint.
;; Example: (candidateDeltaG (actionCandidate act schema (0.1) 0.2 (0.0) ())) -> (0.0)
(= (candidateDeltaG (actionCandidate $id $schema $correlations $risk $deltaG $metadata))
    $deltaG
)

;; Return candidate metadata.
;; Example: (candidateMetadata (actionCandidate act schema (0.1) 0.2 (0.0) ((risk 0.2)))) -> ((risk 0.2))
(= (candidateMetadata (actionCandidate $id $schema $correlations $risk $deltaG $metadata))
    $metadata
)

;; Validate candidate vector dimensions against its schema.
;; Example: (validationIsOk (validateActionCandidate candidate)) -> True
(= (validateActionCandidate $candidate)
    (let* (
        ($schema (candidateSchema $candidate))
        ($correlations (candidateGoalCorrelations $candidate))
        ($deltaG (candidateDeltaG $candidate))
    )
        (if (== (size-atom $correlations) (schemaGoalCount $schema))
            (if (== (size-atom $deltaG) (schemaGoalCount $schema))
                (validationOk $candidate)
                (validationError candidate-delta-length-mismatch ($deltaG $schema))
            )
            (validationError candidate-correlation-length-mismatch ($correlations $schema))
        )
    )
)

;; Read a candidate goal correlation by name.
;; Example: (candidateGoalCorrelation candidate help) -> 0.7
(= (candidateGoalCorrelation $candidate $goalName)
    (let* (
        ($schema (candidateSchema $candidate))
        ($idxResult (schemaGoalIndex $schema $goalName))
    )
        (case $idxResult (
            ((validationOk $idx) (index-atom (candidateGoalCorrelations $candidate) $idx))
            ($_ $idxResult)
        ))
    )
)

;; Read a candidate Delta G hint by name.
;; Example: (candidateGoalDelta candidate help) -> 0.01
(= (candidateGoalDelta $candidate $goalName)
    (let* (
        ($schema (candidateSchema $candidate))
        ($idxResult (schemaGoalIndex $schema $goalName))
    )
        (case $idxResult (
            ((validationOk $idx) (index-atom (candidateDeltaG $candidate) $idx))
            ($_ $idxResult)
        ))
    )
)

;; Compute schema-aware distance between two canonical states.
;; Example: (stateDistance (motivationState schema (0.0) (0.0)) (motivationState schema (1.0) (0.0))) -> 1.0
(= (stateDistance $left $right)
    (if (== (stateSchema $left) (stateSchema $right))
        (+ (eval (norm (listDifference (stateGoals $left) (stateGoals $right))))
           (eval (norm (listDifference (stateModulators $left) (stateModulators $right)))))
        (validationError state-schema-mismatch ((stateSchema $left) (stateSchema $right)))
    )
)
