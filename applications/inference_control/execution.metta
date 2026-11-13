(: InferenceExecution Type)
(: inferenceExecution
   (-> InferencePreparation Expression Expression InferenceExecution))

(= (inferenceControlExecute $prepared)
   (let* (($proposal (inferencePreparationProposal $prepared))
          ($derivedItems (collapse (plnApplyOne $proposal))))
         (if (== $derivedItems ())
             (validationError inference-application-failed $proposal)
             (let* (($derived (car-atom $derivedItems))
                    ($beliefs (inferenceRequestBeliefs
                                (inferencePreparationRequest $prepared)))
                    ($nextBeliefs (list_to_set (append $beliefs ($derived)))))
                   (validationOk
                     (inferenceExecution $prepared $derived $nextBeliefs))))))

(= (inferenceControlStep $state $request $attempted)
   (case (inferenceControlPrepare $state $request $attempted)
     (((validationOk $prepared)
       (inferenceControlExecute $prepared))
      ((validationError $code $details)
       (validationError $code $details)))))

(= (inferenceControlStep $state $request)
   (inferenceControlStep $state $request ()))

(= (inferenceExecutionField
      (inferenceExecution $prepared $derived $beliefs) $field)
   (case $field
     ((prepared $prepared)
      (derived $derived)
      (beliefs $beliefs)
      ($_ (empty)))))

(= (inferenceExecutionPreparation $record) (inferenceExecutionField $record prepared))
(= (inferenceExecutionDerived $record) (inferenceExecutionField $record derived))
(= (inferenceExecutionBeliefs $record) (inferenceExecutionField $record beliefs))
(= (inferenceExecutionCandidate $execution)
   (inferencePreparationCandidate (inferenceExecutionPreparation $execution)))
(= (inferenceExecutionProposal $execution)
   (inferencePreparationProposal (inferenceExecutionPreparation $execution)))
(= (inferenceExecutionScore $execution)
   (inferencePreparationScore (inferenceExecutionPreparation $execution)))
(= (inferenceExecutionAppraisedState $execution)
   (inferencePreparationAppraisedState
     (inferenceExecutionPreparation $execution)))
(= (inferenceExecutionNextRequest
      (inferenceExecution
        (inferencePreparation
          (inferenceRequest $query $previousBeliefs $previousIndex) $batch $selection)
        $derived $beliefs))
   (inferenceRequest $query $beliefs (inferenceBatchNextIndex $batch)))
