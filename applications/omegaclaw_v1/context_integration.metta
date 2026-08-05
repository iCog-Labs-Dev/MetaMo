;; ContextFrames integration boundary for the v1 MetaMo application.
;;
;; MetaMo does not mutate ContextFrames. It receives a small policy result and
;; emits an AttentionDirective for the scheduler/reasoner. The existing
;; candidate scorer remains the transitional S3 selector.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Bounded FrameStateBundle
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This is the sole ContextFrames -> MetaMo state boundary. The bundle contains
;; compact projections, not the raw RootFrame/current-frame cache, transcript,
;; command log, or vector-store records.
;;
;; Exact chronological data remains in the audit substrates owned by
;; OmegaClaw/ContextFrames: history.metta, frame notes, command-batch records,
;; STM/LTM memory, and runtime logs. Those substrates are deliberately not
;; fields of FrameStateBundle.

(= (frameStateGoalSummary)
   (let $goalNamespace (get-state &cfv2-current-goal-namespace)
      (if (== $goalNamespace ())
          ()
          (get-state $goalNamespace))))

;; Fixed-cardinality bounds are applied before character compaction. This
;; keeps a large number of short refs/relations from bypassing text limits.
(= (frameStateMaxIndexRefs) 20)
(= (frameStateMaxRelations) 10)

(= (frameStateTake $n () ()) ())
(= (frameStateTake $n $items)
   (if (<= $n 0)
       ()
       (let* (
          (($head $tail) (decons-atom $items))
          ($rest (frameStateTake (- $n 1) $tail)))
          (cons $head $rest))))

(= (frameStateBoundRefs $status)
   (if (== (get-state &cfv2-frame-indexspace) ())
       ()
       (let $refs (cfv2-frame-refs-by-status $status)
          (if (== $refs FRAME-REF-EMPTY)
              ()
              (frameStateTake (frameStateMaxIndexRefs) $refs)))))

(= (frameStateRootProjection)
   (let $root (cfv2-root-frame)
      (FrameStateRoot
         (id (get-state &cfv2-root-id))
         (current-frame-id (get-state &cfv2-current-frame-id))
         (mode (get-state &cfv2-root-mode))
         (global-budget (cfv2-compact-limited
                           (get-state &cfv2-global-budget) 600))
         (global-constraints (cfv2-compact-limited
                                (get-state &cfv2-global-constraints) 900)))))

(= (frameStateCurrentProjection)
   (let $frame (cfv2-current-frame)
      (FrameStateCurrent
         (id (get-state &cfv2-current-frame-id))
         (parent (cfv2-compact-limited
                    (get-state &cfv2-current-parent-frame-id) 120))
         (source (get-state &cfv2-current-source))
         (status (get-state &cfv2-current-status))
         (frame-mode (get-state &cfv2-current-frame-mode))
         (priority (get-state &cfv2-current-priority))
         (goal-summary (cfv2-compact-limited
                           (frameStateGoalSummary) 500))
         (history-summary (cfv2-compact-limited
                              (get-state &cfv2-current-history-summary) 900))
         (deliverable-summary (cfv2-compact-limited
                                  (get-state &cfv2-current-deliverables) 500))
         (results-summary (cfv2-compact-limited
                             (get-state &cfv2-current-results) 900))
         (budget (cfv2-compact-limited
                    (get-state &cfv2-current-budget) 600))
         (constraints (cfv2-compact-limited
                         (get-state &cfv2-current-constraints) 900))
         (certified-method (cfv2-compact-limited
                              (get-state &cfv2-current-method) 500)))))

(= (frameStateIndexProjection)
   (let $index (cfv2-frame-indexspace)
      (FrameStateIndex
         (active (cfv2-compact-limited
                    (frameStateBoundRefs Active) 1200))
         (completed (cfv2-compact-limited
                       (frameStateBoundRefs Completed) 1200)))))

(= (frameStateBundle)
   (let* (
      ($currentID (get-state &cfv2-current-frame-id))
      ($relations (if (== $currentID ()) ()
                     (cfv2-compact-limited
                        (frameStateTake (frameStateMaxRelations)
                           (cfv2-get-relation $currentID))
                        1200)))
      ($root (frameStateRootProjection))
      ($current (frameStateCurrentProjection))
      ($index (frameStateIndexProjection))
      ($runtime
         (FrameStateRuntime
            (new-message (get-state &new-msg-flag))
            (message-present (not (== (get-state &prevmsg) "")))
            (message-summary
               (cfv2-compact-limited (get-state &prevmsg) 1200))
            ;; Task lifecycle fields are exposed only as bounded, typed
            ;; projections. MetaMo must not read the OmegaClaw states below.
            (task-open (get-state &task-open))
            (task-execution-observed
               (cfv2-compact-limited
                  (get-state &task-execution-observed) 1200))
            (active-task-summary
               (cfv2-compact-limited (get-state &active-task) 500))
            (last-results-summary
               (cfv2-compact-limited
                  (get-state &lastresults) 1200))
            (error
               (cfv2-compact-limited
                  (get-state &error) 600))
            (wake-loops (get-state &loops))
            (next-wake-at (get-state &nextWakeAt))
            (budget-state
               (cfv2-compact-limited
                  (get-state &cfv2-current-budget) 600))))
   )
      (FrameStateBundle
         (root $root)
         (current $current)
         (index $index)
         (relations $relations)
         (runtime $runtime))))

;; Explicit MetaMo boundary name. Callers should use this projection rather
;; than passing RootFrame, CurrentFrame, history, or audit records directly.
(= (frameStateForMetaMo)
   (frameStateBundle))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Bounded exposure slices
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A slice describes exposure depth only. It is not a priority, urgency, or
;; candidate score.

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
            (next-wake-at $nextWakeAt)
            (budget-state $budgetState))
         $runtime
         (FrameSliceRuntime
         (new-message $newMessage)
         (message-present $messagePresent)
         (last-results-summary $lastResults)
         (error $error)
         (wake-loops $wakeLoops)
         (next-wake-at $nextWakeAt)
         (budget-state $budgetState))))

;; Direct slice projections use the already bounded ContextFrames cache. They
;; intentionally reconstruct only the fields allowed by each slice.
(= (frameStateDirectRoot)
   (FrameSliceRoot
      (current-frame-id (get-state &cfv2-current-frame-id))
      (mode (get-state &cfv2-root-mode))))

(= (frameStateDirectMinimal)
   (FrameSliceCurrent
      (id (get-state &cfv2-current-frame-id))
      (status (get-state &cfv2-current-status))
      (priority (get-state &cfv2-current-priority))
      (budget (cfv2-compact-limited
                 (get-state &cfv2-current-budget) 600))))

(= (frameStateDirectSummary)
   (FrameSliceCurrent
      (id (get-state &cfv2-current-frame-id))
      (parent (cfv2-compact-limited
                 (get-state &cfv2-current-parent-frame-id) 120))
      (source (get-state &cfv2-current-source))
      (status (get-state &cfv2-current-status))
      (frame-mode (get-state &cfv2-current-frame-mode))
      (priority (get-state &cfv2-current-priority))
      (goal-summary (cfv2-compact-limited
                        (frameStateGoalSummary) 500))
      (history-summary (cfv2-compact-limited
                           (get-state &cfv2-current-history-summary) 900))
      (deliverable-summary (cfv2-compact-limited
                               (get-state &cfv2-current-deliverables) 500))
      (results-summary (cfv2-compact-limited
                           (get-state &cfv2-current-results) 900))
      (budget (cfv2-compact-limited
                 (get-state &cfv2-current-budget) 600))
      (constraints (cfv2-compact-limited
                      (get-state &cfv2-current-constraints) 900))))

(= (frameStateDirectTask)
   (FrameSliceCurrent
      (id (get-state &cfv2-current-frame-id))
      (parent (cfv2-compact-limited
                 (get-state &cfv2-current-parent-frame-id) 120))
      (source (get-state &cfv2-current-source))
      (status (get-state &cfv2-current-status))
      (frame-mode (get-state &cfv2-current-frame-mode))
      (priority (get-state &cfv2-current-priority))
      (goal-summary (cfv2-compact-limited
                        (frameStateGoalSummary) 500))
      (history-summary (cfv2-compact-limited
                           (get-state &cfv2-current-history-summary) 900))
      (deliverable-summary (cfv2-compact-limited
                               (get-state &cfv2-current-deliverables) 500))
      (results-summary (cfv2-compact-limited
                           (get-state &cfv2-current-results) 900))
      (budget (cfv2-compact-limited
                 (get-state &cfv2-current-budget) 600))
      (constraints (cfv2-compact-limited
                      (get-state &cfv2-current-constraints) 900))
      (certified-method (cfv2-compact-limited
                           (get-state &cfv2-current-method) 500))))

(= (frameStateForSlice Minimal $bundle)
   (FrameStateSlice
      (slice Minimal)
      (root (frameStateDirectRoot))
      (current (frameStateDirectMinimal))
      (index ())
      (relations ())
      (runtime ())))

(= (frameStateForSlice CurrentFrameSummary $bundle)
   (FrameStateSlice
      (slice CurrentFrameSummary)
      (root (frameStateDirectRoot))
      (current (frameStateDirectSummary))
      (index ())
      (relations ())
      (runtime ())))

(= (frameStateForSlice CurrentFrameTask $bundle)
   (FrameStateSlice
      (slice CurrentFrameTask)
      (root (frameStateDirectRoot))
      (current (frameStateDirectTask))
      (index ())
      (relations ())
      (runtime (frameStateSliceRuntime
                   (frameBundleRuntime (frameStateBundle))))))

(= (frameStateForSlice CurrentFrameAndRelations $bundle)
   (FrameStateSlice
      (slice CurrentFrameAndRelations)
      (root (frameStateDirectRoot))
      (current (frameStateDirectTask))
      (index ())
      (relations (if (== (get-state &cfv2-current-frame-id) ())
                     ()
                     (cfv2-compact-limited
                        (frameStateTake (frameStateMaxRelations)
                           (cfv2-get-relation
                              (get-state &cfv2-current-frame-id)))
                        1200)))
      (runtime (frameStateSliceRuntime
                   (frameBundleRuntime (frameStateBundle))))))

(= (frameStateForSlice IndexOverview $bundle)
   (FrameStateSlice
      (slice IndexOverview)
      (root (frameStateDirectRoot))
      (current ())
      (index (frameStateIndexProjection))
      (relations ())
      (runtime ())))


;; Named accessors keep MetaMo modules from reaching through the bundle into
;; ContextFrames state directly.
(= (frameBundleRoot $bundle)
   (let (FrameStateBundle (root $root) $_ $_ $_ $_) $bundle $root))
(= (frameBundleCurrent $bundle)
   (let (FrameStateBundle $_ (current $current) $_ $_ $_) $bundle $current))
(= (frameBundleIndex $bundle)
   (let (FrameStateBundle $_ $_ (index $index) $_ $_) $bundle $index))
(= (frameBundleRelations $bundle)
   (let (FrameStateBundle $_ $_ $_ (relations $relations) $_) $bundle $relations))
(= (frameBundleRuntime $bundle)
   (let (FrameStateBundle $_ $_ $_ $_ (runtime $runtime)) $bundle $runtime))

(= (frameBundleCurrentStatus $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            $id $parent $source (status $value) $mode $priority $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentMode $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            $id $parent $source $status (frame-mode $value) $priority $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentPriority $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            $id $parent $source $status $mode (priority $value) $goal
            $history $deliverables $results $budget $constraints $method))
         $index $relations $runtime)
         $bundle $value))
(= (frameBundleCurrentBudget $bundle)
   (let (FrameStateBundle $root (current (FrameStateCurrent
            $id $parent $source $status $mode $priority $goal
            $history $deliverables $results (budget $value) $constraints $method))
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
   (if (== $value ()) "" $value))

;; Migration seam: keep raw OmegaClaw state reads in this adapter and expose
;; only derived, bounded values to MetaMo modules.
(= (bundle-runtime-has-error $bundle)
   (not (== (get-state &error) "")))
(= (bundle-runtime-has-new-message $bundle)
   (frameRuntimeNewMessage $bundle))
(= (bundle-current-status $bundle)
   (frameBundleCurrentStatus $bundle))
(= (bundle-current-budget-state $bundle)
   (frameBundleCurrentBudget $bundle))
(= (bundle-current-priority $bundle)
   (frameBundleCurrentPriority $bundle))

!(bind! &last-attention-directive
   (new-state
      (AttentionDirective
         (target ())
         (slice None)
         (task none)
         (admission Rejected)
         (priority 0)
         (source MetaMo))))

(= (cfv2-current-frame-active)
   (or (== (get-state &cfv2-current-status) Active)
       (== (get-state &cfv2-current-status) Focused)))

(= (cfv2-current-frame-mode-compatible)
   (== (get-state &cfv2-current-frame-mode)
       (get-state &cfv2-root-mode)))

(= (cfv2-budget-open)
   (let $budget (get-state &cfv2-current-budget)
      (if (== $budget ())
          False
          (case $budget (
             ((ResourceBudget $_ $_ $_ (status Closed)) False)
             ((ResourceBudget $_ $_ $_ (status Exhausted)) False)
             ($_ True))))))

;; These candidates can cause work or side effects and therefore require an
;; admitted, active, mode-compatible frame with an open budget.
(= (candidateRequiresFrame $candidate)
   (case $candidate
      ((execute-skill True)
       (learn True)
       (self-improve True)
       (background-work True)
       (invent-goal True)
       (plan-goal True)
       (repair-failure True)
       ($_ False))))

(= (frameBundleHasCurrent $bundle)
   (not (== (frameBundleCurrentId $bundle) ())))

(= (frameBundleActive $bundle)
   (or (== (bundle-current-status $bundle) Active)
       (== (bundle-current-status $bundle) Focused)))

(= (frameBundleModeCompatible $bundle)
   (== (frameBundleCurrentMode $bundle) (frameBundleRootMode $bundle)))

(= (frameBundleBudgetOpen $bundle)
   (let $budget (bundle-current-budget-state $bundle)
      (case $budget
         ((ResourceBudget $maximum $remaining $unit (status Closed)) False)
          ((ResourceBudget $maximum $remaining $unit (status Exhausted)) False)
          ($otherBudget True))))

(= (contextPolicyGate $bundle $candidate)
   (contextPolicyGateFacts
      (candidateRequiresFrame $candidate)
      (frameBundleHasCurrent $bundle)
      (frameBundleActive $bundle)
      (frameBundleModeCompatible $bundle)
      (frameBundleBudgetOpen $bundle)))

(= (feasibilityGate $bundle $candidate)
   (contextPolicyGate $bundle $candidate))

(= (contextPolicyGateFacts False $_ $_ $_ $_)
   (GateDecision Admitted Feasible))
(= (contextPolicyGateFacts True False $_ $_ $_)
   (GateDecision Rejected NoActiveFrame))
(= (contextPolicyGateFacts True True False $_ $_)
   (GateDecision Rejected InactiveFrame))
(= (contextPolicyGateFacts True True True False $_)
   (GateDecision Rejected FrameModeMismatch))
(= (contextPolicyGateFacts True True True True False)
   (GateDecision Rejected BudgetExhausted))
(= (contextPolicyGateFacts True True True True True)
   (GateDecision Admitted Feasible))

(= (candidateAdmitted $bundle $candidate)
   (let (GateDecision $admission $reason) (feasibilityGate $bundle $candidate)
      (== $admission Admitted)))

(= (feasibilityGateActions $bundle ()) True)
(= (feasibilityGateActions $bundle $actions)
   (let* (
      (($head $tail) (decons-atom $actions))
      ($gate (feasibilityGate $bundle (actionId $head)))
      ((GateDecision $admission $reason) $gate))
      (and (== $admission Admitted)
           (feasibilityGateActions $bundle $tail))))

(= (directiveSlice $candidate)
   (case $candidate
      ((retrieve-memory CurrentFrameAndRelations)
       (search-knowledge CurrentFrameAndRelations)
       (background-work CurrentFrameTask)
       (execute-skill CurrentFrameTask)
       (learn CurrentFrameSummary)
       (self-improve CurrentFrameSummary)
       ($_ CurrentFrameSummary))))

;; Directive priority is deliberately separate from frame priority and
;; candidate score. It is a bounded scheduler hint derived from both inputs;
;; neither source value is overwritten.
(= (directivePriority $bundle $score)
   (let $framePriority (bundle-current-priority $bundle)
      (clampValue (+ (* 0.70 $score) (* 0.30 $framePriority)))))

(= (makeAttentionDirective $bundle $candidate $score)
   (let* (
      ($gate (feasibilityGate $bundle $candidate))
      ((GateDecision $admission $reason) $gate)
      ($target (if (!= (frameBundleCurrentId $bundle) ())
                   (frameBundleCurrentId $bundle)
                   ()))
      ($priority (if (== $admission Admitted)
                     (directivePriority $bundle $score)
                     0))
   )
      (AttentionDirective
         (target $target)
         (slice (directiveSlice $candidate))
         (task $candidate)
         (admission $admission)
         (reason $reason)
         (priority $priority)
         (source MetaMo))))

(= (attentionDirectiveForDecision $bundle $candidate $score)
   (makeAttentionDirective $bundle $candidate $score))

(= (lastAttentionDirective)
   (get-state &last-attention-directive))
