(: InferenceCandidateAssessment Type)
(: inferenceCandidateAssessment
   (-> ActionCandidate InferenceAnnotatedProposal MotivationState Number
       InferenceCandidateAssessment))

(: InferenceSelection Type)
(: inferenceSelection (-> InferenceCandidateAssessment Expression InferenceSelection))

(= (inferenceAssessmentField
      (inferenceCandidateAssessment $candidate $annotation $state $score) $field)
   (case $field
     ((candidate $candidate)
      (annotation $annotation)
      (state $state)
      (score $score)
      ($_ (empty)))))

(= (inferenceAssessmentCandidate $record) (inferenceAssessmentField $record candidate))
(= (inferenceAssessmentAnnotation $record) (inferenceAssessmentField $record annotation))
(= (inferenceAssessmentState $record) (inferenceAssessmentField $record state))
(= (inferenceAssessmentScore $record) (inferenceAssessmentField $record score))

(= (inferenceAssessWithAnnotation $state $candidate $annotation)
   (let* (($appraised
            (eval (openPsiAppraiseWithProfile
                    (inferenceControlAppraisalProfile) $state $annotation)))
          ($score
            (eval (magusScore
                    (inferenceControlDecision) $appraised $candidate))))
         (validationOk
           (inferenceCandidateAssessment
             $candidate $annotation $appraised $score))))

(= (inferenceAssessCandidate $state $batch $candidate)
   (if (== (stateSchema $state) (inferenceControlSchema))
       (if (== (candidateSchema $candidate) (inferenceControlSchema))
           (let $candidateValidation (validateActionCandidate $candidate)
                (case $candidateValidation
                  (((validationOk $validated)
                    (case (inferenceAnnotationForId $batch (candidateId $candidate))
                      (((validationOk $annotation)
                        (inferenceAssessWithAnnotation $state $candidate $annotation))
                       ((validationError $code $details)
                        (validationError $code $details)))))
                   ((validationError $code $details)
                    (validationError $code $details)))))
           (validationError candidate-schema-mismatch (candidateSchema $candidate)))
       (validationError inference-schema-mismatch (stateSchema $state))))

(= (inferenceAssessBatchFrom $state $batch $remaining $assessments)
   (if (== $remaining ())
       (validationOk $assessments)
       (let $result
            (inferenceAssessCandidate $state $batch (car-atom $remaining))
            (case $result
              (((validationOk $assessment)
                (inferenceAssessBatchFrom
                  $state $batch (cdr-atom $remaining)
                  (append $assessments ($assessment))))
               ((validationError $code $details)
                (validationError $code $details)))))))

(= (inferenceAssessBatch $state $batch)
   (inferenceAssessBatchFrom
     $state $batch (inferenceBatchCandidates $batch) ()))

(= (inferenceBestAssessmentFrom $best $remaining)
   (if (== $remaining ())
       $best
       (let* (($current (car-atom $remaining))
              ($rest (cdr-atom $remaining)))
             (if (> (inferenceAssessmentScore $current)
                    (inferenceAssessmentScore $best))
                 (inferenceBestAssessmentFrom $current $rest)
                 (inferenceBestAssessmentFrom $best $rest)))))

(= (inferenceSelect $state $batch)
   (case (inferenceAssessBatch $state $batch)
     (((validationOk $assessments)
       (if (== $assessments ())
           (validationError empty-candidates inference_control)
           (validationOk
             (inferenceSelection
               (inferenceBestAssessmentFrom
                 (car-atom $assessments) (cdr-atom $assessments))
               $assessments))))
      ((validationError $code $details)
       (validationError $code $details)))))

(= (inferenceSelectedAssessment (inferenceSelection $best $assessments)) $best)
(= (inferenceSelectionAssessments (inferenceSelection $best $assessments))
   $assessments)
(= (inferenceSelectedCandidate $selection)
   (inferenceAssessmentCandidate (inferenceSelectedAssessment $selection)))
(= (inferenceSelectedProposal $selection)
   (inferenceAnnotationProposal
     (inferenceAssessmentAnnotation (inferenceSelectedAssessment $selection))))
(= (inferenceSelectedState $selection)
   (inferenceAssessmentState (inferenceSelectedAssessment $selection)))
(= (inferenceSelectedScore $selection)
   (inferenceAssessmentScore (inferenceSelectedAssessment $selection)))
