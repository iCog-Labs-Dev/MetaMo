
!(bind! &goal-space        (new-space))
!(bind! &motivation-space  (new-space))
!(bind! &appraisal-space   (new-space))
!(bind! &signal-space      (new-space))
!(bind! &candidateSpace    (new-space))
!(bind! &self-model-space  (new-space))

!(bind! &failure-streak           (new-state 0))
!(bind! &active-task              (new-state ""))
!(bind! &task-open                (new-state False))
!(bind! &motivation-restored      (new-state False))
!(bind! &motivation-save-countdown (new-state 10))
!(bind! &last-motivation-decision (new-state (decision clarity orient inspect 0.0)))
!(bind! &autonomy-phase          (new-state recall))
!(bind! &autonomy-action-count   (new-state 0))
!(bind! &task-execution-observed (new-state ""))
!(bind! &success-count            (new-state 0))
!(bind! &failure-count            (new-state 0))
!(bind! &cycle-count              (new-state 0))




(= (clamp $value)
   (if (< $value 0.0) 0.0 (if (> $value 1.0) 1.0 $value)))

(= (selfModelAlpha)
   (let $v (collapse (match &self (DynamicsConfig self_model_alpha $x) $x))
      (if (== $v ()) 0.20 (car-atom $v))))

(= (persistenceInterval)
   (let $v (collapse (match &self (DynamicsConfig persistence_interval $x) $x))
      (if (== $v ()) 10 (car-atom $v))))

(= (autonomyActionsBeforeRefresh)
   (let $v (collapse (match &self (DynamicsConfig autonomy_actions_before_refresh $x) $x))
      (if (== $v ()) 2 (car-atom $v))))

(= (executionOpportunityThreshold)
   (let $v (collapse (match &self (DynamicsConfig execution_opportunity_threshold $x) $x))
      (if (== $v ()) 0.75 (car-atom $v))))

(= (executionIntentThreshold)
   (let $v (collapse (match &self (DynamicsConfig execution_intent_threshold $x) $x))
      (if (== $v ()) 0.50 (car-atom $v))))

(= (executionRiskLimit)
   (let $v (collapse (match &self (DynamicsConfig execution_risk_limit $x) $x))
      (if (== $v ()) 0.45 (car-atom $v))))

(= (executionUncertaintyLimit)
   (let $v (collapse (match &self (DynamicsConfig execution_uncertainty_limit $x) $x))
      (if (== $v ()) 0.65 (car-atom $v))))

(= (executionCautionLimit)
   (let $v (collapse (match &self (DynamicsConfig execution_caution_limit $x) $x))
      (if (== $v ()) 0.75 (car-atom $v))))

(= (idleAutonomyActive)
   (and (not (get-state &new-msg-flag))
        (not (get-state &task-open))))

(= (autonomyPhaseAllows $name)
   (let $phase (get-state &autonomy-phase)
      (case $phase (
         (recall (== $name recall-goals))
         (invent (== $name invent-goal))
         (plan   (== $name plan-goal))
         (act    (== $name background-work))
         ($_ False)
      ))))

(= (advanceAutonomyPhase $candidate)
   (if (idleAutonomyActive)
       (case $candidate (
          (recall-goals
             (let* (
                ($_ (change-state! &autonomy-action-count 0))
                ($_ (change-state! &autonomy-phase invent))
             ) True))
          (invent-goal
             (let $_ (change-state! &autonomy-phase plan) True))
          (plan-goal
             (let $_ (change-state! &autonomy-phase act) True))
          (background-work
             (let* (
                ($nextCount (+ (get-state &autonomy-action-count) 1))
                ($_ (change-state! &autonomy-action-count $nextCount))
             )
             (if (< $nextCount (autonomyActionsBeforeRefresh))
                 (let $_ (change-state! &autonomy-phase plan) True)
                 (let* (
                    ($_ (change-state! &autonomy-action-count 0))
                    ($_ (change-state! &autonomy-phase recall))
                 ) True))))
          ($_ False)
       ))
       False))

(= (autonomyPhaseForCandidate $candidate)
   (case $candidate (
      (recall-goals recall)
      (invent-goal  invent)
      (plan-goal    plan)
      (background-work act)
      ($_ none)
   )))

(= (ensureMotivationRestored)
   (if (get-state &motivation-restored)
       True
       (let* (
          ($_ (tryRestoreOrInit))
          ($_ (change-state! &motivation-restored True))
          ($_ (change-state! &motivation-save-countdown (persistenceInterval)))
       ) True)))

(= (maybeSaveMotivationalState)
   (let $count (get-state &motivation-save-countdown)
      (if (<= $count 0)
          (let* (
             ($_ (saveMotivationalState))
             ($_ (change-state! &motivation-save-countdown (persistenceInterval)))
          ) True)
          (let $_ (change-state! &motivation-save-countdown (- $count 1)) False))))

(= (hasSignal $kind)
    (let $res (collapse (match &signal-space (signal $kind $_) True))
        (if (== $res ()) False True))
)

(= (refreshTaskExecutionObserved)
   (if (get-state &new-msg-flag)
       (let $_ (change-state! &task-execution-observed "") True)
       (let $merged (py-call (helper.merge_observed_execution_commands
                              (get-state &task-execution-observed)
                              (get-state &lastresults)))
          (change-state! &task-execution-observed $merged))))

(= (executionContinuationNeeded)
   (and (get-state &task-open)
        (and (not (get-state &new-msg-flag))
             (py-call (helper.task_needs_more_execution
                       (get-state &active-task)
                       (get-state &task-execution-observed))))))

(= (awaitingClarificationResponse)
   (let* (
      ($lastDecision (get-state &last-motivation-decision))
      ((decision $candidate $_mode $_directive $_score) $lastDecision)
   )
   (and (get-state &task-open)
        (and (not (get-state &new-msg-flag))
             (== $candidate ask-clarification)))))

(= (directUserResponseNeeded)
   (and (hasSignal user-waiting)
        (< (extractAppraisalDim opportunity) (executionIntentThreshold))))

(= (executionCautionBlocks)
   (and (> (extractModulatorValue caution) (executionCautionLimit))
        (or (> (extractAppraisalDim risk) 0.10)
            (> (extractAppraisalDim uncertainty) 0.20))))

(= (executionRiskCurrentlyHigh)
   (or (> (extractAppraisalDim risk) (executionRiskLimit))
       (or (> (extractAppraisalDim uncertainty) (executionUncertaintyLimit))
           (executionCautionBlocks))))

(= (freshExecutionRequestNeeded)
   (and (hasSignal user-waiting)
        (> (extractAppraisalDim opportunity) (executionIntentThreshold))))

(= (taskResultReady)
   (and (get-state &task-open)
        (and (not (get-state &new-msg-flag))
             (and (not (awaitingClarificationResponse))
                  (and (hasResults) (not (hasErrors)))))))

(= (resultQuestionNeedsResponse)
   (and (hasSignal user-waiting)
        (py-call (helper.is_result_status_question (get-state &prevmsg)))))

        
(= (printDecisionRoutingDebug)
   (let* (
      ($idle                 (idleAutonomyActive))
      ($_ (println! ("[MotivationDebug] Idle autonomy active" $idle)))
      ($userWaiting          (hasSignal user-waiting))
      ($_ (println! ("[MotivationDebug] User waiting signal" $userWaiting)))
      ($directResponse       (directUserResponseNeeded))
      ($_ (println! ("[MotivationDebug] Direct response needed" $directResponse)))
      ($resultQuestion       (resultQuestionNeedsResponse))
      ($_ (println! ("[MotivationDebug] Result question needs response" $resultQuestion)))
      ($taskResult           (taskResultReady))
      ($_ (println! ("[MotivationDebug] Task result ready" $taskResult)))
      ($freshExecution       (freshExecutionRequestNeeded))
      ($_ (println! ("[MotivationDebug] Fresh execution request needed" $freshExecution)))
      ($continuation         (executionContinuationNeeded))
      ($_ (println! ("[MotivationDebug] continuation needed" $continuation)))
      ($executionRiskHigh    (executionRiskCurrentlyHigh))
      ($_ (println! ("[MotivationDebug] execution risk currently high" $executionRiskHigh)))
      ($opportunity          (extractAppraisalDim opportunity))
      ($_ (println! ("[MotivationDebug]  opportunity" $opportunity)))
      ($risk                 (extractAppraisalDim risk))
      ($_ (println! ("[MotivationDebug] Risk " $risk)))
      ($uncertainty          (extractAppraisalDim uncertainty))
      ($_ (println! ("[MotivationDebug] uncertainty" $uncertainty)))
      ($caution              (extractModulatorValue caution))
      ($_ (println! ("[MotivationDebug] Caution " $caution)))
   )
   ()))

(= (completeTaskIfTerminal $candidate)
   (if (or (== $candidate respond)
           (or (== $candidate repair-failure)
               (or (== $candidate defer) (== $candidate none))))
       (let* (
          ($_ (change-state! &task-open False))
          ($_ (change-state! &active-task ""))
          ($_ (change-state! &task-execution-observed ""))
       ) True)
       False))

(= (completePreviousTaskIfSuccessful)
   (if (and (not (get-state &new-msg-flag))
            (and (hasResults) (not (hasErrors))))
       (let* (
          ($lastDecision (get-state &last-motivation-decision))
          ((decision $candidate $_mode $_directive $_score) $lastDecision)
       )
          (completeTaskIfTerminal $candidate))
       False))


(= (homeostaticRuleTriggered $condType $metric $threshold)
   (case $condType (
      (modulator-exceeds (> (extractModulatorValue $metric) $threshold))
      (modulator-below   (< (extractModulatorValue $metric) $threshold))
      (self-metric-exceeds (> (fetchSelfMetricValue $metric) $threshold))
      (self-metric-below   (< (fetchSelfMetricValue $metric) $threshold))
      ($_ (println! ("Unknown homeostatic condition type: " $condType)))
   ))
)

(= (applyHomeostaticAction $actionType $target $delta)
   (case $actionType (
      (raise-modulator (replaceModulator $target (clamp (+ (extractModulatorValue $target) $delta))))
      (lower-modulator (replaceModulator $target (clamp (- (extractModulatorValue $target) $delta))))
      (raise-goal      (replaceGoal       $target (clamp (+ (extractGoalValue       $target) $delta))))
      (lower-goal      (replaceGoal       $target (clamp (- (extractGoalValue       $target) $delta))))
      ($_ (println! ("Unknown homeostatic action type: " $actionType)))
   ))
)

(= (applyHomeostaticRule $rule)
   (let (HomeostaticRule $condType $metric $threshold $actionType $target $delta) $rule
      (if (homeostaticRuleTriggered $condType $metric $threshold)
          (applyHomeostaticAction $actionType $target $delta)
          ())))

(= (runHomeostasis)
   (collapse
      (let $rule (match &self
                     (HomeostaticRule $condType $metric $threshold $actionType $target $delta)
                     (HomeostaticRule $condType $metric $threshold $actionType $target $delta))
         (applyHomeostaticRule $rule))))

(= (fetchSelfMetricValue $name)
   (let $res (collapse (match &self-model-space (self-metric $name $v) $v))
      (if (== $res ()) 0.0 (car-atom $res))))

(= (replaceSelfMetric $name $newValue)
   (let* (
      ($existing (collapse (match &self-model-space
                                (self-metric $name $v) (self-metric $name $v))))
      ($_ (if (!= $existing ())
              (remove-atom &self-model-space (car-atom $existing))
              _))
      ($_ (add-atom &self-model-space (self-metric $name $newValue)))
   ) ()))

(= (updateSelfModel $hadError $hadResults)
   (let* (
      ($_ (change-state! &cycle-count   (+ (get-state &cycle-count)   1)))
      ($_ (if (and $hadResults (not $hadError))
              (change-state! &success-count (+ (get-state &success-count) 1))
              _))
      ($_ (if $hadError
              (change-state! &failure-count (+ (get-state &failure-count) 1))
              _))
      ($cycles    (get-state &cycle-count))
      ($successes (get-state &success-count))
      ($failures  (get-state &failure-count))
      ($instSuccess (if (> $cycles 0) (/ $successes $cycles) 0.5))
      ($instFailure (if (> $cycles 0) (/ $failures  $cycles) 0.1))
      ($alpha    (selfModelAlpha))
      ($oldSucc  (fetchSelfMetricValue success_rate))
      ($oldFail  (fetchSelfMetricValue failure_rate))
      ($newSucc  (clamp (+ (* (- 1.0 $alpha) $oldSucc) (* $alpha $instSuccess))))
      ($newFail  (clamp (+ (* (- 1.0 $alpha) $oldFail) (* $alpha $instFailure))))
      ($_ (replaceSelfMetric success_rate     $newSucc))
      ($_ (replaceSelfMetric failure_rate     $newFail))
      ($_ (replaceSelfMetric memory_confidence (clamp (* $newSucc 1.4))))
      ($streak   (get-state &failure-streak))
      ($_ (replaceSelfMetric identity_continuity (clamp (- 0.90 (* $streak 0.08)))))
      ($_ (replaceSelfMetric resource_usage
              (clamp (/ $cycles (+ $cycles 50.0)))))
   ) ()))


;; Constructs the MetaMo bimonad wired to OmegaClaw's appraisal + decision.
(= (omegaclawBimonad)
    (metaMoPseudoBimonad
        (omegaclawAppraisal)        ;; AppraisalComonad
        (omegaclawDecision)         ;; DecisionMonad
        applyHomeostaticDamping     ;; dampingFn 
        raiseBoundaryCaution        ;; boundaryFn
        projectToSafeRegion         ;; projectFn
        checkContractiveUpdateLaw   ;; contractiveFn
        isInSafeRegion              ;; safeRegionFn
    )
)


;; MotivOS-formatted decision result for injection into the LLM prompt.
(= (motivationContextBlock)
    (let* (
        ($_ (ensureMotivationRestored))
        ($signals (eval (refreshSignals)))
      ;   ($_ (println! ("Signals" $signals)))
        ($_ (refreshTaskExecutionObserved))
        ($_ (completePreviousTaskIfSuccessful))
        ($_ (eval (clearSpace &appraisal-space)))
        ($_ (eval (computeAllDimensions)))
         
         ($currentMetaMoState (eval (motivosToMetamoState)))
         ; ($_ (println! ("Current state" $currentMetaMoState)))
         ($stimulus (eval (appraisalToStimulus)))
         ; ($_ (println! ("Current Stimulus" $stimulus)))
         ; ($_ (printDecisionRoutingDebug))
         
         ($_ (generateCandidates))
         ($availableCandidates
            (collapse (match &candidateSpace (candidate $name) $name)))
         ; ($_ (println! ("[MotivationDebug] Available candidates" $availableCandidates)))
         ($actions (eval (candidatesToActions)))
         ; ($_ (println! ("[MotivationDebug] Candidate actions" $actions)))
         
         ($sysStates (cons-atom (subsystemState omegaclaw $currentMetaMoState) ()))
         
         ($bimonad     (omegaclawBimonad))
         ; ($_ (println! ("Bimonad" $bimonad)))
         ($cycleResult (runMetaMoCycleDefault $bimonad $sysStates $stimulus $actions () ()))
         ; ($_ (println! ("cycle result" $cycleResult)))

        ($finalAction   (cycleFinalAction  $cycleResult))
        ($nextSysStates (cycleNextStates   $cycleResult))
      ;   ($_ (println! ("[MotivationDebug] Final action" $finalAction)))
      ;   ($_ (println! ("next sys states" $nextSysStates)))

        ($rawNextState (findSubsystemState omegaclaw $nextSysStates))
        ($nextState (eval (decayMetamoState $rawNextState)))
      ;   ($_ (println! ("next state" $nextState)))
        ($x (eval (writeBackMetamoState $nextState)))
      ;   ($_ (println! ("write back result" $x)))
        
        ($score (omegaclawScore $nextState $finalAction))
      ;   ($_ (println! ("score" $score)))
        ($decisionResult (eval (metamoActionToDecision $finalAction $score)))
      ;   ($_ (println! ("decision result" $decisionResult)))
        ((decision $selectedCand $_mode $_directive $_score) $decisionResult)

        ($_ (advanceAutonomyPhase $selectedCand))
        ($_ (change-state! &last-motivation-decision $decisionResult))
        ($_ (updateSelfModel (hasErrors) (hasResults)))
        ($_ (runHomeostasis))
        ($_ (maybeSaveMotivationalState))
        ($_ (collapse (clearSignals)))
    )
        $decisionResult
    )
)


(= (hasErrors)
    (or (hasSignal failure) (hasSignal repeated-failure))
)

(= (hasResults)
    (or (hasSignal progress-made) (hasSignal verified-success))
)

;; Weighted contribution of one signal kind to one appraisal dimension.
(= (signalDimContrib $kind $strength $dim)
   (let $weights (collapse (match &self (SignalAppraisal $kind $dim $w) $w))
      (if (== $weights ()) 0.0 (* $strength (car-atom $weights)))))

;; Sum contributions from a list of signals for one dimension.
(= (sumDimFromSignals $dim () $acc) $acc)
(= (sumDimFromSignals $dim $signals $acc)
   (let* (
      (($head $tail) (decons-atom $signals))
      ((signal $kind $strength) $head)
      ($contrib (signalDimContrib $kind $strength $dim))
   )
   (sumDimFromSignals $dim $tail (+ $acc $contrib))))

;; Compute total value for one appraisal dimension from current &signal-space.
(= (computeDimension $dim)
   (let $signals (collapse (match &signal-space (signal $k $s) (signal $k $s)))
      (clamp (sumDimFromSignals $dim $signals 0.0))))

;; Populate &appraisal-space with all 6 dimension values.
(= (computeAllDimensions)
    (let* (
        ($n (computeDimension novelty))
        ($r (computeDimension risk))
        ($i (computeDimension importance))
        ($u (computeDimension uncertainty))
        ($o (computeDimension opportunity))
        ($p (computeDimension progress))
        ($_ (add-atom &appraisal-space (appraisal novelty     $n)))
        ($_ (add-atom &appraisal-space (appraisal risk        $r)))
        ($_ (add-atom &appraisal-space (appraisal importance  $i)))
        ($_ (add-atom &appraisal-space (appraisal uncertainty $u)))
        ($_ (add-atom &appraisal-space (appraisal opportunity $o)))
        ($_ (add-atom &appraisal-space (appraisal progress    $p)))
    ) True)
)


(= (evalCondition $type $param $thresh)
   (case $type (
      (always True)
      (task-active (get-state &task-open))
      (task-inactive (not (get-state &task-open)))
      (appraisal-above (> (extractAppraisalDim $param) $thresh))
      (appraisal-below (< (extractAppraisalDim $param) $thresh))
      (modulator-above (> (extractModulatorValue $param) $thresh))
      (self-metric-above (> (fetchSelfMetricValue $param) $thresh))
      (self-metric-below (< (fetchSelfMetricValue $param) $thresh))
      ($_ (println! ("Unknown condition type: " $type)))
   ))
)

(= (allTrue ()) True)
(= (allTrue $lst)
   (let* (
      (($head $tail) (decons-atom $lst))
      ((CandidateCondition $_ $type $param $thresh) $head)
      ($result (evalCondition $type $param $thresh))
   )
   (if $result (allTrue $tail) False)))

(= (anyTrue ()) False)
(= (anyTrue $lst)
   (let* (
      (($head $tail) (decons-atom $lst))
      ((CandidateConditionAny $_ $type $param $thresh) $head)
      ($result (evalCondition $type $param $thresh))
   )
   (if $result True (anyTrue $tail))))

(= (candidateIsAvailable $name)
   (if (idleAutonomyActive)
       (if (hasErrors)
           (== $name self-improve)
           (autonomyPhaseAllows $name))
       (if (directUserResponseNeeded)
           (== $name respond)
           (if (resultQuestionNeedsResponse)
               (== $name respond)
               (if (taskResultReady)
                   (if (executionContinuationNeeded)
                       (if (executionRiskCurrentlyHigh)
                           (== $name ask-clarification)
                           (== $name execute-skill))
                       (== $name respond))
                   (if (freshExecutionRequestNeeded)
                       (if (executionRiskCurrentlyHigh)
                           (== $name ask-clarification)
                           (== $name execute-skill))
                       (let* (
                  ($andRows (collapse (match &self (CandidateCondition $name $t $p $h)
                                          (CandidateCondition $name $t $p $h))))
                  ($orRows  (collapse (match &self (CandidateConditionAny $name $t $p $h)
                                          (CandidateConditionAny $name $t $p $h))))
                  ($hasAnd  (not (== $andRows ())))
                  ($hasOr   (not (== $orRows  ())))
                  ($highExecutionIntent (and (get-state &task-open)
                                             (> (extractAppraisalDim opportunity)
                                                (executionOpportunityThreshold))))
                  ($executionIntent (and (get-state &task-open)
                                         (> (extractAppraisalDim opportunity)
                                            (executionIntentThreshold))))
                  ($executionRisky (executionRiskCurrentlyHigh))
                  ($executionContinuation (executionContinuationNeeded))
                  ($blockedExecution (and (or $executionIntent $executionContinuation)
                                          $executionRisky))
                  ($safeHighExecutionIntent (and $highExecutionIntent
                                                 (not $executionRisky)))
                  ($safeExecutionContinuation (and $executionContinuation
                                                   (not $executionRisky)))
                  ($awaitingClarification (awaitingClarificationResponse))
                  ($needsRepair (and (get-state &task-open) (hasErrors)))
               )
               (if $needsRepair
                   (== $name repair-failure)
                   (if $awaitingClarification
                       False
                       (if $blockedExecution
                           (== $name ask-clarification)
                           (if $safeExecutionContinuation
                               (== $name execute-skill)
                               (if $safeHighExecutionIntent
                                   (== $name execute-skill)
                                   (if (and (not $hasAnd) (not $hasOr))
                                       False
                                       (and (if $hasAnd (eval (allTrue $andRows)) True)
                                            (if $hasOr  (eval (anyTrue $orRows))  True)))))))))))))))

(= (generateCandidates)
   (let* (
      ($_ (clearSpace &candidateSpace))
      ($allCandidates (collapse (match &self (CandidateSpec $n $_type) $n)))
      ($_ (println! ("[MotivationDebug] Candidate sources"
                     (registered-names $allCandidates))))
      ($_ (collapse
             (let $n (superpose $allCandidates)
                (if (candidateIsAvailable $n)
                    (add-atom &candidateSpace (candidate $n))
                    (empty)))))
   )
   True))

;; Simple union/unique utilities
(= (unionAtom $a $b)
    (collapse (superpose ((superpose $a) (superpose $b))))
)


;; Map winning candidate name to a binding imperative for the LLM.
(= (candidateInstruction $directive)
   (case $directive (
      (respond           "REQUIRED: Respond to the user now. Your primary output MUST include a send command. Base completion and status claims only on LAST_SKILL_USE_RESULTS. If it already answers the user's question, send that result and do not rerun tools. When the user requests only the tool result, relay only the observed result without adding claims from HISTORY or assumptions.")
      (retrieve-memory   "REQUIRED: Query long-term memory before responding. Your primary output MUST include a query command.")
      (search-knowledge  "REQUIRED: Search for relevant knowledge before responding. Your primary output MUST include a search or query command.")
      (execute-skill     "REQUIRED: Execute the requested skill or task now. If the user requested multiple executable steps, include the next pending skill command instead of only reporting progress. Include send only for truthful status or already-observed results; never invent command output.")
      (learn             "REQUIRED: Capture and store new knowledge this cycle. Your primary output MUST include a remember command.")
      (self-improve      "REQUIRED: Reflect on recent failures and update your approach. Consider using remember to store the lesson.")
      (background-work   "REQUIRED: Execute exactly one safe read-only background step from the active internal plan. Do not send. Prefer read-file, query, or a read-only shell inspection such as pwd, ls, find, rg, grep, wc, head, tail, or git status/log/diff/show. Do not write files.")
      (recall-goals      "REQUIRED: Query long-term memory for current goals or active-goal context. Do not send this cycle.")
      (invent-goal       "REQUIRED: Create one bounded non-duplicate active-goal proposal. Use pin or remember. Do not send this cycle.")
      (plan-goal         "REQUIRED: Convert the active internal goal and latest results into one concrete next background step. Use pin or remember. Do not send this cycle.")
      (repair-failure    "REQUIRED: Repair the previous failed command or formatting issue now. If the failed command was send, output one corrected send. If it was a file command, output the smallest corrective read-file, write-file, or append-file. Do not merely say you will fix it.")
      (defer             "REQUIRED: Do not take irreversible action this cycle. Verify the situation first before acting.")
      (ask-clarification "REQUIRED: Ask the user a clarifying question. Your primary output MUST include a send command with a question.")
      (none              "REQUIRED: No user-facing task is active. Work silently or output an empty command list: ().")
      ($other            "REQUIRED: Act according to your current motivational state and the STEP_POLICY above.")
   ))
)

;; Look up directive guidance text from registry.
(= (directiveGuidance $directive)
    (let $res (collapse (match &self (DirectiveText $directive $text) $text))
        (if (== $res ()) "" (car-atom $res)))
)

;; standard OmegaClaw prompt structure.
(= (getContext)
   (let* (
      ($decisionResult (motivationContextBlock))
      ($_ (println! (MOTIVATION-CONTEXT-BLOCK: $decisionResult)))
      ((decision $selectedCand $mode $directive $score) $decisionResult)
      ($guidance    (directiveGuidance $directive))
      ($instruction (candidateInstruction $selectedCand))
      ($activeTask  (get-state &active-task))
      ($autonomyPhase (autonomyPhaseForCandidate $selectedCand))
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
         " Example — one command:"
         " ((send \"message\"))"
         " Example — multiple commands:"
         " ((query \"topic\") (send \"message\"))"
         " Do not output conversational text outside the expression."
         " IMPORTANT: For code passed as a string argument, prefer single-quoted Python strings inside the code. Avoid quote characters that can terminate the surrounding MeTTa string."
         " LAST_SKILL_USE_RESULTS: " (eval (last_chars (get-state &lastresults) (maxFeedback)))
         " HISTORY: " (eval (getHistory))
         " ACTIVE_TASK: " (eval (string-safe $activeTask))
         " TASK_EXECUTION_OBSERVED: " (eval (string-safe (repr $taskExecutionObserved)))
         " AUTONOMY_PHASE: " (eval (string-safe (repr $autonomyPhase)))
         " AUTONOMY_NEXT_PHASE: " (eval (string-safe (repr $nextAutonomyPhase)))
         " AUTONOMY_ACTION_COUNT: " (eval (string-safe (repr $autonomyActionCount)))
         " RUNTIME_CONTEXT: " (eval (string-safe $runtimeContext))
         " FILE_PATH_POLICY: Relative file paths used by file skills resolve against RUNTIME_CONTEXT working_directory."
         " TIME: " (eval (get_time_as_string))
         " STEP_POLICY: " $guidance
         " MOTIVATION_INSTRUCTION: " $instruction
         " MOTIVATION_DECISION: " (eval (string-safe (repr $decisionResult)))
         )))))
))

(= (initOmegaClawMotivation)
    (let* (
        ($_ (clearSpace &goal-space))
        ($_ (collapse
                (let* (
                    (($name $b) (match &self (GoalSpec $name $b) ($name $b)))
                )
                (add-atom &goal-space (goal $name $b)))))

        ($_ (collapse
                (let* (
                    (($name $w) (match &self (AntiGoalSpec $name $w) ($name $w)))
                )
                (add-atom &goal-space (anti-goal $name $w)))))

        ($_ (clearSpace &motivation-space))
        ($_ (collapse
                (let* (
                    (($name $b) (match &self (ModulatorSpec $name $b) ($name $b)))
                )
                (add-atom &motivation-space (modulator $name $b)))))

        ($_ (collapse
                (let* (
                    (($name $b) (match &self (MotiveSpec $name $b) ($name $b)))
                )
                (add-atom &motivation-space (motive $name $b)))))

        ($_ (add-atom &motivation-space (mode orient)))
        ($_ (clearSpace &self-model-space))
        ($_ (collapse
                (let* (
                    (($name $b) (match &self (SelfModelSpec $name $b) ($name $b)))
                )
                (add-atom &self-model-space (self-metric $name $b)))))
    )
        (println! "OmegaClaw Motivation Initialized via MetaMo Adapter")
    )
)

;; initialize all MotivOS spaces from registry specs
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
      ($_ (change-state! &motivation-save-countdown (persistenceInterval)))
   )
   (eval (omegaclaw))))
