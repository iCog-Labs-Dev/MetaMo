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
            (last-command-result
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

(= (contextPolicyGate $candidate)
   (contextPolicyGateFacts
      (candidateRequiresFrame $candidate)
      (cfv2-has-current-frame)
      (cfv2-current-frame-active)
      (cfv2-current-frame-mode-compatible)
      (cfv2-budget-open)))

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

(= (candidateAdmitted $candidate)
   (let (GateDecision $admission $_reason) (contextPolicyGate $candidate)
      (== $admission Admitted)))

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
(= (directivePriority $score)
   (let $framePriority (get-state &cfv2-current-priority)
      (clampValue (+ (* 0.70 $score) (* 0.30 $framePriority)))))

(= (makeAttentionDirective $candidate $score)
   (let* (
      ($gate (contextPolicyGate $candidate))
      ((GateDecision $admission $reason) $gate)
      ($target (if (cfv2-has-current-frame)
                   (cfv2-root-current-frame-id)
                   ()))
      ($priority (if (== $admission Admitted)
                     (directivePriority $score)
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

(= (attentionDirectiveForDecision $candidate $score)
   (makeAttentionDirective $candidate $score))

(= (lastAttentionDirective)
   (get-state &last-attention-directive))
