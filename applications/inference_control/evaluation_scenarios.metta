(: InferenceScenario Type)
(: inferenceScenario (-> Symbol InferenceRequest Number InferenceScenario))

(= (INFERENCE_EVALUATION_SCENARIOS)
   (competingPaths irrelevantBeliefs uncertainPremises revision unreachable
    deductionChain overlappingEvidence initialAnswer induction abduction
    mixedRules feedbackTradeoff))


(= (inferenceEvaluationScenario $name)
   (case $name
     ((competingPaths
       (inferenceScenario competingPaths
         (inferenceRequest Goal
           ((Sentence (Weak (stv 0.9 0.4)) (1))
            (Sentence ((Implication Weak Goal) (stv 0.8 0.4)) (2))
            (Sentence (Strong (stv 0.9 0.9)) (3))
            (Sentence ((Implication Strong Goal) (stv 0.8 0.9)) (4))) 0) 1))
      (irrelevantBeliefs
       (inferenceScenario irrelevantBeliefs
         (inferenceRequest Goal
           ((Sentence (Distractor (stv 0.9 0.99)) (11))
            (Sentence ((Implication Distractor Noise) (stv 0.8 0.99)) (12))
            (Sentence (Relevant (stv 0.9 0.8)) (13))
            (Sentence ((Implication Relevant Goal) (stv 0.8 0.8)) (14))) 0) 1))
      (uncertainPremises
       (inferenceScenario uncertainPremises
         (inferenceRequest Goal
           ((Sentence (Uncertain (stv 0.9 0.2)) (21))
            (Sentence ((Implication Uncertain Goal) (stv 0.8 0.3)) (22))) 0) 1))
      (revision
       (inferenceScenario revision
         (inferenceRequest Missing
           ((Sentence (Evidence (stv 0.6 0.5)) (31))
            (Sentence (Evidence (stv 0.6 0.5)) (32))) 0) 1))
      (unreachable
       (inferenceScenario unreachable
         (inferenceRequest Missing
           ((Sentence (Start (stv 0.9 0.8)) (41))
            (Sentence ((Implication Start Other) (stv 0.8 0.8)) (42))) 0) 3))
      (deductionChain
       (inferenceScenario deductionChain
         (inferenceRequest (Inheritance EvalA EvalD)
           ((Sentence ((Inheritance EvalA EvalB) (stv 0.8 0.9)) (51))
            (Sentence ((Inheritance EvalB EvalC) (stv 0.7 0.8)) (52))
            (Sentence ((Inheritance EvalC EvalD) (stv 0.6 0.9)) (53))) 0) 2))
      (overlappingEvidence
       (inferenceScenario overlappingEvidence
         (inferenceRequest Goal
           ((Sentence (Shared (stv 0.9 0.8)) (61))
            (Sentence ((Implication Shared Goal) (stv 0.8 0.8)) (61))) 0) 3))
      (induction
       (inferenceScenario induction
         (inferenceRequest (Inheritance EvalB EvalC)
           ((Sentence ((Inheritance EvalA EvalB) (stv 0.8 0.9)) (81))
            (Sentence ((Inheritance EvalA EvalC) (stv 0.7 0.8)) (82))) 0) 1))
      (abduction
       (inferenceScenario abduction
         (inferenceRequest (Inheritance EvalA EvalB)
           ((Sentence ((Inheritance EvalA EvalC) (stv 0.8 0.9)) (91))
            (Sentence ((Inheritance EvalB EvalC) (stv 0.7 0.8)) (92))) 0) 1))
      (mixedRules
       (inferenceScenario mixedRules
         (inferenceRequest (Inheritance EvalB EvalD)
           ((Sentence ((Inheritance EvalA EvalB) (stv 0.8 0.9)) (101))
            (Sentence ((Inheritance EvalA EvalC) (stv 0.7 0.8)) (102))
            (Sentence ((Inheritance EvalD EvalB) (stv 0.7 0.9)) (103))
            (Sentence ((Inheritance EvalC EvalD) (stv 0.6 0.9)) (104))
            (Sentence (Distractor (stv 0.9 0.99)) (105))
            (Sentence ((Implication Distractor Noise) (stv 0.8 0.99)) (106))) 0) 2))
      (feedbackTradeoff
       (inferenceScenario feedbackTradeoff
         (inferenceRequest (Inheritance EvalB EvalD)
           ((Sentence ((Inheritance EvalA EvalB) (stv 0.8 0.9)) (111))
            (Sentence ((Inheritance EvalA EvalC) (stv 0.7 0.8)) (112))
            (Sentence ((Inheritance EvalC EvalD) (stv 0.6 0.65)) (113))
            (Sentence ((Inheritance EvalD EvalC) (stv 0.7 0.9)) (114))
            (Sentence (Distractor (stv 0.9 0.99)) (115))
            (Sentence ((Implication Distractor Noise) (stv 0.8 0.99)) (116))) 0) 2))
      (initialAnswer
       (inferenceScenario initialAnswer
         (inferenceRequest Goal ((Sentence (Goal (stv 0.7 0.6)) (71))) 0) 0)))))

(= (inferenceEvaluateScenario $policy
      (inferenceScenario $name $request $budget))
   (case $policy
     ((metamo (inferenceEvaluateControlled (inferenceControlDefaultState) $request $budget))
      (fixedState (inferenceEvaluateFixedState (inferenceControlDefaultState) $request $budget))
      (thresholdAware (inferenceEvaluateThresholdAware
                        (inferenceControlDefaultState) $request $budget))
      (confidenceFirst (inferenceEvaluateConfidence $request $budget))
      (queryRelevance (inferenceEvaluateRelevance $request $budget)))))
