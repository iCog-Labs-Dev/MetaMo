;; Candidate availability and conversion of registry rules into runtime choices.

!(bind! &candidateSpace (new-space))

(= (evalCondition $bundle $type $param $thresh)
   (case $type (
      (always True)
      (task-active (frameRuntimeTaskOpen $bundle))
      (task-inactive (not (frameRuntimeTaskOpen $bundle)))
      (appraisal-above (> (extractAppraisalDim $param) $thresh))
      (appraisal-below (< (extractAppraisalDim $param) $thresh))
      (modulator-above (> (extractModulatorValue $param) $thresh))
      (self-metric-above (> (fetchSelfMetricValue $param) $thresh))
      (self-metric-below (< (fetchSelfMetricValue $param) $thresh))
      ($_ (println! ("Unknown condition type: " $type)))
   )))

(= (allTrue ()) True)
(= (allTrue $bundle $lst)
   (let* (
      (($head $tail) (decons-atom $lst))
      ((CandidateCondition $_ $type $param $thresh) $head)
      ($result (evalCondition $bundle $type $param $thresh))
   )
   (if $result (allTrue $bundle $tail) False)))

(= (anyTrue ()) False)
(= (anyTrue $bundle $lst)
   (let* (
      (($head $tail) (decons-atom $lst))
      ((CandidateConditionAny $_ $type $param $thresh) $head)
      ($result (evalCondition $bundle $type $param $thresh))
   )
   (if $result True (anyTrue $bundle $tail))))

(= (candidateIsAvailable $bundle $name)
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
                          ($andRows
                             (collapse (match &self
                                (CandidateCondition $name $t $p $h)
                                (CandidateCondition $name $t $p $h))))
                          ($orRows
                             (collapse (match &self
                                (CandidateConditionAny $name $t $p $h)
                                (CandidateConditionAny $name $t $p $h))))
                          ($hasAnd (not (== $andRows ())))
                          ($hasOr (not (== $orRows ())))
                          ($highExecutionIntent
                             (and (frameRuntimeTaskOpen $bundle)
                                  (> (extractAppraisalDim opportunity)
                                     (executionOpportunityThreshold))))
                          ($executionIntent
                             (and (frameRuntimeTaskOpen $bundle)
                                  (> (extractAppraisalDim opportunity)
                                     (executionIntentThreshold))))
                          ($executionRisky (executionRiskCurrentlyHigh))
                          ($executionContinuation (executionContinuationNeeded))
                          ($blockedExecution
                             (and (or $executionIntent $executionContinuation)
                                  $executionRisky))
                          ($safeHighExecutionIntent
                             (and $highExecutionIntent (not $executionRisky)))
                          ($safeExecutionContinuation
                             (and $executionContinuation (not $executionRisky)))
                          ($awaitingClarification
                             (awaitingClarificationResponse))
                          ($needsRepair
                             (and (frameRuntimeTaskOpen $bundle) (hasErrors)))
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
                                               (and
                                                  (if $hasAnd
                                                      (eval (allTrue $bundle $andRows))
                                                      True)
                                                  (if $hasOr
                                                      (eval (anyTrue $bundle $orRows))
                                                      True)))))))))))))))

(= (generateCandidates $bundle)
   (let* (
      ($_ (clearSpace &candidateSpace))
      ($allCandidates
         (collapse (match &self (CandidateSpec $n $_type) $n)))
      ($_ (collapse
             (let $n (superpose $allCandidates)
                (if (and (candidateIsAvailable $bundle $n)
                         (candidateAdmitted $bundle $n))
                    (add-atom &candidateSpace (candidate $n))
                    (empty)))))
   ) True))
