;; Pure MeTTa review policy plus session-local scheduling memory.
;; Loaded after the context facade (tpContains/tpResource and bundle accessors).
;; No host mutation, action admission, priority promotion, or execution.

(= (rsId $id)
   (or (== (get-metatype $id) Symbol) (tpId $id)))
(= (rsCount $n $limit)
   (if (tpQuantity $n)
       (and (<= $n $limit) (== (floor-math $n) $n)) 
       False
   )
)

(= (rsConfigValid $config)
   (case $config (
      ((FrameResurfacingPolicy $cap $batch $delay)
       (if (tpAllTrue ((rsCount $cap 128) (rsCount $batch 128)
                       (rsCount $delay 1000)))
           (and (> $cap 0) (and (> $batch 0)
              (and (<= $batch $cap) (> $delay 0)))) False))
      ($_ False))
   )
)

   
(= (rsEntryValid $kind $entry)
   (case $entry (
      ((ResurfacingFrame $id $reason)
       (and (== $kind rows) (and (rsId $id)
          (tpContains (Blocked Deferred) $reason))))
      ((ReviewDue $id $reason $due)
       (and (== $kind state) (and (rsId $id)
          (and (tpContains (Blocked Deferred) $reason)
               (rsCount $due 9007199254740991)))))
      ($_ False))))

(= (rsListValid $kind $items $remaining $seen)
   (if (== (get-metatype $items) Expression)
       (if (== $items ()) 
         True
           (if (<= $remaining 0) 
               False
               (let ($head $tail) (decons-atom $items)
                  (if (rsEntryValid $kind $head)
                      (let $id (index-atom $head 1)
                         (if (tpContains $seen $id) False
                             (rsListValid $kind $tail (- $remaining 1)
                              (cons-atom $id $seen))
                        )) 
                     False
                  )
               )
            )
      ) 
      False  
   )
)

;; Preserve queue order and age even when host index order or reason changes.
(= (rsRetain $old $rows)
   (if (== $old ()) ()
       (let* ((($head $tail) (decons-atom $old))
              ((ReviewDue $id $_reason $due) $head)
              ($row (tpResource $rows $id))
              ($rest (rsRetain $tail $rows)))
          (if (== $row None) $rest
              (cons-atom (ReviewDue $id (index-atom $row 2) $due) $rest)))))


(= (rsNew $rows $old $due)
   (if (== $rows ()) ()
       (let* ((($head $tail) (decons-atom $rows))
              ((ResurfacingFrame $id $reason) $head)
              ($rest (rsNew $tail $old $due)))
          (if (== (tpResource $old $id) None)
              (cons-atom (ReviewDue $id $reason $due) $rest) $rest))))

;; Selected entries move to the tail; existing waiting work precedes arrivals.
(= (rsReview $queue $cycle $slots $delay)
   (if (== $queue ()) (ReviewPass () () ())
       (let* ((($head $tail) (decons-atom $queue))
              ((ReviewDue $id $reason $due) $head)
              ($selected (and (> $slots 0) (<= $due $cycle)))
              ((ReviewPass $waiting $reviewed $hints)
                 (rsReview $tail $cycle (if $selected (- $slots 1) $slots) $delay)))
          (if $selected
              (ReviewPass $waiting
                 (cons-atom (ReviewDue $id $reason (+ $cycle $delay)) $reviewed)
                 (cons-atom (FrameReview $id $reason) $hints))
              (ReviewPass (cons-atom $head $waiting) $reviewed $hints)))))



(= (rsStepChecked $cap $batch $delay $cycle $old $rows)
   (if (and (rsCount $cycle 9007199254739990)
            (and (rsListValid state $old $cap ())
                 (rsListValid rows $rows $cap ())))
       (let* (($next (+ $cycle 1))
              ($queue (append (rsRetain $old $rows)
                              (rsNew $rows $old (+ $next $delay))))
              ((ReviewPass $waiting $reviewed $hints)
                 (rsReview $queue $next $batch $delay)))
          (ResurfacingResult (ResurfacingState $next (append $waiting $reviewed)) $hints))
       (ResurfacingRejected InvalidOrOverCapacity)))


(= (frameResurfacingStep $config $state $rows)
   (if (and (is-ground ($config $state $rows)) (rsConfigValid $config))
       (case $state (
          ((ResurfacingState $cycle $old)
           (let (FrameResurfacingPolicy $cap $batch $delay) $config
              (rsStepChecked $cap $batch $delay $cycle $old $rows)))
          ($_ (ResurfacingRejected InvalidOrOverCapacity))))
       (ResurfacingRejected InvalidOrOverCapacity)))

;; Host projection helpers. The complete typed index is bounded before review;
;; compacted display text cannot silently hide waiting frames.
(= (rsStatus $status)
   (case $status (((status $value) $value) ($_ $status))))
(= (rsFrameRow $id $rawStatus $candidate)
   (let $status (rsStatus $rawStatus)
      (if (rsId $id)
          (case $status (
             (Blocked (ResurfacingFrame $id Blocked))
             (Suspended (ResurfacingFrame $id Deferred))
             (Active (if (tpContains (defer none waiting) $candidate)
                         (ResurfacingFrame $id Deferred) Skip))
             (Focused (if (tpContains (defer none waiting) $candidate)
                          (ResurfacingFrame $id Deferred) Skip))
             (Completed Skip) (Failed Skip) (Archived Skip)
             ($_ Invalid))) Invalid)))


(= (rsIndexRows $index $current $remaining)
   (if (== (get-metatype $index) Expression)
       (if (== $index ()) (ResurfacingRows ())
           (if (<= $remaining 0) (ResurfacingRejected IndexScanLimit)
               (let* ((($head $tail) (decons-atom $index))
                      ($row (if (is-ground $head) (case $head (
                         (() Skip)
                         ((FrameRef (frameID $id) $_parent $_space $_source
                             $_priority $status $_mode $_summary $_created $_updated $_completed)
                          (if (== $id $current) Skip (rsFrameRow $id $status waiting)))
                         ($_ Invalid))) Invalid)))
                  (if (== $row Invalid) (ResurfacingRejected InvalidIndex)
                      (case (rsIndexRows $tail $current (- $remaining 1)) (
                         ((ResurfacingRows $rows)
                          (ResurfacingRows (if (== $row Skip) $rows (cons-atom $row $rows))))
                         ($error $error)))))))
       (ResurfacingRejected InvalidIndex)))



(= (frameResurfacingRows $config $index $current $status $candidate)
   (if (and (is-ground ($config $current $status $candidate)) (rsConfigValid $config))
       (case (rsIndexRows $index $current 512) (
          ((ResurfacingRows $indexed)
           (let* (($row (if (== $current ()) Skip (rsFrameRow $current $status $candidate)))
                  ($rows (if (== $row Skip) $indexed (cons-atom $row $indexed)))
                  ((FrameResurfacingPolicy $cap $_batch $_delay) $config))
              (if (rsListValid rows $rows $cap ()) (ResurfacingRows $rows)
                  (ResurfacingRejected InvalidOrOverCapacity))))
          ($error $error)))
       (ResurfacingRejected InvalidOrOverCapacity)))

!(bind! &frame-resurfacing-state (new-state (ResurfacingState 0 ())))
!(bind! &last-frame-reviews (new-state ()))
(= (frameResurfacingConfig)
   (let $configs (collapse (match &self
      (FrameResurfacingPolicy $capacity $batch $delay)
      (FrameResurfacingPolicy $capacity $batch $delay)))
      (if (== (size-atom $configs) 1) (car-atom $configs) Invalid)))

(= (resetFrameResurfacing)
   (progn (change-state! &frame-resurfacing-state (ResurfacingState 0 ()))
          (change-state! &last-frame-reviews ())))
          
(= (applyFrameResurfacingRows $input)
   (let $result (case $input (
      ((ResurfacingRows $rows) (frameResurfacingStep (frameResurfacingConfig)
         (get-state &frame-resurfacing-state) $rows))
      ($error $error)))
      (case $result (
         ((ResurfacingResult $state $hints)
          (progn (change-state! &frame-resurfacing-state $state)
                 (change-state! &last-frame-reviews $hints)))
         ($error (change-state! &last-frame-reviews $error))))))

(= (refreshFrameResurfacing $bundle $candidate)
   (applyFrameResurfacingRows (frameStateResurfacingRows $bundle $candidate)))

(= (lastFrameReviews) (get-state &last-frame-reviews))
