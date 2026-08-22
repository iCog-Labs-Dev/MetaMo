!(import! &self ../helper/anti_goal_helpers)
!(import! &self ../helper/utils)
!(import! &self ../config)

!(bind! &space (new-space))
!(addState &space ((default-goals) (default-mods) (default-anti-goals)))


; matchValue: returns the canonical pair for a known modulator name.
!(test
	(matchValue m_threshold
		((m_urgency 0.20) (m_resolution 0.40) (m_user_expertise 0.50)
		 (m_threshold 0.30) (m_topic_familiarity 0.50) (m_failure_wariness 0.10)
		 (m_securing 0.10) (m_approach 0.40) (m_arousal 0.40)
		 (m_risk_aversion 0.40) (m_error_tolerance 0.45) (m_creativity 0.45)
		 (m_valence 0.00)))
	(m_threshold 0.30)
)

; matchValue: returns the fallback string for an unknown name.
!(test
	(matchValue m_unknown
		((m_urgency 0.20) (m_resolution 0.40) (m_user_expertise 0.50)))
	"value not found"
)

; getMod: reads the requested modulator value from the current space.
!(test
	(getMod &space m_creativity)
	0.45
)

; getSingleGoal: reads the requested goal value from the current space.
!(test
	(getSingleGoal &space efficiency)
	0.60
)

; getAntiGoal: reads the requested anti-goal value from the current space.
!(test
	(getAntiGoal &space rabbit_hole)
	0.28
)
; matchAntiGoalValue: returns the canonical pair for a known anti-goal name.
!(test 
	(matchAntiGoalValue redundant 
	(
        (hallucinate 0.35)
        (redundant   0.30)
        (rabbit_hole 0.28)
        (premature   0.30)
    ))
    (redundant 0.3)
)
