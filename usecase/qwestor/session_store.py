from __future__ import annotations

import json
import math
import os
import tempfile
from pathlib import Path
from typing import Any, Mapping, Sequence


SCHEMA_ID = "qwestor"
GOAL_COUNT = 20
MODULATOR_COUNT = 13
OUTCOME_NAMES = (
    "short_help",
    "long_help",
    "grounding",
    "safety",
    "progress",
    "novel_yield",
    "original_yield",
    "breakthrough_yield",
    "coherence",
    "social_quality",
    "efficiency",
    "accuracy",
)
SNAPSHOT_KEYS = ("schema_id", "goals", "modulators", "pending_outcome")


class SessionFormatError(ValueError):
    pass


def _symbol_text(value: Any) -> str:
    text = str(value)
    if len(text) >= 2 and text[0] == text[-1] == '"':
        return text[1:-1]
    return text


def _bounded_vector(value: Any, size: int, field: str) -> list[float]:
    if not isinstance(value, Sequence) or isinstance(value, (str, bytes)):
        raise SessionFormatError(f"{field} must be a sequence")
    if len(value) != size:
        raise SessionFormatError(f"{field} must contain exactly {size} values")
    result: list[float] = []
    for item in value:
        if isinstance(item, bool) or not isinstance(item, (int, float)):
            raise SessionFormatError(f"{field} values must be numeric")
        number = float(item)
        if not math.isfinite(number) or not 0.0 <= number <= 1.0:
            raise SessionFormatError(f"{field} values must lie in [0, 1]")
        result.append(number)
    return result


def _pending_outcome(value: Any) -> dict[str, Any] | None:
    if value is None:
        return None
    if not isinstance(value, Mapping):
        raise SessionFormatError("pending_outcome must be null or an object")
    if set(value) != {"outcome_id", "values"}:
        raise SessionFormatError("pending_outcome has an invalid shape")
    outcome_id = _symbol_text(value["outcome_id"])
    if not outcome_id or outcome_id == "none":
        raise SessionFormatError("pending outcome id must be non-empty")
    values = value["values"]
    if not isinstance(values, Mapping) or set(values) != set(OUTCOME_NAMES):
        raise SessionFormatError("pending outcome fields are not canonical")
    bounded = _bounded_vector(
        [values[name] for name in OUTCOME_NAMES], len(OUTCOME_NAMES), "outcome"
    )
    return {
        "outcome_id": outcome_id,
        "values": dict(zip(OUTCOME_NAMES, bounded, strict=True)),
    }


def normalize_snapshot(value: Mapping[str, Any]) -> dict[str, Any]:
    if not isinstance(value, Mapping) or set(value) != set(SNAPSHOT_KEYS):
        raise SessionFormatError("snapshot fields are not canonical")
    schema_id = _symbol_text(value["schema_id"])
    if schema_id != SCHEMA_ID:
        raise SessionFormatError(f"unsupported schema id: {schema_id}")
    return {
        "schema_id": schema_id,
        "goals": _bounded_vector(value["goals"], GOAL_COUNT, "goals"),
        "modulators": _bounded_vector(
            value["modulators"], MODULATOR_COUNT, "modulators"
        ),
        "pending_outcome": _pending_outcome(value["pending_outcome"]),
    }


def build_snapshot(
    schema_id: Any,
    goals: Sequence[float],
    modulators: Sequence[float],
    outcome_id: Any = "none",
    outcome_values: Sequence[float] = (),
) -> dict[str, Any]:
    outcome_name = _symbol_text(outcome_id)
    pending: dict[str, Any] | None
    if outcome_name == "none":
        if len(outcome_values) != 0:
            raise SessionFormatError("none outcome cannot contain values")
        pending = None
    else:
        bounded = _bounded_vector(outcome_values, len(OUTCOME_NAMES), "outcome")
        pending = {
            "outcome_id": outcome_name,
            "values": dict(zip(OUTCOME_NAMES, bounded, strict=True)),
        }
    return normalize_snapshot(
        {
            "schema_id": _symbol_text(schema_id),
            "goals": list(goals),
            "modulators": list(modulators),
            "pending_outcome": pending,
        }
    )


def encode_snapshot(
    schema_id: Any,
    goals: Sequence[float],
    modulators: Sequence[float],
    outcome_id: Any = "none",
    outcome_values: Sequence[float] = (),
) -> str:
    snapshot = build_snapshot(
        schema_id, goals, modulators, outcome_id, outcome_values
    )
    return json.dumps(snapshot, ensure_ascii=False, separators=(",", ":"))


def decode_snapshot(payload: str) -> list[Any]:
    try:
        raw = json.loads(payload)
    except (json.JSONDecodeError, TypeError) as exc:
        raise SessionFormatError("snapshot is not valid JSON") from exc
    snapshot = normalize_snapshot(raw)
    pending = snapshot["pending_outcome"]
    if pending is None:
        return [
            snapshot["schema_id"],
            snapshot["goals"],
            snapshot["modulators"],
            "none",
            [],
        ]
    return [
        snapshot["schema_id"],
        snapshot["goals"],
        snapshot["modulators"],
        pending["outcome_id"],
        list(pending["values"].values()),
    ]


def save_snapshot(
    path: str | os.PathLike[str],
    schema_id: Any,
    goals: Sequence[float],
    modulators: Sequence[float],
    outcome_id: Any = "none",
    outcome_values: Sequence[float] = (),
) -> bool:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    payload = encode_snapshot(
        schema_id, goals, modulators, outcome_id, outcome_values
    )
    temporary_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=destination.parent,
            prefix=f".{destination.name}.",
            suffix=".tmp",
            delete=False,
        ) as handle:
            temporary_name = handle.name
            handle.write(payload)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, destination)
        temporary_name = None
    finally:
        if temporary_name is not None:
            Path(temporary_name).unlink(missing_ok=True)
    return True


def load_snapshot(path: str | os.PathLike[str]) -> list[Any]:
    payload = Path(path).read_text(encoding="utf-8")
    return decode_snapshot(payload)
