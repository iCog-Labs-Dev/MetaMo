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

(= (plnTermStv IndA) (stv 0.2 0.9))
(= (plnTermStv IndB) (stv 0.4 0.85))
(= (plnTermStv IndC) (stv 0.5 0.8))
(= (plnTermStv IndD) (stv 0.6 0.9))
(= (plnTermStv IndWeak) (stv 0.2 0.3))

(= (inductionTestBeliefs $kind $source)
   ((Sentence (($kind $source IndB) (stv 0.8 0.95)) (1))
    (Sentence (($kind $source IndC) (stv 0.7 0.9)) (2))))

(= (inductionTestProposal $kind $source)
   (let ($first $second) (inductionTestBeliefs $kind $source)
        (plnProposePair $first $second)))

(= (inductionTestTruth)
   (plnTruthInduction
     (plnTermStv IndA) (plnTermStv IndB) (plnTermStv IndC)
     (stv 0.8 0.95) (stv 0.7 0.9)))

(= (inductionTestNear $value $expected)
   (and (> $value (- $expected 0.000001))
        (< $value (+ $expected 0.000001))))

!(test (inductionTestNear (plnTruthStrength (inductionTestTruth)) 0.55) True)
!(test (plnTruthConfidence (inductionTestTruth)) 0.8)
!(test (plnTruthInduction
         (stv 0.2 0.9) (stv 0.0 0.9) (stv 0.5 0.9)
         (stv 0.0 0.9) (stv 0.7 0.9))
       (stv 1.0 0.0))
!(test (plnTruthInduction
         (stv 0.0 0.9) (stv 0.4 0.9) (stv 0.5 0.9)
         (stv 0.8 0.9) (stv 0.7 0.9))
       (stv 1.0 0.0))
!(test (plnTruthInduction
         (stv 0.8 0.9) (stv 0.1 0.9) (stv 0.5 0.9)
         (stv 0.8 0.9) (stv 0.6 0.9))
       (stv 1.0 0.0))
!(test (plnTruthInduction
         (stv 0.2 0.9) (stv 0.4 0.9) (stv 0.1 0.9)
         (stv 0.8 0.9) (stv 0.9 0.9))
       (stv 1.0 0.0))
!(test (plnTruthInduction
         (stv 1.0 0.9) (stv 0.4 0.9) (stv 0.5 0.8)
         (stv 0.4 0.9) (stv 0.5 0.9))
       (stv 0.5 0.8))

!(test (inductionTestProposal Inheritance IndA)
       (plnProposal induction
         (Sentence ((Inheritance IndA IndB) (stv 0.8 0.95)) (1))
         (Sentence ((Inheritance IndA IndC) (stv 0.7 0.9)) (2))))
!(test (inferencePredictedTerm (inductionTestProposal Inheritance IndA))
       (Inheritance IndB IndC))
!(test (inferencePredictedTerm (inductionTestProposal Implication IndA))
       (Implication IndB IndC))
!(test (length (plnPropose (inductionTestBeliefs Inheritance IndA))) 2)
!(test (let ($first $second) (inductionTestBeliefs Inheritance IndA)
            (inferencePredictedTerm (plnProposePair $second $first)))
       (Inheritance IndC IndB))
!(test (let ($first $second) (inductionTestBeliefs Inheritance IndA)
            (let (Sentence ($term (stv $s $c)) $e)
                 (plnApplyOne (plnProposePair $second $first))
                 (inductionTestNear $s 0.44)))
       True)

(= (inductionTestChain)
   (validationValue
     (inferenceEvaluateControlled
       (inferenceControlDefaultState)
       (inferenceRequest (Inheritance IndB IndD)
         (append (inductionTestBeliefs Inheritance IndA)
                 ((Sentence ((Inheritance IndC IndD) (stv 0.8 0.9)) (3)))) 0)
       2)))

!(test (let (inferenceEvaluation $policy $status ((stv $s $c) $e) $steps $cost $trace)
            (inductionTestChain)
            ($status (inductionTestNear $s 0.62) $c $e $steps $cost))
       (answered True 0.8 (1 2 3) 2 1.25))
!(test (let ((inferenceTraceStep (plnProposal $firstRule $a $b) $firstDerived $firstState)
             (inferenceTraceStep (plnProposal $secondRule $c $d) $secondDerived $secondState))
            (inferenceEvaluationField (inductionTestChain) trace)
            ($firstRule $secondRule))
       (induction deduction))

(= (inductionTestExecution $kind)
   (let (Sentence ($term (stv $s $c)) $e)
        (plnApplyOne (inductionTestProposal $kind IndA))
        ($term (inductionTestNear $s 0.55) $c $e)))

!(test (inductionTestExecution Inheritance) ((Inheritance IndB IndC) True 0.8 (1 2)))
!(test (inductionTestExecution Implication) ((Implication IndB IndC) True 0.8 (1 2)))
!(test (collapse
         (plnProposePair
           (Sentence ((Inheritance IndA IndB) (stv 0.8 0.9)) (1))
           (Sentence ((Inheritance IndA IndC) (stv 0.7 0.9)) (1))))
       ())
!(test (collapse
         (plnApplyOne
           (plnProposal induction
             (Sentence ((Inheritance IndA IndB) (stv 0.8 0.9)) (1))
             (Sentence ((Inheritance IndA IndC) (stv 0.7 0.9)) (1)))))
       ())
!(test (plnProposePair
         (Sentence ((Inheritance IndA IndB) (stv 0.8 0.9)) (1))
         (Sentence ((Inheritance IndA IndB) (stv 0.8 0.9)) (2)))
       (plnProposal revision
         (Sentence ((Inheritance IndA IndB) (stv 0.8 0.9)) (1))
         (Sentence ((Inheritance IndA IndB) (stv 0.8 0.9)) (2))))
!(test (collapse
         (plnProposePair
           (Sentence ((Inheritance IndA IndB) (stv 0.8 0.9)) (1))
           (Sentence ((Implication IndA IndC) (stv 0.7 0.9)) (2))))
       ())
!(test (inferenceEstimatedCost (inductionTestProposal Inheritance IndA)) 0.75)
!(test (featureMapNumericUnit
         (inferenceProposalFeatures
           (inductionTestProposal Inheritance IndA)
           (Inheritance IndB IndC) (inductionTestBeliefs Inheritance IndA))
         query_relevance 0.0) 1.0)

(= (inductionTestEvaluate $policy $kind $source)
   (let $request
        (inferenceRequest ($kind IndB IndC) (inductionTestBeliefs $kind $source) 0)
        (validationValue
          (case $policy
            ((metamo (inferenceEvaluateControlled (inferenceControlDefaultState) $request 1))
             (confidenceFirst (inferenceEvaluateConfidence $request 1))
             (queryRelevance (inferenceEvaluateRelevance $request 1)))))))

(= (inductionTestSummary $policy $kind $source)
   (let (inferenceEvaluation $name $status ((stv $s $c) $e) $steps $cost $trace)
        (inductionTestEvaluate $policy $kind $source)
        ($status (inductionTestNear $s 0.55) $c $e $steps $cost)))

!(test (inductionTestSummary metamo Inheritance IndA) (answered True 0.8 (1 2) 1 0.75))
!(test (inductionTestSummary metamo Implication IndA) (answered True 0.8 (1 2) 1 0.75))
!(test (inductionTestSummary confidenceFirst Inheritance IndA) (answered True 0.8 (1 2) 1 0.75))
!(test (inductionTestSummary queryRelevance Inheritance IndA) (answered True 0.8 (1 2) 1 0.75))
!(test (inductionTestSummary metamo Inheritance IndWeak) (budgetExhausted True 0.3 (1 2) 1 0.75))
!(test (inductionTestSummary confidenceFirst Inheritance IndWeak) (budgetExhausted True 0.3 (1 2) 1 0.75))
!(test (inductionTestSummary queryRelevance Inheritance IndWeak) (budgetExhausted True 0.3 (1 2) 1 0.75))
!(test (let (inferenceTraceStep $proposal $derived $state)
            (car-atom (inferenceEvaluationField (inductionTestEvaluate metamo Inheritance IndA) trace))
            (and (== $proposal (inductionTestProposal Inheritance IndA))
                 (not (== $state (inferenceControlDefaultState)))))
       True)

