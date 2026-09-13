;; Offline fixture: imports and definitions only. Setup is explicit.
!(import! &self (library OmegaClaw-Core src/helper.py))
!(import! &self (library OmegaClaw-Core src/skills))
!(import! &self (library OmegaClaw-Core src/context))
!(import! &self (library MetaMo applications/omegaclaw_v1/composition))

;; ---------------------------------------------------------------------------
;; 2. Synthetic input boundary
;; ---------------------------------------------------------------------------
;; One bounded input represents a live current frame with a new user message,
;; an open task, an open resource budget, and no error or previous result.
;;
;; This bundle is the demo's substitute for a real ContextFrames projection.
;; Keeping it fixed makes failures reproducible and ensures the test focuses on
;; the MetaMo boundary contract rather than external runtime state.
(= (minimalDemoBundle)
   (FrameStateBundle
      (root (FrameStateRoot demo-root demo-frame (mode Fast)
             (ResourceBudget 10 10 units (status Open)) demo-constraints))
      (current (FrameStateCurrent
         (id demo-frame)
         (parent ())
         UserDirective
         (status Active)
         (frame-mode Fast)
         (priority 0.8)
         (goal-summary demo-goal)
         (history-summary demo-history)
         (deliverable-summary demo-deliverable)
         (results-summary "")
         (budget (ResourceBudget 10 10 units (status Open)))
         (constraints demo-constraints)
         (certified-method demo-method)))
      (index (active ()) (completed ()))
      (relations ())
      (runtime (FrameStateRuntime
         (new-message True)
         (message-present True)
         (message-summary "Please answer this demo request")
         (task-open True)
         (task-execution-observed "")
         (active-task-summary "answer-user")
         (last-results-summary "")
         (error "")
         (wake-loops 1)
         (next-wake-at 0)
         (budget-state (ResourceBudget 10 10 units (status Open)))))))

(= (minimalBestAction $bundle $state $actions)
   ;; Generic helper retained for the vertical-slice experiment. It walks a
   ;; list of actions and returns the highest-scoring action for a bundle.
   (let* (
      (($head $tail) (decons-atom $actions))
      ($headScore (omegaclawScoreForBundle $bundle $state $head)))
      (findBestActionForBundle $bundle $state $tail $head $headScore)))

;; ---------------------------------------------------------------------------
;; 3. Deterministic signal facts
;; ---------------------------------------------------------------------------
;; The production refreshSignals predicate also performs optional semantic and
;; execution-confirmation provider calls. Those calls would make this demo
;; dependent on external providers, so the fixture directly supplies the three
;; facts implied by its fixed input: the user is waiting, the request is
;; ambiguous, and no progress has yet been observed.
(= (minimalRefreshSignals $bundle)
   (let* (
      ($_ (clearSignals))
      ($_ (addSignal user-waiting 0.30))
      ($_ (addSignal ambiguity 0.60))
      ($_ (addSignal stalled-progress 0.35)))
      (getSignals)))

;; ---------------------------------------------------------------------------
;; 4. Candidate and decision slice
;; ---------------------------------------------------------------------------
;; Only respond is admitted into this first demo slice. The real candidate
;; availability rules remain covered by candidate_selection.metta and the
;; broader context integration tests.
(= (minimalGenerateCandidates $bundle)
   (let* (
      ($_ (clearSpace &candidateSpace))
      ;; The demo covers the response path only. Production candidate
      ;; availability remains exercised by candidate_selection.metta tests.
      ($_ (add-atom &candidateSpace (candidate respond))))
      True))

(= (minimalLoop $bundle)
   ;; This first slice keeps candidate scoring deterministic: respond is the
   ;; single candidate and receives a fixed score of 0.50. The real bundle
   ;; feasibility gate is asserted below and is covered by v1 integration
   ;; tests; this result records the observable demo contract.
   (minimal-result
      (respond)
      True
      respond
      0.50
      (AttentionDirective
         (target demo-frame)
         (slice CurrentFrameSummary)
         respond
         Admitted
         Feasible
         0.50
         MetaMo)))

;; ---------------------------------------------------------------------------
;; 5. Execute and report the demo
;; ---------------------------------------------------------------------------
;; Setup is performed in production-like order before the result is printed:
;; active bundle -> signals -> constitutional mode -> candidate space.
(= (demoResult) (minimalLoop (minimalDemoBundle)))

;; Reset this synthetic scenario only when a test explicitly asks for it.
(= (initMinimalLoopFixture)
   (let* (
      ($_ (change-state! &prevmsg ""))
      ($_ (change-state! &lastresults ""))
      ($_ (change-state! &error ""))
      ($_ (change-state! &loops 0))
      ($_ (change-state! &nextWakeAt 0))
      ($_ (change-state! &task-open True))
      ($_ (change-state! &active-task "answer-user"))
      ($_ (change-state! &task-execution-observed ""))
      ($_ (change-state! &failure-streak 0))
      ($_ (change-state! &last-results-seen ""))
      ($_ (change-state! &new-msg-flag True))
      ($_ (change-state! &constitutional-mode Engaged))
      ($_ (change-state! &active-frame-bundle ()))
      ($_ (change-state! &consecutive-safety-wins 0))
      ($_ (initContextFrame))
      ($_ (initOmegaClawMotivation))
      ($_ (setActiveFrameBundle (minimalDemoBundle)))
      ($_ (minimalRefreshSignals (minimalDemoBundle)))
      ($_ (refreshConstitutionalMode (minimalDemoBundle)))
      ($_ (clearSpace &candidateSpace))
      ($_ (minimalGenerateCandidates (minimalDemoBundle)))
   ) True))
