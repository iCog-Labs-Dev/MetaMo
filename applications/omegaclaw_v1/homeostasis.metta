;; Self-model tracking and registry-driven homeostatic regulation.

!(bind! &success-count (new-state 0))
!(bind! &failure-count (new-state 0))
!(bind! &cycle-count   (new-state 0))

(= (selfModelAlpha)
   (let $v (collapse (match &self (DynamicsConfig self_model_alpha $x) $x))
      (if (== $v ()) 0.20 (car-atom $v))))

(= (homeostaticRuleTriggered $condType $metric $threshold)
   (case $condType (
      (modulator-exceeds (> (extractModulatorValue $metric) $threshold))
      (modulator-below   (< (extractModulatorValue $metric) $threshold))
      (self-metric-exceeds (> (fetchSelfMetricValue $metric) $threshold))
      (self-metric-below   (< (fetchSelfMetricValue $metric) $threshold))
      ($_ (println! ("Unknown homeostatic condition type: " $condType)))
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

(= (replaceSelfMetric $name $newValue)
   (let* (
      ($existing (collapse (match &self-model-space
                                (self-metric $name $v) (self-metric $name $v))))
      ($_ (if (!= $existing ())
              (remove-atom &self-model-space (car-atom $existing))
              _))
      ($_ (add-atom &self-model-space (self-metric $name $newValue)))
   ) ()))

(= (updateSelfModel $hadError $hadResults)
   (let* (
      ($_ (change-state! &cycle-count (+ (get-state &cycle-count) 1)))
      ($_ (if (and $hadResults (not $hadError))
              (change-state! &success-count (+ (get-state &success-count) 1))
              _))
      ($_ (if $hadError
              (change-state! &failure-count (+ (get-state &failure-count) 1))
              _))
      ($cycles (get-state &cycle-count))
      ($successes (get-state &success-count))
      ($failures (get-state &failure-count))
      ($instSuccess (if (> $cycles 0) (/ $successes $cycles) 0.5))
      ($instFailure (if (> $cycles 0) (/ $failures $cycles) 0.1))
      ($alpha (selfModelAlpha))
      ($oldSucc (fetchSelfMetricValue success_rate))
      ($oldFail (fetchSelfMetricValue failure_rate))
      ($newSucc
         (clampValue (+ (* (- 1.0 $alpha) $oldSucc) (* $alpha $instSuccess))))
      ($newFail
         (clampValue (+ (* (- 1.0 $alpha) $oldFail) (* $alpha $instFailure))))
      ($_ (replaceSelfMetric success_rate $newSucc))
      ($_ (replaceSelfMetric failure_rate $newFail))
      ($_ (replaceSelfMetric memory_confidence (clampValue (* $newSucc 1.4))))
      ($streak (get-state &failure-streak))
      ($_ (replaceSelfMetric identity_continuity
              (clampValue (- 0.90 (* $streak 0.08)))))
      ($_ (replaceSelfMetric resource_usage
              (clampValue (/ $cycles (+ $cycles 50.0)))))
   ) ()))
