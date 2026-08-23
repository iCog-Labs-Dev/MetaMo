!(import! &self ../../helper/anti_goal_helpers)
!(import! &self ../../helper/utils)  
!(import! &self ../qwestor_actions)

;Test getQwestorActionValue returns correct action atom for each action

!(test (getQwestorActionValue act_respond)
  (action act_respond
    (0.45 0.05 0.95 0.05 0.00 0.30 0.55 0.85)
    0.08
    (0.01 0.00 0.04 -0.01 -0.02 0.01 0.02 0.04))
)

!(test (getQwestorActionValue act_search)
  (action act_search
    (0.20 0.75 0.45 0.90 0.70 0.35 0.20 0.15)
    0.18
    (0.00 0.04 0.01 0.05 0.04 0.01 0.00 -0.01))
)

!(test (getQwestorActionValue act_verify)
  (action act_verify
    (0.90 0.05 0.65 0.05 0.00 0.30 1.00 0.35)
    0.04
    (0.05 0.00 0.01 -0.01 -0.02 0.02 0.07 0.00))
)

!(test (getQwestorActionValue act_clarify)
  (action act_clarify
    (0.55 0.05 0.85 0.05 0.00 0.25 0.65 1.00)
    0.04
    (0.02 0.00 0.04 -0.01 -0.02 0.02 0.03 0.06))
)

!(test (getQwestorActionValue act_decompose)
  (action act_decompose
    (0.35 0.70 0.95 0.35 0.20 0.85 0.45 0.35)
    0.12
    (0.01 0.05 0.03 0.02 0.01 0.05 0.01 0.02))
)

!(test (getQwestorActionValue act_think)
  (action act_think
    (0.35 0.55 0.45 0.75 0.75 0.95 0.35 0.25) 
    0.18
    (0.01 0.06 0.00 0.04 0.04 0.06 0.01 0.00))
)

!(test (getQwestorActionValue act_synthesize)
  (action act_synthesize
    (0.30 0.65 0.65 0.75 0.50 0.75 0.45 0.55)
    0.18
    (0.00 0.04 0.03 0.03 0.02 0.04 0.02 0.03))
)

; getQwestorAntiGoalExposureValue: fetches the exposure vector through the
!(test
  (getQwestorAntiGoalExposureValue act_respond)
  (0.45 0.15 0.05 0.65)
)

; Tests that context-based candidate filtering returns the correct action subset
; for different request contexts, including the default case and higher-priority
; search and planning scenarios.
!(test
  (qwestorCandidatesForContext
    ((ambiguity 0.0) (threshold 0.2) (failure_signal 0.0) (verify_request 0)
     (needs_external_evidence 0.0) (needs_task_plan 0.0)
     (needs_multi_source_integration 0.0) (reflective_intent 0.2) (complexity 0.2)))
  ((getQwestorActionValue act_respond)
   (getQwestorActionValue act_verify))
)

!(test
  (qwestorCandidatesForContext
    ((ambiguity 0.0) (threshold 0.2) (failure_signal 0.0) (verify_request 0)
     (needs_external_evidence 0.9) (needs_task_plan 0.0)
     (needs_multi_source_integration 0.8) (reflective_intent 0.7) (complexity 0.6)))
  ((getQwestorActionValue act_search)
   (getQwestorActionValue act_verify))
)

!(test
  (qwestorCandidatesForContext
    ((ambiguity 0.0) (threshold 0.2) (failure_signal 0.0) (verify_request 0)
     (needs_external_evidence 0.9) (needs_task_plan 0.9)
     (needs_multi_source_integration 0.8) (reflective_intent 0.8) (complexity 0.8)))
  ((getQwestorActionValue act_decompose)
   (getQwestorActionValue act_think)
   (getQwestorActionValue act_respond))
)
