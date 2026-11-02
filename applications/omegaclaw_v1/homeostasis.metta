;; Self-model tracking and registry-driven homeostatic regulation.

!(bind! &success-count (new-state 0))
!(bind! &failure-count (new-state 0))
!(bind! &cycle-count   (new-state 0))

;; Example: a normalized physiological or motivational field has a bounded seed.
;; Pure schema checks are shared by initialization, updates and restore.
(= (selfModelFieldSpecValid $spec)
    (case $spec (
        ((SelfModelFieldSpec $name $class normalized 0 1 $seed)
            (and (== (get-metatype $name) Symbol)
                (and (fsContains (motivational physiological) $class)
                    (fsNumberIn $seed 0 1))))
        ($_ False)
    ))
)

;; Example: (selfModelFieldSpec energy) returns one declaration; unknowns reject.
(= (selfModelFieldSpec $name)
    (case (collapse (match &self
            (SelfModelFieldSpec $name $class $unit $low $high $seed)
            (SelfModelFieldSpec $name $class $unit $low $high $seed))) (
        (() (SelfModelFieldRejected UnknownField))
        (($spec) (if (selfModelFieldSpecValid $spec)
            $spec (SelfModelFieldRejected InvalidFieldSpec)))
        ($_ (SelfModelFieldRejected InvalidFieldSpec))
    ))
)

;; Example: (selfModelMetricValid (quote (self-metric energy 0.5))) -> True.
;; Legacy performance fields, nonfinite numbers and executable data are invalid S.
(= (selfModelMetricValid $metric)
    (if (not (is-ground $metric)) False
        (case $metric (
            ((self-metric $name $value)
                (case (selfModelFieldSpec $name) (
                    ((SelfModelFieldSpec $_ $_ $_ $low $high $_)
                        (fsNumberIn $value $low $high))
                    ($_ False)
                )))
            ($_ False)
        ))
    )
)

;; Example: a partial saved S may be valid, but duplicate or forbidden fields reject.
(= (selfModelMetricsValid $metrics)
    (if (or (not (is-ground $metrics)) (!= (get-metatype $metrics) Expression)) False
        (if (!= (filter-atom $metrics $metric (not (selfModelMetricValid $metric))) ()) False
            (== (filter-atom $metrics $metric
                (!= (size-atom (filter-atom $metrics $other
                    (== (index-atom $metric 1) (index-atom $other 1)))) 1)) ()))
    )
)

;; Example: duplicate declarations cannot be used to initialize even valid seeds.
(= (selfModelDefaults)
    (let* (
        ($specs (collapse (match &self
            (SelfModelFieldSpec $n $c $u $lo $hi $seed)
            (SelfModelFieldSpec $n $c $u $lo $hi $seed))))
        ($invalid (filter-atom $specs $spec
            (!= (selfModelFieldSpec (index-atom $spec 1)) $spec)))
    )
        (if (or (== $specs ()) (!= $invalid ()))
            (SelfModelRejected InvalidSchema)
            (SelfModelDefaults (map-atom $specs $spec
                (self-metric (index-atom $spec 1) (index-atom $spec 6)))))
    )
)

;; Example: unavailable memory_confidence is not a zero-confidence observation.
;; Retired names remain rejected even after their rule dependencies are migrated.
(= (selfMetricCondition $name $comparison $threshold)
    (case (collapse (match &self-model-space
            (self-metric $name $value) (self-metric $name $value))) (
        (($metric)
            (if (and (selfModelMetricValid $metric) (fsNumberIn $threshold 0 1))
                (case $comparison (
                    (above (> (index-atom $metric 2) $threshold))
                    (below (< (index-atom $metric 2) $threshold))
                    ($_ False)
                )) False))
        ($_ False)
    ))
)

;; Example: missing/duplicate context_depth is unavailable, never a numeric zero.
;; Modulator values express motivational preferences, not adjudicated knowledge.
(= (modulatorCondition $name $comparison $threshold)
    (case (collapse (match &motivation-space
            (modulator $name $value) $value)) (
        (($value)
            (if (and (fsNumberIn $value 0 1) (fsNumberIn $threshold 0 1))
                (case $comparison (
                    (above (> $value $threshold))
                    (below (< $value $threshold))
                    ($_ False)
                )) False))
        ($_ False)
    ))
)

;; Example: repeated-failure must be a True fact; count thresholds use count units.
(= (homeostaticRuleTriggered $condType $metric $threshold)
   (case $condType (
      (modulator-exceeds (modulatorCondition $metric above $threshold))
      (modulator-below   (modulatorCondition $metric below $threshold))
      (self-metric-exceeds (selfMetricCondition $metric above $threshold))
      (self-metric-below   (selfMetricCondition $metric below $threshold))
      (signal-true (and (== $threshold IsTrue) (signalTrue $metric)))
      (signal-count-at-least (signalQuantityAtLeast $metric count $threshold))
      ($_ False)
   )))

(= (applyHomeostaticAction $actionType $target $delta)
   (case $actionType (
      (raise-modulator
         (replaceModulator $target
            (clampValue (+ (extractModulatorValue $target) $delta))))
      (lower-modulator
         (replaceModulator $target
            (clampValue (- (extractModulatorValue $target) $delta))))
      (raise-goal
         (replaceGoal $target
            (clampValue (+ (extractGoalValue $target) $delta))))
      (lower-goal
         (replaceGoal $target
            (clampValue (- (extractGoalValue $target) $delta))))
      ($_ (println! ("Unknown homeostatic action type: " $actionType)))
   )))

(= (applyHomeostaticRule $rule)
   (let (HomeostaticRule $condType $metric $threshold $actionType $target $delta) $rule
      (if (homeostaticRuleTriggered $condType $metric $threshold)
          (applyHomeostaticAction $actionType $target $delta)
          ())))

(= (runHomeostasis)
   (collapse
      (let $rule (match &self
                     (HomeostaticRule $condType $metric $threshold $actionType $target $delta)
                     (HomeostaticRule $condType $metric $threshold $actionType $target $delta))
         (applyHomeostaticRule $rule))))

(= (fetchSelfMetricValue $name)
   (let $res (collapse (match &self-model-space (self-metric $name $v) $v))
      (if (== $res ()) 0.0 (car-atom $res))))

;; Example: (replaceSelfMetric energy 0.7) updates; forbidden/invalid writes preserve S.
(= (replaceSelfMetric $name $newValue)
    (if (not (selfModelMetricValid (self-metric $name $newValue)))
        (SelfModelRejected InvalidMetric)
        (let* (
            ($_ (collapse (let $old (match &self-model-space
                (self-metric $name $value) (self-metric $name $value))
                (remove-atom &self-model-space $old))))
            ($_ (add-atom &self-model-space (self-metric $name $newValue)))
        ) ()))
)

;; Example: (initializeSelfModel) installs all declared seeds only after validation.
(= (initializeSelfModel)
    (case (selfModelDefaults) (
        ((SelfModelDefaults $metrics)
            (progn (clearSpace &self-model-space)
                (map-atom $metrics $metric
                    (let (self-metric $name $value) $metric (replaceSelfMetric $name $value)))
                SelfModelInitialized))
        ($rejection $rejection)
    ))
)

;; Example: a failed cycle updates counters outside S, never memory/capability claims.
;; Energy/fatigue retain their valid values; no measurement/update law is invented.
;; Urgency mirrors the existing motivational modulator through the validated writer.
(= (updateSelfModel $hadError $hadResults)
   (let* (
      ($_ (change-state! &cycle-count (+ (get-state &cycle-count) 1)))
      ($_ (if (and $hadResults (not $hadError))
              (change-state! &success-count (+ (get-state &success-count) 1))
              _))
      ($_ (if $hadError
              (change-state! &failure-count (+ (get-state &failure-count) 1))
              _))
   ) 
      (replaceSelfMetric urgency (extractModulatorValue urgency))
   )
   )
