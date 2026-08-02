"""
Default Qwestor session configuration values.

"""
DEFAULT_GOALS = {
    "efficiency": 0.60, "accuracy": 0.70, "success_moderate": 0.62, "knowledge": 0.52,
    "novelty": 0.46, "success_breakthrough": 0.44, "coherence": 0.58, "originality": 0.48,
    "social": 0.58, "help_short": 0.55, "help_long": 0.45, "over_beneficial": 0.60,
    "over_safety": 0.65, "over_honesty": 0.65,
}
DEFAULT_MODS = {
    "m_urgency": 0.20, "m_resolution": 0.40, "m_user_expertise": 0.50, "m_threshold": 0.30,
    "m_topic_familiarity": 0.50, "m_failure_wariness": 0.10, "m_securing": 0.10,
    "m_approach": 0.40, "m_arousal": 0.40, "m_risk_aversion": 0.40,
    "m_error_tolerance": 0.45, "m_creativity": 0.45, "m_valence": 0.00,
}
DEFAULT_ANTI_GOALS = {"hallucinate": 0.35, "redundant": 0.30, "rabbit_hole": 0.28, "premature": 0.30}