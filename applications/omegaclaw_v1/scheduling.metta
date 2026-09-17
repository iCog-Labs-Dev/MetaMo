;; Scheduling precedence over already-admitted work. This module is pure:
;; it consumes existing signal facts and actions, never changes a mode, and
;; cannot authorize work. Registry entries are the single source of ranks.

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

(= (schedulingHasSignal $kind $signals)
   (if (== $signals ())
       False
       (let* (
          (($head $tail) (decons-atom $signals))
          ((signal $name $_strength) $head))
          (if (== $name $kind) True (schedulingHasSignal $kind $tail)))))

(= (schedulingThreat $signals)
   (or (schedulingHasSignal danger $signals)
       (schedulingHasSignal user-angry $signals)))

(= (schedulingRecovery $signals)
   (or (schedulingHasSignal failure $signals)
       (or (schedulingHasSignal repeated-failure $signals)
           (schedulingHasSignal stalled-progress $signals))))

(= (schedulingBasePriority $candidate)
   (let $classes
         (collapse (match &self (CandidateSchedulingPriority $candidate $class) $class))
      (if (== $classes ()) Unknown (car-atom $classes))))

(= (schedulingPriorityForCandidate $signals $candidate)
   (let $threatWork
         (collapse (match &self (ThreatRemediationCandidate $candidate) True))
      (if (and (schedulingThreat $signals) (!= $threatWork ()))
          Threat-remediation
          (if (and (== $candidate self-improve) (schedulingRecovery $signals))
              Recovery
              (schedulingBasePriority $candidate)))))

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
