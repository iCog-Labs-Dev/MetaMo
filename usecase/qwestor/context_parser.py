from __future__ import annotations

import json
import re
from collections.abc import Mapping
from typing import Any


CONTEXT_KEYS = (
    "complexity",
    "specificity",
    "ambiguity",
    "requested_threshold",
    "urgency",
    "user_expertise",
    "topic_familiarity",
    "failure_pressure",
    "verification",
    "reflective_intent",
    "external_evidence",
    "task_plan",
    "multi_source",
    "signed_valence",
    "additional_information_expected",
    "intent_type",
    "query_type",
)

CONTEXT_ALIASES = {
    "requested_threshold": ("requested_threshold", "threshold"),
    "urgency": ("urgency", "urgent"),
    "user_expertise": ("user_expertise", "expertise"),
    "failure_pressure": ("failure_pressure", "failure_signal"),
    "verification": ("verification", "verification_request", "verify_request"),
    "external_evidence": ("external_evidence", "needs_external_evidence"),
    "task_plan": ("task_plan", "needs_task_plan"),
    "multi_source": ("multi_source", "needs_multi_source_integration"),
    "signed_valence": ("signed_valence", "valence"),
    "additional_information_expected": (
        "additional_information_expected",
        "awaiting_information",
        "more_information_expected",
    ),
}


def clampUnit(value: Any, default: float = 0.0) -> float:
    """Convert a value to a float in the closed unit interval."""
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        numeric = default
    return max(0.0, min(1.0, numeric))


def clampSigned(value: Any, default: float = 0.0) -> float:
    """Convert a value to a float in the closed signed unit interval."""
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        numeric = default
    return max(-1.0, min(1.0, numeric))


def coerceBoolean(value: Any, default: bool = False) -> bool:
    """Convert common boolean encodings without accepting arbitrary strings."""
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"true", "yes", "y", "1"}:
            return True
        if normalized in {"false", "no", "n", "0"}:
            return False
    return default


def extractJsonObject(payload: str) -> dict[str, Any] | None:
    """Extract the first JSON object from plain or fenced provider text."""
    if not isinstance(payload, str):
        return None
    text = payload.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\s*```$", "", text)
    try:
        value = json.loads(text)
        return value if isinstance(value, dict) else None
    except json.JSONDecodeError:
        pass
    decoder = json.JSONDecoder()
    for index, token in enumerate(text):
        if token != "{":
            continue
        try:
            value, _ = decoder.raw_decode(text[index:])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            return value
    return None


def neutralContext() -> dict[str, Any]:
    """Return a new canonical neutral-context dictionary."""
    return {
        "complexity": 0.30,
        "specificity": 0.50,
        "ambiguity": 0.00,
        "requested_threshold": 0.30,
        "urgency": 0.00,
        "user_expertise": 0.50,
        "topic_familiarity": 0.50,
        "failure_pressure": 0.30,
        "verification": 0.00,
        "reflective_intent": 0.50,
        "external_evidence": 0.30,
        "task_plan": 0.20,
        "multi_source": 0.30,
        "signed_valence": 0.00,
        "additional_information_expected": 0.00,
        "intent_type": "mixed",
        "query_type": "unknown",
    }


def contextValue(rawContext: Mapping[str, Any], name: str, default: Any) -> Any:
    """Read a canonical signal through its accepted aliases."""
    aliases = CONTEXT_ALIASES.get(name, (name,))
    for alias in aliases:
        if alias in rawContext:
            return rawContext[alias]
    return default


def normalizeContext(rawContext: Mapping[str, Any] | None) -> dict[str, Any]:
    """Normalize provider data into the canonical Qwestor context schema."""
    defaults = neutralContext()
    source = rawContext if isinstance(rawContext, Mapping) else {}
    normalized = {
        "complexity": clampUnit(contextValue(source, "complexity", defaults["complexity"]), defaults["complexity"]),
        "specificity": clampUnit(contextValue(source, "specificity", defaults["specificity"]), defaults["specificity"]),
        "ambiguity": clampUnit(contextValue(source, "ambiguity", defaults["ambiguity"]), defaults["ambiguity"]),
        "requested_threshold": clampUnit(contextValue(source, "requested_threshold", defaults["requested_threshold"]), defaults["requested_threshold"]),
        "urgency": clampUnit(contextValue(source, "urgency", defaults["urgency"]), defaults["urgency"]),
        "user_expertise": clampUnit(contextValue(source, "user_expertise", defaults["user_expertise"]), defaults["user_expertise"]),
        "topic_familiarity": clampUnit(contextValue(source, "topic_familiarity", defaults["topic_familiarity"]), defaults["topic_familiarity"]),
        "failure_pressure": clampUnit(contextValue(source, "failure_pressure", defaults["failure_pressure"]), defaults["failure_pressure"]),
        "verification": 1.0 if coerceBoolean(contextValue(source, "verification", defaults["verification"])) else 0.0,
        "reflective_intent": clampUnit(contextValue(source, "reflective_intent", defaults["reflective_intent"]), defaults["reflective_intent"]),
        "external_evidence": clampUnit(contextValue(source, "external_evidence", defaults["external_evidence"]), defaults["external_evidence"]),
        "task_plan": clampUnit(contextValue(source, "task_plan", defaults["task_plan"]), defaults["task_plan"]),
        "multi_source": clampUnit(contextValue(source, "multi_source", defaults["multi_source"]), defaults["multi_source"]),
        "signed_valence": clampSigned(contextValue(source, "signed_valence", defaults["signed_valence"]), defaults["signed_valence"]),
        "additional_information_expected": 1.0 if coerceBoolean(contextValue(source, "additional_information_expected", defaults["additional_information_expected"])) else 0.0,
    }
    intentType = str(contextValue(source, "intent_type", defaults["intent_type"])).strip().lower()
    normalized["intent_type"] = intentType if intentType in {"factual", "reflective", "mixed"} else "mixed"
    queryType = str(contextValue(source, "query_type", defaults["query_type"])).strip().lower()
    normalized["query_type"] = queryType or "unknown"
    return normalized


def parseContextPayload(payload: str | Mapping[str, Any] | None) -> dict[str, Any]:
    """Parse provider output and return neutral values on malformed input."""
    if isinstance(payload, Mapping):
        return normalizeContext(payload)
    extracted = extractJsonObject(payload) if isinstance(payload, str) else None
    return normalizeContext(extracted)


def contextPairs(context: Mapping[str, Any]) -> list[list[Any]]:
    """Return canonical context values in deterministic MeTTa pair order."""
    normalized = normalizeContext(context)
    return [[name, normalized[name]] for name in CONTEXT_KEYS]


def parseContextPairs(payload: str | Mapping[str, Any] | None) -> list[list[Any]]:
    """Parse provider output directly into deterministic MeTTa pairs."""
    return contextPairs(parseContextPayload(payload))
