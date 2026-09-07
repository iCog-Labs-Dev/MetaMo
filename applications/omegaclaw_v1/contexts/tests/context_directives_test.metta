;; Focused tests for AttentionDirective and scheduler output.

!(import! &self (library lib_import))
!(import! &self "../../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../../repos/OmegaClaw-Core/src/context)
!(import! &self (library MetaMo core/state))
!(import! &self (library MetaMo core/state_accessors))
!(import! &self (library MetaMo core/helper))
!(import! &self (library MetaMo core/helpers.py))
!(import! &self (library MetaMo applications/omegaclaw_v1/utils))
!(import! &self ../../../../../MetaMo/applications/omegaclaw_v1/mode_layer)
!(import! &self ../../../../../MetaMo/applications/omegaclaw_v1/context_integration)
!(import! &self ../../../../../MetaMo/applications/omegaclaw_v1/contexts/context_accessors)
!(import! &self ../../../../../MetaMo/applications/omegaclaw_v1/contexts/context_policy)
!(import! &self ../../../../../MetaMo/applications/omegaclaw_v1/contexts/context_directives)

(= (directiveTestBundle)
   (FrameStateBundle
      (root (FrameStateRoot root-id frame-a (mode Fast)
             root-budget root-constraints))
      (current (FrameStateCurrent
         (id frame-a) (parent ()) UserDirective (status Active)
         (frame-mode Fast) (priority 0.8) (goal-summary goal)
         (history-summary history) (deliverable-summary deliverable)
         (results-summary results) (budget open-budget)
         (constraints constraints) (certified-method method)))
      (index (active ()) (completed ()))
      (relations ())
      (runtime (FrameStateRuntime
         (new-message False) (message-present False) (message-summary "")
         (task-open True) (task-execution-observed "")
         (active-task-summary task) (last-results-summary "")
         (error "") (wake-loops 0) (next-wake-at 0)
         (budget-state open-budget)))))

!(test (directiveSlice respond) CurrentFrameSummary)
!(test (directiveSlice retrieve-memory) CurrentFrameAndRelations)
!(test (directiveSlice execute-skill) CurrentFrameTask)
!(test (directiveSlice verify-frame-state) CurrentFrameAndRelations)
!(test (frameStateVerificationOperation) verify-frame-state)
!(test (directivePriority (directiveTestBundle) 0.80)
      (clampValue 0.7999999999999999))

!(test (!= (makeAttentionDirective
               (directiveTestBundle) respond 0.80)
           ()) True)
!(test (makeAttentionDirective
         (directiveTestBundle) execute-skill 0.80)
      (AttentionDirective
         (target frame-a)
         (slice CurrentFrameTask)
         (task execute-skill)
         (admission Admitted)
         (reason Feasible)
         (priority (clampValue 0.7999999999999999))
         (source MetaMo)))

!(setConstitutionalMode Sleep)
!(test (makeAttentionDirective
         (directiveTestBundle) execute-skill 0.80)
      (AttentionDirective
         (target frame-a)
         (slice CurrentFrameTask)
         (task execute-skill)
         (admission Rejected)
         (reason SleepModeOperationalWork)
         (priority 0)
         (source MetaMo)))
!(setConstitutionalMode Engaged)

!(test (metaMoPolicyOutput (directiveTestBundle) respond 0.50)
      (MetaMoPolicyOutput
         (mode Engaged)
         (operation-class respond)
         (feasibility Admitted)
         (priority (clampValue 0.59))))

!(test (schedulerAttentionDirective
         (directiveTestBundle)
         (metaMoPolicyOutput (directiveTestBundle) respond 0.50))
      (AttentionDirective
         (target frame-a)
         (slice CurrentFrameSummary)
         (task respond)
         (admission Admitted)
         (reason Feasible)
         (priority (clampValue 0.59))
         (source MetaMo)))
