;; Focused tests for bounded ContextFrames exposure slices.

!(import! &self (library lib_import))
!(import! &self "../../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../../repos/OmegaClaw-Core/src/context)
!(import! &self (library MetaMo core/state))
!(import! &self (library MetaMo core/state_accessors))
!(import! &self (library MetaMo core/helper))
!(import! &self (library MetaMo core/helpers.py))
!(import! &self (library MetaMo applications/omegaclaw_v1/utils))
!(import! &self ../../../../../MetaMo/applications/omegaclaw_v1/context_integration)
!(import! &self ../../../../../MetaMo/applications/omegaclaw_v1/contexts/context_accessors)
!(import! &self ../../../../../MetaMo/applications/omegaclaw_v1/contexts/context_slices)

(= (sliceTestBundle)
   (FrameStateBundle
      (root (FrameStateRoot snapshot-root current-id (mode SnapshotMode)
             root-budget root-constraints))
      (current (FrameStateCurrent
         current-id
         (parent snapshot-parent)
         SnapshotSource
         (status SnapshotStatus)
         (frame-mode SnapshotFrameMode)
         (priority 0.91)
         (goal-summary snapshot-goal)
         (history-summary snapshot-history)
         (deliverable-summary snapshot-deliverable)
         (results-summary snapshot-results)
         (budget snapshot-budget)
         (constraints snapshot-constraints)
         (certified-method snapshot-method)))
      (index (active (snapshot-active)) (completed (snapshot-completed)))
      (relations (snapshot-relations))
      (runtime (FrameStateRuntime
         (new-message SnapshotNewMessage)
         (message-present SnapshotMessagePresent)
         (message-summary snapshot-message)
         (task-open SnapshotTaskOpen)
         (task-execution-observed snapshot-observed)
         (active-task-summary snapshot-task)
         (last-results-summary snapshot-results)
         (error snapshot-error)
         (wake-loops 4)
         (next-wake-at 8)
         (budget-state snapshot-budget)))))

;; IndexOverview contains no current-frame ID, so it is a stable regression
;; check that the slice is assembled from the supplied bundle.
!(test (!= (frameStateForSlice IndexOverview (sliceTestBundle)) ()) True)
!(test (frameStateSliceRuntime
         (frameBundleRuntime (sliceTestBundle)))
      (FrameSliceRuntime
         (new-message SnapshotNewMessage)
         (message-present SnapshotMessagePresent)
         (last-results-summary snapshot-results)
         (error snapshot-error)
         (wake-loops 4)
         (next-wake-at 8)
         (budget-state snapshot-budget)))
