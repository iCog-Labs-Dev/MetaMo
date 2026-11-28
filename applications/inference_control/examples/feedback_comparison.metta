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
(= (feedbackTraceRules $trace)
   (if (== $trace ())
       ()
       (let (inferenceTraceStep (plnProposal $rule $first $second) $derived $state)
            (car-atom $trace)
            (cons-atom $rule (feedbackTraceRules (cdr-atom $trace))))))

(= (feedbackEvaluate $policy $request $budget)
   (validationValue
     (case $policy
       ((metamo (inferenceEvaluateControlled
                  (inferenceControlDefaultState) $request $budget))
        (fixedState (inferenceEvaluateFixedState
                      (inferenceControlDefaultState) $request $budget))))))

(= (feedbackCompareRequest $policy $request $budget)
   (let $result (feedbackEvaluate $policy $request $budget)
        ((summary (inferenceEvaluationSummary $result))
         (rules (feedbackTraceRules (inferenceEvaluationField $result trace))))))

(= (feedbackScenarioRequest $scenario)
   (let (inferenceScenario $name $request $budget)
        (inferenceEvaluationScenario $scenario)
        $request))

(= (feedbackReversedRequest
      (inferenceRequest $query ($a $b $c $d $e $f) $index))
   (inferenceRequest $query ($f $e $d $c $b $a) $index))

!(feedbackCompareRequest metamo (feedbackScenarioRequest mixedRules) 1)
!(feedbackCompareRequest fixedState (feedbackScenarioRequest mixedRules) 1)
!(feedbackCompareRequest metamo (feedbackScenarioRequest mixedRules) 2)
!(feedbackCompareRequest fixedState (feedbackScenarioRequest mixedRules) 2)
!(feedbackCompareRequest metamo
    (feedbackReversedRequest (feedbackScenarioRequest mixedRules)) 2)
!(feedbackCompareRequest fixedState
    (feedbackReversedRequest (feedbackScenarioRequest mixedRules)) 2)
!(feedbackCompareRequest metamo (feedbackScenarioRequest mixedRules) 4)
!(feedbackCompareRequest fixedState (feedbackScenarioRequest mixedRules) 4)

!(feedbackCompareRequest metamo (feedbackScenarioRequest feedbackTradeoff) 2)
!(feedbackCompareRequest fixedState (feedbackScenarioRequest feedbackTradeoff) 2)
!(feedbackCompareRequest metamo
    (feedbackReversedRequest (feedbackScenarioRequest feedbackTradeoff)) 2)
!(feedbackCompareRequest fixedState
    (feedbackReversedRequest (feedbackScenarioRequest feedbackTradeoff)) 2)

(= (feedbackCompareThreshold $policy $request $budget $minimumConfidence)
   (let $result
        (validationValue
          (case $policy
            ((metamo (inferenceEvaluateControlled
                       (inferenceControlDefaultState)
                       $request $budget $minimumConfidence))
             (fixedState (inferenceEvaluateFixedState
                           (inferenceControlDefaultState)
                           $request $budget $minimumConfidence)))))
        ((minimumConfidence $minimumConfidence)
         (summary (inferenceEvaluationSummary $result))
         (rules (feedbackTraceRules (inferenceEvaluationField $result trace))))))

!(feedbackCompareThreshold
    metamo (feedbackScenarioRequest feedbackTradeoff) 2 0.7)
!(feedbackCompareThreshold
    fixedState (feedbackScenarioRequest feedbackTradeoff) 2 0.7)

