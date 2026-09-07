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
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_policy)
!(import! &self ../../../MetaMo/applications/omegaclaw_v1/contexts/context_directives)

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
