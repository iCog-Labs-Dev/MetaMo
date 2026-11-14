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
!(import! &self ../reasoning_loop)

(= (loopTestFact)
   (Sentence (A (stv 0.8 0.9)) (1)))
(= (loopTestRule)
   (Sentence ((Implication A B) (stv 0.7 0.8)) (2)))
(= (loopTestRequest)
   (inferenceRequest B ((loopTestFact) (loopTestRule)) 0))
(= (loopTestOneStep)
   (validationValue
     (inferenceControlRun
       (inferenceControlDefaultState) (loopTestRequest) 1)))

(= (plnTermStv A) (stv 0.2 0.9))
(= (plnTermStv B) (stv 0.3 0.9))
(= (plnTermStv C) (stv 0.4 0.9))
(= (plnTermStv D) (stv 0.5 0.9))
(= (loopTestChainRequest)
   (inferenceRequest
     (Inheritance A D)
     ((Sentence ((Inheritance A B) (stv 0.8 0.9)) (11))
      (Sentence ((Inheritance B C) (stv 0.7 0.8)) (12))
      (Sentence ((Inheritance C D) (stv 0.6 0.9)) (13)))
     10))
(= (loopTestTwoSteps)
   (validationValue
     (inferenceControlRun
       (inferenceControlDefaultState) (loopTestChainRequest) 2)))

!(test (inferenceRunStatus (loopTestOneStep)) answered)
!(test (inferenceRunSteps (loopTestOneStep)) 1)
!(test (inferenceRunAnswer (loopTestOneStep))
       ((stv 0.564 0.7200000000000001) (1 2)))
!(test (length (inferenceRunHistory (loopTestOneStep))) 1)
!(test (inferenceRequestNextIndex (inferenceRunRequest (loopTestOneStep))) 1)
!(test (inferenceRunState (loopTestOneStep))
       (inferenceOutcomeState (car-atom (inferenceRunHistory (loopTestOneStep)))))

!(test (inferenceRunStatus
         (validationValue
           (inferenceControlRun
             (inferenceControlDefaultState)
             (inferenceRequest A ((loopTestFact) (loopTestRule)) 0)
             0)))
       answered)
!(test (inferenceRunSteps
         (validationValue
           (inferenceControlRun
             (inferenceControlDefaultState)
             (inferenceRequest A ((loopTestFact) (loopTestRule)) 0)
             0)))
       0)
!(test (inferenceRunStatus
         (validationValue
           (inferenceControlRun
             (inferenceControlDefaultState) (loopTestRequest) 0)))
       budgetExhausted)
!(test (inferenceRunStatus
         (validationValue
           (inferenceControlRun
             (inferenceControlDefaultState)
             (inferenceRequest B () 0) 1)))
       noCandidates)
!(test (inferenceControlRun
         (inferenceControlDefaultState) (loopTestRequest) -1)
       (validationError invalid-step-budget -1))
!(test (inferenceRunStatus
         (validationValue
           (inferenceControlRun
             (inferenceControlDefaultState)
             (inferenceRequest C ((loopTestFact) (loopTestRule)) 0)
             5)))
       noCandidates)
!(test (inferenceRunSteps
         (validationValue
           (inferenceControlRun
             (inferenceControlDefaultState)
             (inferenceRequest C ((loopTestFact) (loopTestRule)) 0)
             5)))
       1)

!(test (inferenceRunStatus (loopTestTwoSteps)) answered)
!(test (inferenceRunSteps (loopTestTwoSteps)) 2)
!(test (length (inferenceRunHistory (loopTestTwoSteps))) 2)
!(test (inferenceRunStatus
         (validationValue
           (inferenceControlRun
             (inferenceControlDefaultState) (loopTestChainRequest) 1)))
       budgetExhausted)
!(test (inferenceTermPresent
         (Inheritance A D)
         (inferenceRequestBeliefs (inferenceRunRequest (loopTestTwoSteps))))
       True)
