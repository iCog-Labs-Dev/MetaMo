;; Pure views of existing signals and the current snapshot. Trigger groups
;; are registry queries, not stored signals or a second appraisal system.

(= (modeSignalMeetsThreshold $kind $threshold $signals)
   (if (== $signals ()) False
       (let* (
          (($head $tail) (decons-atom $signals))
          ((signal $name $strength) $head))
          (if (and (== $kind $name) (>= $strength $threshold)) True
              (modeSignalMeetsThreshold $kind $threshold $tail)))))

(= (modeSignalRowsActive $rows $phase $signals)
   (if (== $rows ()) False
       (let* (
          (($head $tail) (decons-atom $rows))
          ((ModeSignalTrigger $_group $kind $enter $exit) $head)
          ($threshold (if (== $phase Exit) $exit $enter)))
          (if (modeSignalMeetsThreshold $kind $threshold $signals) True
              (modeSignalRowsActive $tail $phase $signals)))))

(= (modeSignalGroupActive $group $phase $signals)
   (modeSignalRowsActive
      (collapse (match &self (ModeSignalTrigger $group $kind $enter $exit)
         (ModeSignalTrigger $group $kind $enter $exit))) $phase $signals))

(= (modeContextCondition $condition $hasFrame)
   (case $condition
      ((frame-present $hasFrame)
       (frame-absent (not $hasFrame))
       ($_ False))))

(= (modeContextRowsActive $rows $hasFrame)
   (if (== $rows ()) False
       (let* (
          (($head $tail) (decons-atom $rows))
          ((ModeContextTrigger $_group $condition) $head))
          (if (modeContextCondition $condition $hasFrame) True
              (modeContextRowsActive $tail $hasFrame)))))

(= (modeTriggerGroupActive $group $phase $signals $hasFrame)
   (or (modeSignalGroupActive $group $phase $signals)
       (modeContextRowsActive
          (collapse (match &self (ModeContextTrigger $group $condition)
             (ModeContextTrigger $group $condition))) $hasFrame)))
