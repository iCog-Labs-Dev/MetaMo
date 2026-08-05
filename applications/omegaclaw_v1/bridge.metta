
;; Construct the MetaMo bimonad from the OmegaClaw appraisal and decision
;; implementations plus the shared stability controls.
(= (omegaclawBimonad)
   (metaMoPseudoBimonad
      (omegaclawAppraisal)
      (omegaclawDecision)
      applyHomeostaticDamping
      raiseBoundaryCaution
      projectToSafeRegion
      checkContractiveUpdateLaw
      isInSafeRegion))


;; Run one motivational cycle and return the decision injected into the LLM.
(= (motivationContextBlock)
   (let* (
      ($_ (ensureMotivationRestored))
      ;; Capture the adapter snapshot before any MetaMo lifecycle logic.
      ($bundle (frameStateForMetaMo))
      ($_ (setActiveFrameBundle $bundle))
      ;; Refresh internal execution bookkeeping before ContextFrames publishes
      ;; the snapshot consumed by MetaMo.
      ($_ (refreshTaskExecutionObserved))
      ($_ (completePreviousTaskIfSuccessful))
      ;; ContextFrames has already ingested input and updated its frame state.
      ;; Capture one bounded snapshot and pass it through the whole cycle.
      ($_ (eval (refreshSignals $bundle)))
      ($_ (eval (clearSpace &appraisal-space)))
      ($_ (eval (computeAllDimensions)))

      ($currentMetaMoState (eval (motivosToMetamoState)))
      ($stimulus (eval (appraisalToStimulus)))

      ($_ (generateCandidates $bundle))
      ($actions (eval (candidatesToActions)))
      ;; Hard feasibility is complete before the MetaMo decision/mode step.
      ($feasibility (feasibilityGateActions $bundle $actions))
      ($admittedActions (if $feasibility $actions ()))
      ($sysStates
         (cons-atom (subsystemState omegaclaw $currentMetaMoState) ()))
      ($cycleResult
         (runMetaMoCycleDefault
            (omegaclawBimonad) $sysStates $stimulus $admittedActions () ()))

      ($finalAction (cycleFinalAction $cycleResult))
      ($nextSysStates (cycleNextStates $cycleResult))
      ($rawNextState (findSubsystemState omegaclaw $nextSysStates))
      ($nextState (eval (decayMetamoState $rawNextState)))
      ($_ (eval (writeBackMetamoState $nextState)))

      ($score (omegaclawScoreForBundle $bundle $nextState $finalAction))
      ($decisionResult
         (eval (metamoActionToDecision $finalAction $score)))
      ((decision $selectedCandidate $_mode $_directive $_score)
         $decisionResult)
      ($attentionDirective
         (attentionDirectiveForDecision $bundle $selectedCandidate $score))
      ($_ (change-state! &last-attention-directive $attentionDirective))

      ($_ (advanceAutonomyPhase $selectedCandidate))
      ($_ (change-state! &last-motivation-decision $decisionResult))
      ($_ (updateSelfModel (hasErrors) (hasResults)))
      ($_ (runHomeostasis))
      ($_ (maybeSaveMotivationalState))
      ($_ (collapse (clearSignals)))
   )
      $decisionResult))


;; Map the selected candidate to an imperative instruction for the LLM.
(= (candidateInstruction $candidate)
   (case $candidate (
      (respond
         "REQUIRED: Respond to the user now. Your primary output MUST include a send command. Base completion and status claims only on LAST_SKILL_USE_RESULTS. If it already answers the user's question, send that result and do not rerun tools. When the user requests only the tool result, relay only the observed result without adding claims from HISTORY or assumptions.")
      (retrieve-memory
         "REQUIRED: Query long-term memory before responding. Your primary output MUST include a query command.")
      (search-knowledge
         "REQUIRED: Search for relevant knowledge before responding. Your primary output MUST include a search or query command.")
      (execute-skill
         "REQUIRED: Execute the requested skill or task now. If the user requested multiple executable steps, include the next pending skill command instead of only reporting progress. Include send only for truthful status or already-observed results; never invent command output.")
      (learn
         "REQUIRED: Capture and store new knowledge this cycle. Your primary output MUST include a remember command.")
      (self-improve
         "REQUIRED: Reflect on recent failures and update your approach. Consider using remember to store the lesson.")
      (background-work
         "REQUIRED: Execute exactly one safe read-only background step from the active internal plan. Do not send. Prefer read-file, query, or a read-only shell inspection such as pwd, ls, find, rg, grep, wc, head, tail, or git status/log/diff/show. Do not write files.")
      (recall-goals
         "REQUIRED: Query long-term memory for current goals or active-goal context. Do not send this cycle.")
      (invent-goal
         "REQUIRED: Create one bounded non-duplicate active-goal proposal. Use pin or remember. Do not send this cycle.")
      (plan-goal
         "REQUIRED: Convert the active internal goal and latest results into one concrete next background step. Use pin or remember. Do not send this cycle.")
      (repair-failure
         "REQUIRED: Repair the previous failed command or formatting issue now. If the failed command was send, output one corrected send. If it was a file command, output the smallest corrective read-file, write-file, or append-file. Do not merely say you will fix it.")
      (defer
         "REQUIRED: Do not take irreversible action this cycle. Verify the situation first before acting.")
      (ask-clarification
         "REQUIRED: Ask the user a clarifying question. Your primary output MUST include a send command with a question.")
      (none
         "REQUIRED: No user-facing task is active. Work silently or output an empty command list: ().")
      ($_
         "REQUIRED: Act according to your current motivational state and the STEP_POLICY above.")
   )))

(= (directiveGuidance $directive)
   (let $result
         (collapse (match &self (DirectiveText $directive $text) $text))
      (if (== $result ()) "" (car-atom $result))))


;; Build the standard OmegaClaw prompt with the current MetaMo decision.
(= (getContext)
   (let* (
      ($decisionResult (motivationContextBlock))
      ($bundle (activeFrameBundle))
      ($_ (println! (MOTIVATION-CONTEXT-BLOCK: $decisionResult)))
      ((decision $selectedCandidate $_mode $directive $_score)
         $decisionResult)
      ($guidance (directiveGuidance $directive))
      ($instruction (candidateInstruction $selectedCandidate))
      ($activeTask (frameRuntimeActiveTask $bundle))
      ($autonomyPhase (autonomyPhaseForCandidate $selectedCandidate))
      ($nextAutonomyPhase (get-state &autonomy-phase))
      ($autonomyActionCount (get-state &autonomy-action-count))
      ($taskExecutionObserved (get-state &task-execution-observed))
      ($runtimeContext (py-call (helper.runtime_context)))
   )
   (eval (string-safe
      (eval (py-str (
         "PROMPT: " (eval (getPrompt))
         " SKILLS: " (eval (getSkills))
         " OUTPUT_FORMAT: Output a single valid MeTTa s-expression list of commands."
         " Example - one command:"
         " ((send \"message\"))"
         " Example - multiple commands:"
         " ((query \"topic\") (send \"message\"))"
         " Do not output conversational text outside the expression."
         " IMPORTANT: For code passed as a string argument, prefer single-quoted Python strings inside the code. Avoid quote characters that can terminate the surrounding MeTTa string."
         " LAST_SKILL_USE_RESULTS: "
            (eval (last_chars (frameRuntimeResults $bundle) (maxFeedback)))
         " HISTORY: " (eval (getHistory))
         " ACTIVE_TASK: " (eval (string-safe $activeTask))
         " TASK_EXECUTION_OBSERVED: "
            (eval (string-safe (repr $taskExecutionObserved)))
         " AUTONOMY_PHASE: "
            (eval (string-safe (repr $autonomyPhase)))
         " AUTONOMY_NEXT_PHASE: "
            (eval (string-safe (repr $nextAutonomyPhase)))
         " AUTONOMY_ACTION_COUNT: "
            (eval (string-safe (repr $autonomyActionCount)))
         " RUNTIME_CONTEXT: " (eval (string-safe $runtimeContext))
         " FILE_PATH_POLICY: Relative file paths used by file skills resolve against RUNTIME_CONTEXT working_directory."
         " TIME: " (eval (get_time_as_string))
         " STEP_POLICY: " $guidance
         " MOTIVATION_INSTRUCTION: " $instruction
         " MOTIVATION_DECISION: "
            (eval (string-safe (repr $decisionResult)))
         " ATTENTION_DIRECTIVE: "
            (eval (string-safe (repr (lastAttentionDirective))))
      )))))))


;; Initialize all motivational spaces from the registry defaults.
(= (initOmegaClawMotivation)
   (let* (
      ($_ (clearSpace &goal-space))
      ($_ (collapse
             (let* (
                (($name $baseline)
                   (match &self (GoalSpec $name $baseline)
                                ($name $baseline)))
             )
                (add-atom &goal-space (goal $name $baseline)))))
      ($_ (collapse
             (let* (
                (($name $weight)
                   (match &self (AntiGoalSpec $name $weight)
                                ($name $weight)))
             )
                (add-atom &goal-space (anti-goal $name $weight)))))

      ($_ (clearSpace &motivation-space))
      ($_ (collapse
             (let* (
                (($name $baseline)
                   (match &self (ModulatorSpec $name $baseline)
                                ($name $baseline)))
             )
                (add-atom &motivation-space
                   (modulator $name $baseline)))))
      ($_ (collapse
             (let* (
                (($name $baseline)
                   (match &self (MotiveSpec $name $baseline)
                                ($name $baseline)))
             )
                (add-atom &motivation-space (motive $name $baseline)))))
      ($_ (add-atom &motivation-space (mode orient)))

      ($_ (clearSpace &self-model-space))
      ($_ (collapse
             (let* (
                (($name $baseline)
                   (match &self (SelfModelSpec $name $baseline)
                                ($name $baseline)))
             )
                (add-atom &self-model-space
                   (self-metric $name $baseline)))))
   )
      (println! "OmegaClaw Motivation Initialized via MetaMo Adapter")))


;; Initialize the motivational runtime, then start the OmegaClaw loop.
(= (motivatedOmegaclaw)
   (let* (
      ($_ (initOmegaClawMotivation))
      ($_ (collapse (clearSignals)))
      ($_ (change-state! &new-msg-flag False))
      ($_ (change-state! &last-results-seen ""))
      ($_ (change-state! &active-task ""))
      ($_ (change-state! &task-open False))
      ($_ (change-state! &task-execution-observed ""))
      ($_ (change-state! &autonomy-phase recall))
      ($_ (change-state! &autonomy-action-count 0))
      ($_ (change-state! &motivation-restored False))
      ($_ (change-state! &motivation-save-countdown
              (persistenceInterval)))
   )
      (eval (omegaclaw))))
