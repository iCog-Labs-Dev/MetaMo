

; config file for aplha, modulators , context values (for case where the context parser fails), goals and anti-goal 

; ─────────────────────────────────────────────
; Alpha hyper-parameters (learning rates)
; ─────────────────────────────────────────────
(= (alpha)
  (
    (urgency_alpha              0.60)
    (resolution_alpha           0.45)
    (expertise_alpha            0.45)
    (threshold_alpha            0.40)
    (familiarity_alpha          0.35)
    (failure_alpha              0.55)
    (failure_decay              0.20)
    (securing_alpha             0.45)
    (approach_alpha             0.40)
    (arousal_alpha              0.40)
    (risk_aversion_alpha        0.45)
    (error_tolerance_alpha      0.40)
    (creativity_alpha           0.40)
    (valence_alpha              0.40)
    (goal_alpha                 0.18)
    (anti_goal_alpha            0.16)
    (cold_start_horizon         2.0)
    (cold_start_strength        0.70)
    (decompose_min_complexity   0.60)
    (decompose_urgent_min_complexity 0.70)
    (decompose_max_ambiguity    0.70)
    (reflective_think_bonus     0.14)
    (reflective_search_penalty  0.10)
    (intent_margin              0.12)
    (enable_homeostasis         0)
    (homeostasis_theta_safe     0.55)
    (homeostasis_eta            0.05)
    (homeostasis_alpha_near     0.10)
  )
)


; ─────────────────────────────────────────────
; Default modulator vector (13 modulators)
; ─────────────────────────────────────────────
(= (default-mods) (
         modulator-vector
        (m_urgency           0.20)
        (m_resolution        0.40)
        (m_user_expertise    0.50)
        (m_threshold         0.30)
        (m_topic_familiarity 0.50)
        (m_failure_wariness  0.10)
        (m_securing          0.10)
        (m_approach          0.40)
        (m_arousal           0.40)
        (m_risk_aversion     0.40)
        (m_error_tolerance   0.45)
        (m_creativity        0.45)
        (m_valence           0.00)
))

; ─────────────────────────────────────────────
; Default context values
; ─────────────────────────────────────────────
(= (context)(
   ; core signals
   (complexity              0.30)
   (threshold               0.30)
   (ambiguity               0.00)
   (urgent                  0.00)
   (intent_type             mixed)
   ; user and topic
   (expertise               0.50)
   (topic_familiarity       0.50)   
   (failure_signal          0.30)
   (verify_request          False)  
   ; advanced signals
   (reflective_intent       0.50)
   (needs_external_evidence 0.30)
   (needs_task_plan         0.20)
   (needs_multi_source_integration 0.30)
   (valence                 0.00)
))


; ─────────────────────────────────────────────
; Default goal vector
; ─────────────────────────────────────────────
(= (default-goals) (goal-vector
 (efficiency           0.60)
 (accuracy             0.70)
 (success_moderate     0.62)
 (knowledge            0.52)
 (novelty              0.46)           
 (success_breakthrough  0.44)          
 (coherence            0.58)
 (originality          0.48)
 (social               0.58)
 (help_short           0.55)
 (help_long            0.45)
 (over_beneficial      0.60)
 (over_safety          0.65)
 (over_honesty         0.65)
))

; ─────────────────────────────────────────────
; Default anti-goal vector
; ─────────────────────────────────────────────
(= (default-anti-goals)(anti-goals
    (hallucinate 0.35)
    (redundant   0.30)
    (rabbit_hole 0.28)
    (premature   0.30)
))

