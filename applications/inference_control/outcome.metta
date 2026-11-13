(: InferenceOutcome Type)
(: inferenceOutcome
   (-> InferenceExecution StimulusFeatures GoalChangeFeedback ActionCandidate
       MotivationState MotivationState InferenceOutcome))

(= (inferenceProposalRule (plnProposal $rule $first $second)) $rule)

(= (inferenceControlUpdate $state $execution)
   (case (inferenceExecutionDerived $execution)
     (((Sentence ($term (stv $strength $confidence)) $evidence)
       (let* (((inferencePreparation $request $batch $selection)
                (inferenceExecutionPreparation $execution))
              ((inferenceRequest $query $beliefs $nextIndex) $request)
              ($proposal (inferenceSelectedProposal $selection))
              ((plnProposal $rule $first $second) $proposal)
              ($bridge (inferenceBestBridge $term $query $beliefs))
              ($relevance (inferenceQueryRelevance $term $query $bridge))
              ($novelty (inferenceNovelty $term $beliefs))
              ($cost (inferenceEstimatedCost $proposal))
              ($risk (- 1.0 $confidence))
              ($features
                (inferenceAppraisalFeaturesFromSignals
                  $rule $relevance $novelty $confidence $cost $risk))
              ($observedCandidate
                (inferenceCandidateFromSignals
                  (candidateId (inferenceExecutionCandidate $execution))
                  $rule $term $relevance $novelty $confidence $cost $risk))
              ($feedback (eval (inferenceGoalFeedback $state $execution $features)))
              ($appraised
                (eval (applyCoreModulatorDeltas
                        (inferenceControlAppraisalProfile)
                        $state (inferenceCoreDeltas $state $features))))
              ($decision (inferenceControlDecision))
              ($deltaG
                (eval (profiledMagusProposeDeltaG
                        (magusDecisionGoalChangeFn $decision)
                        (magusDecisionProfile $decision)
                        $appraised $observedCandidate $feedback
                        (magusDecisionLambdaInd $decision)
                        (magusDecisionLambdaTrans $decision))))
              ($computation
                (eval (stateFromDeltaComputation
                        (bundleBimonad (inferenceControlBundle))
                        $appraised $deltaG $feedback))))
             (validationOk
               (inferenceOutcome
                 $execution $features $feedback $observedCandidate
                 $appraised (transitionComputationState $computation)))))
      ($_ (validationError invalid-derived-sentence
                          (inferenceExecutionDerived $execution))))))

(= (inferenceControlTransition $state $request $attempted)
   (case (inferenceControlStep $state $request $attempted)
     (((validationOk $execution)
       (inferenceControlUpdate $state $execution))
      ((validationError $code $details)
       (validationError $code $details)))))

(= (inferenceControlTransition $state $request)
   (inferenceControlTransition $state $request ()))

(= (inferenceOutcomeField
      (inferenceOutcome $execution $features $feedback $candidate $appraised $state) $field)
   (case $field
     ((execution $execution)
      (features $features)
      (feedback $feedback)
      (candidate $candidate)
      (appraised $appraised)
      (state $state)
      ($_ (empty)))))

(= (inferenceOutcomeExecution $record) (inferenceOutcomeField $record execution))
(= (inferenceOutcomeFeatures $record) (inferenceOutcomeField $record features))
(= (inferenceOutcomeFeedback $record) (inferenceOutcomeField $record feedback))
(= (inferenceOutcomeCandidate $record) (inferenceOutcomeField $record candidate))
(= (inferenceOutcomeAppraisedState $record) (inferenceOutcomeField $record appraised))
(= (inferenceOutcomeState $record) (inferenceOutcomeField $record state))
(= (inferenceOutcomeNextRequest $outcome)
   (inferenceExecutionNextRequest (inferenceOutcomeExecution $outcome)))
