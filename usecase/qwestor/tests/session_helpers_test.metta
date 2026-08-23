!(import! &self ../helper/utils)
!(import! &self ../config)
!(import! &self ../helper/session_helpers)

; updateState: replace the entire goals/modulators/anti-goals triple in a space.
!(bind! &testSpace (new-space))
!(addState &testSpace ((default-goals) (default-mods) (default-anti-goals)))
!(get-atoms &testSpace)

; test updateState
!(updateState &testSpace
  (goal-vector
    (efficiency           0.11)
    (accuracy             0.12)
    (success_moderate     0.13)
    (knowledge            0.14)
    (novelty              0.15)
    (success_breakthrough 0.16)
    (coherence            0.17)
    (originality          0.18)
    (social               0.19)
    (help_short           0.20)
    (help_long            0.21)
    (over_beneficial      0.22)
    (over_safety          0.23)
    (over_honesty         0.24)
  )
  (modulator-vector
    (m_urgency           0.25)
    (m_resolution        0.26)
    (m_user_expertise    0.27)
    (m_threshold         0.28)
    (m_topic_familiarity 0.29)
    (m_failure_wariness  0.30)
    (m_securing          0.31)
    (m_approach          0.32)
    (m_arousal           0.33)
    (m_risk_aversion     0.34)
    (m_error_tolerance   0.35)
    (m_creativity        0.36)
    (m_valence           0.37)
  )
  (anti-goals
    (hallucinate 0.05)
    (redundant   0.06)
    (rabbit_hole 0.07)
    (premature   0.08)
  )
)

!(test (getGoalQwestor &testSpace efficiency) 0.11)
!(test (getGoalQwestor &testSpace accuracy) 0.12)
!(test (getMod &testSpace m_urgency) 0.25)
!(test (getMod &testSpace m_valence) 0.37)

; test injectMotivation 
!(bind! &testSpace2 (new-space))
!(addState &testSpace2 ((default-goals) (default-mods) (default-anti-goals)))
!(injectMotivation &testSpace2
  (motivation
    (0.75 0.80 0.25 0.33 0.11 0.94 0.01 0.47)
    (0.25 0.35 0.45 0.55 0.65 0.75)
  )
)

!(test (getGoalQwestor &testSpace2 success_moderate) 0.94)
!(test (getGoalQwestor &testSpace2 knowledge) 0.33)
!(test (getGoalQwestor &testSpace2 help_short) 0.25)
!(test (getGoalQwestor &testSpace2 help_long) 0.25)
!(test (getGoalQwestor &testSpace2 over_safety) 0.75)
!(test (getGoalQwestor &testSpace2 over_honesty) 0.01)

!(test (getMod &testSpace2 m_resolution) 0.55)
!(test (getMod &testSpace2 m_threshold) 0.65)
!(test (getMod &testSpace2 m_securing) 0.75)
!(test (getMod &testSpace2 m_valence) -0.50)
!(test (getMod &testSpace2 m_urgency) 0.20)

!(test (match &testSpace2 ($g $m $a) $a)
  (anti-goals (hallucinate 0.35) (redundant 0.30) (rabbit_hole 0.28) (premature 0.30))
)
