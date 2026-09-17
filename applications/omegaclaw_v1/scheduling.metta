;; Scheduling precedence over already-admitted work. This module is pure:
;; it consumes existing signal facts and actions, never changes a mode, and
;; cannot authorize work. Registry entries are the single source of ranks.

!(import! &self (library MetaMo applications/omegaclaw_v1/mode_triggers))

(= (schedulingPriorityOrder)
   (collapse (match &self (SchedulingPriority $class $_rank) $class)))

(= (schedulingPriorityRank $class)
   (let $ranks (collapse (match &self (SchedulingPriority $class $rank) $rank))
      (if (== $ranks ()) 0 (car-atom $ranks))))

;; Unknown classes are not scheduling priorities, even on the losing side.
(= (schedulingPriorityPreempts $higher $lower)
   (let* (
      ($higherRank (schedulingPriorityRank $higher))
      ($lowerRank (schedulingPriorityRank $lower)))
      (and (> $lowerRank 0) (> $higherRank $lowerRank))))

(= (schedulingThreat $signals)
   (modeSignalGroupActive threat Enter $signals))

(= (schedulingRecovery $signals)
   (modeSignalGroupActive recovery Enter $signals))

(= (schedulingBasePriority $candidate)
   (let $classes
         (collapse (match &self (CandidateSchedulingPriority $candidate $class) $class))
      (if (== $classes ()) Unknown (car-atom $classes))))

(= (schedulingPromotedPriority $signals $rows $best)
   (if (== $rows ()) $best
       (let* (
          (($head $tail) (decons-atom $rows))
          ((SchedulingPromotion $_candidate $group $class) $head)
          ($promote (and (modeSignalGroupActive $group Enter $signals)
                        (> (schedulingPriorityRank $class) (schedulingPriorityRank $best)))))
          (schedulingPromotedPriority $signals $tail (if $promote $class $best)))))

(= (schedulingPriorityForCandidate $signals $candidate)
   (schedulingPromotedPriority $signals
      (collapse (match &self (SchedulingPromotion $candidate $group $class)
         (SchedulingPromotion $candidate $group $class)))
      (schedulingBasePriority $candidate)))

(= (schedulingActionRank $signals (action $candidate $_ $_ $_))
   (schedulingPriorityRank (schedulingPriorityForCandidate $signals $candidate)))

(= (highestSchedulingRank $signals $actions)
   (if (== $actions ())
       0
       (let* (
          (($head $tail) (decons-atom $actions))
          ($rank (schedulingActionRank $signals $head))
          ($rest (highestSchedulingRank $signals $tail)))
          (if (> $rank $rest) $rank $rest))))

(= (actionsAtSchedulingRank $signals $rank $actions)
   (if (== $actions ())
       ()
       (let* (
          (($head $tail) (decons-atom $actions))
          ($rest (actionsAtSchedulingRank $signals $rank $tail)))
          (if (== (schedulingActionRank $signals $head) $rank)
              (cons-atom $head $rest)
              $rest))))

;; Keep all actions at the highest known rank, preserving order and payloads.
;; Lower ranks are deferred, not policy-rejected. No scoring occurs here.
;; Unknown-only input returns no work; it cannot manufacture a priority.
(= (scheduleAdmittedActions $signals $actions)
   (let $rank (highestSchedulingRank $signals $actions)
      (if (== $rank 0) () (actionsAtSchedulingRank $signals $rank $actions))))
