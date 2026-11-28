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
!(import! &self ../evaluation_scenarios)

(= (plnTermStv EvalA) (stv 0.2 0.9))
(= (plnTermStv EvalB) (stv 0.3 0.9))
(= (plnTermStv EvalC) (stv 0.4 0.9))
(= (plnTermStv EvalD) (stv 0.5 0.9))

(= (feedbackTestRequest)
   (let (inferenceScenario $name $request $budget)
        (inferenceEvaluationScenario mixedRules)
        $request))

(= (feedbackTestTradeoffRequest)
   (let (inferenceScenario $name $request $budget)
        (inferenceEvaluationScenario feedbackTradeoff)
        $request))

(= (feedbackTestReversed
      (inferenceRequest $query ($a $b $c $d $e $f) $index))
   (inferenceRequest $query ($f $e $d $c $b $a) $index))

(= (feedbackTestResult $policy $request $budget)
   (validationValue
     (case $policy
       ((metamo
         (inferenceEvaluateControlled
           (inferenceControlDefaultState) $request $budget))
        (fixedState
         (inferenceEvaluateFixedState
           (inferenceControlDefaultState) $request $budget))))))

(= (feedbackTestRules $trace)
   (if (== $trace ())
       ()
       (let (inferenceTraceStep (plnProposal $rule $first $second) $derived $state)
            (car-atom $trace)
            (cons-atom $rule (feedbackTestRules (cdr-atom $trace))))))

(= (feedbackTestSummary $policy $request $budget)
   (let $result (feedbackTestResult $policy $request $budget)
        ((inferenceEvaluationSummary $result)
         (feedbackTestRules (inferenceEvaluationField $result trace)))))

!(test (feedbackTestSummary metamo (feedbackTestRequest) 1)
       (((policy metamo) (status budgetExhausted) (answer ())
         (ruleApplications 1) (estimatedCost 0.75))
        (induction)))
!(test (feedbackTestSummary fixedState (feedbackTestRequest) 1)
       (((policy fixedState) (status budgetExhausted) (answer ())
         (ruleApplications 1) (estimatedCost 0.75))
        (induction)))
!(test (feedbackTestSummary metamo (feedbackTestRequest) 2)
       (((policy metamo) (status answered)
         (answer ((stv 0.5208333333333334 0.8) (101 102 104)))
         (ruleApplications 2) (estimatedCost 1.25))
        (induction deduction)))
!(test (feedbackTestSummary fixedState (feedbackTestRequest) 2)
       (((policy fixedState) (status answered)
         (answer ((stv 0.5208333333333334 0.8) (101 102 104)))
         (ruleApplications 2) (estimatedCost 1.25))
        (induction deduction)))
!(test (feedbackTestRules
         (inferenceEvaluationField
           (feedbackTestResult metamo
             (feedbackTestReversed (feedbackTestRequest)) 2)
           trace))
       (induction deduction))
!(test (feedbackTestSummary fixedState
         (feedbackTestReversed (feedbackTestRequest)) 2)
       (((policy fixedState) (status answered)
         (answer ((stv 0.5208333333333334 0.8) (101 102 104)))
         (ruleApplications 2) (estimatedCost 1.25))
        (induction deduction)))
!(test (inferenceEvaluationField
         (feedbackTestResult fixedState (feedbackTestRequest) 4)
         applications) 2)
!(test (inferenceEvaluationField
         (feedbackTestResult metamo (feedbackTestRequest) 4)
         applications) 2)

(= (feedbackTestSelectionStates $policy)
   (let ((inferenceTraceStep $firstProposal $firstDerived $firstState)
         (inferenceTraceStep $secondProposal $secondDerived $secondState))
        (inferenceEvaluationField
          (feedbackTestResult $policy (feedbackTestRequest) 2) trace)
        ($firstState $secondState)))

!(test (feedbackTestSelectionStates fixedState)
       ((inferenceControlDefaultState) (inferenceControlDefaultState)))
!(test (== (car-atom (feedbackTestSelectionStates metamo))
           (inferenceControlDefaultState)) False)
!(test (== (car-atom (cdr-atom (feedbackTestSelectionStates metamo)))
           (inferenceControlDefaultState)) False)
!(test (== (car-atom (feedbackTestSelectionStates metamo))
           (car-atom (cdr-atom (feedbackTestSelectionStates metamo)))) False)

!(test (inferenceEvaluateFixedState
         (inferenceControlDefaultState) (feedbackTestRequest) -1)
       (validationError invalid-step-budget -1))
!(test (inferenceEvaluateFixedState
         (inferenceControlDefaultState) (feedbackTestRequest) 1 1.1)
       (validationError invalid-minimum-confidence 1.1))
!(test (inferenceEvaluationSummary
         (feedbackTestResult fixedState (feedbackTestRequest) 0))
       ((policy fixedState) (status budgetExhausted) (answer ())
        (ruleApplications 0) (estimatedCost 0.0)))
!(test (inferenceEvaluationSummary
         (validationValue
           (inferenceEvaluateFixedState
             (inferenceControlDefaultState)
             (inferenceRequest Goal
               ((Sentence (Goal (stv 0.7 0.6)) (9))) 0) 0)))
       ((policy fixedState) (status answered)
        (answer ((stv 0.7 0.6) (9)))
        (ruleApplications 0) (estimatedCost 0.0)))

!(test (inferenceEvaluationSummary
         (validationValue
           (inferenceEvaluateFixedState
             (inferenceControlDefaultState)
             (inferenceRequest Goal () 0) 2)))
       ((policy fixedState) (status noCandidates) (answer ())
        (ruleApplications 0) (estimatedCost 0.0)))
!(test (inferenceEvaluationSummary
         (validationValue
           (inferenceEvaluateFixedState
             (inferenceControlDefaultState)
             (inferenceRequest Goal
               ((Sentence (Goal (stv 0.7 0.4)) (9))) 0) 1)))
       ((policy fixedState) (status noCandidates)
        (answer ((stv 0.7 0.4) (9)))
        (ruleApplications 0) (estimatedCost 0.0)))

!(test (feedbackTestSummary metamo (feedbackTestTradeoffRequest) 2)
       (((policy metamo) (status answered)
         (answer ((stv 0.5208333333333334 0.65) (111 112 113)))
         (ruleApplications 2) (estimatedCost 1.25))
        (induction deduction)))
!(test (feedbackTestSummary fixedState (feedbackTestTradeoffRequest) 2)
       (((policy fixedState) (status answered)
         (answer ((stv 0.578125 0.8) (111 112 114)))
         (ruleApplications 2) (estimatedCost 1.5))
        (induction abduction)))
!(test (feedbackTestSummary metamo
         (feedbackTestReversed (feedbackTestTradeoffRequest)) 2)
       (((policy metamo) (status answered)
         (answer ((stv 0.5208333333333334 0.65) (111 112 113)))
         (ruleApplications 2) (estimatedCost 1.25))
        (induction deduction)))
!(test (feedbackTestSummary fixedState
         (feedbackTestReversed (feedbackTestTradeoffRequest)) 2)
       (((policy fixedState) (status answered)
         (answer ((stv 0.578125 0.8) (111 112 114)))
         (ruleApplications 2) (estimatedCost 1.5))
        (induction abduction)))

(= (feedbackTestTradeoffThreshold $policy)
   (let $request (feedbackTestTradeoffRequest)
        (inferenceEvaluationSummary
          (validationValue
            (case $policy
              ((metamo
                (inferenceEvaluateControlled
                  (inferenceControlDefaultState) $request 2 0.7))
               (fixedState
                (inferenceEvaluateFixedState
                  (inferenceControlDefaultState) $request 2 0.7))))))))

!(test (feedbackTestTradeoffThreshold metamo)
       ((policy metamo) (status budgetExhausted)
        (answer ((stv 0.5208333333333334 0.65) (111 112 113)))
        (ruleApplications 2) (estimatedCost 1.25)))
!(test (feedbackTestTradeoffThreshold fixedState)
       ((policy fixedState) (status answered)
        (answer ((stv 0.578125 0.8) (111 112 114)))
        (ruleApplications 2) (estimatedCost 1.5)))

