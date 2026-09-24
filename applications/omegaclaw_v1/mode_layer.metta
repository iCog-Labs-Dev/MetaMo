;; Constitutional MVP mode layer.
;;
;; These modes are distinct from ContextFrames' Fast/Slow frame execution mode
;; and from MetaMo's operation directives (orient/execute/verify/recover).

!(import! &self (library MetaMo applications/omegaclaw_v1/scheduling))

!(bind! &constitutional-mode (new-state Engaged))
;; Bookkeeping only: current mode, held cycles, pending target/count, cooldown.
;; It contains no signals, scores, or host frame state.
!(bind! &mode-transition-state (new-state (ModeTransitionState Engaged 0 none 0 0)))

(= (constitutionalModeSet)
   (Engaged Threat Rumination Sleep))

(= (constitutionalModeDefault)
   (let ($mode) (collapse (match &self (ConstitutionalModeDefault $value) $value))
      $mode))

;; Historical API aliases. These describe scheduling classes, NOT members of
;; constitutionalModeSet. New callers should use schedulingPriority* names.
(= (constitutionalModePreemptionOrder) (schedulingPriorityOrder))
(= (constitutionalModePreemptionRank $class) (schedulingPriorityRank $class))
(= (constitutionalModePreempts $higher $lower)
   (schedulingPriorityPreempts $higher $lower))

;; Pure registry evaluator. These temporary booleans are views of this cycle's
;; inputs, never additional facts written into the signal space.
(= (modeTransitionRules)
   (collapse (match &self (ModeTransitionRule $group $mode $priority)
      (ModeTransitionRule $group $mode $priority))))

(= (modeActiveGroups $rules $signals $hasFrame $current)
   (if (== $rules ()) ()
       (let* (
          (($head $tail) (decons-atom $rules))
          ((ModeTransitionRule $group $target $_priority) $head)
          ($phase (if (== $current $target) Exit Enter))
          ($active (modeTriggerGroupActive $group $phase $signals $hasFrame)))
          (cons-atom (ModeGroup $group $active)
             (modeActiveGroups $tail $signals $hasFrame $current)))))

(= (modeGroupEnabled $group $groups)
   (if (== $groups ()) False
       (let* (
          (($head $tail) (decons-atom $groups))
          ((ModeGroup $name $active) $head))
          (if (== $group $name) $active (modeGroupEnabled $group $tail)))))

(= (modeChooseRule $rules $groups $best $bestRank)
   (if (== $rules ()) $best
       (let* (
          (($head $tail) (decons-atom $rules))
          ((ModeTransitionRule $group $_target $rank) $head))
          (if (and (modeGroupEnabled $group $groups) (> $rank $bestRank))
              (modeChooseRule $tail $groups $head $rank)
              (modeChooseRule $tail $groups $best $bestRank)))))

(= (modeRuleTarget $rule)
   (case $rule (
      ((ModeTransitionRule $_ $target $_) $target)
      ((ModeDefault $target) $target))))

;; Preserve the existing target-only API; diagnostics retain the actual winner.
(= (modeChooseTarget $rules $groups $best $bestRank)
   (modeRuleTarget (modeChooseRule $rules $groups (ModeDefault $best) $bestRank)))

(= (modeTargetFromContext $signals $hasFrame $current)
   (let $rules (modeTransitionRules)
      (modeChooseTarget $rules (modeActiveGroups $rules $signals $hasFrame $current)
         (constitutionalModeDefault) 0)))

;; Compatibility entry point for existing boolean fixtures. The fourth
;; argument remains reserved; collision resolution now reads registry rules.
(= (constitutionalModeFromSignalFacts $threat $recovery $sleep $_reserved)
   (modeChooseTarget (modeTransitionRules)
      ((ModeGroup threat $threat) (ModeGroup recovery $recovery) (ModeGroup sleep $sleep))
      (constitutionalModeDefault) 0))

(= (constitutionalModeFromSignals $bundle)
   (modeTargetFromContext (eval (getSignals))
      (eval (!= (frameBundleCurrentId $bundle) ())) (constitutionalMode)))

(= (modeHighestRank $ranks)
   (if (== $ranks ()) 0
       (let* ((($head $tail) (decons-atom $ranks)) ($rest (modeHighestRank $tail)))
          (if (> $head $rest) $head $rest))))

(= (modeTransitionRank $mode)
   (modeHighestRank (collapse (match &self (ModeTransitionRule $_ $mode $rank) $rank))))

;; Exactly one timing row per mode and one option row are required. Registry
;; configuration is trusted host data, never derived from model output.
(= (modeTransitionTiming $mode)
   (let (($entry $hold $cooldown))
         (collapse (match &self (ModeTransitionParameters $mode $entry $hold $cooldown)
            ($entry $hold $cooldown)))
      (ModeTiming $entry $hold $cooldown)))

(= (modeUrgentBypass)
   (let ($enabled)
         (collapse (match &self (ModeTransitionOption urgent-bypass $value) $value))
      $enabled))

(= (modeDecrement $value) (if (> $value 0) (- $value 1) 0))

;; One timing calculation serves both the transition and its diagnostic view.
(= (modeTimingEvidence
      (ModeTransitionState $current $age $pending $count $cooldown) $target)
   (let* (
      ($currentTiming (modeTransitionTiming $current))
      ($targetTiming (modeTransitionTiming $target))
      ((ModeTiming $_ $hold $_) $currentTiming)
      ((ModeTiming $entry $_ $_) $targetTiming)
      ($nextCount (if (== $pending $target) (+ $count 1) 1))
      ($bypass (modeUrgentBypass))
      ($urgent (and $bypass (> (modeTransitionRank $target) (modeTransitionRank $current)))))
      (ModeTimingEvidence
         (current $current $currentTiming) (target $target $targetTiming)
         (urgent-bypass $bypass $urgent)
         (checks $nextCount (>= $nextCount $entry) (>= $age $hold) (== $cooldown 0)))))

;; Pure transition step. Higher urgency may bypass timers, never entry evidence.
;; Changing/clearing the desired target resets its consecutive-entry counter.
(= (modeTransitionStepForTarget
      (ModeTransitionState $current $age $pending $count $cooldown) $target)
   (let* (
      ((ModeTimingEvidence $_ (target $_ (ModeTiming $_ $_ $targetCooldown))
          (urgent-bypass $_ $urgent) (checks $nextCount $confirmed $held $cooled))
       (modeTimingEvidence (ModeTransitionState $current $age $pending $count $cooldown) $target))
      ($ready (and $confirmed (or $urgent (and $held $cooled)))))
      (case (== $target $current) (
         (True (ModeTransitionState $current (+ $age 1) none 0 (modeDecrement $cooldown)))
         (False
          (if $ready
              (ModeTransitionState $target 0 none 0 $targetCooldown)
              (ModeTransitionState $current (+ $age 1) $target $nextCount
                 (modeDecrement $cooldown))))))))

;; Registry/configuration is trusted and fixed during a serialized refresh.
;; Every rule keeps its matching evidence, including lower-priority collisions.
(= (modeEvaluationForContext $state $signals $hasFrame)
   (let* (
      ((ModeTransitionState $current $_ $_ $_ $_) $state)
      ($rules (modeTransitionRules))
      ($groups (modeActiveGroups $rules $signals $hasFrame $current))
      ($winner (modeChooseRule $rules $groups (ModeDefault (constitutionalModeDefault)) 0))
      ($target (modeRuleTarget $winner)))
      (ModeEvaluation $winner $target
         (map-atom $rules $rule
            (let* (
               ((ModeTransitionRule $group $mode $_) $rule)
               ($phase (if (== $current $mode) Exit Enter)))
               (ModeRuleEvidence $rule (modeGroupEnabled $group $groups)
                  (modeTriggerEvidence $group $phase $signals $hasFrame))))
         (modeTimingEvidence $state $target))))

(= (modeTransitionStep $state $signals $hasFrame)
   (let (ModeTransitionState $current $_ $_ $_ $_) $state
      (modeTransitionStepForTarget $state (modeTargetFromContext $signals $hasFrame $current))))

(= (modeTransitionState) (get-state &mode-transition-state))

;; Direct legacy state restoration cannot carry another mode's timing counters.
(= (modeTransitionStateForCurrent $current)
   (let (ModeTransitionState $tracked $age $pending $count $cooldown) (modeTransitionState)
      (if (== $current $tracked)
          (ModeTransitionState $tracked $age $pending $count $cooldown)
          (ModeTransitionState $current 0 none 0 0))))

(= (refreshConstitutionalMode $bundle)
   (let* (
      ($next (modeTransitionStep (modeTransitionStateForCurrent (constitutionalMode))
         (eval (getSignals)) (eval (!= (frameBundleCurrentId $bundle) ()))))
      ((ModeTransitionState $mode $_ $_ $_ $_) $next))
      (if (constitutionalModeValid $mode)
          (let $_ (change-state! &mode-transition-state $next)
             (change-state! &constitutional-mode $mode))
          (ModeRejected $mode))))

(= (constitutionalModeValid $mode)
   (case $mode
      ((Engaged True)
       (Threat True)
       (Rumination True)
       (Sleep True)
       ($_ False))))

(= (constitutionalMode)
   (get-state &constitutional-mode))

(= (setConstitutionalMode $mode)
   (if (constitutionalModeValid $mode)
       (let $_ (change-state! &mode-transition-state (ModeTransitionState $mode 0 none 0 0))
          (change-state! &constitutional-mode $mode))
       (ModeRejected $mode)))
