;; Bounded ContextFrames -> MetaMo projection.
;;
;; This is the only module that reads raw ContextFrames and OmegaClaw runtime
;; state. It emits the bounded FrameStateBundle consumed by MetaMo modules.

;; Callers import context_relations alongside this module. Keeping the
;; dependency explicit at the application boundary avoids duplicate relation
;; clauses when the façade imports every context submodule.
;; Only bounded status/streak enters the snapshot; raw observations stay host-side.
!(bind! &operation-feedback (new-state LegacyFeedback))
!(bind! &host-continuation (new-state ()))
!(bind! &continuation-applied-decision (new-state ()))
!(bind! &task-continuation-view (new-state NoContinuation))

(= (frameStateGoalSummary)
   (let $goalNamespace (get-state &cfv2-current-goal-namespace)
      (if (== $goalNamespace ())
          ()
          (get-state $goalNamespace))))

;; Fixed-cardinality bounds are applied before character compaction. This
;; keeps a large number of short refs/relations from bypassing text limits.
(= (frameStateMaxIndexRefs) 20)

;; Preserve absence before adding a display digest. Otherwise an empty error
;; or result becomes nonempty text and is misread as an observed event.
(= (frameStateRuntimeSummary $value $limit)
   (if (or (== $value "") (== $value ()))
       ""
       (cfv2-compact-limited $value $limit)))

;; Separate host review projection: compacted index text is not a complete
;; backlog. The helper validates/caps live rows and reports overflow explicitly.
;; eval defers resolution until the optional resurfacing module is loaded.
(= (frameStateResurfacingRows $bundle $candidate)
   (eval (frameResurfacingRows (frameResurfacingConfig)
      (get-state &cfv2-frame-indexspace)
      (frameBundleCurrentId $bundle) (frameBundleCurrentStatus $bundle)
      $candidate)))

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
      ;; Consumers inspect relation records structurally. Keep the bounded list
      ;; typed; frameStateProjectRelation already compacts each display reason.
      ($relations (if (== $currentID ()) ()
                     (frameStateBoundRelations
                        (cfv2-get-relation $currentID))))
      ($root (frameStateRootProjection))
      ($current (frameStateCurrentProjection))
      ($index (frameStateIndexProjection))
      ($runtime
         (FrameStateRuntime
            (operation-feedback (get-state &operation-feedback))
            (task-continuation (get-state &task-continuation-view))
            (new-message (get-state &new-msg-flag))
            (result-status-question
               (== (py-call (helper.is_result_status_question (get-state &prevmsg))) 1))
            (message-present (not (== (get-state &prevmsg) "")))
            (message-summary
               (frameStateRuntimeSummary (get-state &prevmsg) 1200))
            ;; Task lifecycle fields are exposed only as bounded, typed
            ;; projections. MetaMo must not read the OmegaClaw states below.
            (task-open (get-state &task-open))
            (task-execution-observed
               (frameStateRuntimeSummary
                  (get-state &task-execution-observed) 1200))
            (active-task-summary
               (frameStateRuntimeSummary (get-state &active-task) 500))
            (last-results-summary
               (frameStateRuntimeSummary
                  (get-state &lastresults) 1200))
            (error
               (frameStateRuntimeSummary
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
