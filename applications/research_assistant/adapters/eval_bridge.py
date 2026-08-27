"""Serialization bridge for the MeTTa Research Assistant eval bench.

This module is intentionally boring: it timestamps cases and emits JSON lines
for the outer batch runner.  It does not import, reimplement, or decide over
MetaMo motivational semantics.
"""

from __future__ import annotations

import time
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any

try:
    from .eval_protocol import (
        CASE_PREFIX,
        DIAGNOSTICS_PREFIX,
        PERCEPTION_KEYS,
        adjustments_text,
        emit_record,
        normalized_actions,
        number,
        text,
        truth,
    )
except ImportError:  # PeTTa loads bridge modules by their file stem.
    from eval_protocol import (  # type: ignore[no-redef]
        CASE_PREFIX,
        DIAGNOSTICS_PREFIX,
        PERCEPTION_KEYS,
        adjustments_text,
        emit_record,
        normalized_actions,
        number,
        text,
        truth,
    )

_CASE_STARTS: dict[str, float] = {}

CASE_METADATA_FIELD_COUNT = 7
DECISION_OUTCOME_FIELD_COUNT = 10
PERCEPTION_FIELD_COUNT = len(PERCEPTION_KEYS)


@dataclass(frozen=True)
class CaseMetadata:
    """Dataset metadata for one evaluation case."""

    case_id: str
    task_type: str
    risk_label: str
    paper_path: str
    query: str
    expected_action: str
    acceptable_actions: tuple[str, ...]

    @classmethod
    def from_bridge_values(cls, values: Sequence[Any]) -> "CaseMetadata":
        if len(values) != CASE_METADATA_FIELD_COUNT:
            raise ValueError(f"expected {CASE_METADATA_FIELD_COUNT} case metadata values, got {len(values)}")
        expected = text(values[5])
        acceptable = normalized_actions(values[6])
        if expected and expected not in acceptable:
            acceptable.insert(0, expected)
        return cls(
            case_id=text(values[0]),
            task_type=text(values[1]),
            risk_label=text(values[2]),
            paper_path=text(values[3]),
            query=text(values[4]),
            expected_action=expected,
            acceptable_actions=tuple(acceptable),
        )


@dataclass(frozen=True)
class DecisionOutcome:
    """Selected action, motivational coordinates, and response payload."""

    action_id: str
    curiosity_action: str
    ethics_action: str
    individuation: float
    transcendence: float
    simulation_error: float
    lax_error: float
    self_model_drift: float
    calibration_adjustments: str
    response_text: str

    @classmethod
    def from_bridge_values(cls, values: Sequence[Any]) -> "DecisionOutcome":
        if len(values) != DECISION_OUTCOME_FIELD_COUNT:
            raise ValueError(f"expected {DECISION_OUTCOME_FIELD_COUNT} decision values, got {len(values)}")
        return cls(
            action_id=text(values[0]),
            curiosity_action=text(values[1]),
            ethics_action=text(values[2]),
            individuation=number(values[3]),
            transcendence=number(values[4]),
            simulation_error=number(values[5]),
            lax_error=number(values[6]),
            self_model_drift=number(values[7]),
            calibration_adjustments=adjustments_text(values[8]),
            response_text=text(values[9]),
        )


@dataclass(frozen=True)
class PerceptionSnapshot:
    """One raw or calibrated perception represented in protocol order."""

    values: tuple[str | float, ...]

    @classmethod
    def from_bridge_values(cls, values: Sequence[Any]) -> "PerceptionSnapshot":
        if len(values) != PERCEPTION_FIELD_COUNT:
            raise ValueError(f"expected {PERCEPTION_FIELD_COUNT} perception values, got {len(values)}")
        normalized = tuple(
            text(value) if key == "task_intent" else number(value)
            for key, value in zip(PERCEPTION_KEYS, values)
        )
        return cls(normalized)

    def columns(self, prefix: str) -> dict[str, str | float]:
        return {
            f"{prefix}_{key}": value
            for key, value in zip(PERCEPTION_KEYS, self.values)
        }


@dataclass(frozen=True)
class CaseResultInput:
    """Typed representation of the compatibility-sensitive bridge payload."""

    metadata: CaseMetadata
    outcome: DecisionOutcome
    raw_perception: PerceptionSnapshot
    calibrated_perception: PerceptionSnapshot

    @classmethod
    def from_bridge_groups(
        cls,
        metadata_values: Sequence[Any],
        outcome_values: Sequence[Any],
        raw_values: Sequence[Any],
        calibrated_values: Sequence[Any],
    ) -> "CaseResultInput":
        return cls(
            metadata=CaseMetadata.from_bridge_values(metadata_values),
            outcome=DecisionOutcome.from_bridge_values(outcome_values),
            raw_perception=PerceptionSnapshot.from_bridge_values(raw_values),
            calibrated_perception=PerceptionSnapshot.from_bridge_values(calibrated_values),
        )


def start_case(case_id: Any) -> bool:
    """Start timing one eval case.

    Example:
        start_case("case_1") is True
    """
    _CASE_STARTS[text(case_id)] = time.perf_counter()
    return True


def emit_case_result(
    metadata_values: Sequence[Any],
    outcome_values: Sequence[Any],
    raw_values: Sequence[Any],
    calibrated_values: Sequence[Any],
) -> bool:
    """Emit one Python-runner-compatible case row as JSON.

    MeTTa supplies four small field groups. They are parsed once into typed
    records so serialization logic operates on named fields.
    """
    result = CaseResultInput.from_bridge_groups(
        metadata_values,
        outcome_values,
        raw_values,
        calibrated_values,
    )
    metadata = result.metadata
    outcome = result.outcome
    ended_at = time.perf_counter()
    started_at = _CASE_STARTS.pop(metadata.case_id, ended_at)
    duration_s = ended_at - started_at
    strict_match = (
        ""
        if not metadata.expected_action or not outcome.action_id
        else str(metadata.expected_action == outcome.action_id)
    )
    acceptable_match = (
        ""
        if not metadata.acceptable_actions or not outcome.action_id
        else str(outcome.action_id in metadata.acceptable_actions)
    )

    row: dict[str, Any] = {
        "case_id": metadata.case_id,
        "task_type": metadata.task_type,
        "risk_label": metadata.risk_label,
        "paper_path": metadata.paper_path,
        "query": metadata.query,
        "expected_action": metadata.expected_action,
        "acceptable_actions": "|".join(metadata.acceptable_actions),
        "action_id": outcome.action_id,
        "action_match": strict_match,
        "strict_action_match": strict_match,
        "acceptable_action_match": acceptable_match,
        "curiosity_action": outcome.curiosity_action,
        "ethics_action": outcome.ethics_action,
        "individuation": outcome.individuation,
        "transcendence": outcome.transcendence,
        "simulation_error": outcome.simulation_error,
        "lax_error": outcome.lax_error,
        "self_model_drift": outcome.self_model_drift,
        "calibration_adjustments": outcome.calibration_adjustments,
        "duration_s": duration_s,
        "error": "",
        "response_text": outcome.response_text,
    }
    row.update(result.raw_perception.columns("raw"))
    row.update(result.calibrated_perception.columns("calibrated"))
    return emit_record(CASE_PREFIX, row)


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
        "action_id": text(action_id),
        "lax_error": number(lax_error),
        "lax_tolerance": number(lax_tolerance),
        "lax_holds": truth(lax_holds),
        "contractive_holds": truth(contractive_holds),
        "target_in_safe_region": truth(target_in_safe_region),
        "final_in_safe_region": truth(final_in_safe_region),
        "boundary_pressure_before": number(boundary_pressure_before),
        "boundary_pressure_target": number(boundary_pressure_target),
        "boundary_pressure_final": number(boundary_pressure_final),
        "projection_delta": number(projection_delta),
        "target_distance": number(target_distance),
        "state_drift": number(state_drift),
        "self_model_drift": number(self_model_drift),
        "combined_self_model_drift": number(combined_self_model_drift),
        "self_model_drift_tolerance": "",
        "self_model_drift_holds": truth(self_model_drift_holds),
        "blend_alpha": number(blend_alpha),
        "base_blend_alpha": number(base_blend_alpha),
    }
    return emit_record(DIAGNOSTICS_PREFIX, row)