from __future__ import annotations

import json
import re
from collections.abc import Mapping, Sequence
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
    "evidence_available",
    "primary_operation",
    "final_deliverable",
    "task_plan",
    "multi_source",
    "signed_valence",
    "additional_information_expected",
    "missing_required_input",
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
    "evidence_available": (
        "evidence_available",
        "required_evidence_available",
    ),
    "task_plan": ("task_plan", "needs_task_plan"),
    "multi_source": ("multi_source", "needs_multi_source_integration"),
    "signed_valence": ("signed_valence", "valence"),
    "additional_information_expected": (
        "additional_information_expected",
        "awaiting_information",
        "more_information_expected",
    ),
    "missing_required_input": (
        "missing_required_input",
        "required_input_missing",
    ),
}

PENDING_INFORMATION_KINDS = {"future_user_input", "external_event"}
AMBIGUITY_KINDS = {
    "unresolved_reference",
    "missing_operation",
    "missing_scope",
    "missing_deliverable",
    "requested_clarification",
}
MISSING_INPUT_KINDS = {
    "unresolved_reference",
    "missing_operation",
    "missing_scope",
    "missing_deliverable",
    "omitted_required_value",
    "unavailable_artifact",
    "absent_claim_content",
}
REFLECTION_KINDS = {
    "causal_analysis",
    "hypothesis_generation",
    "tradeoff_reasoning",
    "self_correction",
}
TASK_PLAN_KINDS = {
    "research_plan",
    "execution_plan",
    "procedural_decomposition",
}
INTEGRATION_SCOPES = {
    "multiple_substantive_inputs",
    "open_evidence_set",
}
FAILURE_PRESSURE_KINDS = {
    "user_correction",
    "repeated_failure",
    "contradiction_report",
}
EXTERNAL_EVIDENCE_KINDS = {
    "explicit_retrieval",
    "current_information",
    "explicit_source_requirement",
}
AVAILABLE_EVIDENCE_STATUSES = {
    "available_in_query",
    "available_in_history",
    "retained_artifact",
    "retrieved",
    "verified",
}
PRIMARY_OPERATIONS = {
    "direct_response",
    "clarification",
    "retrieval",
    "reflection",
    "decomposition",
    "verification",
    "synthesis",
    "waiting",
}
FINAL_DELIVERABLES = {
    "direct_answer",
    "clarifying_question",
    "source_findings",
    "analysis",
    "research_plan",
    "verified_assessment",
    "synthesis",
    "waiting_record",
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
        "requested_threshold": 0.00,
        "urgency": 0.00,
        "user_expertise": 0.50,
        "topic_familiarity": 0.50,
        "failure_pressure": 0.00,
        "verification": 0.00,
        "reflective_intent": 0.00,
        "external_evidence": 0.00,
        "evidence_available": 0.00,
        "primary_operation": "unknown",
        "final_deliverable": "unknown",
        "task_plan": 0.00,
        "multi_source": 0.00,
        "signed_valence": 0.00,
        "additional_information_expected": 0.00,
        "missing_required_input": 0.00,
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
        "evidence_available": 1.0 if coerceBoolean(contextValue(source, "evidence_available", defaults["evidence_available"])) else 0.0,
        "task_plan": clampUnit(contextValue(source, "task_plan", defaults["task_plan"]), defaults["task_plan"]),
        "multi_source": clampUnit(contextValue(source, "multi_source", defaults["multi_source"]), defaults["multi_source"]),
        "signed_valence": clampSigned(contextValue(source, "signed_valence", defaults["signed_valence"]), defaults["signed_valence"]),
        "additional_information_expected": 1.0 if coerceBoolean(contextValue(source, "additional_information_expected", defaults["additional_information_expected"])) else 0.0,
        "missing_required_input": 1.0 if coerceBoolean(contextValue(source, "missing_required_input", defaults["missing_required_input"])) else 0.0,
    }
    intentType = str(contextValue(source, "intent_type", defaults["intent_type"])).strip().lower()
    normalized["intent_type"] = intentType if intentType in {"factual", "reflective", "mixed"} else "mixed"
    queryType = str(contextValue(source, "query_type", defaults["query_type"])).strip().lower()
    normalized["query_type"] = queryType or "unknown"
    primaryOperation = normalizedCategory(source, "primary_operation", "unknown")
    normalized["primary_operation"] = (
        primaryOperation if primaryOperation in PRIMARY_OPERATIONS else "unknown"
    )
    finalDeliverable = normalizedCategory(source, "final_deliverable", "unknown")
    normalized["final_deliverable"] = (
        finalDeliverable if finalDeliverable in FINAL_DELIVERABLES else "unknown"
    )
    return normalized


def _normalizedEvidenceText(value: Any) -> str:
    return " ".join(str(value).strip().casefold().split())


def groundedEvidenceSpan(
    query: Any, payload: Mapping[str, Any] | None, field: str
) -> bool:
    if not isinstance(payload, Mapping):
        return False
    evidence = payload.get(field, "")
    if not isinstance(evidence, str):
        return False
    queryText = _normalizedEvidenceText(query)
    evidenceText = _normalizedEvidenceText(evidence)
    return bool(evidenceText) and evidenceText in queryText


def conversationText(conversation: Any) -> str:
    if not isinstance(conversation, Sequence) or isinstance(
        conversation, (str, bytes)
    ):
        return ""
    contents: list[str] = []
    for item in conversation:
        if isinstance(item, Mapping):
            role = _normalizedEvidenceText(item.get("role", ""))
            content = item.get("content", "")
        elif (
            isinstance(item, Sequence)
            and not isinstance(item, (str, bytes))
            and len(item) == 2
        ):
            role = _normalizedEvidenceText(item[0])
            content = item[1]
        else:
            continue
        if role in {"user", "assistant"} and str(content).strip():
            contents.append(str(content))
    return "\n".join(contents)


def conversationArtifacts(conversation: Any) -> list[dict[str, Any]]:
    artifacts: list[dict[str, Any]] = []
    if not isinstance(conversation, Sequence) or isinstance(
        conversation, (str, bytes)
    ):
        return artifacts
    marker = "QWESTOR_ARTIFACT"
    decoder = json.JSONDecoder()
    for turnIndex, item in enumerate(conversation):
        if isinstance(item, Mapping):
            role = _normalizedEvidenceText(item.get("role", ""))
            content = str(item.get("content", ""))
        elif (
            isinstance(item, Sequence)
            and not isinstance(item, (str, bytes))
            and len(item) == 2
        ):
            role = _normalizedEvidenceText(item[0])
            content = str(item[1])
        else:
            continue
        if role != "assistant":
            continue
        offset = 0
        while True:
            markerIndex = content.find(marker, offset)
            if markerIndex < 0:
                break
            payloadStart = markerIndex + len(marker)
            payloadText = content[payloadStart:].lstrip()
            try:
                artifact, consumed = decoder.raw_decode(payloadText)
            except json.JSONDecodeError:
                offset = payloadStart
                continue
            offset = payloadStart + consumed
            if not isinstance(artifact, dict):
                continue
            if artifact.get("schema", "qwestor_artifact") != "qwestor_artifact":
                continue
            normalized = dict(artifact)
            normalized["history_turn_index"] = turnIndex
            artifacts.append(normalized)
    return artifacts


def groundedConversationEvidenceSpan(
    conversation: Any, payload: Mapping[str, Any] | None, field: str
) -> bool:
    if not isinstance(payload, Mapping):
        return False
    evidence = payload.get(field, "")
    if not isinstance(evidence, str):
        return False
    historyText = _normalizedEvidenceText(conversationText(conversation))
    evidenceText = _normalizedEvidenceText(evidence)
    return bool(evidenceText) and evidenceText in historyText


def normalizedCategory(payload: Mapping[str, Any], field: str, default: str) -> str:
    value = payload.get(field, default)
    return str(value).strip().casefold().replace("-", "_")


def artifactIsAvailable(artifact: Mapping[str, Any]) -> bool:
    return (
        normalizedCategory(artifact, "status", "unavailable") == "available"
        or normalizedCategory(artifact, "evidence_status", "unavailable")
        in AVAILABLE_EVIDENCE_STATUSES
    )


def groundedHistoryArtifactReference(
    query: Any,
    conversation: Any,
    payload: Mapping[str, Any] | None,
) -> bool:
    if not isinstance(payload, Mapping):
        return False
    referenceKind = normalizedCategory(payload, "history_reference_kind", "none")
    if referenceKind not in {"latest_assistant_artifact", "named_history_artifact"}:
        return False
    if not groundedEvidenceSpan(query, payload, "history_reference_evidence"):
        return False
    subject = _normalizedEvidenceText(payload.get("history_artifact_subject", ""))
    if not subject:
        return False
    available = [
        artifact
        for artifact in conversationArtifacts(conversation)
        if artifactIsAvailable(artifact)
        and _normalizedEvidenceText(artifact.get("subject", "")) == subject
    ]
    if not available:
        return False
    if referenceKind == "named_history_artifact":
        return True
    allAvailable = [
        artifact
        for artifact in conversationArtifacts(conversation)
        if artifactIsAvailable(artifact)
    ]
    return bool(allAvailable) and available[-1] == allAvailable[-1]


def semanticContextConflicts(context: Mapping[str, Any]) -> list[str]:
    normalized = normalizeContext(context)
    operation = normalized["primary_operation"]
    conflicts: list[str] = []
    if operation == "clarification" and max(
        normalized["ambiguity"], normalized["missing_required_input"]
    ) == 0.0:
        conflicts.append("clarification_without_unresolved_input")
    if operation == "verification" and normalized["verification"] == 0.0:
        conflicts.append("verification_without_verification_signal")
    if operation == "retrieval" and normalized["external_evidence"] == 0.0:
        conflicts.append("retrieval_without_external_evidence_requirement")
    if operation == "synthesis" and normalized["multi_source"] == 0.0:
        conflicts.append("synthesis_without_multiple_inputs")
    return conflicts


def enforceQueryGroundedContext(
    query: Any,
    context: Mapping[str, Any],
    evidenceSource: Mapping[str, Any] | None = None,
    conversation: Any = (),
) -> dict[str, Any]:
    normalized = normalizeContext(context)
    source = evidenceSource if evidenceSource is not None else context
    primaryOperation = normalizedCategory(source, "primary_operation", "unknown")
    normalized["primary_operation"] = (
        primaryOperation
        if primaryOperation in PRIMARY_OPERATIONS
        and groundedEvidenceSpan(query, source, "primary_operation_evidence")
        else "unknown"
    )
    finalDeliverable = normalizedCategory(source, "final_deliverable", "unknown")
    normalized["final_deliverable"] = (
        finalDeliverable
        if finalDeliverable in FINAL_DELIVERABLES
        and groundedEvidenceSpan(query, source, "final_deliverable_evidence")
        else "unknown"
    )
    pendingKind = normalizedCategory(source, "pending_information_kind", "none")
    normalized["additional_information_expected"] = (
        1.0
        if pendingKind in PENDING_INFORMATION_KINDS
        and groundedEvidenceSpan(query, source, "pending_information_evidence")
        else 0.0
    )
    evidenceStatus = normalizedCategory(source, "evidence_status", "unavailable")
    currentEvidenceAvailable = groundedEvidenceSpan(
        query, source, "evidence_status_evidence"
    )
    historyEvidenceAvailable = groundedConversationEvidenceSpan(
        conversation, source, "evidence_status_evidence"
    )
    artifactReferenceAvailable = groundedHistoryArtifactReference(
        query, conversation, source
    )
    groundedAvailableArtifact = (
        historyEvidenceAvailable
        and any(artifactIsAvailable(item) for item in conversationArtifacts(conversation))
    )
    if evidenceStatus == "available_in_query":
        evidenceAvailable = currentEvidenceAvailable
    elif evidenceStatus in {
        "available_in_history", "retained_artifact", "retrieved", "verified"
    }:
        evidenceAvailable = historyEvidenceAvailable or artifactReferenceAvailable
    else:
        evidenceAvailable = False
    normalized["evidence_available"] = 1.0 if evidenceAvailable else 0.0
    requiredInputStatus = normalizedCategory(source, "required_input_status", "complete")
    missingInputKind = normalizedCategory(source, "missing_input_kind", "none")
    legacyHistoryResolution = groundedConversationEvidenceSpan(
        conversation, source, "history_resolution_evidence"
    )
    subjectResolved = groundedConversationEvidenceSpan(
        conversation, source, "history_subject_evidence"
    ) or artifactReferenceAvailable or groundedAvailableArtifact
    operationResolved = groundedConversationEvidenceSpan(
        conversation, source, "history_operation_evidence"
    )
    scopeResolved = groundedConversationEvidenceSpan(
        conversation, source, "history_scope_evidence"
    )
    deliverableResolved = groundedConversationEvidenceSpan(
        conversation, source, "history_deliverable_evidence"
    )
    currentOperationResolved = normalized["primary_operation"] not in {
        "unknown", "clarification"
    }
    currentDeliverableResolved = normalized["final_deliverable"] not in {
        "unknown", "clarifying_question"
    }
    historyResolutionByKind = {
        "unresolved_reference": subjectResolved or legacyHistoryResolution,
        "missing_operation": operationResolved or currentOperationResolved,
        "missing_scope": scopeResolved,
        "missing_deliverable": deliverableResolved or currentDeliverableResolved,
        "unavailable_artifact": artifactReferenceAvailable,
        "omitted_required_value": legacyHistoryResolution,
        "absent_claim_content": legacyHistoryResolution,
    }
    historyResolvesInput = historyResolutionByKind.get(missingInputKind, False)
    clarificationGap = (
        normalized["primary_operation"] == "clarification"
        and not operationResolved
        and not deliverableResolved
    )
    normalized["missing_required_input"] = (
        1.0
        if requiredInputStatus == "missing"
        and missingInputKind in MISSING_INPUT_KINDS
        and groundedEvidenceSpan(query, source, "missing_required_input_evidence")
        and (not historyResolvesInput or clarificationGap)
        else 0.0
    )

    ambiguityKind = normalizedCategory(source, "ambiguity_kind", "none")
    historyResolvesAmbiguity = {
        "unresolved_reference": subjectResolved or legacyHistoryResolution,
        "missing_operation": operationResolved or currentOperationResolved,
        "missing_scope": scopeResolved,
        "missing_deliverable": deliverableResolved or currentDeliverableResolved,
    }.get(ambiguityKind, False)
    normalized["ambiguity"] = 1.0 if (
        ambiguityKind in AMBIGUITY_KINDS
        and groundedEvidenceSpan(query, source, "ambiguity_evidence")
        and (not historyResolvesAmbiguity or clarificationGap)
    ) else 0.0

    reflectionKind = normalizedCategory(source, "reflective_intent_kind", "none")
    normalized["reflective_intent"] = 1.0 if (
        reflectionKind in REFLECTION_KINDS
        and groundedEvidenceSpan(query, source, "reflective_intent_evidence")
    ) else 0.0

    externalEvidenceKind = normalizedCategory(
        source, "external_evidence_kind", "none"
    )
    normalized["external_evidence"] = 1.0 if (
        externalEvidenceKind in EXTERNAL_EVIDENCE_KINDS
        and groundedEvidenceSpan(
            query, source, "external_evidence_request_evidence"
        )
    ) else 0.0
    if normalized["primary_operation"] not in {
        "unknown", "retrieval", "verification"
    }:
        normalized["external_evidence"] = 0.0
    if (
        normalized["primary_operation"] == "retrieval"
        and normalized["external_evidence"] == 0.0
    ):
        normalized["primary_operation"] = "unknown"

    taskPlanKind = normalizedCategory(source, "task_plan_kind", "none")
    normalized["task_plan"] = 1.0 if (
        taskPlanKind in TASK_PLAN_KINDS
        and groundedEvidenceSpan(query, source, "task_plan_evidence")
    ) else 0.0

    integrationScope = normalizedCategory(source, "integration_scope", "none")
    normalized["multi_source"] = 1.0 if (
        integrationScope in INTEGRATION_SCOPES
        and groundedEvidenceSpan(query, source, "multi_source_evidence")
    ) else 0.0

    failurePressureKind = normalizedCategory(
        source, "failure_pressure_kind", "none"
    )
    normalized["failure_pressure"] = 1.0 if (
        failurePressureKind in FAILURE_PRESSURE_KINDS
        and groundedEvidenceSpan(query, source, "failure_pressure_evidence")
    ) else 0.0
    normalized["verification"] = (
        1.0 if groundedEvidenceSpan(query, source, "verification_evidence") else 0.0
    )
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
