;; Named accessors for bounded FrameStateBundle and FrameStateRuntime values.
;;
;; These predicates are the read-only API consumed by MetaMo modules. They do
;; not reach through the bundle into ContextFrames state.

;; Named accessors keep MetaMo modules from reaching through the bundle into
;; ContextFrames state directly.
(= (frameBundleRoot $bundle)
   (let (FrameStateBundle (root $root) $_ $_ $_ $_) $bundle $root))
(= (frameBundleCurrent $bundle)
   (let (FrameStateBundle $_ (current $current) $_ $_ $_) $bundle $current))
(= (frameBundleIndex $bundle)
   (let (FrameStateBundle $_ $_ (index $active $completed) $_ $_)
         $bundle
      (index $active $completed)))
(= (frameBundleRelations $bundle)
   (let (FrameStateBundle $_ $_ $_ (relations $relations) $_) $bundle $relations))
(= (frameBundleRuntime $bundle)
   (let (FrameStateBundle $_ $_ $_ $_ (runtime $runtime)) $bundle $runtime))

(= (frameBundleCurrentStatus $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            (id $id) (parent $parent) $source (status $value)
            (frame-mode $mode) (priority $priority) $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentMode $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            (id $id) (parent $parent) $source $status (frame-mode $value)
            (priority $priority) $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentPriority $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            (id $id) (parent $parent) $source $status (frame-mode $mode)
            (priority $value) $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentBudget $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            (id $id) (parent $parent) $source $status (frame-mode $mode)
            (priority $priority) $goal
            $history $deliverables $results (budget $value) $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentHistory $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            (id $id) (parent $parent) $source $status (frame-mode $mode)
            (priority $priority) $goal
            (history-summary $value) $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleRootMode $bundle)
   (let (FrameStateBundle (root (FrameStateRoot $id $currentFrame (mode $value)
            $globalBudget $globalConstraints)) $current $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentId $bundle)
   (let (FrameStateBundle (root $root) (current (FrameStateCurrent
            (id $value) $parent $source $status $mode $priority $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))

;; Typed projections are the only runtime values consumed by MetaMo modules.
(= (frameRuntimeNewMessage $bundle)
   (let (FrameStateRuntime (new-message $value) (message-present $messagePresent)
            (message-summary $messageSummary) (task-open $taskOpen)
            (task-execution-observed $observed)
            (active-task-summary $activeTask) (last-results-summary $results)
            (error $error) (wake-loops $wakeLoops) (next-wake-at $nextWake)
            (budget-state $budgetState))
         (frameBundleRuntime $bundle) $value))
(= (frameRuntimeMessagePresent $bundle)
   (let (FrameStateRuntime (new-message $newMessage) (message-present $value)
            (message-summary $messageSummary) (task-open $taskOpen)
            (task-execution-observed $observed)
            (active-task-summary $activeTask) (last-results-summary $results)
            (error $error) (wake-loops $wakeLoops) (next-wake-at $nextWake)
            (budget-state $budgetState))
         (frameBundleRuntime $bundle) $value))
(= (frameRuntimeMessage $bundle)
   (let (FrameStateRuntime (new-message $newMessage) (message-present $messagePresent)
            (message-summary $value) (task-open $taskOpen)
            (task-execution-observed $observed)
            (active-task-summary $activeTask) (last-results-summary $results)
            (error $error) (wake-loops $wakeLoops) (next-wake-at $nextWake)
            (budget-state $budgetState))
         (frameBundleRuntime $bundle) $value))
(= (frameRuntimeTaskOpen $bundle)
   (let (FrameStateRuntime (new-message $newMessage) (message-present $messagePresent)
            (message-summary $messageSummary) (task-open $value)
            (task-execution-observed $observed)
            (active-task-summary $activeTask) (last-results-summary $results)
            (error $error) (wake-loops $wakeLoops) (next-wake-at $nextWake)
            (budget-state $budgetState))
         (frameBundleRuntime $bundle) $value))
(= (frameRuntimeActiveTask $bundle)
   (let (FrameStateRuntime (new-message $newMessage) (message-present $messagePresent)
            (message-summary $messageSummary) (task-open $taskOpen)
            (task-execution-observed $observed)
            (active-task-summary $value) (last-results-summary $results)
            (error $error) (wake-loops $wakeLoops) (next-wake-at $nextWake)
            (budget-state $budgetState))
         (frameBundleRuntime $bundle) $value))
(= (frameRuntimeResults $bundle)
   (let (FrameStateRuntime (new-message $newMessage) (message-present $messagePresent)
            (message-summary $messageSummary) (task-open $taskOpen)
            (task-execution-observed $observed)
            (active-task-summary $activeTask) (last-results-summary $value)
            (error $error) (wake-loops $wakeLoops) (next-wake-at $nextWake)
            (budget-state $budgetState))
         (frameBundleRuntime $bundle) $value))
(= (frameRuntimeError $bundle)
   (let (FrameStateRuntime (new-message $newMessage) (message-present $messagePresent)
            (message-summary $messageSummary) (task-open $taskOpen)
            (task-execution-observed $observed)
            (active-task-summary $activeTask) (last-results-summary $results)
            (error $value) (wake-loops $wakeLoops) (next-wake-at $nextWake)
            (budget-state $budgetState))
         (frameBundleRuntime $bundle) $value))

(= (frameRuntimeExecutionObserved $bundle)
   (let (FrameStateRuntime (new-message $newMessage) (message-present $messagePresent)
            (message-summary $messageSummary) (task-open $taskOpen)
            (task-execution-observed $value)
            (active-task-summary $activeTask) (last-results-summary $results)
            (error $error) (wake-loops $wakeLoops) (next-wake-at $nextWake)
            (budget-state $budgetState))
         (frameBundleRuntime $bundle) $value))

(= (frameRuntimeText $value)
   ;; Example: `(frameRuntimeText ())` returns the safe empty string `""`,
   ;; while `(frameRuntimeText "result")` returns `"result"`.
   (if (== $value ()) "" $value))

;; Migration seam: keep raw OmegaClaw state reads in this adapter and expose
;; only derived, bounded values to MetaMo modules.
(= (bundle-runtime-has-error $bundle)
   (not (== (frameRuntimeError $bundle) "")))
(= (bundle-runtime-has-new-message $bundle)
   (frameRuntimeNewMessage $bundle))
(= (bundle-current-status $bundle)
   (frameBundleCurrentStatus $bundle))
(= (bundle-current-budget-state $bundle)
   (frameBundleCurrentBudget $bundle))
(= (bundle-current-priority $bundle)
   (frameBundleCurrentPriority $bundle))
