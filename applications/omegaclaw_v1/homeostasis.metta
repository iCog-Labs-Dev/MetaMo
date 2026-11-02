;; Self-model tracking and registry-driven homeostatic regulation.

!(bind! &success-count (new-state 0))
!(bind! &failure-count (new-state 0))
!(bind! &cycle-count   (new-state 0))
!(bind! &last-homeostatic-corrections (new-state ()))

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

;; Example: only a declared goal/modulator can have a homeostatic correction target.
(= (homeostaticVariableDefaults $kind $name)
    (case $kind (
        (modulator (collapse (match &self (ModulatorSpec $name $seed) $seed)))
        (goal (collapse (match &self (GoalSpec $name $seed) $seed)))
        ($_ ())
    ))
)

;; Example: (homeostaticTarget modulator caution) returns one validated declaration.
;; Missing, duplicate, nonfinite or out-of-domain targets cannot drive a write.
(= (homeostaticTarget $kind $name)
    (case ((collapse (match &self
            (HomeostaticTarget $kind $name $unit $point) ($unit $point)))
            (homeostaticVariableDefaults $kind $name)) (
        ((() $_) (HomeostasisRejected UndeclaredTarget))
        ((((normalized (set-point $point))) ($seed))
            (if (and (== (get-metatype $name) Symbol)
                    (and (fsNumberIn $point 0 1) (fsNumberIn $seed 0 1)))
                (HomeostaticTarget $kind $name normalized (set-point $point))
                (HomeostasisRejected InvalidTarget)))
        ($_ (HomeostasisRejected InvalidTarget))
    ))
)

;; Example: a missing/duplicate current value is unavailable, not an implicit zero.
(= (homeostaticCurrentValue $kind $name)
    (let $values (case $kind (
            (modulator (collapse (match &motivation-space (modulator $name $v) $v)))
            (goal (collapse (match &goal-space (goal $name $v) $v)))
            ($_ ())))
        (case $values (
            (($value) (if (fsNumberIn $value 0 1)
                (HomeostaticValue $value) (HomeostasisRejected InvalidCurrentValue)))
            ($_ (HomeostasisRejected InvalidCurrentValue))
        ))
    )
)

;; Example: raise-modulator addresses only a modulator; S/host state are not writable.
(= (homeostaticActionSpec $action)
    (case $action (
        (raise-modulator (HomeostaticAction modulator raise))
        (lower-modulator (HomeostaticAction modulator lower))
        (raise-goal (HomeostaticAction goal raise))
        (lower-goal (HomeostaticAction goal lower))
        ($_ (HomeostasisRejected UnsupportedAction))
    ))
)

;; Example: raising 0.70 by 0.20 toward 0.75 stops at 0.75; 0.90 stays 0.90.
;; The caller validates normalized values and a positive finite step first.
(= (homeostaticStep $direction $current $point $step)
    (case $direction (
        (raise (if (>= $current $point) $current
            (let $next (+ $current $step) (if (> $next $point) $point $next))))
        (lower (if (<= $current $point) $current
            (let $next (- $current $step) (if (< $next $point) $point $next))))
    ))
)

;; Example: even direct correction calls must agree with the declared target and step.
(= (homeostaticCorrectionValid $kind $direction $name $point $step)
    (if (fsNumberIn $step 0 1)
        (and (> $step 0)
            (and (fsContains (raise lower) $direction)
                (== (homeostaticTarget $kind $name)
                    (HomeostaticTarget $kind $name normalized (set-point $point)))))
        False
    )
)

;; Example: an admitted correction returns its actual before/after and set-point.
(= (applyHomeostaticCorrection $kind $direction $name $point $step)
    (if (not (homeostaticCorrectionValid $kind $direction $name $point $step))
        (HomeostasisRejected InvalidCorrection)
    (case (homeostaticCurrentValue $kind $name) (
        ((HomeostaticValue $current)
            (let* (
                ($next (homeostaticStep $direction $current $point $step))
                ($_ (if (== $current $next) ()
                    (case $kind (
                        (modulator (replaceModulator $name $next))
                        (goal (replaceGoal $name $next))
                    ))))
            ) (HomeostaticCorrection (variable $kind $name)
                (from $current) (to $next) (set-point $point))))
        ($rejection $rejection)
    )))
)

;; Example: correction dispatch requires a supported action and declared set-point.
(= (applyDeclaredHomeostaticAction $action $name $step)
    (case (homeostaticActionSpec $action) (
        ((HomeostaticAction $kind $direction)
            (case (homeostaticTarget $kind $name) (
                ((HomeostaticTarget $_ $_ normalized (set-point $point))
                    (applyHomeostaticCorrection $kind $direction $name $point $step))
                ($rejection $rejection)
            )))
        ($rejection $rejection)
    ))
)

;; Example: negative/nonfinite steps reject before any target or current value changes.
(= (applyHomeostaticAction $actionType $target $delta)
    (if (fsNumberIn $delta 0 1)
        (if (> $delta 0) (applyDeclaredHomeostaticAction $actionType $target $delta)
            (HomeostasisRejected InvalidStep))
        (HomeostasisRejected InvalidStep)
    )
)

;; Example: a triggered rule retains both its trigger declaration and correction result.
(= (applyHomeostaticRule $rule)
   (let (HomeostaticRule $condType $metric $threshold $actionType $target $delta) $rule
      (if (homeostaticRuleTriggered $condType $metric $threshold)
          (HomeostaticRuleResult $rule (applyHomeostaticAction $actionType $target $delta))
          ())))

;; Example: latest-cycle diagnostics include adjusted, unchanged and rejected actions.
(= (lastHomeostaticCorrections) (get-state &last-homeostatic-corrections))

;; Example: runHomeostasis uses the live registry and replaces the previous trace.
(= (runHomeostasis)
   (let $results (collapse
      (let $rule (match &self
                     (HomeostaticRule $condType $metric $threshold $actionType $target $delta)
                     (HomeostaticRule $condType $metric $threshold $actionType $target $delta))
         (applyHomeostaticRule $rule)))
      (let $trace (filter-atom $results $result (!= $result ()))
         (progn (change-state! &last-homeostatic-corrections $trace) $trace))))

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
