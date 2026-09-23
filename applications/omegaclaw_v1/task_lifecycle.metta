;; User-task state, execution continuation, and idle-autonomy phases.

!(import! &self (library MetaMo applications/omegaclaw_v1/commitments))
!(bind! &task-commitment-id (new-state ()))

!(bind! &active-task              (new-state ""))
!(bind! &task-open                (new-state False))
!(bind! &last-motivation-decision
   (new-state (decision clarity orient inspect 0.0)))
!(bind! &last-meta-mo-policy-output
   (new-state (legacyStartupPolicyOutput (constitutionalModeDefault))))
!(bind! &autonomy-phase          (new-state recall))
!(bind! &autonomy-action-count   (new-state 0))
!(bind! &task-execution-observed (new-state ""))

(= (autonomyActionsBeforeRefresh)
   (let $v (collapse (match &self
                       (DynamicsConfig autonomy_actions_before_refresh $x) $x))
      (if (== $v ()) 2 (car-atom $v))))

(= (seedThreshold $key)
   (let $v (collapse (match &self (SeedThreshold $key $x) $x))
      (if (== $v ()) 0.0 (car-atom $v))))

(= (executionOpportunityThreshold)
   (seedThreshold execution_opportunity_threshold))

(= (executionIntentThreshold)
   (seedThreshold execution_intent_threshold))

(= (executionRiskLimit)
   (seedThreshold execution_risk_limit))

(= (executionUncertaintyLimit)
   (seedThreshold execution_uncertainty_limit))

(= (executionCautionLimit)
   (seedThreshold execution_caution_limit))

(= (idleAutonomyActive)
   ;; The bundle accessor is supplied by the later-loaded decision module.
   ;; Resolve this compatibility wrapper at runtime, as the snapshot setter is.
   (eval (idleAutonomyActiveForBundle (activeFrameBundle))))

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
   (eval (advanceAutonomyPhaseForBundle (activeFrameBundle) $candidate)))

(= (advanceAutonomyPhaseForBundle $bundle $candidate)
   (if (idleAutonomyActiveForBundle $bundle)
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
   ;; Host-side bookkeeping runs before publication, so it must not consult
   ;; the previous cycle's bounded (and possibly truncated) bundle.
      (if (get-state &new-msg-flag)
          (let $_ (change-state! &task-execution-observed "") True)
          ;; No new result means no merge. In particular, do not round-trip
          ;; the empty MeTTa string through Python into a nonempty digest.
          (if (or (== (get-state &lastresults) "") (== (get-state &lastresults) ()))
              True
              (let $merged (py-call (helper.merge_observed_execution_commands
                                 (get-state &task-execution-observed)
                                 (get-state &lastresults)))
                 (change-state! &task-execution-observed $merged)))))

(= (executionContinuationNeeded)
   (executionContinuationNeededForBundle (activeFrameBundle)))

(= (executionContinuationNeededForBundle $bundle)
   ;; Continuation requires an execution observation. A newly admitted task
   ;; with none yet falls through to ordinary registry candidate generation.
   ;; Use if: and evaluates its arguments, including the optional host call.
   (if (and (frameRuntimeTaskOpen $bundle)
            (not (bundle-runtime-has-new-message $bundle)))
       (let $observed (frameRuntimeText (frameRuntimeExecutionObserved $bundle))
          (if (== $observed "")
              False
              (py-call (helper.task_needs_more_execution
                 (frameRuntimeText (frameRuntimeActiveTask $bundle)) $observed))))
       False))

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
   (if (hasSignal user-waiting)
        (py-call (helper.is_result_status_question
                  (frameRuntimeText (frameRuntimeMessage $bundle))))
        False))

;; Historical entry points cannot infer commitment completion from candidates,
;; motivation, or result text. Hosts must publish an explicit commitment event.
(= (completeTaskIfTerminal $_candidate) False)

(= (hostTaskValuePresent $value)
   (and (!= $value "") (!= $value ())))

(= (completePreviousTaskIfSuccessful)
   False)

;; Mirror authoritative host commitment state into the legacy task projection.
;; No host record means preserve legacy state, never invent an identity or close
;; a task. A new message alone cannot abandon or supersede an open commitment.
(= (refreshTaskCommitment)
   (let $snapshot (commitmentSnapshot)
      (case $snapshot (
         ((CommitmentSnapshot $id $_frame $_revision $status $summary)
          (let* (
             ($open (== $status Open))
             ($_ (if (or (not $open) (!= (get-state &task-commitment-id) $id))
                     (change-state! &task-execution-observed "") True))
             ($_ (change-state! &task-commitment-id $id))
             ($_ (change-state! &task-open $open))
             ($_ (change-state! &active-task (if $open $summary "")))) True))
         (NoCommitment False)))))

;; Host adapter publication boundary for the serialized OmegaClaw loop.
;; Ingestion has already updated host state. Finish bookkeeping, then publish
;; exactly one snapshot; downstream MetaMo consumers only read that snapshot.
(= (prepareTaskStateForMetaMo)
   (let* (
      ($_ (refreshTaskExecutionObserved))
      ($_ (refreshTaskCommitment))
      ($bundle (frameStateForMetaMo))
      ;; The decision module providing this setter loads after lifecycle.
      ($_ (eval (setActiveFrameBundle $bundle)))
   ) $bundle))
