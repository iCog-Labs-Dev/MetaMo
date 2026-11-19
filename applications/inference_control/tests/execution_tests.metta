!(import! &self ../../../core/validation)
!(import! &self ../../../core/schema)
!(import! &self ../../../core/features)
!(import! &self ../../../core/state)
!(import! &self ../../../core/helper)
!(import! &self "../../../core/helpers.py")
!(import! &self ../../../core/runtime)
!(import! &self ../../common/openpsi_conventions)
!(import! &self ../../../openpsi/profile)
!(import! &self ../../../openpsi/appraisal)
!(import! &self ../../../magus/profile)
!(import! &self ../../../magus/goal_change)
!(import! &self ../../../magus/decision)
!(import! &self ../../../dynamics/stability)
!(import! &self ../../../dynamics/coherence)
!(import! &self ../../../category/merge)
!(import! &self ../schema)
!(import! &self ../state)
!(import! &self ../pln)
!(import! &self ../stimulus)
!(import! &self ../planning)
!(import! &self ../appraisal_profile)
!(import! &self ../decision_profile)
!(import! &self ../selection)
!(import! &self ../bundle)
!(import! &self ../execution)

(= (executionTestFact)
   (Sentence (A (stv 0.8 0.9)) (1)))
(= (executionTestRule)
   (Sentence ((Implication A B) (stv 0.7 0.8)) (2)))
(= (executionTestRequest)
   (inferenceRequest B ((executionTestFact) (executionTestRule)) 7))
(= (executionTestResult)
   (validationValue
     (inferenceControlStep
       (inferenceControlDefaultState) (executionTestRequest))))
(= (executionTestDerived)
   (Sentence (B (stv 0.564 0.7200000000000001)) (1 2)))
(= (executionTestInvalidProposal)
   (plnProposal modus-ponens
     (executionTestFact)
     (Sentence ((Implication A B) (stv 0.7 0.8)) (1))))
(= (executionTestInvalidPrepared)
   (inferencePreparation
     (executionTestRequest)
     (inferencePreparationBatch
       (inferenceExecutionPreparation (executionTestResult)))
     (inferenceSelection
       (inferenceCandidateAssessment
         (inferenceExecutionCandidate (executionTestResult))
         (inferenceAnnotatedProposal
           (executionTestInvalidProposal) B () (stimulusFeatures ()))
         (inferenceControlDefaultState) 0.0)
       ())))

!(test (validationIsOk
         (inferenceControlStep
           (inferenceControlDefaultState) (executionTestRequest))) True)
!(test (candidateId (inferenceExecutionCandidate (executionTestResult)))
       inference_7)
!(test (inferenceExecutionProposal (executionTestResult))
       (plnProposal modus-ponens (executionTestFact) (executionTestRule)))
!(test (inferenceExecutionDerived (executionTestResult))
       (executionTestDerived))
!(test (is-member (executionTestDerived)
                  (inferenceExecutionBeliefs (executionTestResult))) True)
!(test (length (inferenceExecutionBeliefs (executionTestResult))) 3)
!(test (inferenceRequestQuery
         (inferenceExecutionNextRequest (executionTestResult))) B)
!(test (inferenceRequestBeliefs
         (inferenceExecutionNextRequest (executionTestResult)))
       (inferenceExecutionBeliefs (executionTestResult)))
!(test (inferenceRequestNextIndex
         (inferenceExecutionNextRequest (executionTestResult))) 8)
!(test (> (stateModulator
            (inferenceExecutionAppraisedState (executionTestResult)) approach)
          (stateModulator (inferenceControlDefaultState) approach)) True)
!(test (inferenceControlStep
         (inferenceControlDefaultState)
         (inferenceRequest B () 0))
       (validationError empty-candidates inference_control))
!(test (inferenceControlExecute (executionTestInvalidPrepared))
       (validationError inference-application-failed
                        (executionTestInvalidProposal)))
