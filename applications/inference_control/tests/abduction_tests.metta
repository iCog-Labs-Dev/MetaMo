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

(= (plnTermStv AbdA) (stv 0.2 0.9))
(= (plnTermStv AbdB) (stv 0.4 0.85))
(= (plnTermStv AbdC) (stv 0.5 0.8))
(= (plnTermStv AbdD) (stv 0.6 0.9))
(= (plnTermStv AbdWeak) (stv 0.5 0.3))

(= (abductionTestBeliefs $kind $shared)
   ((Sentence (($kind AbdA $shared) (stv 0.8 0.95)) (1))
    (Sentence (($kind AbdB $shared) (stv 0.7 0.9)) (2))))

(= (abductionTestProposal $kind $shared)
   (let ($first $second) (abductionTestBeliefs $kind $shared)
        (plnProposePair $first $second)))

(= (abductionTestNear $value $expected)
   (and (> $value (- $expected 0.000001))
        (< $value (+ $expected 0.000001))))

(= (abductionTestTruth)
   (plnTruthAbduction
     (plnTermStv AbdA) (plnTermStv AbdB) (plnTermStv AbdC)
     (stv 0.8 0.95) (stv 0.7 0.9)))

!(test (abductionTestNear (plnTruthStrength (abductionTestTruth)) 0.496) True)
!(test (plnTruthConfidence (abductionTestTruth)) 0.8)
!(test (plnTruthAbduction
         (stv 0.2 0.9) (stv 0.4 0.9) (stv 0.0 0.9)
         (stv 0.0 0.9) (stv 0.0 0.9))
       (stv 1.0 0.0))
!(test (plnTruthAbduction
         (stv 0.0 0.9) (stv 0.4 0.9) (stv 0.5 0.9)
         (stv 0.8 0.9) (stv 0.7 0.9))
       (stv 1.0 0.0))
!(test (plnTruthAbduction
         (stv 0.2 0.9) (stv 0.0 0.9) (stv 0.5 0.9)
         (stv 0.8 0.9) (stv 0.7 0.9))
       (stv 1.0 0.0))
!(test (plnTruthAbduction
         (stv 0.8 0.9) (stv 0.4 0.9) (stv 0.5 0.9)
         (stv 0.9 0.9) (stv 0.7 0.9))
       (stv 1.0 0.0))
!(test (plnTruthAbduction
         (stv 0.2 0.9) (stv 0.8 0.9) (stv 0.5 0.9)
         (stv 0.8 0.9) (stv 0.9 0.9))
       (stv 1.0 0.0))
!(test (plnTruthAbduction
         (stv 0.2 0.9) (stv 0.4 0.8) (stv 1.0 0.9)
         (stv 1.0 0.9) (stv 1.0 0.9))
       (stv 0.4 0.8))

!(test (abductionTestProposal Inheritance AbdC)
       (plnProposal abduction
         (Sentence ((Inheritance AbdA AbdC) (stv 0.8 0.95)) (1))
         (Sentence ((Inheritance AbdB AbdC) (stv 0.7 0.9)) (2))))
!(test (inferencePredictedTerm (abductionTestProposal Inheritance AbdC))
       (Inheritance AbdA AbdB))
!(test (inferencePredictedTerm (abductionTestProposal Implication AbdC))
       (Implication AbdA AbdB))
!(test (length (plnPropose (abductionTestBeliefs Inheritance AbdC))) 2)
!(test (let ($first $second) (abductionTestBeliefs Inheritance AbdC)
            (inferencePredictedTerm (plnProposePair $second $first)))
       (Inheritance AbdB AbdA))
!(test (let ($first $second) (abductionTestBeliefs Inheritance AbdC)
            (let (Sentence ($term (stv $s $c)) $e)
                 (plnApplyOne (plnProposePair $second $first))
                 (abductionTestNear $s 0.248)))
       True)

(= (abductionTestExecution $kind)
   (let (Sentence ($term (stv $s $c)) $e)
        (plnApplyOne (abductionTestProposal $kind AbdC))
        ($term (abductionTestNear $s 0.496) $c $e)))

!(test (abductionTestExecution Inheritance) ((Inheritance AbdA AbdB) True 0.8 (1 2)))
!(test (abductionTestExecution Implication) ((Implication AbdA AbdB) True 0.8 (1 2)))
!(test (collapse
         (plnProposePair
           (Sentence ((Inheritance AbdA AbdC) (stv 0.8 0.9)) (1))
           (Sentence ((Inheritance AbdB AbdC) (stv 0.7 0.9)) (1))))
       ())
!(test (collapse
         (plnApplyOne
           (plnProposal abduction
             (Sentence ((Inheritance AbdA AbdC) (stv 0.8 0.9)) (1))
             (Sentence ((Inheritance AbdB AbdC) (stv 0.7 0.9)) (1)))))
       ())
!(test (plnProposePair
         (Sentence ((Inheritance AbdA AbdC) (stv 0.8 0.9)) (1))
         (Sentence ((Inheritance AbdA AbdC) (stv 0.8 0.9)) (2)))
       (plnProposal revision
         (Sentence ((Inheritance AbdA AbdC) (stv 0.8 0.9)) (1))
         (Sentence ((Inheritance AbdA AbdC) (stv 0.8 0.9)) (2))))
!(test (collapse
         (plnProposePair
           (Sentence ((Inheritance AbdA AbdC) (stv 0.8 0.9)) (1))
           (Sentence ((Implication AbdB AbdC) (stv 0.7 0.9)) (2))))
       ())
!(test (inferenceEstimatedCost (abductionTestProposal Inheritance AbdC)) 0.75)
!(test (featureMapNumericUnit
         (inferenceProposalFeatures
           (abductionTestProposal Inheritance AbdC)
           (Inheritance AbdA AbdB) (abductionTestBeliefs Inheritance AbdC))
         query_relevance 0.0) 1.0)

(= (abductionTestEvaluate $policy $kind $shared)
   (let $request
        (inferenceRequest ($kind AbdA AbdB) (abductionTestBeliefs $kind $shared) 0)
        (validationValue
          (case $policy
            ((metamo (inferenceEvaluateControlled (inferenceControlDefaultState) $request 1))
             (confidenceFirst (inferenceEvaluateConfidence $request 1))
             (queryRelevance (inferenceEvaluateRelevance $request 1)))))))

(= (abductionTestSummary $policy $kind $shared)
   (let (inferenceEvaluation $name $status ((stv $s $c) $e) $steps $cost $trace)
        (abductionTestEvaluate $policy $kind $shared)
        ($status (abductionTestNear $s 0.496) $c $e $steps $cost)))

!(test (abductionTestSummary metamo Inheritance AbdC) (answered True 0.8 (1 2) 1 0.75))
!(test (abductionTestSummary metamo Implication AbdC) (answered True 0.8 (1 2) 1 0.75))
!(test (abductionTestSummary confidenceFirst Inheritance AbdC) (answered True 0.8 (1 2) 1 0.75))
!(test (abductionTestSummary queryRelevance Inheritance AbdC) (answered True 0.8 (1 2) 1 0.75))
!(test (abductionTestSummary metamo Inheritance AbdWeak) (budgetExhausted True 0.3 (1 2) 1 0.75))
!(test (abductionTestSummary confidenceFirst Inheritance AbdWeak) (budgetExhausted True 0.3 (1 2) 1 0.75))
!(test (abductionTestSummary queryRelevance Inheritance AbdWeak) (budgetExhausted True 0.3 (1 2) 1 0.75))
!(test (let (inferenceTraceStep $proposal $derived $state)
            (car-atom (inferenceEvaluationField (abductionTestEvaluate metamo Inheritance AbdC) trace))
            (and (== $proposal (abductionTestProposal Inheritance AbdC))
                 (not (== $state (inferenceControlDefaultState)))))
       True)

(= (abductionTestChain)
   (validationValue
     (inferenceEvaluateControlled
       (inferenceControlDefaultState)
       (inferenceRequest (Inheritance AbdA AbdD)
         (append (abductionTestBeliefs Inheritance AbdC)
                 ((Sentence ((Inheritance AbdB AbdD) (stv 0.8 0.9)) (3)))) 0)
       2)))

!(test (let (inferenceEvaluation $policy $status ((stv $s $c) $e) $steps $cost $trace)
            (abductionTestChain)
            ($status (abductionTestNear $s 0.632) $c $e $steps $cost))
       (answered True 0.8 (1 2 3) 2 1.25))
!(test (let ((inferenceTraceStep (plnProposal $firstRule $a $b) $firstDerived $firstState)
             (inferenceTraceStep (plnProposal $secondRule $c $d) $secondDerived $secondState))
            (inferenceEvaluationField (abductionTestChain) trace)
            ($firstRule $secondRule))
       (abduction deduction))

(= (plnTermStv CompA) (stv 0.5 0.9))
(= (plnTermStv CompB) (stv 0.5 0.9))
(= (plnTermStv CompC) (stv 0.5 0.9))
(= (plnTermStv CompD) (stv 0.5 0.9))
(= (plnTermStv CompE) (stv 0.5 0.9))

(= (abductionTestCompetingBeliefs $deductionConfidence)
   ((Sentence ((Inheritance CompA CompC) (stv 0.7 0.9)) (11))
    (Sentence ((Inheritance CompB CompC) (stv 0.7 0.9)) (12))
    (Sentence ((Inheritance CompD CompA) (stv 0.7 0.9)) (13))
    (Sentence ((Inheritance CompD CompB) (stv 0.7 0.9)) (14))
    (Sentence ((Inheritance CompA CompE) (stv 0.7 $deductionConfidence)) (15))
    (Sentence ((Inheritance CompE CompB) (stv 0.7 $deductionConfidence)) (16))))

!(test (let $proposals (plnPropose (abductionTestCompetingBeliefs 0.9))
            (list_to_set
              (collapse
                (let $proposal (superpose $proposals)
                     (if (== (inferencePredictedTerm $proposal) (Inheritance CompA CompB))
                         (let (plnProposal $rule $first $second) $proposal $rule)
                         (empty))))))
       (abduction induction deduction))

(= (abductionTestSelectedRule $deductionConfidence)
   (let (inferenceTraceStep (plnProposal $rule $first $second) $derived $state)
            (car-atom
              (inferenceEvaluationField
                (validationValue
                  (inferenceEvaluateControlled
                    (inferenceControlDefaultState)
                    (inferenceRequest (Inheritance CompA CompB)
                      (abductionTestCompetingBeliefs $deductionConfidence) 0) 1))
                trace))
            $rule))

!(test (abductionTestSelectedRule 0.9) deduction)
!(test (abductionTestSelectedRule 0.3) abduction)

