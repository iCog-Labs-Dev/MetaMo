(: AppraisalProfile Type)
(: appraisalProfile (-> Symbol Expression Symbol Symbol Symbol Symbol Number Expression AppraisalProfile))

;; Return the profile name.
;; Example: (appraisalProfileName (appraisalProfile openpsi (valence) featureFn coreFn appFn feedbackFn 1.0 ())) -> openpsi
(= (appraisalProfileName (appraisalProfile $name $required $featureFn $coreDeltaFn $appDeltaFn $feedbackFn $appScale $bounds))
    $name
)

;; Return required modulator names.
;; Example: (appraisalProfileRequiredModulators profile) -> (valence arousal)
(= (appraisalProfileRequiredModulators (appraisalProfile $name $required $featureFn $coreDeltaFn $appDeltaFn $feedbackFn $appScale $bounds))
    $required
)

;; Return the feature extraction callback symbol.
;; Example: (appraisalProfileFeatureFn profile) -> featureFn
(= (appraisalProfileFeatureFn (appraisalProfile $name $required $featureFn $coreDeltaFn $appDeltaFn $feedbackFn $appScale $bounds))
    $featureFn
)

;; Return the core modulator delta callback symbol.
;; Example: (appraisalProfileCoreDeltaFn profile) -> coreFn
(= (appraisalProfileCoreDeltaFn (appraisalProfile $name $required $featureFn $coreDeltaFn $appDeltaFn $feedbackFn $appScale $bounds))
    $coreDeltaFn
)

;; Return the application modulator delta callback symbol.
;; Example: (appraisalProfileApplicationDeltaFn profile) -> appFn
(= (appraisalProfileApplicationDeltaFn (appraisalProfile $name $required $featureFn $coreDeltaFn $appDeltaFn $feedbackFn $appScale $bounds))
    $appDeltaFn
)

;; Return the goal feedback callback symbol.
;; Example: (appraisalProfileFeedbackFn profile) -> feedbackFn
(= (appraisalProfileFeedbackFn (appraisalProfile $name $required $featureFn $coreDeltaFn $appDeltaFn $feedbackFn $appScale $bounds))
    $feedbackFn
)

;; Return the application modulator delta scale.
;; Example: (appraisalProfileApplicationScale profile) -> 1.0
(= (appraisalProfileApplicationScale (appraisalProfile $name $required $featureFn $coreDeltaFn $appDeltaFn $feedbackFn $appScale $bounds))
    $appScale
)

;; Return application modulator bounds.
;; Example: (appraisalProfileApplicationBounds profile) -> ((focus 0.0 1.0))
(= (appraisalProfileApplicationBounds (appraisalProfile $name $required $featureFn $coreDeltaFn $appDeltaFn $feedbackFn $appScale $bounds))
    $bounds
)

;; Return the name from a bound triple.
;; Example: (appraisalBoundName (focus 0.0 1.0)) -> focus
(= (appraisalBoundName ($name $lower $upper))
    $name
)

;; Return the lower value from a bound triple.
;; Example: (appraisalBoundLower (focus 0.0 1.0)) -> 0.0
(= (appraisalBoundLower ($name $lower $upper))
    $lower
)

;; Return the upper value from a bound triple.
;; Example: (appraisalBoundUpper (focus 0.0 1.0)) -> 1.0
(= (appraisalBoundUpper ($name $lower $upper))
    $upper
)

;; Validate that every required modulator is present in the schema.
;; Example: (validationIsOk (appraisalProfileValidateRequired (valence) schema)) -> True
(= (appraisalProfileValidateRequired $required $schema)
    (if (== $required ())
        (validationOk $schema)
        (let* (
            (($head $tail) (decons $required))
            ($idxResult (schemaModulatorIndex $schema $head))
        )
            (if (validationIsOk $idxResult)
                (appraisalProfileValidateRequired $tail $schema)
                (validationError missing-appraisal-modulator $head)
            )
        )
    )
)

;; Validate profile compatibility with a motivation schema.
;; Example: (validationIsOk (appraisalProfileValidate profile schema)) -> True
(= (appraisalProfileValidate $profile $schema)
    (appraisalProfileValidateRequired
        (appraisalProfileRequiredModulators $profile)
        $schema
    )
)

;; Default feature callback: accept an already prepared feature map.
;; Example: (appraisalIdentityFeatures state (stimulusFeatures ((risk 0.2)))) -> (stimulusFeatures ((risk 0.2)))
(= (appraisalIdentityFeatures $state $stimulus)
    $stimulus
)

;; Default application delta callback: no application deltas.
;; Example: (appraisalNoApplicationDeltas state features) -> ()
(= (appraisalNoApplicationDeltas $state $features)
    ()
)

;; Default feedback callback: empty goal-change feedback.
;; Example: (appraisalNoGoalFeedback state stimulus features) -> (goalChangeFeedback ())
(= (appraisalNoGoalFeedback $state $stimulus $features)
    (goalChangeFeedback ())
)

;; Extract stimulus features through the profile callback.
;; Example: (appraisalProfileStimulusFeatures profile state stimulus) -> features
(= (appraisalProfileStimulusFeatures $profile $state $stimulus)
    (let* (
        ($featureFn (appraisalProfileFeatureFn $profile))
    )
        (eval ($featureFn $state $stimulus))
    )
)

;; Compute core modulator deltas through the profile callback.
;; Example: (appraisalProfileCoreDeltas profile state features) -> ((valence 0.1))
(= (appraisalProfileCoreDeltas $profile $state $features)
    (let* (
        ($coreDeltaFn (appraisalProfileCoreDeltaFn $profile))
    )
        (eval ($coreDeltaFn $state $features))
    )
)

;; Compute application modulator deltas through the profile callback.
;; Example: (appraisalProfileApplicationDeltas profile state features) -> ((focus 0.1))
(= (appraisalProfileApplicationDeltas $profile $state $features)
    (let* (
        ($appDeltaFn (appraisalProfileApplicationDeltaFn $profile))
    )
        (eval ($appDeltaFn $state $features))
    )
)

;; Bound a core OpenPsi modulator value using sigmoid(4*(value-0.5)).
;; Example: (appraisalProfileBoundCoreValue profile 0.5) -> 0.5
(= (appraisalProfileBoundCoreValue $profile $value)
    (sigmoidNum (* 4.0 (- $value 0.5)))
)

;; Find a bound triple for an application modulator.
;; Example: (appraisalFindBound ((focus 0.0 1.0)) focus) -> (validationOk (focus 0.0 1.0))
(= (appraisalFindBound $bounds $name)
    (if (== $bounds ())
        (validationError missing-bound $name)
        (let* (
            (($head $tail) (decons $bounds))
        )
            (if (== (appraisalBoundName $head) $name)
                (validationOk $head)
                (appraisalFindBound $tail $name)
            )
        )
    )
)

;; Bound an application-specific modulator value.
;; Example: (appraisalProfileBoundApplicationValue profile focus 1.2) -> 1.0
(= (appraisalProfileBoundApplicationValue $profile $name $value)
    (let* (
        ($boundResult (appraisalFindBound (appraisalProfileApplicationBounds $profile) $name))
    )
        (case $boundResult (
            ((validationOk $bound)
                (clipRange
                    $value
                    (appraisalBoundLower $bound)
                    (appraisalBoundUpper $bound)
                )
            )
            ($_ (clipUnit $value))
        ))
    )
)

;; Apply core deltas recursively to a state.
;; Example: (applyCoreModulatorDeltas profile state ((valence 0.0))) -> updated-state
(= (applyCoreModulatorDeltas $profile $state $deltas)
    (if (== $deltas ())
        $state
        (let* (
            (($head $tail) (decons $deltas))
            ($name (featurePairName $head))
            ($delta (featurePairValue $head))
            ($current (stateModulator $state $name))
            ($next (appraisalProfileBoundCoreValue $profile (+ $current $delta)))
            ($nextState (stateSetModulator $state $name $next))
        )
            (applyCoreModulatorDeltas $profile $nextState $tail)
        )
    )
)

;; Apply application-specific deltas recursively to a state.
;; Example: (applyApplicationModulatorDeltas profile state ((focus 0.1))) -> updated-state
(= (applyApplicationModulatorDeltas $profile $state $deltas)
    (if (== $deltas ())
        $state
        (let* (
            (($head $tail) (decons $deltas))
            ($name (featurePairName $head))
            ($delta (featurePairValue $head))
            ($schema (stateSchema $state))
            ($applicationNames (modulatorSchemaApplication (motivationSchemaModulators $schema)))
        )
            (if (listContains $applicationNames $name)
                (let* (
                    ($current (stateModulator $state $name))
                    ($scaledDelta (* (appraisalProfileApplicationScale $profile) $delta))
                    ($next (appraisalProfileBoundApplicationValue $profile $name (+ $current $scaledDelta)))
                    ($nextState (stateSetModulator $state $name $next))
                )
                    (applyApplicationModulatorDeltas $profile $nextState $tail)
                )
                (validationError not-application-modulator $name)
            )
        )
    )
)

;; Produce optional goal-change feedback through the profile callback.
;; Example: (appraisalProfileGoalChangeFeedback profile state stimulus features) -> (goalChangeFeedback ())
(= (appraisalProfileGoalChangeFeedback $profile $state $stimulus $features)
    (let* (
        ($feedbackFn (appraisalProfileFeedbackFn $profile))
    )
        (eval ($feedbackFn $state $stimulus $features))
    )
)

;; Appraise a state using the profile rules.
;; Example: (appraisalProfileAppraise profile state features) -> updated-state
(= (appraisalProfileAppraise $profile $state $stimulus)
    (let* (
        ($schema (stateSchema $state))
        ($validation (appraisalProfileValidate $profile $schema))
    )
        (if (validationIsOk $validation)
            (let* (
                ($features (appraisalProfileStimulusFeatures $profile $state $stimulus))
                ($coreDeltas (appraisalProfileCoreDeltas $profile $state $features))
                ($afterCore (applyCoreModulatorDeltas $profile $state $coreDeltas))
                ($appDeltas (appraisalProfileApplicationDeltas $profile $afterCore $features))
            )
                (applyApplicationModulatorDeltas $profile $afterCore $appDeltas)
            )
            $validation
        )
    )
)

