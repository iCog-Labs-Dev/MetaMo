
!(bind! &goal-space        (new-space))
!(bind! &motivation-space  (new-space))
!(bind! &appraisal-space   (new-space))
!(bind! &signal-space      (new-space))
!(bind! &candidateSpace    (new-space))
!(bind! &self-model-space  (new-space))

!(bind! &failure-streak           (new-state 0))
!(bind! &active-task              (new-state ""))
!(bind! &last-motivation-decision (new-state (decision clarity orient inspect 0.0)))
!(bind! &success-count            (new-state 0))
!(bind! &failure-count            (new-state 0))
!(bind! &cycle-count              (new-state 0))




(= (clamp $value)
   (if (< $value 0.0) 0.0 (if (> $value 1.0) 1.0 $value)))

(= (selfModelAlpha)
   (let $v (collapse (match &self (DynamicsConfig self_model_alpha $x) $x))
      (if (== $v ()) 0.20 (car-atom $v))))

(= (fetchSelfMetricValue $name)
   (let $res (collapse (match &self-model-space (self-metric $name $v) $v))
      (if (== $res ()) 0.0 (car-atom $res))))

(= (replaceSelfMetric $name $newValue)
   (let* (
      ($existing (collapse (match &self-model-space
                                (self-metric $name $v) (self-metric $name $v))))
      ($_ (if (!= $existing ())
              (remove-atom &self-model-space (car-atom $existing))
              _))
      ($_ (add-atom &self-model-space (self-metric $name $newValue)))
   ) ()))

(= (updateSelfModel $hadError $hadResults)
   (let* (
      ($_ (change-state! &cycle-count   (+ (get-state &cycle-count)   1)))
      ($_ (if (and $hadResults (not $hadError))
              (change-state! &success-count (+ (get-state &success-count) 1))
              _))
      ($_ (if $hadError
              (change-state! &failure-count (+ (get-state &failure-count) 1))
              _))
      ($cycles    (get-state &cycle-count))
      ($successes (get-state &success-count))
      ($failures  (get-state &failure-count))
      ($instSuccess (if (> $cycles 0) (/ $successes $cycles) 0.5))
      ($instFailure (if (> $cycles 0) (/ $failures  $cycles) 0.1))
      ($alpha    (selfModelAlpha))
      ($oldSucc  (fetchSelfMetricValue success_rate))
      ($oldFail  (fetchSelfMetricValue failure_rate))
      ($newSucc  (clamp (+ (* (- 1.0 $alpha) $oldSucc) (* $alpha $instSuccess))))
      ($newFail  (clamp (+ (* (- 1.0 $alpha) $oldFail) (* $alpha $instFailure))))
      ($_ (replaceSelfMetric success_rate     $newSucc))
      ($_ (replaceSelfMetric failure_rate     $newFail))
      ($_ (replaceSelfMetric memory_confidence (clamp (* $newSucc 1.4))))
      ($streak   (get-state &failure-streak))
      ($_ (replaceSelfMetric identity_continuity (clamp (- 0.90 (* $streak 0.08)))))
      ($_ (replaceSelfMetric resource_usage
              (clamp (/ $cycles (+ $cycles 50.0)))))
   ) ()))


;; Constructs the MetaMo bimonad wired to OmegaClaw's appraisal + decision.
(= (omegaclawBimonad)
    (metaMoPseudoBimonad
        (omegaclawAppraisal)        ;; AppraisalComonad
        (omegaclawDecision)         ;; DecisionMonad
        applyHomeostaticDamping     ;; dampingFn 
        raiseBoundaryCaution        ;; boundaryFn
        projectToSafeRegion         ;; projectFn
        checkContractiveUpdateLaw   ;; contractiveFn
        isInSafeRegion              ;; safeRegionFn
    )
)


;; MotivOS-formatted decision result for injection into the LLM prompt.
(= (motivationContextBlock)
    (let* (
        ($signals (eval (refreshSignals)))
      ;   ($_ (println! ("Signals" $signals)))
        ($_ (eval (clearSpace &appraisal-space)))
        ($_ (eval (computeAllDimensions)))
         
         ($currentMetaMoState (eval (motivosToMetamoState)))
         ; ($_ (println! ("Current state" $currentMetaMoState)))
         ($stimulus (eval (appraisalToStimulus)))
         ; ($_ (println! ("Current Stimulus" $stimulus)))
         
         ($_ (generateCandidates))
         ($actions (eval (candidatesToActions)))
         ; ($_ (println! ("Actions" $actions)))
         
         ($sysStates (cons-atom (subsystemState omegaclaw $currentMetaMoState) ()))
         
         ($bimonad     (omegaclawBimonad))
         ; ($_ (println! ("Bimonad" $bimonad)))
         ($cycleResult (runMetaMoCycleDefault $bimonad $sysStates $stimulus $actions () ()))
         ; ($_ (println! ("cycle result" $cycleResult)))

        ($finalAction   (cycleFinalAction  $cycleResult))
        ($nextSysStates (cycleNextStates   $cycleResult))
      ;   ($_ (println! ("final action" $finalAction)))
      ;   ($_ (println! ("next sys states" $nextSysStates)))

        ($nextState (findSubsystemState omegaclaw $nextSysStates))
      ;   ($_ (println! ("next state" $nextState)))
        ($x (eval (writeBackMetamoState $nextState)))
      ;   ($_ (println! ("write back result" $x)))
        
        ($score (omegaclawScore $currentMetaMoState $finalAction))
      ;   ($_ (println! ("score" $score)))
        ($decisionResult (eval (metamoActionToDecision $finalAction $score)))
      ;   ($_ (println! ("decision result" $decisionResult)))
        ($_ (change-state! &last-motivation-decision $decisionResult))
        ($_ (updateSelfModel (hasErrors) (hasResults)))
        ;; ($_ (saveMotivationalState))
    )
        $decisionResult
    )
)


(= (hasErrors)
    (let $err (collapse (match &signal-space (signal failure $_) True))
        (if (== $err ()) False True))
)

(= (hasResults)
    (let $res (collapse (match &signal-space (signal verified-success $_) True))
        (if (== $res ()) False True))
)

;; Weighted contribution of one signal kind to one appraisal dimension.
(= (signalDimContrib $kind $strength $dim)
   (let $weights (collapse (match &self (SignalAppraisal $kind $dim $w) $w))
      (if (== $weights ()) 0.0 (* $strength (car-atom $weights)))))

;; Sum contributions from a list of signals for one dimension.
(= (sumDimFromSignals $dim () $acc) $acc)
(= (sumDimFromSignals $dim $signals $acc)
   (let* (
      (($head $tail) (decons-atom $signals))
      ((signal $kind $strength) $head)
      ($contrib (signalDimContrib $kind $strength $dim))
   )
   (sumDimFromSignals $dim $tail (+ $acc $contrib))))

;; Compute total value for one appraisal dimension from current &signal-space.
(= (computeDimension $dim)
   (let $signals (collapse (match &signal-space (signal $k $s) (signal $k $s)))
      (clamp (sumDimFromSignals $dim $signals 0.0))))

;; Populate &appraisal-space with all 6 dimension values.
(= (computeAllDimensions)
    (let* (
        ($n (computeDimension novelty))
        ($r (computeDimension risk))
        ($i (computeDimension importance))
        ($u (computeDimension uncertainty))
        ($o (computeDimension opportunity))
        ($p (computeDimension progress))
        ($_ (add-atom &appraisal-space (appraisal novelty     $n)))
        ($_ (add-atom &appraisal-space (appraisal risk        $r)))
        ($_ (add-atom &appraisal-space (appraisal importance  $i)))
        ($_ (add-atom &appraisal-space (appraisal uncertainty $u)))
        ($_ (add-atom &appraisal-space (appraisal opportunity $o)))
        ($_ (add-atom &appraisal-space (appraisal progress    $p)))
    ) True)
)


(= (evalCondition always _ _) True)
(= (evalCondition task-active _ _) (hasContent (get-state &active-task)))
(= (evalCondition appraisal-above $param $thresh)
   (let $v (eval (extractAppraisalDim $param)) (> $v $thresh)))
(= (evalCondition appraisal-below $param $thresh)
   (let $v (eval (extractAppraisalDim $param)) (< $v $thresh)))
(= (evalCondition modulator-above $param $thresh)
   (let $v (eval (extractModulatorValue $param)) (> $v $thresh)))
(= (evalCondition self-metric-above $param $thresh)
   (let $v (eval (fetchSelfMetricValue $param)) (> $v $thresh)))
(= (evalCondition self-metric-below $param $thresh)
   (let $v (eval (fetchSelfMetricValue $param)) (< $v $thresh)))

(= (hasContent $str) (not (== $str "")))

(= (allTrue ()) True)
(= (allTrue $lst)
   (let* (
      (($head $tail) (decons-atom $lst))
      ((CandidateCondition $_ $type $param $thresh) $head)
      ($result (evalCondition $type $param $thresh))
   )
   (if $result (allTrue $tail) False)))

(= (anyTrue ()) False)
(= (anyTrue $lst)
   (let* (
      (($head $tail) (decons-atom $lst))
      ((CandidateConditionAny $_ $type $param $thresh) $head)
      ($result (evalCondition $type $param $thresh))
   )
   (if $result True (anyTrue $tail))))

(= (candidateIsAvailable $name)
   (let* (
      ($andRows (collapse (match &self (CandidateCondition $name $t $p $h)
                              (CandidateCondition $name $t $p $h))))
      ($orRows  (collapse (match &self (CandidateConditionAny $name $t $p $h)
                              (CandidateConditionAny $name $t $p $h))))
      ($hasAnd  (not (== $andRows ())))
      ($hasOr   (not (== $orRows  ())))
   )
   (if (and (not $hasAnd) (not $hasOr))
       False
       (and (if $hasAnd (eval (allTrue $andRows)) True)
            (if $hasOr  (eval (anyTrue $orRows))  True)))))

(= (generateCandidates)
   (let* (
      ($_ (clearSpace &candidateSpace))
      ($andNames (collapse (match &self (CandidateCondition $n $_t $_p $_h) $n)))
      ($orNames  (collapse (match &self (CandidateConditionAny $n $_t $_p $_h) $n)))
      ($allCandidates (unionAtom $andNames $orNames))
      ($_ (collapse
             (let $n (superpose $allCandidates)
                (if (candidateIsAvailable $n)
                    (add-atom &candidateSpace (candidate $n))
                    (empty)))))
   )
   True))

;; Simple union/unique utilities
(= (unionAtom $a $b)
    (collapse (superpose ((superpose $a) (superpose $b))))
)


;; Map winning candidate name to a binding imperative for the LLM.
(= (candidateInstruction $directive)
   (case $directive (
      (respond           "REQUIRED: Respond to the user now. Your primary output MUST include a send command.")
      (retrieve-memory   "REQUIRED: Query long-term memory before responding. Your primary output MUST include a query command.")
      (search-knowledge  "REQUIRED: Search for relevant knowledge before responding. Your primary output MUST include a search or query command.")
      (execute-skill     "REQUIRED: Execute the requested skill or task now. Your primary output MUST include the appropriate skill command.")
      (learn             "REQUIRED: Capture and store new knowledge this cycle. Your primary output MUST include a remember command.")
      (self-improve      "REQUIRED: Reflect on recent failures and update your approach. Consider using remember to store the lesson.")
      (defer             "REQUIRED: Do not take irreversible action this cycle. Verify the situation first before acting.")
      (ask-clarification "REQUIRED: Ask the user a clarifying question. Your primary output MUST include a send command with a question.")
      ($other            "REQUIRED: Act according to your current motivational state and the STEP_POLICY above.")
   ))
)

;; Look up directive guidance text from registry.
(= (directiveGuidance $directive)
    (let $res (collapse (match &self (DirectiveText $directive $text) $text))
        (if (== $res ()) "" (car-atom $res)))
)

;; standard OmegaClaw prompt structure.
(= (getContext)
   (let* (
      ($decisionResult (motivationContextBlock))
      ($_ (println! (MOTIVATION-CONTEXT-BLOCK: $decisionResult)))
      ((decision $selectedCand $mode $directive $score) $decisionResult)
      ($guidance    (directiveGuidance $directive))
      ($instruction (candidateInstruction $selectedCand))
   )
   (eval (string-safe
      (eval (py-str (
         "PROMPT: " (eval (getPrompt))
         " SKILLS: " (eval (getSkills))
         " OUTPUT_FORMAT: Output a single valid MeTTa s-expression list of commands."
         " Example — one command:"
         " ((send \"message\"))"
         " Example — multiple commands:"
         " ((query \"topic\") (send \"message\"))"
         " Do not output conversational text outside the expression."
         " LAST_SKILL_USE_RESULTS: " (eval (last_chars (get-state &lastresults) (maxFeedback)))
         " HISTORY: " (eval (getHistory))
         " TIME: " (eval (get_time_as_string))
         " STEP_POLICY: " $guidance
         " MOTIVATION_INSTRUCTION: " $instruction
         " MOTIVATION_DECISION: " (eval (string-safe (repr $decisionResult)))
         )))))
))

(= (initOmegaClawMotivation)
    (let* (
        ($_ (clearSpace &goal-space))
        ($_ (collapse
                (let* (
                    (($name $b) (match &self (GoalSpec $name $b) ($name $b)))
                )
                (add-atom &goal-space (goal $name $b)))))

        ($_ (collapse
                (let* (
                    (($name $w) (match &self (AntiGoalSpec $name $w) ($name $w)))
                )
                (add-atom &goal-space (anti-goal $name $w)))))

        ($_ (clearSpace &motivation-space))
        ($_ (collapse
                (let* (
                    (($name $b) (match &self (ModulatorSpec $name $b) ($name $b)))
                )
                (add-atom &motivation-space (modulator $name $b)))))

        ($_ (collapse
                (let* (
                    (($name $b) (match &self (MotiveSpec $name $b) ($name $b)))
                )
                (add-atom &motivation-space (motive $name $b)))))

        ($_ (add-atom &motivation-space (mode orient)))
        ($_ (clearSpace &self-model-space))
        ($_ (collapse
                (let* (
                    (($name $b) (match &self (SelfModelSpec $name $b) ($name $b)))
                )
                (add-atom &self-model-space (self-metric $name $b)))))
    )
        (println! "OmegaClaw Motivation Initialized via MetaMo Adapter")
    )
)

;; initialize all MotivOS spaces from registry specs
(= (motivatedOmegaclaw)
   (let* (
      ($_ (initOmegaClawMotivation))
      ($_ (collapse (clearSignals)))
      ($_ (change-state! &new-msg-flag False))
   )
   (eval (omegaclaw))))
