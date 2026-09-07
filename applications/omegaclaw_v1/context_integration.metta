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
;; PUBLIC API AND USAGE GUIDE
;; --------------------------
;; The main public flow is:
;;
;;   (frameStateForMetaMo)
;;       -> (frameStateForSlice <slice> $bundle)
;;       -> (contextPolicyGate $bundle <candidate>)
;;       -> (attentionDirectiveForDecision $bundle <candidate> <score>)
;;
;; Example:
;;
;;   (= (demoBundle) (frameStateForMetaMo))
;;   (frameBundleCurrentId (demoBundle))
;;   (frameStateForSlice CurrentFrameSummary (demoBundle))
;;   (contextPolicyGate (demoBundle) respond)
;;   (attentionDirectiveForDecision (demoBundle) respond 0.80)
;;
;; The predicates in this file are divided into four responsibilities:
;;
;;   1. Projection: build bounded Root/Current/Index/Runtime values.
;;   2. Access: read fields from a FrameStateBundle without raw state access.
;;   3. Policy: check frame, mode, and budget constraints for a candidate.
;;   4. Output: create an AttentionDirective for the scheduler/reasoner.
;;
;; Constructors use tagged fields deliberately. For example, a budget is
;; represented as `(ResourceBudget 10 7 units (status Open))`, and a resulting
;; directive can be inspected with `(directiveSlice $directive)` or by matching
;; its `(admission ...)` and `(reason ...)` fields.
;;
;; Exact chronological data remains in the audit substrates owned by
;; OmegaClaw/ContextFrames: history.metta, frame notes, command-batch records,
;; STM/LTM memory, and runtime logs. Those substrates are deliberately not
;; fields of FrameStateBundle.

;; Relation projection and verification evidence live in a focused submodule;
;; this file remains the compatibility façade for the complete boundary.
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_relations)
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_accessors)
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_slices)

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
         ;; ResourceBudget is already a bounded typed record; preserve its
         ;; status so feasibility can distinguish open/closed/exhausted.
         (budget (get-state &cfv2-current-budget))
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
   ;; Example: `(frameStateBundle)` returns one bounded snapshot of the current
   ;; ContextFrames cache. It is safe to pass that snapshot to MetaMo modules;
   ;; those modules should not read `&cfv2-*` or OmegaClaw runtime states.
   (let* (
      ($currentID (get-state &cfv2-current-frame-id))
      ($relations (if (== $currentID ()) ()
                     (cfv2-compact-limited
                        (frameStateBoundRelations
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
   ;; Preferred boundary call:
   ;;   (= (bundle) (frameStateForMetaMo))
   ;;   (frameBundleCurrentId (bundle))
   ;; This is intentionally equivalent to `(frameStateBundle)` but gives
   ;; callers an explicit name for the ContextFrames -> MetaMo contract.
   (frameStateBundle))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Bounded exposure slices
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A slice describes exposure depth only. It is not a priority, urgency, or
;; candidate score.


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
       (verify-frame-state True)
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
      (frameBundleBudgetOpenValue $budget)))

(= (frameBundleBudgetOpenValue
      (ResourceBudget $_ $_ $_ (status $status)))
   (and (not (== $status Closed))
        (not (== $status Exhausted))))
(= (frameBundleBudgetOpenValue open-budget) True)

(= (contextPolicyGate $bundle $candidate)
   ;; Base policy example:
   ;;   `(contextPolicyGate $bundle execute-skill)` returns either
   ;;   `(GateDecision Admitted Feasible)` or a typed rejection such as
   ;;   `(GateDecision Rejected BudgetExhausted)`.
   ;; Candidates that do not require a frame, such as `respond`, may be
   ;; admitted even when the current-frame requirement is false.
   (contextPolicyGateFacts
      (candidateRequiresFrame $candidate)
      (frameBundleHasCurrent $bundle)
      (frameBundleActive $bundle)
      (frameBundleModeCompatible $bundle)
      (frameBundleBudgetOpen $bundle)))

;; Constitutional modes are a monotonic tightening layer. They may reject an
;; otherwise feasible candidate, but they never admit a candidate rejected by
;; the base action-policy gate.
(= (constitutionalModeGate $candidate)
   ;; Constitutional policy is a tightening layer. Example:
   ;;   `(constitutionalModeGate execute-skill)` rejects operational work in
   ;;   Sleep mode with `SleepModeOperationalWork`; it never overrides a base
   ;;   policy rejection.
   (if (and (== (constitutionalMode) Sleep)
            (candidateRequiresFrame $candidate))
       (GateDecision Rejected SleepModeOperationalWork)
       (GateDecision Admitted Feasible)))

(= (feasibilityGate $bundle $candidate)
   ;; Use this as the complete single-candidate admission check:
   ;;   `(feasibilityGate $bundle respond)`.
   ;; The base context gate runs first; constitutional mode can then further
   ;; reject an otherwise feasible candidate.
   (let (GateDecision $baseAdmission $baseReason)
           (contextPolicyGate $bundle $candidate)
      (if (== $baseAdmission Rejected)
          (GateDecision Rejected $baseReason)
          (constitutionalModeGate $candidate))))

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
   ;; Boolean convenience form:
   ;;   `(candidateAdmitted $bundle respond)` -> `True` or `False`.
   ;; Use `feasibilityGate` instead when the rejection reason is needed.
   (let (GateDecision $admission $reason) (feasibilityGate $bundle $candidate)
      (== $admission Admitted)))

(= (feasibilityGateActions $bundle ()) True)
(= (feasibilityGateActions $bundle $actions)
   ;; Example with adapter actions:
   ;;   `(feasibilityGateActions $bundle (action-list))` returns `True` only
   ;;   when every action in the list is admitted. This predicate checks all
   ;;   actions; it does not remove rejected actions from the list.
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
       (verify-frame-state CurrentFrameAndRelations)
       (background-work CurrentFrameTask)
       (execute-skill CurrentFrameTask)
       (learn CurrentFrameSummary)
       (self-improve CurrentFrameSummary)
       ($_ CurrentFrameSummary))))

;; Explicit scheduler operation for relation evidence that could imply a
;; same-frame judgment. Verification must publish evidence before any merge,
;; rewrite, switch, or action is allowed to rely on the relation.
(= (frameStateVerificationOperation) verify-frame-state)

;; Directive priority is deliberately separate from frame priority and
;; candidate score. It is a bounded scheduler hint derived from both inputs;
;; neither source value is overwritten.
(= (directivePriority $bundle $score)
   (let $framePriority (bundle-current-priority $bundle)
      (clampValue (+ (* 0.70 $score) (* 0.30 $framePriority)))))

(= (makeAttentionDirective $bundle $candidate $score)
   ;; Example:
   ;;   `(makeAttentionDirective $bundle respond 0.80)` returns a typed
   ;;   AttentionDirective containing target, slice, task, admission, reason,
   ;;   bounded priority, and source fields.
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
   ;; Public facade used by the bridge after candidate selection:
   ;;   `(attentionDirectiveForDecision $bundle $candidate $score)`.
   ;; Prefer this name at call sites so the decision-to-scheduler contract is
   ;; clear even if directive construction changes internally.
   (makeAttentionDirective $bundle $candidate $score))

;; Public MetaMo -> scheduler contract. Internal decision/action structures
;; remain available to the motivational dynamics, but this is the only policy
;; result exposed across the integration boundary.
(= (metaMoPolicyOutput $bundle $candidate $score)
   (let* (
      ($directive (attentionDirectiveForDecision $bundle $candidate $score))
      ((AttentionDirective $_ $_ $_ (admission $admission) $_
          (priority $priority) $_) $directive))
      (MetaMoPolicyOutput
         (mode (constitutionalMode))
         (operation-class $candidate)
         (feasibility $admission)
         (priority $priority))))

(= (policyOutputOperation
      (MetaMoPolicyOutput $_ (operation-class $operation) $_ $_))
   $operation)
(= (policyOutputMode
      (MetaMoPolicyOutput (mode $mode) $_ $_ $_))
   $mode)
(= (policyOutputFeasibility
      (MetaMoPolicyOutput $_ $_ (feasibility $feasibility) $_))
   $feasibility)
(= (policyOutputPriority
      (MetaMoPolicyOutput $_ $_ $_ (priority $priority)))
   $priority)

;; Scheduler-facing adapter. MetaMo supplies policy fields; the scheduler
;; receives a typed AttentionDirective and remains responsible for resolving
;; the operation class into a concrete handler.
(= (schedulerAttentionDirective
      $bundle
      (MetaMoPolicyOutput $_ (operation-class $operation)
         (feasibility $feasibility) (priority $priority)))
   (AttentionDirective
      (target (frameBundleCurrentId $bundle))
      (slice (directiveSlice $operation))
      (task $operation)
      (admission $feasibility)
      (reason (if (== $feasibility Admitted) Feasible PolicyRejected))
      (priority $priority)
      (source MetaMo)))

(= (lastAttentionDirective)
   ;; Example: `(lastAttentionDirective)` reads the most recently published
   ;; directive. It is initialized to a rejected `none` directive at startup.
   (get-state &last-attention-directive))
