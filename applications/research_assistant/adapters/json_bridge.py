"""JSON bridge for Research Assistant MeTTa adapters.

This module owns JSON decoding/encoding only. It intentionally contains no
motivational-state, action-selection, appraisal, or decision imports.
"""

from __future__ import annotations

import json
from typing import Any


def decode_json_object(payload: str) -> dict[str, Any]:
    """Decode *payload* as a JSON object.

    Example:
        decode_json_object('{"x": 1}') == {"x": 1}
    """
    value = json.loads(payload)
    if not isinstance(value, dict):
        raise ValueError("expected a JSON object")
    return value


def encode_json_object(value: dict[str, Any]) -> str:
    """Encode a JSON object with deterministic key order.

    Example:
        encode_json_object({"x": 1}) == '{"x": 1}'
    """
    return json.dumps(value, sort_keys=True)

