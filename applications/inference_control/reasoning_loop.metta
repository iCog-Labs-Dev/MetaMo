(: InferenceRun Type)
(: inferenceRun
   (-> Symbol Number InferenceRequest Expression MotivationState Expression
       InferenceRun))

(= (INFERENCE_CONTROL_MIN_CONFIDENCE) 0.5)

(= (inferenceAnswerAccepted () $minimumConfidence) False)
(= (inferenceAnswerAccepted ((stv $strength $confidence) $evidence) $minimumConfidence)
   (>= $confidence $minimumConfidence))

(= (inferenceValidMinimumConfidence $minimumConfidence)
   (and (>= $minimumConfidence 0.0) (<= $minimumConfidence 1.0)))

(= (inferenceControlRunFrom
      $state $request $steps $maxSteps $history $attempted $minimumConfidence)
   (let $answer (plnAnswer
                  (inferenceRequestBeliefs $request)
                  (inferenceRequestQuery $request))
        (if (inferenceAnswerAccepted $answer $minimumConfidence)
            (validationOk
              (inferenceRun answered $steps $request $answer $state $history))
            (if (>= $steps $maxSteps)
                (validationOk
                  (inferenceRun budgetExhausted $steps $request $answer
                                $state $history))
                (case (inferenceControlTransition $state $request $attempted)
                  (((validationOk $outcome)
                    (inferenceControlRunFrom
                      (inferenceOutcomeState $outcome)
                      (inferenceOutcomeNextRequest $outcome)
                      (+ $steps 1) $maxSteps
                      (append $history ($outcome))
                      (append $attempted
                        ((inferenceExecutionProposal
                            (inferenceOutcomeExecution $outcome))))
                      $minimumConfidence))
                   ((validationError empty-candidates $details)
                    (validationOk
                      (inferenceRun noCandidates $steps $request $answer
                                    $state $history)))
                   ((validationError $code $details)
                    (validationError $code $details))))))))

(= (inferenceControlRun $state $request $maxSteps $minimumConfidence)
   (if (< $maxSteps 0)
       (validationError invalid-step-budget $maxSteps)
       (if (inferenceValidMinimumConfidence $minimumConfidence)
           (inferenceControlRunFrom
             $state $request 0 $maxSteps () () $minimumConfidence)
           (validationError invalid-minimum-confidence $minimumConfidence))))

(= (inferenceControlRun $state $request $maxSteps)
   (inferenceControlRun $state $request $maxSteps
                        (INFERENCE_CONTROL_MIN_CONFIDENCE)))

(= (inferenceControlRun $state $request)
   (inferenceControlRun $state $request (PLN_MAX_STEPS)))

(= (inferenceRunField
      (inferenceRun $status $steps $request $answer $state $history) $field)
   (case $field
     ((status $status)
      (steps $steps)
      (request $request)
      (answer $answer)
      (state $state)
      (history $history)
      ($_ (empty)))))

(= (inferenceRunStatus $record) (inferenceRunField $record status))
(= (inferenceRunSteps $record) (inferenceRunField $record steps))
(= (inferenceRunRequest $record) (inferenceRunField $record request))
(= (inferenceRunAnswer $record) (inferenceRunField $record answer))
(= (inferenceRunState $record) (inferenceRunField $record state))
(= (inferenceRunHistory $record) (inferenceRunField $record history))
