(: InferenceProposalBinding Type)
(: inferenceProposalBinding (-> Symbol InferenceAnnotatedProposal InferenceProposalBinding))

(: InferenceCandidateBatch Type)
(: inferenceCandidateBatch (-> Expression Expression Number InferenceCandidateBatch))

(= (inferenceLowInformationGain $rule $relevance $novelty)
   (case $rule
     ((revision 0.0)
      ($_ (- 1.0 (* $relevance $novelty))))))

(= (inferenceCandidateFromAnnotation
      $id
      (inferenceAnnotatedProposal
        (plnProposal $rule $first $second) $term $context $features))
   (let* (($relevance (featureMapGet $features query_relevance 0.0))
          ($novelty (featureMapGet $features novelty 0.0))
          ($confidence (featureMapGet $features premise_confidence 0.0))
          ($cost (featureMapGet $features estimated_cost 1.0))
          ($risk (featureMapGet $features estimated_risk 1.0)))
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
            (source inference_control)))))

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

(= (inferenceBatchCandidates (inferenceCandidateBatch $candidates $bindings $nextIndex))
   $candidates)
(= (inferenceBatchBindings (inferenceCandidateBatch $candidates $bindings $nextIndex))
   $bindings)
(= (inferenceBatchNextIndex (inferenceCandidateBatch $candidates $bindings $nextIndex))
   $nextIndex)

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
