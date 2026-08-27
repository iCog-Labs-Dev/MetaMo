"""Wire protocol shared by the Research Assistant eval emitter and runner.

The prefixes and JSON formatting in this module are compatibility-sensitive:
the outer runner discovers records by prefix before decoding their JSON body.
This module contains serialization only and has no motivational semantics.
"""

from __future__ import annotations

import json
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

CASE_FIELDNAMES = [
    "case_id",
    "task_type",
    "risk_label",
    "paper_path",
    "query",
    "expected_action",
    "acceptable_actions",
    "action_id",
    "action_match",
    "strict_action_match",
    "acceptable_action_match",
    "curiosity_action",
    "ethics_action",
    "individuation",
    "transcendence",
    "simulation_error",
    "lax_error",
    "self_model_drift",
    "calibration_adjustments",
    "duration_s",
    "error",
    "response_text",
]
CASE_FIELDNAMES.extend(
    [f"raw_{name}" for name in PERCEPTION_KEYS]
    + [f"calibrated_{name}" for name in PERCEPTION_KEYS]
)

DIAGNOSTICS_FIELDNAMES = [
    "action_id",
    "lax_error",
    "lax_tolerance",
    "lax_holds",
    "contractive_holds",
    "target_in_safe_region",
    "final_in_safe_region",
    "boundary_pressure_before",
    "boundary_pressure_target",
    "boundary_pressure_final",
    "projection_delta",
    "target_distance",
    "state_drift",
    "self_model_drift",
    "combined_self_model_drift",
    "self_model_drift_tolerance",
    "self_model_drift_holds",
    "blend_alpha",
    "base_blend_alpha",
]


def text(value: Any) -> str:
    """Return the stable text representation used on the eval wire."""
    if value is None:
        return ""
    return str(value)


def number(value: Any) -> float:
    """Return the numeric representation used on the eval wire."""
    return float(value)


def truth(value: Any) -> bool:
    """Return the boolean representation used on the eval wire."""
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() == "true"


def normalized_actions(value: Any) -> list[str]:
    """Normalize the accepted MeTTa action-list encodings."""
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return [text(item).strip() for item in value if text(item).strip()]
    encoded = text(value)
    for separator in ("|", ";", ","):
        if separator in encoded:
            return [part.strip() for part in encoded.split(separator) if part.strip()]
    return [encoded.strip()] if encoded.strip() else []


def adjustments_text(value: Any) -> str:
    """Format calibration adjustment markers like the Python eval runner."""
    if value is None:
        return ""
    if isinstance(value, (list, tuple)):
        return " | ".join(text(item) for item in value)
    encoded = text(value).strip()
    if encoded in {"", "()"}:
        return ""
    if encoded.startswith("(") and encoded.endswith(")"):
        inner = encoded[1:-1].strip()
        return " | ".join(part for part in inner.split() if part)
    return encoded


def encode_record(prefix: str, payload: dict[str, Any]) -> str:
    """Encode one prefix-delimited, deterministic JSON record."""
    return prefix + json.dumps(payload, ensure_ascii=False, sort_keys=True)


def emit_record(prefix: str, payload: dict[str, Any]) -> bool:
    """Write one compatible protocol record to stdout."""
    print(encode_record(prefix, payload), flush=True)
    return True