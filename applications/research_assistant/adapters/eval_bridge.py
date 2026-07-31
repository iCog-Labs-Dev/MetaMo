"""Serialization bridge for the MeTTa Research Assistant eval bench.

This module is intentionally boring: it timestamps cases and emits JSON lines
for the outer batch runner.  It does not import, reimplement, or decide over
MetaMo motivational semantics.
"""

from __future__ import annotations

import json
import time
from typing import Any


CASE_PREFIX = "__METAMO_EVAL_CASE__ "
DIAGNOSTICS_PREFIX = "__METAMO_EVAL_DIAGNOSTICS__ "

PERCEPTION_KEYS = (
    "stimulus_novelty",
    "stimulus_conduciveness",
    "stimulus_risk",
    "stimulus_effort",
    "task_intent",
    "ambiguity",
    "citation_need",
    "comparison_need",
    "summary_need",
    "exploration_need",
    "unsafe_pressure",
    "privacy_pressure",
    "unsupported_claim_pressure",
    "context_loss_pressure",
)

_CASE_STARTS: dict[str, float] = {}


def _text(value: Any) -> str:
    """Return a stable string for a MeTTa/Python bridge value.

    Example:
        _text("safe_answer") == "safe_answer"
    """
    if value is None:
        return ""
    return str(value)


def _number(value: Any) -> float:
    """Return a float for a MeTTa/Python bridge value.

    Example:
        _number("0.5") == 0.5
    """
    return float(value)


def _truth(value: Any) -> bool:
    """Return a Python bool for a MeTTa/Python bridge value.

    Example:
        _truth("True") is True
    """
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() == "true"


def _normalized_actions(value: Any) -> list[str]:
    """Normalize expected/acceptable action strings.

    Example:
        _normalized_actions("safe_answer|compare_options") == ["safe_answer", "compare_options"]
    """
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return [_text(item).strip() for item in value if _text(item).strip()]
    text = _text(value)
    for separator in ("|", ";", ","):
        if separator in text:
            return [part.strip() for part in text.split(separator) if part.strip()]
    return [text.strip()] if text.strip() else []


def _adjustments_text(value: Any) -> str:
    """Format calibration adjustment markers like the Python eval runner.

    Example:
        _adjustments_text(["a", "b"]) == "a | b"
    """
    if value is None:
        return ""
    if isinstance(value, (list, tuple)):
        return " | ".join(_text(item) for item in value)
    text = _text(value).strip()
    if text in {"", "()"}:
        return ""
    if text.startswith("(") and text.endswith(")"):
        inner = text[1:-1].strip()
        return " | ".join(part for part in inner.split() if part)
    return text


def _emit(prefix: str, payload: dict[str, Any]) -> bool:
    print(prefix + json.dumps(payload, ensure_ascii=False, sort_keys=True), flush=True)
    return True


def start_case(case_id: Any) -> bool:
    """Start timing one eval case.

    Example:
        start_case("case_1") is True
    """
    _CASE_STARTS[_text(case_id)] = time.perf_counter()
    return True


def emit_case_result(
    case_id: Any,
    task_type: Any,
    risk_label: Any,
    paper_path: Any,
    query: Any,
    expected_action: Any,
    acceptable_actions_value: Any,
    action_id: Any,
    curiosity_action: Any,
    ethics_action: Any,
    individuation: Any,
    transcendence: Any,
    simulation_error: Any,
    lax_error: Any,
    self_model_drift: Any,
    calibration_adjustments: Any,
    response_text: Any,
    raw_stimulus_novelty: Any,
    raw_stimulus_conduciveness: Any,
    raw_stimulus_risk: Any,
    raw_stimulus_effort: Any,
    raw_task_intent: Any,
    raw_ambiguity: Any,
    raw_citation_need: Any,
    raw_comparison_need: Any,
    raw_summary_need: Any,
    raw_exploration_need: Any,
    raw_unsafe_pressure: Any,
    raw_privacy_pressure: Any,
    raw_unsupported_claim_pressure: Any,
    raw_context_loss_pressure: Any,
    calibrated_stimulus_novelty: Any,
    calibrated_stimulus_conduciveness: Any,
    calibrated_stimulus_risk: Any,
    calibrated_stimulus_effort: Any,
    calibrated_task_intent: Any,
    calibrated_ambiguity: Any,
    calibrated_citation_need: Any,
    calibrated_comparison_need: Any,
    calibrated_summary_need: Any,
    calibrated_exploration_need: Any,
    calibrated_unsafe_pressure: Any,
    calibrated_privacy_pressure: Any,
    calibrated_unsupported_claim_pressure: Any,
    calibrated_context_loss_pressure: Any,
) -> bool:
    """Emit one Python-runner-compatible case row as JSON.

    Example:
        emit_case_result("c", "", "", "", "q", "safe_answer", "safe_answer", "safe_answer", "a", "b", 0.5, 0.5, 0, 0, 0, (), "text", *([""] * 28))
    """
    case_key = _text(case_id)
    duration_s = time.perf_counter() - _CASE_STARTS.pop(case_key, time.perf_counter())
    expected = _text(expected_action)
    acceptable_actions = _normalized_actions(acceptable_actions_value)
    if expected and expected not in acceptable_actions:
        acceptable_actions.insert(0, expected)
    selected_action = _text(action_id)
    strict_match = "" if not expected or not selected_action else str(expected == selected_action)
    acceptable_match = (
        "" if not acceptable_actions or not selected_action else str(selected_action in acceptable_actions)
    )

    row: dict[str, Any] = {
        "case_id": case_key,
        "task_type": _text(task_type),
        "risk_label": _text(risk_label),
        "paper_path": _text(paper_path),
        "query": _text(query),
        "expected_action": expected,
        "acceptable_actions": "|".join(acceptable_actions),
        "action_id": selected_action,
        "action_match": strict_match,
        "strict_action_match": strict_match,
        "acceptable_action_match": acceptable_match,
        "curiosity_action": _text(curiosity_action),
        "ethics_action": _text(ethics_action),
        "individuation": _number(individuation),
        "transcendence": _number(transcendence),
        "simulation_error": _number(simulation_error),
        "lax_error": _number(lax_error),
        "self_model_drift": _number(self_model_drift),
        "calibration_adjustments": _adjustments_text(calibration_adjustments),
        "duration_s": duration_s,
        "error": "",
        "response_text": _text(response_text),
    }

    raw_values = (
        raw_stimulus_novelty,
        raw_stimulus_conduciveness,
        raw_stimulus_risk,
        raw_stimulus_effort,
        raw_task_intent,
        raw_ambiguity,
        raw_citation_need,
        raw_comparison_need,
        raw_summary_need,
        raw_exploration_need,
        raw_unsafe_pressure,
        raw_privacy_pressure,
        raw_unsupported_claim_pressure,
        raw_context_loss_pressure,
    )
    calibrated_values = (
        calibrated_stimulus_novelty,
        calibrated_stimulus_conduciveness,
        calibrated_stimulus_risk,
        calibrated_stimulus_effort,
        calibrated_task_intent,
        calibrated_ambiguity,
        calibrated_citation_need,
        calibrated_comparison_need,
        calibrated_summary_need,
        calibrated_exploration_need,
        calibrated_unsafe_pressure,
        calibrated_privacy_pressure,
        calibrated_unsupported_claim_pressure,
        calibrated_context_loss_pressure,
    )
    for prefix, values in (("raw", raw_values), ("calibrated", calibrated_values)):
        for key, value in zip(PERCEPTION_KEYS, values):
            column = f"{prefix}_{key}"
            row[column] = _text(value) if key == "task_intent" else _number(value)

    return _emit(CASE_PREFIX, row)


def emit_diagnostics_record(
    action_id: Any,
    lax_error: Any,
    lax_tolerance: Any,
    lax_holds: Any,
    contractive_holds: Any,
    target_in_safe_region: Any,
    final_in_safe_region: Any,
    boundary_pressure_before: Any,
    boundary_pressure_target: Any,
    boundary_pressure_final: Any,
    projection_delta: Any,
    target_distance: Any,
    state_drift: Any,
    self_model_drift: Any,
    combined_self_model_drift: Any,
    self_model_drift_holds: Any,
    blend_alpha: Any,
    base_blend_alpha: Any,
) -> bool:
    """Emit one diagnostics row as JSON.

    Example:
        emit_diagnostics_record("safe_answer", 0, 0.01, True, True, True, True, 0, 0, 0, 0, 0, 0, 0, 0, True, 1, 1)
    """
    row = {
        "action_id": _text(action_id),
        "lax_error": _number(lax_error),
        "lax_tolerance": _number(lax_tolerance),
        "lax_holds": _truth(lax_holds),
        "contractive_holds": _truth(contractive_holds),
        "target_in_safe_region": _truth(target_in_safe_region),
        "final_in_safe_region": _truth(final_in_safe_region),
        "boundary_pressure_before": _number(boundary_pressure_before),
        "boundary_pressure_target": _number(boundary_pressure_target),
        "boundary_pressure_final": _number(boundary_pressure_final),
        "projection_delta": _number(projection_delta),
        "target_distance": _number(target_distance),
        "state_drift": _number(state_drift),
        "self_model_drift": _number(self_model_drift),
        "combined_self_model_drift": _number(combined_self_model_drift),
        "self_model_drift_tolerance": "",
        "self_model_drift_holds": _truth(self_model_drift_holds),
        "blend_alpha": _number(blend_alpha),
        "base_blend_alpha": _number(base_blend_alpha),
    }
    return _emit(DIAGNOSTICS_PREFIX, row)
