;; Candidate availability and conversion of registry rules into runtime choices.

!(bind! &candidateSpace (new-space))
!(bind! &candidate-rejection-space (new-space))

;; Local diagnostics for the most recent generation, not execution authority.
(= (candidateRejections)
   (collapse (match &candidate-rejection-space
      (CandidateRejection $candidate $reason) (CandidateRejection $candidate $reason))))

(= (recordCandidateRejections $rejections)
   (if (== $rejections ()) True
       (let* (
          (($head $tail) (decons-atom $rejections))
          ($_ (add-atom &candidate-rejection-space $head)))
          (recordCandidateRejections $tail))))

(= (recordCandidateGate $candidate $gate)
   (let (GateDecision $admission $reason) $gate
      (if (== $admission Admitted)
          (add-atom &candidateSpace (candidate $candidate))
          (add-atom &candidate-rejection-space (CandidateRejection $candidate $reason)))))

;; Native concrete-operation admission uses the same request gate as proposals
;; and scheduler attention. The operation metadata is resolved by the host.
(= (candidateAdmissionForOperation $bundle $candidate $operation $global $frame)
   (feasibilityGateForRequest $bundle $bundle
      (AdmissionRequest propose-candidate current-frame $candidate)
      $operation $global $frame))

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

;; Keep the empty-list branch in the same two-argument definition. Separate
;; broad recursive and base clauses can overlap in MeTTa's result set.
(= (allTrue $bundle $lst)
   (if (== $lst ())
      True
      (let* (
         (($head $tail) (decons-atom $lst))
         ((CandidateCondition $_ $type $param $thresh) $head)
         ($result (evalCondition $bundle $type $param $thresh))
      )
         (if $result (allTrue $bundle $tail) False))))

(= (anyTrue $bundle $lst)
   (if (== $lst ())
      False
      (let* (
         (($head $tail) (decons-atom $lst))
         ((CandidateConditionAny $_ $type $param $thresh) $head)
         ($result (evalCondition $bundle $type $param $thresh))
      )
         (if $result True (anyTrue $bundle $tail)))))

;; Availability follows an ordered decision chain. Each stage either decides
;; or delegates, preserving precedence without evaluating later branches early.
(= (candidateIsAvailableRaw $bundle $name)
   (and (not (and (== $name ask-clarification) (continuationAwaitingCompletionForBundle $bundle)))
   (if (heldMissingInputForBundle $bundle)
       (and (missingInputClarificationNeededForBundle $bundle) (== $name ask-clarification))
       (if (idleAutonomyActiveForBundle $bundle)
           (autonomousCandidateAvailable $name)
           (responseCandidateAvailable $bundle $name)))))

(= (autonomousCandidateAvailable $name)
   (if (hasErrors) (== $name self-improve) (autonomyPhaseAllows $name)))

(= (responseCandidateAvailable $bundle $name)
   (if (or (directUserResponseNeededForBundle $bundle)
           (resultQuestionNeedsResponseForBundle $bundle))
       (== $name respond)
       (taskResultCandidateAvailable $bundle $name)))

(= (taskResultCandidateAvailable $bundle $name)
   (if (taskResultReadyForBundle $bundle)
       (readyResultCandidateAvailable $bundle $name)
       (freshRequestCandidateAvailable $bundle $name)))

(= (readyResultCandidateAvailable $bundle $name)
   (if (executionContinuationNeededForBundle $bundle)
       (executionCandidateAvailable $bundle $name)
       (== $name respond)))

(= (executionCandidateAvailable $bundle $name)
   (if (executionRiskCurrentlyHighForBundle $bundle)
       (== $name ask-clarification)
       (== $name execute-skill)))

(= (freshRequestCandidateAvailable $bundle $name)
   (if (freshExecutionRequestNeededForBundle $bundle)
       (executionCandidateAvailable $bundle $name)
       (repairCandidateAvailable $bundle $name)))

(= (repairCandidateAvailable $bundle $name)
   (if (and (frameRuntimeTaskOpen $bundle) (hasErrors))
       (== $name repair-failure)
       (clarificationCandidateAvailable $bundle $name)))

(= (clarificationCandidateAvailable $bundle $name)
   (if (awaitingClarificationResponseForBundle $bundle)
       False
       (blockedExecutionCandidateAvailable $bundle $name)))

(= (executionIntentAbove $bundle $threshold)
   (and (frameRuntimeTaskOpen $bundle)
        (> (extractAppraisalDim opportunity) $threshold)))

(= (executionIsBlockedForCandidates $bundle)
   (and (or (executionIntentAbove $bundle (executionIntentThreshold))
            (executionContinuationNeededForBundle $bundle))
        (executionRiskCurrentlyHighForBundle $bundle)))

(= (blockedExecutionCandidateAvailable $bundle $name)
   (if (executionIsBlockedForCandidates $bundle)
       (== $name ask-clarification)
       (safeExecutionCandidateAvailable $bundle $name)))

(= (safeExecutionCandidateAvailable $bundle $name)
   (if (and (not (executionRiskCurrentlyHighForBundle $bundle))
            (or (executionContinuationNeededForBundle $bundle)
                (executionIntentAbove $bundle (executionOpportunityThreshold))))
       (== $name execute-skill)
       (registryCandidateAvailable $bundle $name)))

(= (registryCandidateAvailable $bundle $name)
   (let* (
      ($andRows (collapse (match &self
         (CandidateCondition $name $t $p $h)
         (CandidateCondition $name $t $p $h))))
      ($orRows (collapse (match &self
         (CandidateConditionAny $name $t $p $h)
         (CandidateConditionAny $name $t $p $h)))))
      (case ((== $andRows ()) (== $orRows ())) (
         ((True True) False)
         ((False True) (eval (allTrue $bundle $andRows)))
         ((True False) (eval (anyTrue $bundle $orRows)))
         ((False False) (and (eval (allTrue $bundle $andRows))
                            (eval (anyTrue $bundle $orRows))))))))

;; A possible same-frame relation is advisory evidence, but it must route the
;; cycle through the explicit frame-state verification operation before other
;; work. It must never be treated as permission to merge or act on a frame.
(= (candidateIsAvailable $bundle $name)
   (if (bundleNeedsRelationVerification $bundle)
       (== $name verify-frame-state)
       (candidateIsAvailableRaw $bundle $name)))

(= (generateCandidates $bundle)
   (let* (
      ($_ (clearSpace &candidateSpace))
      ($_ (clearSpace &candidate-rejection-space))
      ($allCandidates
         (collapse (match &self (CandidateSpec $n $_type) $n)))
      ($_ (collapse
             (let $n (superpose $allCandidates)
                (if (candidateIsAvailable $bundle $n)
                    (recordCandidateGate $n (feasibilityGate $bundle $n))
                    (empty)))))
   ) True))

;; Host rows bind each native candidate to one concrete operation and policy.
;; No rows means no executable candidate; this API never falls back to legacy
;; candidate-name-only admission. Availability still uses the existing rules.
(= (generateCandidatesForOperations $bundle $rows)
   (let* (
      ($_ (clearSpace &candidateSpace))
      ($_ (clearSpace &candidate-rejection-space))
      ($_ (collapse
         (let (CandidateOperation $candidate $operation $global $frame) (superpose $rows)
            (let (GateDecision $admission $reason)
                    (candidateAdmissionForOperation $bundle $candidate $operation $global $frame)
               (if (== $admission Admitted)
                   (if (candidateIsAvailable $bundle $candidate)
                       (add-atom &candidateSpace (candidate $candidate)) (empty))
                   (add-atom &candidate-rejection-space
                      (CandidateRejection $candidate $reason)))))))) True))
