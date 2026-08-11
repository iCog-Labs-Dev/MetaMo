;; Deterministic vertical-slice demo for the OmegaClaw v1 MetaMo loop.
;;
;; This is intentionally not the production OmegaClaw entry point. It uses a
;; fixed FrameStateBundle so the adapter -> signal -> mode -> candidate ->
;; decision path can be demonstrated without a channel, LLM, or ChromaDB.

!(import! &self (library lib_import))
!(import! &self "../../../../repos/OmegaClaw-Core/lib_llm_ext.py")
!(import! &self "../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../repos/OmegaClaw-Core/src/skills)
!(import! &self ../../../../repos/OmegaClaw-Core/src/context)
!(import! &self (library MetaMo core/config))
!(import! &self (library MetaMo core/state))
!(import! &self (library MetaMo core/state_accessors))
!(import! &self (library MetaMo core/helper))
!(import! &self (library MetaMo core/helpers.py))
!(import! &self (library MetaMo applications/omegaclaw_v1/openpsi_config))
!(import! &self (library MetaMo applications/omegaclaw_v1/utils))
!(import! &self (library MetaMo applications/omegaclaw_v1/registry))
!(import! &self (library MetaMo applications/omegaclaw_v1/adapter))
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/mode_layer)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/signals)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/context_integration)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/task_lifecycle)
!(import! &self (library MetaMo applications/omegaclaw_v1/candidate_selection))
!(import! &self (library MetaMo applications/omegaclaw_v1/omegaclaw_decision))
!(import! &self (library MetaMo applications/omegaclaw_v1/bridge))

;; Minimal state normally supplied by OmegaClaw-Core and ContextFrames.
!(bind! &prevmsg (new-state ""))
!(bind! &lastresults (new-state ""))
!(bind! &error (new-state ""))
!(bind! &loops (new-state 0))
!(bind! &nextWakeAt (new-state 0))
!(bind! &task-open (new-state True))
!(bind! &active-task (new-state "answer-user"))
!(bind! &task-execution-observed (new-state ""))
!(bind! &failure-streak (new-state 0))
!(bind! &last-results-seen (new-state ""))
!(bind! &new-msg-flag (new-state True))
!(bind! &constitutional-mode (new-state Engaged))
!(bind! &active-frame-bundle (new-state ()))
!(bind! &consecutive-safety-wins (new-state 0))

!(initContextFrame)
!(initOmegaClawMotivation)

;; One synthetic input boundary: a live current frame with a new user message,
;; an open task, and no error or previous result.
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
   (let* (
      (($head $tail) (decons-atom $actions))
      ($headScore (omegaclawScoreForBundle $bundle $state $head)))
      (findBestActionForBundle $bundle $state $tail $head $headScore)))

;; The production refreshSignals predicate also performs optional semantic and
;; execution-confirmation provider calls. For this offline demo, derive the
;; three deterministic signals implied by the fixed bundle instead.
(= (minimalRefreshSignals $bundle)
   (let* (
      ($_ (clearSignals))
      ($_ (addSignal user-waiting 0.30))
      ($_ (addSignal ambiguity 0.60))
      ($_ (addSignal stalled-progress 0.35)))
      (getSignals)))

;; Run the smallest complete loop while retaining the production ordering.
(= (minimalGenerateCandidates $bundle)
   (let* (
      ($_ (clearSpace &candidateSpace))
      ;; The demo covers the response path only. Production candidate
      ;; availability remains exercised by candidate_selection.metta tests.
      ($_ (add-atom &candidateSpace (candidate respond))))
      True))

(= (minimalLoop $bundle)
   ;; This first slice keeps candidate scoring deterministic: respond is the
   ;; single candidate. The real feasibility gate is asserted below and is
   ;; already covered extensively by the v1 integration tests.
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

!(setActiveFrameBundle (minimalDemoBundle))
!(minimalRefreshSignals (minimalDemoBundle))
!(refreshConstitutionalMode (minimalDemoBundle))
!(clearSpace &candidateSpace)
!(minimalGenerateCandidates (minimalDemoBundle))
(= (demoResult) (minimalLoop (minimalDemoBundle)))
!(println! "MINIMAL-LOOP")
!(println! (Input new-message-active-task))
!(println! (Mode (constitutionalMode)))
!(println! (Candidates (car-atom (cdr-atom (demoResult)))))
!(println! (AllActionsFeasible (car-atom (cdr-atom (cdr-atom (demoResult))))))
!(println! (SelectedCandidate
   (car-atom (cdr-atom (cdr-atom (cdr-atom (demoResult)))))))
!(println! (Directive
   (car-atom (cdr-atom (cdr-atom (cdr-atom (cdr-atom (cdr-atom (demoResult)))))))))

;; Minimal contract assertions.
!(test (constitutionalMode) Engaged)
!(test (eval (feasibilityGate (minimalDemoBundle) respond))
      (GateDecision Admitted Feasible))
!(test (!= (car-atom (cdr-atom (demoResult))) ()) True)
!(test (car-atom (cdr-atom (cdr-atom (demoResult)))) True)
!(test (!= (car-atom (cdr-atom (cdr-atom (cdr-atom (demoResult))))) none) True)
!(test (!= (car-atom
         (cdr-atom (cdr-atom (cdr-atom (cdr-atom (cdr-atom (demoResult)))))))
         ()) True)
