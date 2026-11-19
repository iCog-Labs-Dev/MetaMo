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
!(import! &self ../../../magus/correlation)
!(import! &self ../../../magus/profile)
!(import! &self ../../../magus/goal_change)
!(import! &self ../../../magus/decision)
!(import! &self ../../../dynamics/stability)
!(import! &self ../../../dynamics/coherence)
!(import! &self ../../../category/diagnostics)
!(import! &self ../../../category/functors)
!(import! &self ../../../category/bimonad)
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
!(import! &self ../outcome)

(= (outcomeTestRequest)
   (inferenceRequest
     B
     ((Sentence (A (stv 0.8 0.9)) (1))
      (Sentence ((Implication A B) (stv 0.7 0.8)) (2)))
     7))
(= (outcomeTestResult)
   (validationValue
     (inferenceControlTransition
       (inferenceControlDefaultState) (outcomeTestRequest))))

!(test (validationIsOk
         (inferenceControlTransition
           (inferenceControlDefaultState) (outcomeTestRequest))) True)
!(test (inferenceExecutionDerived (inferenceOutcomeExecution (outcomeTestResult)))
       (Sentence (B (stv 0.564 0.7200000000000001)) (1 2)))
!(test (and (> (featureMapNumericUnit
                  (inferenceOutcomeFeatures (outcomeTestResult)) risk 0.0) 0.27)
            (< (featureMapNumericUnit
                  (inferenceOutcomeFeatures (outcomeTestResult)) risk 0.0) 0.29))
       True)
!(test (candidateGoalCorrelation
         (inferenceOutcomeCandidate (outcomeTestResult)) evidence_quality)
       0.7200000000000001)
!(test (and (> (featureMapNumericUnit
                  (inferenceOutcomeFeedback (outcomeTestResult))
                  unreliable_inference_target 0.0) 0.27)
            (< (featureMapNumericUnit
                  (inferenceOutcomeFeedback (outcomeTestResult))
                  unreliable_inference_target 0.0) 0.29))
       True)
!(test (< (stateModulator
            (inferenceOutcomeAppraisedState (outcomeTestResult)) approach)
          (stateModulator
            (inferenceExecutionAppraisedState
              (inferenceOutcomeExecution (outcomeTestResult))) approach))
       True)
!(test (stateSchema (inferenceOutcomeState (outcomeTestResult)))
       (inferenceControlSchema))
!(test (< (stateGoal (inferenceOutcomeState (outcomeTestResult))
                    unreliable_inference)
          (stateGoal (inferenceControlDefaultState) unreliable_inference))
       True)
!(test (inferenceRequestNextIndex
         (inferenceOutcomeNextRequest (outcomeTestResult))) 8)
!(test (inferenceControlTransition
         (inferenceControlDefaultState)
         (inferenceRequest B () 0))
       (validationError empty-candidates inference_control))
