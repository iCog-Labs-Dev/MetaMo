; Changes Qwestor's 7 cognitive actions into MetaMo's action format:
;
;   (action $id $goalCorrelations $riskEstimate $deltaG)
;
; Goal vector index mapping:
;   0  gInd   – individuation 
;   1  gTrans – transcendence 
;   2  gHelp  – helpfulness
;   3  gCurio – curiosity
;   4  gNovel – novelty seeking
;   5  gSelf  – self-improvement
;   6  gEthic – ethical alignment
;   7  gSoc   – social alignment
;
; What each action represents:- 
;   - act_respond: high helpfulness/social alignment for direct known answers
;   - act_search: high curiosity/novelty, with rabbit-hole anti-goal exposure
;   - act_verify: high safety/honesty alignment for risky or disputed claims
;   - act_clarify: high helpfulness/social alignment for underspecified requests
;   - act_decompose: high helpfulness/self-improvement for ordered plans
;   - act_think: high self-improvement/novelty for reflective reasoning
;   - act_synthesize: balanced integration across sources/viewpoints
;; Qwestor wrapper definitions

(: QwestorActionType Type)
(: QwestorAction
   (-> Symbol ActionType QwestorActionType))

(: QwestorAntiGoalExposureType Type)
(: QwestorAntiGoalExposure
   (-> Symbol Expression QwestorAntiGoalExposureType))

(: qwestorCandidatesForSpace
   (-> Atom Expression))

(: qwestorCandidatesForContext
   (-> Expression Expression))

(: qwestorCandidatesForContextAndSpace
   (-> Atom Expression Expression))

(QwestorAction act_respond
  (action act_respond
    (0.45 0.05 0.95 0.05 0.00 0.30 0.55 0.85)
    0.08
    (0.01 0.00 0.04 -0.01 -0.02 0.01 0.02 0.04)
  )
)

(QwestorAction act_search
  (action act_search
    (0.20 0.75 0.45 0.90 0.70 0.35 0.20 0.15)
    0.18
    (0.00 0.04 0.01 0.05 0.04 0.01 0.00 -0.01)
  )
)

(QwestorAction act_verify
  (action act_verify
    (0.90 0.05 0.65 0.05 0.00 0.30 1.00 0.35)
    0.04
    (0.05 0.00 0.01 -0.01 -0.02 0.02 0.07 0.00)
  )
)

(QwestorAction act_clarify
  (action act_clarify
    (0.55 0.05 0.85 0.05 0.00 0.25 0.65 1.00)
    0.04
    (0.02 0.00 0.04 -0.01 -0.02 0.02 0.03 0.06)
  )
)

(QwestorAction act_decompose
  (action act_decompose
    (0.35 0.70 0.95 0.35 0.20 0.85 0.45 0.35) 
    0.12
    (0.01 0.05 0.03 0.02 0.01 0.05 0.01 0.02)
  )
)

(QwestorAction act_think
  (action act_think
    (0.35 0.55 0.45 0.75 0.75 0.95 0.35 0.25) 
    0.18
    (0.01 0.06 0.00 0.04 0.04 0.06 0.01 0.00)
  )
)

(QwestorAction act_synthesize
  (action act_synthesize
    (0.30 0.65 0.65 0.75 0.50 0.75 0.45 0.55)
    0.18
    (0.00 0.04 0.03 0.03 0.02 0.04 0.02 0.03)
  )
)

; Anti-goal exposure mapping:
;   (hallucinate redundant rabbit_hole premature)
; These values do not replace MAGUS scoring. They only adjust one part of 
; the action—the risk estimate.

(QwestorAntiGoalExposure act_respond    (0.45 0.15 0.05 0.65))
(QwestorAntiGoalExposure act_search     (0.25 0.30 0.85 0.10))
(QwestorAntiGoalExposure act_verify     (0.05 0.20 0.15 0.05))
(QwestorAntiGoalExposure act_clarify    (0.10 0.05 0.05 0.10))
(QwestorAntiGoalExposure act_decompose  (0.10 0.25 0.25 0.15))
(QwestorAntiGoalExposure act_think      (0.20 0.15 0.45 0.20))
(QwestorAntiGoalExposure act_synthesize (0.35 0.30 0.50 0.25))

; convenience accessor  
; Returns the MetaMo action atom for a given Qwestor action symbol
;
; Example:
;   (qwestorActionAtom act_search)
;   → (action act_search (0.10 0.65 ...) 0.10 (...))
(= (getQwestorActionValue $name)
  (match &self (QwestorAction $name $atom) $atom)
)

; full candidate list 
; Returns all 7 action atoms which will be used in magusDecide 
(= (qwestorCandidates)
  (
    (getQwestorActionValue act_respond)
    (getQwestorActionValue act_search)
    (getQwestorActionValue act_verify)
    (getQwestorActionValue act_clarify)
    (getQwestorActionValue act_decompose)
    (getQwestorActionValue act_think)
    (getQwestorActionValue act_synthesize)
  )
)

(= (qwestorAntiGoalValues $space)
  (
    (getAntiGoal $space hallucinate)
    (getAntiGoal $space redundant)
    (getAntiGoal $space rabbit_hole)
    (getAntiGoal $space premature)
  )
)
; Risk adjustment
; Risk now depends on current motivational state instead of being fixed. 
; adjusted risk = base_risk + 0.25 (current_anti-goal_vector . action_exposure_vector)

; Example if hallucinate = high, then respond automatically becomes more risky. 

(= (qwestorActionWithAntiGoals $space (action $id $goalCorrelations $riskEstimate $deltaG))
  (let*
    (
      ($anti-values (qwestorAntiGoalValues $space))
      ($exposure (match &self (QwestorAntiGoalExposure $id $values) $values))
      ($anti-pressure (eval (dotProduct $anti-values $exposure)))
      ($adjusted-risk (eval (clampToUnitInterval (+ $riskEstimate (* 0.25 $anti-pressure)))))
    )
    (action $id $goalCorrelations $adjusted-risk $deltaG)
  )
)

(= (qwestorApplyAntiGoalsToCandidates $space $candidates)
  (if (== $candidates ())
      ()
      (let*
        (
          (($candidate $rest) (decons $candidates))
          ($adjusted (qwestorActionWithAntiGoals $space $candidate))
        )
        (cons-atom $adjusted (qwestorApplyAntiGoalsToCandidates $space $rest))
      )
  )
)

(= (qwestorCandidatesForSpace $space)
  (qwestorApplyAntiGoalsToCandidates $space (qwestorCandidates))
)
; When the request is unclear, clarification is prioritised over exploration or planning.
(= (qwestorDefaultCandidates)
  (
    (getQwestorActionValue act_respond)
    (getQwestorActionValue act_verify)
  )
)

; Verification context
; The planner focuses immediately on verification-related behaviours instead of evaluating unrelated actions.
(= (qwestorVerifyCandidates)
  (
    (getQwestorActionValue act_verify)
    (getQwestorActionValue act_search)
    (getQwestorActionValue act_clarify)
    (getQwestorActionValue act_respond)
  )
)

; Clarification context
; When the request is unclear, clarification is prioritised over exploration or planning.
(= (qwestorClarifyCandidates)
  (
    (getQwestorActionValue act_clarify)
    (getQwestorActionValue act_respond)
  )
)

; Search context
; Search-oriented actions are emphasised when  external information is needed.
(= (qwestorSearchCandidates)
  (
    (getQwestorActionValue act_search)
    (getQwestorActionValue act_verify)
  )
)

; Planning context
; The system favours structured planning before attempting a direct response.
(= (qwestorDecomposeCandidates)
  (
    (getQwestorActionValue act_decompose)
    (getQwestorActionValue act_think)
    (getQwestorActionValue act_respond)
  )
)

; Synthesis context
; Tasks that require combining multiple perspectives prioritise synthesis while still allowing supporting actions.
(= (qwestorSynthesizeCandidates)
  (
    (getQwestorActionValue act_synthesize)
    (getQwestorActionValue act_search)
    (getQwestorActionValue act_think)
    (getQwestorActionValue act_verify)
    (getQwestorActionValue act_respond)
  )
)
; Reflection context
; Complex or analytical requests encourage deeper reasoning before responding.
(= (qwestorThinkCandidates)
  (
    (getQwestorActionValue act_think)
    (getQwestorActionValue act_decompose)
    (getQwestorActionValue act_respond)
  )
)
; Candidate filtering
; The context determines which actions are considered first.
(= (qwestorCandidatesForContext $context-list)
  (let*
    (
      ($ambiguity               (findByKey ambiguity $context-list))
      ($threshold               (findByKey threshold $context-list))
      ($failure_signal          (findByKey failure_signal $context-list))
      ($verify_request          (findByKey verify_request $context-list))
      ($needs_external_evidence (findByKey needs_external_evidence $context-list))
      ($needs_task_plan         (findByKey needs_task_plan $context-list))
      ($needs_multi_source      (findByKey needs_multi_source_integration $context-list))
      ($reflective_intent       (findByKey reflective_intent $context-list))
      ($complexity              (findByKey complexity $context-list))
    )
    (if (or (== $verify_request 1) (or (> $threshold 0.75) (> $failure_signal 0.65)))
        (qwestorVerifyCandidates)
        (if (> $ambiguity 0.65)
            (qwestorClarifyCandidates)
            (if (> $needs_task_plan 0.65)
                (qwestorDecomposeCandidates)
                (if (> $needs_external_evidence 0.65)
                    (qwestorSearchCandidates)
                    (if (> $needs_multi_source 0.65)
                        (qwestorSynthesizeCandidates)
                        (if (or (> $reflective_intent 0.65) (> $complexity 0.65))
                            (qwestorThinkCandidates)
                            (qwestorDefaultCandidates)
                        )
                    )
                )
            )
        )
    )
  )
)

(= (qwestorCandidatesForContextAndSpace $space $context-list)
  (qwestorApplyAntiGoalsToCandidates $space (qwestorCandidatesForContext $context-list))
)