(: InferenceTraceStep Type)
(: inferenceTraceStep (-> PlnProposal Expression Expression InferenceTraceStep))

(: InferenceEvaluation Type)
(: inferenceEvaluation
   (-> Symbol Symbol Expression Number Number Expression InferenceEvaluation))

(= (inferenceEvaluationField
      (inferenceEvaluation $policy $status $answer $applications $cost $trace) $field)
   (case $field
     ((policy $policy)
      (status $status)
      (answer $answer)
      (applications $applications)
      (estimatedCost $cost)
      (trace $trace)
      ($_ (empty)))))

(= (inferenceTraceCost $trace)
   (if (== $trace ())
       0.0
       (let (inferenceTraceStep $proposal $derived $state) (car-atom $trace)
            (+ (inferenceEstimatedCost $proposal)
               (inferenceTraceCost (cdr-atom $trace))))))

(= (inferenceOutcomeTrace $history)
   (if (== $history ())
       ()
       (let* (($outcome (car-atom $history))
              ($execution (inferenceOutcomeExecution $outcome)))
             (cons-atom
               (inferenceTraceStep
                 (inferenceExecutionProposal $execution)
                 (inferenceExecutionDerived $execution)
                 (inferenceOutcomeState $outcome))
               (inferenceOutcomeTrace (cdr-atom $history))))))

(= (inferenceFixedStateTrace $state $history)
   (if (== $history ())
       ()
       (let $execution (inferenceOutcomeExecution (car-atom $history))
            (cons-atom
              (inferenceTraceStep
                (inferenceExecutionProposal $execution)
                (inferenceExecutionDerived $execution)
                $state)
              (inferenceFixedStateTrace $state (cdr-atom $history))))))

(= (inferenceEvaluateControlled $state $request $budget $minimumConfidence)
   (case (inferenceControlRun $state $request $budget $minimumConfidence)
     (((validationOk (inferenceRun $status $steps $finalRequest $answer $finalState $history))
       (let $trace (inferenceOutcomeTrace $history)
            (validationOk
              (inferenceEvaluation metamo $status $answer $steps
                                   (inferenceTraceCost $trace) $trace))))
      ((validationError $code $details) (validationError $code $details)))))

(= (inferenceEvaluateControlled $state $request $budget)
   (inferenceEvaluateControlled $state $request $budget
                                (INFERENCE_CONTROL_MIN_CONFIDENCE)))

(= (inferenceEvaluateFixedStateFrom
      $state $request $steps $budget $history $attempted $minimumConfidence)
   (let $answer (plnAnswer
                  (inferenceRequestBeliefs $request)
                  (inferenceRequestQuery $request))
        (if (inferenceAnswerAccepted $answer $minimumConfidence)
            (inferenceEvaluateFixedStateResult $state answered $answer $history)
            (if (>= $steps $budget)
                (inferenceEvaluateFixedStateResult $state budgetExhausted $answer $history)
                (case (inferenceControlTransition $state $request $attempted)
                  (((validationOk $outcome)
                    (inferenceEvaluateFixedStateFrom
                      $state
                      (inferenceOutcomeNextRequest $outcome)
                      (+ $steps 1) $budget
                      (append $history ($outcome))
                      (append $attempted
                        ((inferenceExecutionProposal
                            (inferenceOutcomeExecution $outcome))))
                      $minimumConfidence))
                   ((validationError empty-candidates $details)
                    (inferenceEvaluateFixedStateResult $state noCandidates $answer $history))
                   ((validationError $code $details)
                    (validationError $code $details))))))))

(= (inferenceEvaluateFixedStateResult $state $status $answer $history)
   (let $trace (inferenceFixedStateTrace $state $history)
        (validationOk
          (inferenceEvaluation fixedState $status $answer
                               (length $trace) (inferenceTraceCost $trace) $trace))))

(= (inferenceEvaluateFixedState $state $request $budget $minimumConfidence)
   (if (< $budget 0)
       (validationError invalid-step-budget $budget)
       (if (inferenceValidMinimumConfidence $minimumConfidence)
           (inferenceEvaluateFixedStateFrom
             $state $request 0 $budget () () $minimumConfidence)
           (validationError invalid-minimum-confidence $minimumConfidence))))

(= (inferenceEvaluateFixedState $state $request $budget)
   (inferenceEvaluateFixedState
     $state $request $budget (INFERENCE_CONTROL_MIN_CONFIDENCE)))

(= (inferenceThresholdTransition $state $request $attempted $minimumConfidence)
   (let $batch (inferenceControlBuildBatch $request $attempted)
        (case (inferenceSelectForThreshold
                $state $batch (inferenceRequestQuery $request) $minimumConfidence)
          (((validationOk $selection)
            (case (inferenceControlExecute
                    (inferencePreparation $request $batch $selection))
              (((validationOk $execution)
                (inferenceControlUpdate $state $execution))
               ((validationError $code $details)
                (validationError $code $details)))))
           ((validationError $code $details)
            (validationError $code $details))))))

(= (inferenceEvaluateThresholdAwareFrom
      $state $request $steps $budget $history $attempted $minimumConfidence)
   (let $answer (plnAnswer
                  (inferenceRequestBeliefs $request)
                  (inferenceRequestQuery $request))
        (if (inferenceAnswerAccepted $answer $minimumConfidence)
            (inferenceThresholdResult answered $answer $history)
            (if (>= $steps $budget)
                (inferenceThresholdResult budgetExhausted $answer $history)
                (case (inferenceThresholdTransition
                        $state $request $attempted $minimumConfidence)
                  (((validationOk $outcome)
                    (inferenceEvaluateThresholdAwareFrom
                      (inferenceOutcomeState $outcome)
                      (inferenceOutcomeNextRequest $outcome)
                      (+ $steps 1) $budget
                      (append $history ($outcome))
                      (append $attempted
                        ((inferenceExecutionProposal
                            (inferenceOutcomeExecution $outcome))))
                      $minimumConfidence))
                   ((validationError empty-candidates $details)
                    (inferenceThresholdResult noCandidates $answer $history))
                   ((validationError $code $details)
                    (validationError $code $details))))))))

(= (inferenceThresholdResult $status $answer $history)
   (let $trace (inferenceOutcomeTrace $history)
        (validationOk
          (inferenceEvaluation thresholdAware $status $answer
                               (length $trace) (inferenceTraceCost $trace) $trace))))

(= (inferenceEvaluateThresholdAware $state $request $budget $minimumConfidence)
   (if (< $budget 0)
       (validationError invalid-step-budget $budget)
       (if (inferenceValidMinimumConfidence $minimumConfidence)
           (inferenceEvaluateThresholdAwareFrom
             $state $request 0 $budget () () $minimumConfidence)
           (validationError invalid-minimum-confidence $minimumConfidence))))

(= (inferenceEvaluateThresholdAware $state $request $budget)
   (inferenceEvaluateThresholdAware
     $state $request $budget (INFERENCE_CONTROL_MIN_CONFIDENCE)))

;; Minimum premise confidence; one rule application per step.
(= (inferenceConfidenceBest $best $remaining)
   (if (== $remaining ())
       $best
       (let* (($head (car-atom $remaining))
              ($next (if (> (inferencePremiseConfidence $head)
                            (inferencePremiseConfidence $best))
                         $head $best)))
             (inferenceConfidenceBest $next (cdr-atom $remaining)))))

(= (inferenceProposalRelevance $proposal $query $beliefs)
   (let $term (inferencePredictedTerm $proposal)
        (inferenceQueryRelevance
          $term $query (inferenceBestBridge $term $query $beliefs))))

;; Relevance only; ties preserve proposal order.
(= (inferenceRelevanceBest $query $beliefs $best $remaining)
   (if (== $remaining ())
       $best
       (let* (($head (car-atom $remaining))
              ($next (if (> (inferenceProposalRelevance $head $query $beliefs)
                            (inferenceProposalRelevance $best $query $beliefs))
                         $head $best)))
             (inferenceRelevanceBest $query $beliefs $next (cdr-atom $remaining)))))

(= (inferenceBaselineBest $policy $query $beliefs $proposals)
   (case $policy
     ((confidenceFirst
       (inferenceConfidenceBest (car-atom $proposals) (cdr-atom $proposals)))
      (queryRelevance
       (inferenceRelevanceBest
         $query $beliefs (car-atom $proposals) (cdr-atom $proposals))))))

(= (inferenceEvaluateBaselineFrom
      $policy $query $beliefs $remaining $attempted $trace $minimumConfidence)
   (let $answer (plnAnswer $beliefs $query)
        (if (== (inferenceAnswerAccepted $answer $minimumConfidence) False)
            (if (<= $remaining 0)
                (validationOk
                  (inferenceEvaluation $policy budgetExhausted $answer
                    (length $trace) (inferenceTraceCost $trace) $trace))
                (let $proposals
                     (inferenceControlFreshProposals (plnPropose $beliefs) $attempted)
                     (if (== $proposals ())
                         (validationOk
                           (inferenceEvaluation $policy noCandidates $answer
                             (length $trace) (inferenceTraceCost $trace) $trace))
                         (let* (($proposal (inferenceBaselineBest
                                             $policy $query $beliefs $proposals))
                                ($derivedItems (collapse (plnApplyOne $proposal))))
                               (if (== $derivedItems ())
                                   (validationError inference-application-failed $proposal)
                                   (let $derived (car-atom $derivedItems)
                                        (inferenceEvaluateBaselineFrom
                                          $policy $query
                                          (list_to_set (append $beliefs ($derived)))
                                          (- $remaining 1)
                                          (append $attempted ($proposal))
                                          (append $trace
                                            ((inferenceTraceStep $proposal $derived ())))
                                          $minimumConfidence)))))))
            (validationOk
              (inferenceEvaluation $policy answered $answer
                (length $trace) (inferenceTraceCost $trace) $trace)))))

(= (inferenceEvaluateBaseline $policy
      (inferenceRequest $query $beliefs $nextIndex) $budget $minimumConfidence)
   (if (< $budget 0)
       (validationError invalid-step-budget $budget)
       (if (inferenceValidMinimumConfidence $minimumConfidence)
           (inferenceEvaluateBaselineFrom
             $policy $query $beliefs $budget () () $minimumConfidence)
           (validationError invalid-minimum-confidence $minimumConfidence))))

(= (inferenceEvaluateConfidenceFrom
      $query $beliefs $remaining $attempted $trace $minimumConfidence)
   (inferenceEvaluateBaselineFrom
     confidenceFirst $query $beliefs $remaining $attempted $trace $minimumConfidence))

(= (inferenceEvaluateConfidence $request $budget $minimumConfidence)
   (inferenceEvaluateBaseline confidenceFirst $request $budget $minimumConfidence))

(= (inferenceEvaluateConfidence $request $budget)
   (inferenceEvaluateConfidence $request $budget
                                (INFERENCE_CONTROL_MIN_CONFIDENCE)))

(= (inferenceEvaluateRelevance $request $budget $minimumConfidence)
   (inferenceEvaluateBaseline queryRelevance $request $budget $minimumConfidence))

(= (inferenceEvaluateRelevance $request $budget)
   (inferenceEvaluateRelevance $request $budget
                               (INFERENCE_CONTROL_MIN_CONFIDENCE)))

(= (inferenceEvaluationSummary
      (inferenceEvaluation $policy $status $answer $applications $cost $trace))
   ((policy $policy)
    (status $status)
    (answer $answer)
    (ruleApplications $applications)
    (estimatedCost $cost)))
