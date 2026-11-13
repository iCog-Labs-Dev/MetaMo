(: InferenceRun Type)
(: inferenceRun
   (-> Symbol Number InferenceRequest Expression MotivationState Expression
       InferenceRun))

(= (inferenceControlRunFrom $state $request $steps $maxSteps $history $attempted)
   (let $answer (plnAnswer
                  (inferenceRequestBeliefs $request)
                  (inferenceRequestQuery $request))
        (if (== $answer ())
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
                            (inferenceOutcomeExecution $outcome))))))
                   ((validationError empty-candidates $details)
                    (validationOk
                      (inferenceRun noCandidates $steps $request $answer
                                    $state $history)))
                   ((validationError $code $details)
                    (validationError $code $details)))))
            (validationOk
              (inferenceRun answered $steps $request $answer $state $history)))))

(= (inferenceControlRun $state $request $maxSteps)
   (if (< $maxSteps 0)
       (validationError invalid-step-budget $maxSteps)
       (inferenceControlRunFrom $state $request 0 $maxSteps () ())))

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
