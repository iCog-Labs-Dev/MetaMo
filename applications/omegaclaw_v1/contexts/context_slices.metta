;; Bounded ContextFrames exposure slices.
;;
;; Slices are pure views over a supplied FrameStateBundle. They never read
;; ContextFrames state directly, which keeps one bundle snapshot consistent
;; throughout a MetaMo cycle.

(= (frameStateSliceRoot $root)
   (let (FrameStateRoot
            (id $id)
            (current-frame-id $currentID)
            (mode $mode)
            $_
            $_)
         $root
      (FrameSliceRoot
         (current-frame-id $currentID)
         (mode $mode))))

;; ContextFrames fixtures may use the compact positional root form.
(= (frameStateSliceRoot
      (FrameStateRoot $id $currentID (mode $mode) $_ $_))
   (FrameSliceRoot
      (current-frame-id $currentID)
      (mode $mode)))

(= (frameStateSliceCurrentMinimal $current)
   (let (FrameStateCurrent
            (id $id)
            $_
            $_
            (status $status)
            $_
            (priority $priority)
            $_
            $_
            $_
            (budget $budget)
            $_
            $_
            $_)
         $current
      (FrameSliceCurrent
         (id $id)
         (status $status)
         (priority $priority)
         (budget $budget))))

(= (frameStateSliceCurrentMinimal
      (FrameStateCurrent $id $_ $_ (status $status) $_ (priority $priority)
         $_ $_ $_ (budget $budget) $_ $_ $_))
   (FrameSliceCurrent
      (id $id) (status $status) (priority $priority) (budget $budget)))

(= (frameStateSliceCurrentSummary $current)
   (let (FrameStateCurrent
            (id $id)
            (parent $parent)
            (source $source)
            (status $status)
            (frame-mode $mode)
            (priority $priority)
            (goal-summary $goal)
            (history-summary $history)
            (deliverable-summary $deliverables)
            (results-summary $results)
            (budget $budget)
            (constraints $constraints)
            $_)
         $current
      (FrameSliceCurrent
         (id $id)
         (parent $parent)
         (source $source)
         (status $status)
         (frame-mode $mode)
         (priority $priority)
         (goal-summary $goal)
         (history-summary $history)
         (deliverable-summary $deliverables)
         (results-summary $results)
         (budget $budget)
         (constraints $constraints))))

(= (frameStateSliceCurrentTask $current)
   (let (FrameStateCurrent
            (id $id)
            (parent $parent)
            (source $source)
            (status $status)
            (frame-mode $mode)
            (priority $priority)
            (goal-summary $goal)
            (history-summary $history)
            (deliverable-summary $deliverables)
            (results-summary $results)
            (budget $budget)
            (constraints $constraints)
            (certified-method $method))
         $current
      (FrameSliceCurrent
         (id $id)
         (parent $parent)
         (source $source)
         (status $status)
         (frame-mode $mode)
         (priority $priority)
         (goal-summary $goal)
         (history-summary $history)
         (deliverable-summary $deliverables)
         (results-summary $results)
         (budget $budget)
         (constraints $constraints)
         (certified-method $method))))

(= (frameStateSliceRuntime $runtime)
   (let (FrameStateRuntime
            (new-message $newMessage)
            (message-present $messagePresent)
            (message-summary $messageSummary)
            (task-open $taskOpen)
            (task-execution-observed $observed)
            (active-task-summary $activeTask)
            (last-results-summary $lastResults)
            (error $error)
            (wake-loops $wakeLoops)
            (next-wake-at $nextWake)
            (budget-state $budgetState))
         $runtime
         (FrameSliceRuntime
         (new-message $newMessage)
         (message-present $messagePresent)
         (last-results-summary $lastResults)
         (error $error)
         (wake-loops $wakeLoops)
         (next-wake-at $nextWake)
         (budget-state $budgetState))))

(= (frameStateForSlice Minimal
      (FrameStateBundle (root $root) (current $current) $_ $_ $_))
   ;; Minimal exposes only root mode and current-frame identity/status/priority.
   (FrameStateSlice
      (slice Minimal)
      (root (frameStateSliceRoot $root))
      (current (frameStateSliceCurrentMinimal $current))
      (index ())
      (relations ())
      (runtime ())))

(= (frameStateForSlice CurrentFrameSummary
      (FrameStateBundle (root $root) (current $current) $_ $_ $_))
   ;; Summary exposes bounded current-frame descriptive fields.
   (FrameStateSlice
      (slice CurrentFrameSummary)
      (root (frameStateSliceRoot $root))
      (current (frameStateSliceCurrentSummary $current))
      (index ())
      (relations ())
      (runtime ())))

(= (frameStateForSlice CurrentFrameTask
      (FrameStateBundle (root $root) (current $current) $_ $_ (runtime $runtime)))
   ;; Task context adds the certified method and selected runtime facts.
   (FrameStateSlice
      (slice CurrentFrameTask)
      (root (frameStateSliceRoot $root))
      (current (frameStateSliceCurrentTask $current))
      (index ())
      (relations ())
      (runtime (frameStateSliceRuntime
                   $runtime))))

(= (frameStateForSlice CurrentFrameAndRelations $bundle)
   ;; Relations are advisory evidence; they do not mutate frame topology.
   (FrameStateSlice
      (slice CurrentFrameAndRelations)
      (root (frameStateSliceRoot
               (let (FrameStateBundle (root $root) $_ $_ $_ $_) $bundle $root)))
      (current (frameStateSliceCurrentTask
                  (let (FrameStateBundle $_ (current $current) $_ $_ $_)
                     $bundle $current)))
      (index ())
      (relations (let (FrameStateBundle $_ $_ $_ (relations $relations) $_)
                     $bundle $relations))
      (runtime (frameStateSliceRuntime
                   (let (FrameStateBundle $_ $_ $_ $_ (runtime $runtime))
                     $bundle $runtime)))))

(= (frameStateForSlice IndexOverview
      (FrameStateBundle (root $root) $_ (index $active $completed) $_ $_))
   ;; Index overview exposes the bounded active/completed references already
   ;; captured in the supplied bundle.
   (FrameStateSlice
      (slice IndexOverview)
      (root (frameStateSliceRoot $root))
      (current ())
      (index (index $active $completed))
      (relations ())
      (runtime ())))
