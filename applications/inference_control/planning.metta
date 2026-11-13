(: InferenceProposalBinding Type)
(: inferenceProposalBinding (-> Symbol InferenceAnnotatedProposal InferenceProposalBinding))

(: InferenceCandidateBatch Type)
(: inferenceCandidateBatch (-> Expression Expression Number InferenceCandidateBatch))

(= (inferenceLowInformationGain $rule $relevance $novelty)
   (case $rule
     ((revision 0.0)
      ($_ (- 1.0 (* $relevance $novelty))))))

(= (inferenceCandidateFromSignals
      $id $rule $term $relevance $novelty $confidence $cost $risk)
   (actionCandidate
     $id
     (inferenceControlSchema)
     (0.0 0.0
      $relevance $confidence $novelty (- 1.0 $cost)
      $risk (inferenceLowInformationGain $rule $relevance $novelty))
     (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0)
     ((risk $risk)
      (estimated_cost $cost)
      (rule $rule)
      (predicted_term $term)
      (source inference_control))))

(= (inferenceCandidateFromAnnotation
      $id
      (inferenceAnnotatedProposal
        (plnProposal $rule $first $second) $term $context $features))
   (inferenceCandidateFromSignals
     $id $rule $term
     (featureMapGet $features query_relevance 0.0)
     (featureMapGet $features novelty 0.0)
     (featureMapGet $features premise_confidence 0.0)
     (featureMapGet $features estimated_cost 1.0)
     (featureMapGet $features estimated_risk 1.0)))

(= (inferenceBuildCandidateBatch $annotations $startIndex)
   (inferenceBuildCandidateBatchFrom $annotations $startIndex () ()))

(= (inferenceBuildCandidateBatchFrom $remaining $nextIndex $candidates $bindings)
   (if (== $remaining ())
       (inferenceCandidateBatch $candidates $bindings $nextIndex)
       (let* (($annotation (car-atom $remaining))
              ($rest (cdr-atom $remaining))
              ($id (atom_concat inference_ $nextIndex))
              ($candidate (inferenceCandidateFromAnnotation $id $annotation))
              ($binding (inferenceProposalBinding $id $annotation)))
             (inferenceBuildCandidateBatchFrom
               $rest (+ $nextIndex 1)
               (append $candidates ($candidate))
               (append $bindings ($binding))))))

(= (inferenceBatchField
      (inferenceCandidateBatch $candidates $bindings $nextIndex) $field)
   (case $field
     ((candidates $candidates)
      (bindings $bindings)
      (nextIndex $nextIndex)
      ($_ (empty)))))

(= (inferenceBatchCandidates $record) (inferenceBatchField $record candidates))
(= (inferenceBatchBindings $record) (inferenceBatchField $record bindings))
(= (inferenceBatchNextIndex $record) (inferenceBatchField $record nextIndex))

(= (inferenceAnnotationForId $batch $id)
   (inferenceFindBinding $id (inferenceBatchBindings $batch)))

(= (inferenceFindBinding $id $bindings)
   (if (== $bindings ())
       (validationError candidate-id-not-found $id)
       (let* (($head (car-atom $bindings))
              ($tail (cdr-atom $bindings)))
             (case $head
               (((inferenceProposalBinding $boundId $annotation)
                 (if (== $id $boundId)
                     (validationOk $annotation)
                     (inferenceFindBinding $id $tail))))))))

(= (inferenceProposalForId $batch $id)
   (case (inferenceAnnotationForId $batch $id)
     (((validationOk $annotation)
       (validationOk (inferenceAnnotationProposal $annotation)))
      (($error $code $details) ($error $code $details)))))
