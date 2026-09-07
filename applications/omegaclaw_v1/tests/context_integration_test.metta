;; ContextFrames/MetaMo v1 integration smoke test.
;; This intentionally imports the same local OmegaClaw-Core composition used
;; by MetaMo/applications/omegaclaw_v1/run.metta.

!(import! &self (library lib_import))
!(import! &self "../../../../repos/OmegaClaw-Core/src/helper.py")
!(import! &self ../../../../repos/OmegaClaw-Core/src/skills)
!(import! &self ../../../../repos/OmegaClaw-Core/src/context)
!(import! &self (library MetaMo core/config))
!(import! &self (library MetaMo core/state))
!(import! &self (library MetaMo core/state_accessors))
!(import! &self (library MetaMo core/helper))
!(import! &self (library MetaMo core/helpers.py))
!(import! &self (library MetaMo applications/omegaclaw_v1/utils))
!(import! &self (library MetaMo applications/omegaclaw_v1/registry))
!(import! &self (library MetaMo applications/omegaclaw_v1/adapter))
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/mode_layer)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/signals)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/contexts/context_relations)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/contexts/context_accessors)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/contexts/context_slices)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/contexts/context_policy)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/context_integration)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/candidate_selection)
!(import! &self ../../../../MetaMo/applications/omegaclaw_v1/reasoner_proposals)

;; Minimal runtime state normally initialized by the full OmegaClaw loop.
!(bind! &prevmsg (new-state ""))
!(bind! &lastresults (new-state ""))
!(bind! &error (new-state ""))
!(bind! &loops (new-state 0))
!(bind! &nextWakeAt (new-state 0))
!(bind! &task-open (new-state False))
!(bind! &active-task (new-state ""))
!(bind! &task-execution-observed (new-state ""))
!(bind! &failure-streak (new-state 0))
!(bind! &last-results-seen (new-state ""))

!(initContextFrame)

;; Constitutional MVP mode set is separate from Fast/Slow frame mode and
;; operation directives.
!(test (eval (constitutionalModeSet)) (Engaged Threat Rumination Sleep))
!(test (eval (constitutionalModeDefault)) Engaged)
!(test (eval (constitutionalModeValid Engaged)) True)
!(test (eval (constitutionalModeValid Threat)) True)
!(test (eval (constitutionalModeValid Rumination)) True)
!(test (eval (constitutionalModeValid Sleep)) True)
!(test (eval (constitutionalModeValid Fast)) False)
!(test (constitutionalMode) Engaged)
!(test (eval (constitutionalModePreemptionOrder))
      (Threat-remediation Recovery Interactive Orienting Engaged Rumination Sleep))
!(test (eval (constitutionalModePreemptionRank Threat-remediation)) 7)
!(test (eval (constitutionalModePreemptionRank Sleep)) 1)
!(test (eval (constitutionalModePreempts Threat-remediation Engaged)) True)
!(test (eval (constitutionalModePreempts Engaged Sleep)) True)
!(test (eval (constitutionalModePreempts Sleep Threat-remediation)) False)

;; ---------------------------------------------------------------------------
;; Layer 1: pure adapter projections
;; ---------------------------------------------------------------------------
(= (pureTestBundle)
   (FrameStateBundle
      (root (FrameStateRoot root-id current-id (mode Fast) root-budget root-constraints))
      (current (FrameStateCurrent
         (id current-id)
         (parent ())
         UserDirective
         (status Active)
         (frame-mode Fast)
         (priority 0.8)
         (goal-summary compact-goal)
         (history-summary compact-history)
         (deliverable-summary compact-deliverable)
         (results-summary compact-results)
         (budget open-budget)
         (constraints compact-constraints)
         (certified-method certified-method)))
      (index (active (a b)) (completed (c)))
      (relations
         ((FrameStateRelation
            (source-frame current-id)
            (target-frame other-id)
            (relation-type RelatedButSeparate)
            (reason compact-reason)
            (confidence 0.7)
            (evidence-status Unverified))))
      (runtime (FrameStateRuntime
         (new-message True)
         (message-present True)
         (message-summary compact-message)
         (task-open True)
         (task-execution-observed compact-observed)
         (active-task-summary compact-task)
         (last-results-summary compact-results)
         (error "")
         (wake-loops 1)
         (next-wake-at 2)
         (budget-state open-budget)))))

;; Constitutional mode mapping consumes existing signal facts only.
!(test (eval (constitutionalModeFromSignalFacts True False False True)) Threat)
!(test (eval (constitutionalModeFromSignalFacts False True False True)) Rumination)
!(test (eval (constitutionalModeFromSignalFacts False False True True)) Sleep)
!(test (eval (constitutionalModeFromSignalFacts False False False True)) Engaged)

;; Transition collisions resolve by constitutional priority: danger wins over
;; failure and missing-frame sleep, failure wins over missing-frame sleep, and
;; the no-trigger case remains Engaged.
!(test (eval (constitutionalModeFromSignalFacts True True True True)) Threat)
!(test (eval (constitutionalModeFromSignalFacts True True False True)) Threat)
!(test (eval (constitutionalModeFromSignalFacts False True True True)) Rumination)
!(test (eval (constitutionalModeFromSignalFacts False False True True)) Sleep)
!(test (eval (constitutionalModeFromSignalFacts False False False True)) Engaged)

;; Preemption is strict: equal modes and unknown modes do not preempt.
!(test (eval (constitutionalModePreempts Threat Threat)) False)
!(test (eval (constitutionalModePreempts Engaged Engaged)) False)
!(test (eval (constitutionalModePreempts Unknown Engaged)) False)
!(test (eval (constitutionalModePreempts Engaged Unknown)) True)

;; Signal-driven transitions update the runtime mode, while an invalid mode
;; transition is rejected and leaves the default Engaged state unchanged.
!(clearSignals)
!(setConstitutionalMode Engaged)
!(test (eval (refreshConstitutionalMode (pureTestBundle))) ())
!(test (constitutionalMode) Engaged)
!(setConstitutionalMode Rumination)
!(test (constitutionalMode) Rumination)
!(clearSignals)
!(setConstitutionalMode Engaged)
!(test (setConstitutionalMode InvalidMode) (ModeRejected InvalidMode))
!(test (constitutionalMode) Engaged)

;; Mode gates are monotonic: Sleep may tighten execution, but cannot relax a
;; base-policy rejection.
!(setConstitutionalMode Sleep)
!(test (eval (constitutionalModeGate execute-skill))
      (GateDecision Rejected SleepModeOperationalWork))
!(test (eval (constitutionalModeGate respond))
      (GateDecision Admitted Feasible))
!(test (eval (feasibilityGate (frameStateForMetaMo) execute-skill))
      (GateDecision Rejected NoActiveFrame))
!(setConstitutionalMode Engaged)

(= (hasTypedHistorySummary
      (FrameStateCurrent $_ $_ $_ $_ $_ $_ $_
         (history-summary $_) $_ $_ $_ $_ $_))
   True)

!(test (!= (frameStateForMetaMo) ()) True)
!(test (!= (cfv2-compact-limited "abcdefghijklmnopqrstuvwxyz" 8)
           "abcdefghijklmnopqrstuvwxyz") True)
!(test (size-atom
         (frameStateTake (frameStateMaxIndexRefs)
            (a b c d e f g h i j k l m n o p q r s t u v w x y))) 20)
!(test (size-atom
         (frameStateTake (frameStateMaxRelations)
            (r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12)))
      10)

;; Required ContextFrames symbols must resolve and produce values after init.
!(test (== (cfv2-has-current-frame) False) True)
!(test (!= (contextFrameForPrompt) ()) True)
!(test (!= (frameStateBundle) ()) True)
!(test (!= (frameStateForMetaMo) ()) True)
;; Frame creation is exercised by the full runtime test suite. It requires the
;; optional ChromaDB relation-composer dependency, so this import smoke test
;; deliberately stays independent of that external service.
!(test (!= (ctx-record-command-batch () ()) ()) True)
!(test (!= (switch-mode) ()) True)

;; With no current frame, execution is rejected before scoring. This proves
;; hard pruning is not merely a score penalty.
!(test (== (eval (contextPolicyGate (frameStateForMetaMo) execute-skill))
           (GateDecision Rejected NoActiveFrame)) True)
!(test (== (eval (candidateAdmitted (frameStateForMetaMo) execute-skill)) False) True)
!(test (== (eval (feasibilityGateActions (frameStateForMetaMo) ())) True) True)

;; Same-frame evidence selects the explicit verification operation rather than
;; the generic defer action. The operation remains subject to the normal frame
;; feasibility gate.
(= (sameFrameBundle)
   (FrameStateBundle
      (root (FrameStateRoot root-id frame-a (mode Fast)
             (ResourceBudget 10 10 units (status Open)) root-constraints))
      (current (FrameStateCurrent
         (id frame-a) (parent ()) UserDirective (status Active) (frame-mode Fast)
         (priority 0.8) (goal-summary goal) (history-summary history)
         (deliverable-summary deliverable) (results-summary results)
         (budget (ResourceBudget 10 10 units (status Open)))
         (constraints constraints) (certified-method method)))
      (index (active ()) (completed ()))
      (relations
         ((FrameStateRelation
            (source-frame frame-a) (target-frame frame-a)
            (relation-type SameFrame) (reason same-frame) (confidence 0.90)
            (evidence-status VerificationRequired))))
      (runtime (FrameStateRuntime
         (new-message False) (message-present False) (message-summary "")
         (task-open True) (task-execution-observed "") (active-task-summary task)
         (last-results-summary "") (error "") (wake-loops 0) (next-wake-at 0)
         (budget-state (ResourceBudget 10 10 units (status Open)))))))
!(test (eval (frameStateVerificationOperation)) verify-frame-state)
!(test (eval (metaMoPolicyOutput (sameFrameBundle) verify-frame-state 0.80))
      (MetaMoPolicyOutput
         (mode Engaged)
         (operation-class verify-frame-state)
         (feasibility Admitted)
         (priority (clampValue 0.7999999999999999))))
!(test (eval (policyOutputOperation
               (metaMoPolicyOutput (sameFrameBundle) verify-frame-state 0.80)))
      verify-frame-state)
!(test (eval (policyOutputMode
               (metaMoPolicyOutput (sameFrameBundle) verify-frame-state 0.80)))
      Engaged)
!(test (eval (policyOutputFeasibility
               (metaMoPolicyOutput (sameFrameBundle) verify-frame-state 0.80)))
      Admitted)
!(test (eval (schedulerAttentionDirective
               (sameFrameBundle)
               (metaMoPolicyOutput (sameFrameBundle) verify-frame-state 0.80)))
      (AttentionDirective
         (target frame-a)
         (slice CurrentFrameAndRelations)
         (task verify-frame-state)
         (admission Admitted)
         (reason Feasible)
         (priority (clampValue 0.7999999999999999))
         (source MetaMo)))
!(test (eval (candidateIsAvailable (sameFrameBundle) verify-frame-state)) True)
!(test (eval (candidateIsAvailable (sameFrameBundle) defer)) False)
!(test (eval (candidateIsAvailable (sameFrameBundle) execute-skill)) False)
!(test (eval (generateCandidates (sameFrameBundle))) True)
!(test (eval (candidateRequiresFrame verify-frame-state)) True)
!(test (eval (frameBundleHasCurrent (sameFrameBundle))) True)
!(test (eval (frameBundleActive (sameFrameBundle))) True)
!(test (eval (frameBundleModeCompatible (sameFrameBundle))) True)
!(test (eval (frameBundleBudgetOpen (sameFrameBundle))) True)
!(test (eval (contextPolicyGate (sameFrameBundle) verify-frame-state))
      (GateDecision Admitted Feasible))
!(test (eval (candidateAdmitted (sameFrameBundle) verify-frame-state)) True)
!(test (eval (attentionDirectiveForDecision
               (sameFrameBundle) verify-frame-state 0.80))
      (AttentionDirective
         (target frame-a)
         (slice CurrentFrameAndRelations)
         (task verify-frame-state)
         (admission Admitted)
         (reason Feasible)
         (priority (clampValue 0.7999999999999999))
         (source MetaMo)))

;; Verify that a typed rejected directive is emitted with separate target,
;; slice, admission, priority, task, and source fields.
!(test (eval (makeAttentionDirective (frameStateForMetaMo) execute-skill 0.80))
      (AttentionDirective
         (target ())
         (slice CurrentFrameTask)
         (task execute-skill)
         (admission Rejected)
         (reason NoActiveFrame)
         (priority 0)
         (source MetaMo)))

;; ---------------------------------------------------------------------------
;; Layer 2: ContextFrames integration
;; ---------------------------------------------------------------------------
;; The optional relation-composer dependency is not required for these
;; integration checks; drive the same ContextFrames cache boundary directly.
!(change-state! &cfv2-current-frame-id integrated-frame-one)
!(change-state! &cfv2-current-status Active)
!(change-state! &cfv2-current-frame-mode (get-state &cfv2-root-mode))
!(change-state! &cfv2-current-source UserDirective)
!(change-state! &cfv2-current-history-summary "first integrated user message")
!(test (frameBundleCurrentId (frameStateForMetaMo)) integrated-frame-one)

!(change-state! &cfv2-current-frame-id integrated-frame-two)
!(test (frameBundleCurrentId (frameStateForMetaMo)) integrated-frame-two)
!(change-state! &cfv2-current-frame-id integrated-frame-one)
!(test (frameBundleCurrentId (frameStateForMetaMo)) integrated-frame-one)

;; Closed budget blocks an operational candidate; incompatible mode reports
;; the mode-specific feasibility failure.
!(change-state! &cfv2-current-budget
   (ResourceBudget 1 0 units (status Closed)))
!(test (eval (contextPolicyGateFacts True True True True False))
      (GateDecision Rejected BudgetExhausted))
!(change-state! &cfv2-current-budget (cfv2-default-budget))
!(change-state! &cfv2-current-frame-mode MismatchedMode)
!(test (eval (contextPolicyGateFacts True True True False True))
      (GateDecision Rejected FrameModeMismatch))
!(change-state! &cfv2-current-frame-mode (get-state &cfv2-root-mode))

!(change-state! &prevmsg "new integrated user message")
!(change-state! &new-msg-flag True)
!(test (!= (frameRuntimeMessage (frameStateForMetaMo))
           "new integrated user message") True)
!(change-state! &lastresults "command-result")
!(test (!= (frameRuntimeResults (frameStateForMetaMo)) ()) True)

;; ---------------------------------------------------------------------------
;; Layer 3: MetaMo boundary
;; ---------------------------------------------------------------------------
!(test (!= (frameStateForMetaMo) ()) True)
!(test (bundle-runtime-has-error (pureTestBundle)) False)
!(test (makeAttentionDirective (pureTestBundle) respond 0.5)
      (AttentionDirective
         (target current-id)
         (slice CurrentFrameSummary)
         (task respond)
         (admission Admitted)
         (reason Feasible)
         (priority (clampValue 0.59))
         (source MetaMo)))

;; Required public aliases remain resolvable.
;; These no-current-frame calls intentionally return no operational result;
;; loading and executing them is the resolution check for the public aliases.
!(switch-frame ())
!(complete-goals-stm "smoke completion")
