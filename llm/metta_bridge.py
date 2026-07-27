import os
import sys

# Ensure project root is in sys.path
if __package__ in (None, ""):
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if repo_root not in sys.path:
        sys.path.insert(0, repo_root)

from typing import Dict, Any, List

# Import LLM components
from llm.client import (
    get_candidates_from_text,
    get_stimulus_from_text,
    get_turn_analysis,
)
from llm.conversation import MetaMoChatAssistant

_assistant = None

def _get_assistant() -> MetaMoChatAssistant:
    global _assistant
    if _assistant is None:
        _assistant = MetaMoChatAssistant()
    return _assistant


def _actions_as_lists(actions) -> List[List[Any]]:
    return [
        [
            str(action.id),
            action.goal_correlations.tolist(),
            float(action.risk_estimate),
            action.delta_g.tolist(),
        ]
        for action in actions
    ]


def analyze_turn_as_lists(
    text: str, arousal: float, caution: float
) -> List[Any]:
    """Return ``[stimulus_values, candidates]`` from one Gemini request."""
    current_mood = {"arousal": float(arousal), "caution": float(caution)}
    analysis = get_turn_analysis(text, current_mood)
    stimulus = analysis.stimulus
    return [
        [
            float(stimulus.novelty),
            float(stimulus.conduciveness),
            float(stimulus.risk),
            float(stimulus.effort),
        ],
        _actions_as_lists(analysis.candidates),
    ]


def get_stimulus_as_list(text: str) -> List[float]:
    """
    Calls get_stimulus_from_text and returns the Stimulus object as a flat Python list.
    Expected MeTTa format: (novelty conduciveness risk effort)
    """
    stimulus = get_stimulus_from_text(text)
    return [
        float(stimulus.novelty),
        float(stimulus.conduciveness),
        float(stimulus.risk),
        float(stimulus.effort)
    ]

def get_candidates_as_list(text: str, arousal: float, caution: float) -> List[List[Any]]:
    """
    Calls get_candidates_from_text and converts the List[Action] into a nested list.
    Expected MeTTa format for each action:
    (action_id [goal_correlations...] risk_estimate [delta_g...])
    """
    current_mood = {"arousal": float(arousal), "caution": float(caution)}
    actions = get_candidates_from_text(text, current_mood)
    
    return _actions_as_lists(actions)

def generate_final_response(user_text: str, action_id: str, ind_level: float, trans_level: float) -> str:
    """
    Generates a final response using the selected action and current state.
    Mocks a MotivationalState for the conversation assistant to use.
    """
    from llm.state_types import MotivationalState, Action, G_IND, G_TRANS, NUM_GOALS, NUM_MODULATORS
    import numpy as np
    
    assistant = _get_assistant()
    
    # Reconstruct just enough of the action and state for the conversation logger
    # Action's delta_g and goal_correlations don't matter for the response prompt, 
    # it only uses action.id
    mock_action = Action(
        id=action_id,
        goal_correlations=np.zeros(NUM_GOALS),
        risk_estimate=0.0,
        delta_g=np.zeros(NUM_GOALS)
    )
    
    mock_g = np.zeros(NUM_GOALS)
    mock_g[G_IND] = float(ind_level)
    mock_g[G_TRANS] = float(trans_level)
    
    mock_state = MotivationalState(
        G=mock_g,
        M=np.zeros(NUM_MODULATORS)
    )
    
    return assistant.generate_final_response(user_text, mock_action, mock_state)
