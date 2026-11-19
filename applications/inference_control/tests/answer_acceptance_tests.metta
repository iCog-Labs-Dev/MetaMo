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

!(import! &self ../evaluation)

(= (acceptanceTestRequest)
   (inferenceRequest Answer
     ((Sentence (Answer (stv 0.6 0.4)) (1))
      (Sentence (Answer (stv 0.6 0.4)) (2))) 0))

(= (acceptanceTestEvaluate $policy $request $budget $minimumConfidence)
   (case $policy
     ((metamo
       (inferenceEvaluateControlled
         (inferenceControlDefaultState) $request $budget $minimumConfidence))
      (confidenceFirst
       (inferenceEvaluateConfidence $request $budget $minimumConfidence))
      (queryRelevance
       (inferenceEvaluateRelevance $request $budget $minimumConfidence)))))

(= (acceptanceTestSummary $policy $request $budget $minimumConfidence)
   (let (inferenceEvaluation $name $status $answer $applications $cost $trace)
        (validationValue
          (acceptanceTestEvaluate $policy $request $budget $minimumConfidence))
        ($status $applications $answer)))

!(test (acceptanceTestSummary metamo
         (acceptanceTestRequest) 1 0.5)
       (answered 1 ((stv 0.6 0.5714285714285715) (1 2))))
!(test (acceptanceTestSummary metamo
         (acceptanceTestRequest) 1 0.7)
       (budgetExhausted 1 ((stv 0.6 0.5714285714285715) (1 2))))
!(test (acceptanceTestSummary metamo
         (inferenceRequest Answer ((Sentence (Answer (stv 0.9 0.06)) (3))) 0) 2 0.5)
       (noCandidates 0 ((stv 0.9 0.06) (3))))
!(test (acceptanceTestSummary metamo
         (inferenceRequest Answer ((Sentence (Answer (stv 0.9 0.06)) (3))) 0) 0 0.5)
       (budgetExhausted 0 ((stv 0.9 0.06) (3))))
!(test (acceptanceTestSummary metamo
         (inferenceRequest Answer ((Sentence (Answer (stv 0.2 0.5)) (4))) 0) 0 0.5)
       (answered 0 ((stv 0.2 0.5) (4))))
!(test (acceptanceTestSummary metamo
         (inferenceRequest Answer ((Sentence (Answer (stv 0.0 0.9)) (5))) 0) 0 0.5)
       (answered 0 ((stv 0.0 0.9) (5))))
!(test (acceptanceTestSummary metamo
         (inferenceRequest Answer () 0) 1 0)
       (noCandidates 0 ()))
!(test (acceptanceTestSummary metamo
         (inferenceRequest Answer ((Sentence (Answer (stv 0.9 0.06)) (3))) 0) 0 0)
       (answered 0 ((stv 0.9 0.06) (3))))
!(test (acceptanceTestEvaluate metamo (acceptanceTestRequest) 1 -0.1)
       (validationError invalid-minimum-confidence -0.1))
!(test (acceptanceTestEvaluate metamo (acceptanceTestRequest) 1 1.1)
       (validationError invalid-minimum-confidence 1.1))
!(test (acceptanceTestSummary confidenceFirst
         (acceptanceTestRequest) 1 0.5)
       (answered 1 ((stv 0.6 0.5714285714285715) (1 2))))
!(test (acceptanceTestSummary confidenceFirst
         (acceptanceTestRequest) 1 0.7)
       (budgetExhausted 1 ((stv 0.6 0.5714285714285715) (1 2))))
!(test (acceptanceTestSummary confidenceFirst
         (inferenceRequest Answer ((Sentence (Answer (stv 0.9 0.06)) (3))) 0) 2 0.5)
       (noCandidates 0 ((stv 0.9 0.06) (3))))
!(test (acceptanceTestSummary confidenceFirst
         (inferenceRequest Answer ((Sentence (Answer (stv 0.9 0.06)) (3))) 0) 0 0.5)
       (budgetExhausted 0 ((stv 0.9 0.06) (3))))
!(test (acceptanceTestSummary confidenceFirst
         (inferenceRequest Answer ((Sentence (Answer (stv 0.2 0.5)) (4))) 0) 0 0.5)
       (answered 0 ((stv 0.2 0.5) (4))))
!(test (acceptanceTestSummary confidenceFirst
         (inferenceRequest Answer ((Sentence (Answer (stv 0.0 0.9)) (5))) 0) 0 0.5)
       (answered 0 ((stv 0.0 0.9) (5))))
!(test (acceptanceTestSummary confidenceFirst
         (inferenceRequest Answer () 0) 1 0)
       (noCandidates 0 ()))
!(test (acceptanceTestSummary confidenceFirst
         (inferenceRequest Answer ((Sentence (Answer (stv 0.9 0.06)) (3))) 0) 0 0)
       (answered 0 ((stv 0.9 0.06) (3))))
!(test (acceptanceTestEvaluate confidenceFirst (acceptanceTestRequest) 1 -0.1)
       (validationError invalid-minimum-confidence -0.1))
!(test (acceptanceTestEvaluate confidenceFirst (acceptanceTestRequest) 1 1.1)
       (validationError invalid-minimum-confidence 1.1))

!(test (acceptanceTestSummary queryRelevance
         (acceptanceTestRequest) 1 0.5)
       (answered 1 ((stv 0.6 0.5714285714285715) (1 2))))
!(test (acceptanceTestSummary queryRelevance
         (acceptanceTestRequest) 1 0.7)
       (budgetExhausted 1 ((stv 0.6 0.5714285714285715) (1 2))))
!(test (acceptanceTestSummary queryRelevance
         (inferenceRequest Answer ((Sentence (Answer (stv 0.9 0.06)) (3))) 0) 2 0.5)
       (noCandidates 0 ((stv 0.9 0.06) (3))))
!(test (acceptanceTestSummary queryRelevance
         (inferenceRequest Answer ((Sentence (Answer (stv 0.9 0.06)) (3))) 0) 0 0.5)
       (budgetExhausted 0 ((stv 0.9 0.06) (3))))
!(test (acceptanceTestSummary queryRelevance
         (inferenceRequest Answer ((Sentence (Answer (stv 0.2 0.5)) (4))) 0) 0 0.5)
       (answered 0 ((stv 0.2 0.5) (4))))
!(test (acceptanceTestSummary queryRelevance
         (inferenceRequest Answer ((Sentence (Answer (stv 0.0 0.9)) (5))) 0) 0 0.5)
       (answered 0 ((stv 0.0 0.9) (5))))
!(test (acceptanceTestSummary queryRelevance
         (inferenceRequest Answer () 0) 1 0)
       (noCandidates 0 ()))
!(test (acceptanceTestSummary queryRelevance
         (inferenceRequest Answer ((Sentence (Answer (stv 0.9 0.06)) (3))) 0) 0 0)
       (answered 0 ((stv 0.9 0.06) (3))))
!(test (acceptanceTestEvaluate queryRelevance (acceptanceTestRequest) 1 -0.1)
       (validationError invalid-minimum-confidence -0.1))
!(test (acceptanceTestEvaluate queryRelevance (acceptanceTestRequest) 1 1.1)
       (validationError invalid-minimum-confidence 1.1))
