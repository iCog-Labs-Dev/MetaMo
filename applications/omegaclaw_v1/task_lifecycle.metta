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
   (idleAutonomyActiveForBundle (activeFrameBundle)))

;; Bundle-scoped lifecycle predicates. These are the only variants used by
;; candidate selection; the legacy zero-argument helpers remain for startup
;; and persistence code outside the MetaMo input boundary.
(= (idleAutonomyActiveForBundle $bundle)
   (and (not (bundle-runtime-has-new-message $bundle))
        (not (frameRuntimeTaskOpen $bundle))))

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
   (let $bundle (activeFrameBundle)
      (if (bundle-runtime-has-new-message $bundle)
          (let $_ (change-state! &task-execution-observed "") True)
          (let $merged (py-call (helper.merge_observed_execution_commands
                                 (frameRuntimeExecutionObserved $bundle)
                                 (frameRuntimeResults $bundle)))
             (change-state! &task-execution-observed $merged)))))

(= (executionContinuationNeeded)
   (executionContinuationNeededForBundle (activeFrameBundle)))

(= (executionContinuationNeededForBundle $bundle)
   (and (frameRuntimeTaskOpen $bundle)
        (and (not (bundle-runtime-has-new-message $bundle))
             (py-call (helper.task_needs_more_execution
                       (frameRuntimeText (frameRuntimeActiveTask $bundle))
                       (frameRuntimeExecutionObserved $bundle))))))

(= (awaitingClarificationResponse)
   (awaitingClarificationResponseForBundle (activeFrameBundle)))

(= (awaitingClarificationResponseForBundle $bundle)
   (let* (
      ($lastDecision (get-state &last-motivation-decision))
      ((decision $candidate $_mode $_directive $_score) $lastDecision))
   (and (frameRuntimeTaskOpen $bundle)
        (and (not (bundle-runtime-has-new-message $bundle))
             (== $candidate ask-clarification)))))

(= (directUserResponseNeeded)
   (directUserResponseNeededForBundle (activeFrameBundle)))

(= (directUserResponseNeededForBundle $bundle)
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

(= (executionRiskCurrentlyHighForBundle $bundle)
   (or (> (extractAppraisalDim risk) (executionRiskLimit))
       (or (> (extractAppraisalDim uncertainty) (executionUncertaintyLimit))
           (and (> (extractModulatorValue caution) (executionCautionLimit))
                (or (> (extractAppraisalDim risk) 0.10)
                    (> (extractAppraisalDim uncertainty) 0.20))))))

(= (freshExecutionRequestNeeded)
   (freshExecutionRequestNeededForBundle (activeFrameBundle)))

(= (freshExecutionRequestNeededForBundle $bundle)
   (and (hasSignal user-waiting)
        (> (extractAppraisalDim opportunity) (executionIntentThreshold))))

(= (taskResultReady)
   (taskResultReadyForBundle (activeFrameBundle)))

(= (taskResultReadyForBundle $bundle)
   (and (frameRuntimeTaskOpen $bundle)
        (and (not (bundle-runtime-has-new-message $bundle))
             (and (not (awaitingClarificationResponseForBundle $bundle))
                  (and (hasResults) (not (hasErrors)))))))

(= (resultQuestionNeedsResponse)
   (resultQuestionNeedsResponseForBundle (activeFrameBundle)))

(= (resultQuestionNeedsResponseForBundle $bundle)
   (and (hasSignal user-waiting)
        (py-call (helper.is_result_status_question
                  (frameRuntimeText (frameRuntimeMessage $bundle))))))

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
