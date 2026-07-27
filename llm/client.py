import json
from dataclasses import dataclass
from typing import Dict, List

import numpy as np

from llm.state_types import Action, Stimulus
from llm.action_schema import DEFAULT_ACTION_ID
from llm.parser import parse_actions, parse_stimulus
from llm.gemini_client import generate_json
from llm.prompts import (
    get_action_generation_prompt,
    get_appraisal_prompt,
    get_turn_analysis_prompt,
)


@dataclass(frozen=True)
class TurnAnalysis:
    stimulus: Stimulus
    candidates: List[Action]


def query_llm_for_json(prompt: str) -> str:
    """Compatibility wrapper around the shared Gemini JSON client."""
    return generate_json(prompt)


def _fallback_stimulus(document_text: str) -> Stimulus:
    text = document_text.lower()
    novelty = 0.25 + 0.15 * sum(
        word in text for word in ["bold", "novel", "creative", "future", "autonomous"]
    )
    risk = 0.05 + 0.18 * sum(
        word in text for word in ["unsafe", "bypass", "exploit", "illegal", "weapon"]
    )
    effort = 0.10 + 0.10 * sum(
        word in text
        for word in ["compare", "formal", "technical", "detailed", "step by step"]
    )
    conduciveness = (
        0.80
        if any(word in text for word in ["summarize", "explain", "compare", "analyze"])
        else 0.55
    )
    return Stimulus(
        novelty=float(np.clip(novelty, 0.0, 1.0)),
        conduciveness=float(np.clip(conduciveness, 0.0, 1.0)),
        risk=float(np.clip(risk, 0.0, 1.0)),
        effort=float(np.clip(effort, 0.0, 1.0)),
    )


_ACTION_CATALOG = {
    "safe_answer": (
        [0, 0, 0.85, 0.15, 0.0, 0.0, 0.9, 0.1],
        0.05,
        [-0.01, 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    "guided_explore": (
        [0, 0, 0.45, 0.88, 0.82, 0.65, 0.35, 0.15],
        0.18,
        [0.02, -0.01, 0.0, 0.05, 0.06, 0.04, 0.0, 0.0],
    ),
    "ask_clarifying_question": (
        [0, 0, 0.75, 0.2, 0.1, 0.1, 0.85, 0.3],
        0.03,
        [-0.02, 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    "compare_options": (
        [0, 0, 0.8, 0.3, 0.2, 0.1, 0.8, 0.2],
        0.08,
        [-0.01, 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    "summarize_source": (
        [0, 0, 0.85, 0.1, 0.0, 0.0, 0.9, 0.1],
        0.05,
        [-0.01, 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    "decline_risky_request": (
        [0, 0, 0.3, -0.2, -0.2, 0.0, 1.0, 0.0],
        0.0,
        [0.03, -0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
}


def _catalog_action(action_id: str) -> Action:
    correlations, risk, delta_g = _ACTION_CATALOG[action_id]
    return Action(
        action_id,
        np.array(correlations, dtype=float),
        risk,
        np.array(delta_g, dtype=float),
    )


def _route_candidates(
    routing: Dict[str, float], current_mood: Dict[str, float]
) -> List[Action]:
    """Select stable candidates locally; MAGUS still makes the final choice."""
    caution = float(current_mood.get("caution", 0.5))
    arousal = float(current_mood.get("arousal", 0.5))

    if routing["unsafe"] >= 0.65:
        action_ids = ["decline_risky_request", DEFAULT_ACTION_ID]
    elif routing["ambiguity"] >= 0.65:
        action_ids = ["ask_clarifying_question", DEFAULT_ACTION_ID]
    elif routing["comparison"] >= 0.65:
        action_ids = ["compare_options", DEFAULT_ACTION_ID]
    elif routing["summarization"] >= 0.65:
        action_ids = ["summarize_source", DEFAULT_ACTION_ID]
    elif routing["exploration"] >= 0.65 or (arousal >= 0.7 and caution < 0.7):
        action_ids = ["guided_explore", DEFAULT_ACTION_ID]
    else:
        action_ids = [DEFAULT_ACTION_ID, "guided_explore"]

    return [_catalog_action(action_id) for action_id in action_ids]


def _fallback_routing(document_text: str) -> Dict[str, float]:
    text = document_text.lower()
    short_question = "?" in text and len(text.split()) < 12
    return {
        "ambiguity": 0.8 if short_question or "unclear" in text else 0.1,
        "comparison": (
            0.9
            if any(word in text for word in ["compare", "versus", " vs ", "tradeoff", "options"])
            else 0.1
        ),
        "summarization": (
            0.9
            if any(word in text for word in ["summarize", "summary", "paper", "book", "source"])
            else 0.1
        ),
        "exploration": (
            0.8
            if any(word in text for word in ["bold", "creative", "future", "autonomous", "improve"])
            else 0.2
        ),
        "unsafe": (
            0.95
            if any(word in text for word in ["unsafe", "bypass", "exploit", "illegal", "weapon"])
            else 0.05
        ),
    }


def _fallback_candidates(
    document_text: str, current_mood: Dict[str, float]
) -> List[Action]:
    return _route_candidates(_fallback_routing(document_text), current_mood)


def _unit_float(value) -> float:
    return float(np.clip(float(value), 0.0, 1.0))


def get_turn_analysis(
    document_text: str, current_mood: Dict[str, float]
) -> TurnAnalysis:
    """Produce stimulus and locally routed candidates with one Gemini request."""
    prompt = get_turn_analysis_prompt(document_text, current_mood)
    try:
        payload = json.loads(generate_json(prompt))
        stimulus_payload = payload["stimulus"]
        routing_payload = payload["routing"]
        stimulus = Stimulus(
            novelty=_unit_float(stimulus_payload["novelty"]),
            conduciveness=_unit_float(stimulus_payload["conduciveness"]),
            risk=_unit_float(stimulus_payload["risk"]),
            effort=_unit_float(stimulus_payload["effort"]),
        )
        routing = {
            name: _unit_float(routing_payload[name])
            for name in (
                "ambiguity",
                "comparison",
                "summarization",
                "exploration",
                "unsafe",
            )
        }
        return TurnAnalysis(stimulus, _route_candidates(routing, current_mood))
    except Exception as error:
        print(f"[LLM fallback] Turn analysis is using local heuristics: {error}")
        return TurnAnalysis(
            _fallback_stimulus(document_text),
            _fallback_candidates(document_text, current_mood),
        )


def get_stimulus_from_text(document_text: str) -> Stimulus:
    """Pipeline: Text -> Prompt -> Gemini -> Parser -> Stimulus"""
    prompt = get_appraisal_prompt(document_text)
    try:
        json_response = query_llm_for_json(prompt)
        return parse_stimulus(json_response)
    except Exception as error:
        print(f"[LLM fallback] Stimulus appraisal is using local heuristics: {error}")
        return _fallback_stimulus(document_text)


def get_candidates_from_text(
    document_text: str, current_mood: Dict[str, float]
) -> List[Action]:
    """Pipeline: Text + Mood -> Prompt -> Gemini -> Parser -> Actions"""
    prompt = get_action_generation_prompt(document_text, current_mood)
    try:
        json_response = query_llm_for_json(prompt)
        return parse_actions(json_response)
    except Exception as error:
        print(f"[LLM fallback] Candidate generation is using local heuristics: {error}")
        return _fallback_candidates(document_text, current_mood)
