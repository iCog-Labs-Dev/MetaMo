;; User-task state, execution continuation, and idle-autonomy phases.

!(bind! &active-task              (new-state ""))
!(bind! &task-open                (new-state False))
!(bind! &last-motivation-decision
   (new-state (decision clarity orient inspect 0.0)))
!(bind! &autonomy-phase          (new-state recall))
!(bind! &autonomy-action-count   (new-state 0))
!(bind! &task-execution-observed (new-state ""))

(= (autonomyActionsBeforeRefresh)
   (let $v (collapse (match &self
                       (DynamicsConfig autonomy_actions_before_refresh $x) $x))
      (if (== $v ()) 2 (car-atom $v))))

(= (executionOpportunityThreshold)
   (let $v (collapse (match &self
                       (DynamicsConfig execution_opportunity_threshold $x) $x))
      (if (== $v ()) 0.75 (car-atom $v))))

(= (executionIntentThreshold)
   (let $v (collapse (match &self
                       (DynamicsConfig execution_intent_threshold $x) $x))
      (if (== $v ()) 0.50 (car-atom $v))))

(= (executionRiskLimit)
   (let $v (collapse (match &self
                       (DynamicsConfig execution_risk_limit $x) $x))
      (if (== $v ()) 0.45 (car-atom $v))))

(= (executionUncertaintyLimit)
   (let $v (collapse (match &self
                       (DynamicsConfig execution_uncertainty_limit $x) $x))
      (if (== $v ()) 0.65 (car-atom $v))))

(= (executionCautionLimit)
   (let $v (collapse (match &self
                       (DynamicsConfig execution_caution_limit $x) $x))
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
      (invent-goal invent)
      (plan-goal plan)
      (background-work act)
      ($_ none)
   )))

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
