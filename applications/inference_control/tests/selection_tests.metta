!(import! &self ../../../core/validation)
!(import! &self ../../../core/schema)
!(import! &self ../../../core/features)
!(import! &self ../../../core/state)
!(import! &self ../../../core/helper)
!(import! &self "../../../core/helpers.py")
!(import! &self ../../common/openpsi_conventions)
!(import! &self ../../../openpsi/profile)
!(import! &self ../../../openpsi/appraisal)
!(import! &self ../../../magus/profile)
!(import! &self ../../../magus/goal_change)
!(import! &self ../../../magus/decision)
!(import! &self ../schema)
!(import! &self ../state)
!(import! &self ../pln)
!(import! &self ../stimulus)
!(import! &self ../planning)
!(import! &self ../appraisal_profile)
!(import! &self ../decision_profile)
!(import! &self ../selection)

(= (selectionTestPremiseOne)
   (Sentence ((Inheritance A B) (stv 0.8 0.9)) (1)))
(= (selectionTestPremiseTwo)
   (Sentence ((Inheritance B D) (stv 0.7 0.9)) (2)))
(= (selectionTestOtherOne)
   (Sentence ((Inheritance X Y) (stv 0.8 0.9)) (3)))
(= (selectionTestOtherTwo)
   (Sentence ((Inheritance Y Z) (stv 0.7 0.9)) (4)))
(= (selectionTestWeakOne)
   (Sentence ((Inheritance A C) (stv 0.8 0.2)) (5)))
(= (selectionTestWeakTwo)
   (Sentence ((Inheritance C D) (stv 0.7 0.2)) (6)))

(= (selectionTestRelevant)
   (inferenceAnnotatedProposal
     (plnProposal deduction (selectionTestPremiseOne) (selectionTestPremiseTwo))
     (Inheritance A D)
     ((selectionTestPremiseOne) (selectionTestPremiseTwo))
     (stimulusFeatures
       ((query_relevance 1.0) (novelty 1.0)
        (premise_confidence 0.9) (estimated_cost 0.5)
        (estimated_risk 0.1)))))

(= (selectionTestIrrelevant)
   (inferenceAnnotatedProposal
     (plnProposal deduction (selectionTestOtherOne) (selectionTestOtherTwo))
     (Inheritance X Z)
     ((selectionTestOtherOne) (selectionTestOtherTwo))
     (stimulusFeatures
       ((query_relevance 0.0) (novelty 1.0)
        (premise_confidence 0.9) (estimated_cost 0.5)
        (estimated_risk 0.1)))))

(= (selectionTestRisky)
   (inferenceAnnotatedProposal
     (plnProposal deduction (selectionTestWeakOne) (selectionTestWeakTwo))
     (Inheritance A D)
     ((selectionTestWeakOne) (selectionTestWeakTwo))
     (stimulusFeatures
       ((query_relevance 1.0) (novelty 1.0)
        (premise_confidence 0.2) (estimated_cost 0.5)
        (estimated_risk 0.8)))))

(= (selectionTestCheap)
   (inferenceAnnotatedProposal
     (plnProposal deduction (selectionTestPremiseOne) (selectionTestPremiseTwo))
     (Inheritance A D)
     ((selectionTestPremiseOne) (selectionTestPremiseTwo))
     (stimulusFeatures
       ((query_relevance 1.0) (novelty 1.0)
        (premise_confidence 0.9) (estimated_cost 0.1)
        (estimated_risk 0.1)))))

(= (selectionTestExpensive)
   (inferenceAnnotatedProposal
     (plnProposal deduction (selectionTestPremiseOne) (selectionTestPremiseTwo))
     (Inheritance A D)
     ((selectionTestPremiseOne) (selectionTestPremiseTwo))
     (stimulusFeatures
       ((query_relevance 1.0) (novelty 1.0)
        (premise_confidence 0.9) (estimated_cost 0.9)
        (estimated_risk 0.1)))))

(= (selectionTestBatch)
   (inferenceBuildCandidateBatch
     ((selectionTestIrrelevant) (selectionTestRisky) (selectionTestRelevant)) 0))
(= (selectionTestIrrelevantCandidate)
   (index-atom (inferenceBatchCandidates (selectionTestBatch)) 0))
(= (selectionTestRiskyCandidate)
   (index-atom (inferenceBatchCandidates (selectionTestBatch)) 1))
(= (selectionTestRelevantCandidate)
   (index-atom (inferenceBatchCandidates (selectionTestBatch)) 2))
(= (selectionTestGeneratedBatch)
   (let* (($beliefs
            ((selectionTestPremiseOne) (selectionTestPremiseTwo)
             (selectionTestOtherOne) (selectionTestOtherTwo)))
          ($annotations
            (inferenceAnnotateProposals
              (plnPropose $beliefs) (Inheritance A D) $beliefs)))
         (inferenceBuildCandidateBatch $annotations 30)))

!(test (appraisalProfileName (inferenceControlAppraisalProfile))
       inference_control_openpsi)
!(test (decisionProfileName (inferenceControlDecisionProfile))
       inference_control_magus_additive)
!(test (validationIsOk
         (appraisalProfileValidate
           (inferenceControlAppraisalProfile) (inferenceControlSchema))) True)
!(test (decisionProfileSchema (inferenceControlDecisionProfile))
       (inferenceControlSchema))
!(test (featureMapGet
         (inferenceAppraisalFeatures
           (inferenceControlDefaultState) (selectionTestRelevant))
         conduciveness 0.0) 0.9)
!(test (featureMapGet
         (inferenceAppraisalFeatures
           (inferenceControlDefaultState) (selectionTestRelevant))
         effort 0.0) 0.5)
!(test (featureMapGet
         (inferenceGoalFeedback
           (inferenceControlDefaultState) (selectionTestRisky)
           (inferenceAppraisalFeatures
             (inferenceControlDefaultState) (selectionTestRisky)))
         unreliable_inference_target 0.0) 0.8)
!(test (featureMapGet
         (openPsiGoalChangeFeedbackWithProfile
           (inferenceControlAppraisalProfile)
           (inferenceControlDefaultState) (selectionTestIrrelevant))
         low_information_gain_target 0.0) 1.0)
!(test (== (stateSchema (inferenceControlDefaultState))
           (inferenceControlSchema)) True)
!(test (validationIsOk (validateActionCandidate (selectionTestRelevantCandidate))) True)
!(test (validationIsOk
         (inferenceAnnotationForId
           (selectionTestBatch) (candidateId (selectionTestRelevantCandidate)))) True)
!(test (validationIsOk
         (inferenceAssessWithAnnotation
           (inferenceControlDefaultState)
           (selectionTestRelevantCandidate)
           (selectionTestRelevant))) True)
!(test (validationIsOk
         (inferenceAssessCandidate
           (inferenceControlDefaultState) (selectionTestBatch)
           (selectionTestRelevantCandidate))) True)
!(test (validationIsOk
         (inferenceAssessBatch
           (inferenceControlDefaultState) (selectionTestBatch))) True)
!(test (length
         (validationValue
           (inferenceAssessBatch
             (inferenceControlDefaultState) (selectionTestBatch)))) 3)
!(test (>
         (inferenceAssessmentScore
           (index-atom
             (validationValue
               (inferenceAssessBatch
                 (inferenceControlDefaultState) (selectionTestBatch))) 2))
         (inferenceAssessmentScore
           (index-atom
             (validationValue
               (inferenceAssessBatch
                 (inferenceControlDefaultState) (selectionTestBatch))) 0))) True)
!(test (>
         (inferenceAssessmentScore
           (index-atom
             (validationValue
               (inferenceAssessBatch
                 (inferenceControlDefaultState) (selectionTestBatch))) 2))
         (inferenceAssessmentScore
           (index-atom
             (validationValue
               (inferenceAssessBatch
                 (inferenceControlDefaultState) (selectionTestBatch))) 1))) True)
!(test (candidateId
         (inferenceSelectedCandidate
           (validationValue
             (inferenceSelect
               (inferenceControlDefaultState) (selectionTestBatch)))))
       inference_2)
!(test (inferenceSelectedProposal
         (validationValue
           (inferenceSelect
             (inferenceControlDefaultState) (selectionTestBatch))))
       (plnProposal deduction
         (selectionTestPremiseOne) (selectionTestPremiseTwo)))
!(test (inferenceSelect
         (inferenceControlDefaultState)
         (inferenceBuildCandidateBatch () 4))
       (validationError empty-candidates inference_control))
!(test (inferenceAssessCandidate
         (inferenceControlDefaultState)
         (inferenceCandidateBatch ((selectionTestRelevantCandidate)) () 3)
         (selectionTestRelevantCandidate))
       (validationError candidate-id-not-found inference_2))
!(test (candidateId
         (inferenceSelectedCandidate
           (validationValue
             (inferenceSelect
               (inferenceControlDefaultState)
               (inferenceBuildCandidateBatch
                 ((selectionTestExpensive) (selectionTestCheap)) 10)))))
       inference_11)
!(test (candidateId
         (inferenceSelectedCandidate
           (validationValue
             (inferenceSelect
               (inferenceControlDefaultState)
               (inferenceBuildCandidateBatch
                 ((selectionTestRelevant) (selectionTestRelevant)) 20)))))
       inference_20)
!(test (inferenceAssessCandidate
         (inferenceControlDefaultState) (selectionTestBatch)
         (actionCandidate invalid other
           (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0)
           (0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0) ()))
       (validationError candidate-schema-mismatch other))
!(test (inferenceSelectedProposal
         (validationValue
           (inferenceSelect
             (inferenceControlDefaultState)
             (selectionTestGeneratedBatch))))
       (plnProposal deduction
         (selectionTestPremiseOne) (selectionTestPremiseTwo)))
!(test (length
         (inferenceSelectionAssessments
           (validationValue
             (inferenceSelect
               (inferenceControlDefaultState) (selectionTestBatch))))) 3)
!(test (>
         (stateModulator
           (inferenceSelectedState
             (validationValue
               (inferenceSelect
                 (inferenceControlDefaultState) (selectionTestBatch))))
           approach)
         (stateModulator (inferenceControlDefaultState) approach)) True)
!(test (>
         (stateModulator
           (inferenceAssessmentState
             (index-atom
               (validationValue
                 (inferenceAssessBatch
                   (inferenceControlDefaultState) (selectionTestBatch))) 2))
           approach)
         (stateModulator
           (inferenceAssessmentState
             (index-atom
               (validationValue
                 (inferenceAssessBatch
                   (inferenceControlDefaultState) (selectionTestBatch))) 0))
           approach)) True)
