(: InferenceRequest Type)
(: inferenceRequest (-> Expression Expression Number InferenceRequest))

(: InferencePreparation Type)
(: inferencePreparation
   (-> InferenceRequest InferenceCandidateBatch InferenceSelection
       InferencePreparation))

(= (inferenceRequestField
      (inferenceRequest $query $beliefs $nextIndex) $field)
   (case $field
     ((query $query)
      (beliefs $beliefs)
      (nextIndex $nextIndex)
      ($_ (empty)))))

(= (inferenceRequestQuery $record) (inferenceRequestField $record query))
(= (inferenceRequestBeliefs $record) (inferenceRequestField $record beliefs))
(= (inferenceRequestNextIndex $record) (inferenceRequestField $record nextIndex))

(= (inferenceControlFreshProposals $proposals $attempted)
   (if (== $proposals ())
       ()
       (let* (($head (car-atom $proposals))
              ($tail (cdr-atom $proposals))
              ($freshTail (inferenceControlFreshProposals $tail $attempted)))
             (if (is-member $head $attempted)
                 $freshTail
                 (cons-atom $head $freshTail)))))

(= (inferenceControlBuildBatch
      (inferenceRequest $query $beliefs $nextIndex) $attempted)
   (inferenceBuildCandidateBatch
     (inferenceAnnotateProposals
       (inferenceControlFreshProposals (plnPropose $beliefs) $attempted)
       $query $beliefs)
     $nextIndex))

(= (inferenceControlBuildBatch $request)
   (inferenceControlBuildBatch $request ()))

(= (inferenceControlRawStimulusAdapterFn $request) $request)
(= (inferenceControlCandidateBuilderFn $state $request)
   (inferenceBatchCandidates (inferenceControlBuildBatch $request)))

(= (inferenceControlBundle)
   (applicationBundle
     inference_control
     (inferenceControlSchema)
     (inferenceControlAppraisalProfile)
     (inferenceControlDecisionProfile)
     defaultGoalChangeDeltaG
     (makeDefaultStabilityPolicy)
     (makeDefaultCoherencePolicy)
     (makeDefaultParallelMergePolicy)
     inferenceControlRawStimulusAdapterFn
     inferenceControlCandidateBuilderFn
     ()))

(= (inferenceControlValidatedBundle)
   (validateApplicationBundle (inferenceControlBundle)))

;; Appraise each proposal through inferenceSelect.
(= (inferenceControlPrepare $state $request $attempted)
   (let $batch (inferenceControlBuildBatch $request $attempted)
        (case (inferenceSelect $state $batch)
          (((validationOk $selection)
            (validationOk (inferencePreparation $request $batch $selection)))
           ((validationError $code $details)
            (validationError $code $details))))))

(= (inferenceControlPrepare $state $request)
   (inferenceControlPrepare $state $request ()))

(= (inferencePreparationField
      (inferencePreparation $request $batch $selection) $field)
   (case $field
     ((request $request)
      (batch $batch)
      (selection $selection)
      ($_ (empty)))))

(= (inferencePreparationRequest $record) (inferencePreparationField $record request))
(= (inferencePreparationBatch $record) (inferencePreparationField $record batch))
(= (inferencePreparationSelection $record) (inferencePreparationField $record selection))
(= (inferencePreparationCandidate $prepared)
   (inferenceSelectedCandidate (inferencePreparationSelection $prepared)))
(= (inferencePreparationProposal $prepared)
   (inferenceSelectedProposal (inferencePreparationSelection $prepared)))
(= (inferencePreparationScore $prepared)
   (inferenceSelectedScore (inferencePreparationSelection $prepared)))
(= (inferencePreparationAppraisedState $prepared)
   (inferenceSelectedState (inferencePreparationSelection $prepared)))
(= (inferencePreparationNextIndex $prepared)
   (inferenceBatchNextIndex (inferencePreparationBatch $prepared)))
