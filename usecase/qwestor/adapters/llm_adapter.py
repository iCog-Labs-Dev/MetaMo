from __future__ import annotations

import json
import os
from typing import Any, Protocol

if __package__:
    from .provider_transport import (
        EnvironmentProviderTransport,
        ProviderResult,
        ProviderTransport,
        hasProviderConfig,
        loadProviderConfig,
    )
    from .prompt_builder import (
        OUTCOME_NAMES,
        PROMPT_ID,
        RESPONSE_METRIC_NAMES,
        atomText,
        buildEffectRequest,
        buildOutcomeRequest,
        buildPerceptionRequest,
        buildResponseEvaluationRequest,
        conservativeOutcome,
        normalizeOutcomePayload,
        normalizeResponseMetrics,
    )
    from ..context_parser import (
        contextPairs,
        enforceQueryGroundedContext,
        extractJsonObject,
        normalizeContext,
        semanticContextConflicts,
    )
else:
    from provider_transport import (
        EnvironmentProviderTransport,
        ProviderResult,
        ProviderTransport,
        hasProviderConfig,
        loadProviderConfig,
    )
    from prompt_builder import (
        OUTCOME_NAMES,
        PROMPT_ID,
        RESPONSE_METRIC_NAMES,
        atomText,
        buildEffectRequest,
        buildOutcomeRequest,
        buildPerceptionRequest,
        buildResponseEvaluationRequest,
        conservativeOutcome,
        normalizeOutcomePayload,
        normalizeResponseMetrics,
    )
    from context_parser import (
        contextPairs,
        enforceQueryGroundedContext,
        extractJsonObject,
        normalizeContext,
        semanticContextConflicts,
    )


class ProviderInvocationError(RuntimeError):
    pass


class EvidenceTransport(Protocol):
    """Retrieve host evidence for search and verification effects."""

    def retrieve(self, effectKind: str, query: str) -> str:
        """Return evidence text without making motivational decisions."""


class StaticEvidenceTransport:
    def __init__(self, evidence: str) -> None:
        self.evidence = evidence

    def retrieve(self, effectKind: str, query: str) -> str:
        return self.evidence


class QwestorLlmAdapter:
    """Connect Qwestor's neutral effect data to fakeable provider transports."""

    def __init__(
        self,
        provider: ProviderTransport,
        evidenceTransport: EvidenceTransport | None = None,
        outcomeProvider: ProviderTransport | None = None,
    ) -> None:
        self.provider = provider
        self.evidenceTransport = evidenceTransport
        self.outcomeProvider = outcomeProvider or provider
        self.independentOutcomeProvider = outcomeProvider is not None
        self.providerTrace: list[tuple[str, ProviderResult]] = []
        self.lastEvidence = ""
        self.lastResponseEvaluationError = ""
        self.lastPerceptionQuery = ""
        self.lastPerceptionPayload: dict[str, Any] = {}
        self.lastPerceptionContext: dict[str, Any] = {}

    def generate(
        self,
        transport: ProviderTransport,
        request: Any,
        operation: str,
    ) -> ProviderResult:
        result = transport.generate(request)
        self.providerTrace.append((operation, result))
        return result

    def resetRuntimeTrace(self) -> None:
        self.providerTrace.clear()
        self.lastEvidence = ""
        self.lastResponseEvaluationError = ""
        self.lastPerceptionQuery = ""
        self.lastPerceptionPayload = {}
        self.lastPerceptionContext = {}

    def runtimeSummary(self) -> dict[str, Any]:
        results = [result for _, result in self.providerTrace]
        providers = sorted(
            {result.provider_name for result in results if result.provider_name}
        )
        models = sorted({result.model_name for result in results if result.model_name})
        failed = [
            (operation, result)
            for operation, result in self.providerTrace
            if not result.ok
        ]
        return {
            "provider": ",".join(providers) or "unknown",
            "model": ",".join(models) or "unknown",
            "prompt_id": PROMPT_ID,
            "evaluator_independent": str(self.independentOutcomeProvider).lower(),
            "provider_calls": len(results),
            "latency_ms": sum(result.latency_ms for result in results),
            "input_tokens": sum(result.input_tokens for result in results),
            "output_tokens": sum(result.output_tokens for result in results),
            "cost_usd": sum(result.cost_usd for result in results),
            "failed_provider_calls": len(failed),
            "provider_failures": ",".join(
                f"{operation}:{result.error_code or 'provider_error'}"
                for operation, result in failed
            )
            or "none",
            "response_evaluation_status": (
                self.lastResponseEvaluationError or "ok"
            ),
        }

    def requireText(self, result: ProviderResult, operation: str) -> str:
        """Return successful text or raise a stable adapter-level failure."""
        if not result.ok:
            code = result.error_code or "provider_error"
            raise ProviderInvocationError(f"{operation} failed: {code}")
        text = result.text.strip()
        if not text:
            raise ProviderInvocationError(f"{operation} failed: empty_response")
        return text

    def perceptionTrace(self) -> dict[str, str]:
        return {
            "query": self.lastPerceptionQuery,
            "raw_json": json.dumps(
                self.lastPerceptionPayload, ensure_ascii=False, sort_keys=True
            ),
            "grounded_context_json": json.dumps(
                self.lastPerceptionContext, ensure_ascii=False, sort_keys=True
            ),
            "ambiguity_kind": str(
                self.lastPerceptionPayload.get("ambiguity_kind", "none")
            ),
            "ambiguity_evidence": str(
                self.lastPerceptionPayload.get("ambiguity_evidence", "")
            ),
            "failure_pressure_kind": str(
                self.lastPerceptionPayload.get("failure_pressure_kind", "none")
            ),
            "failure_pressure_evidence": str(
                self.lastPerceptionPayload.get("failure_pressure_evidence", "")
            ),
            "pending_information_kind": str(
                self.lastPerceptionPayload.get("pending_information_kind", "none")
            ),
            "pending_information_evidence": str(
                self.lastPerceptionPayload.get("pending_information_evidence", "")
            ),
            "required_input_status": str(
                self.lastPerceptionPayload.get("required_input_status", "complete")
            ),
            "missing_input_kind": str(
                self.lastPerceptionPayload.get("missing_input_kind", "none")
            ),
            "missing_required_input_evidence": str(
                self.lastPerceptionPayload.get("missing_required_input_evidence", "")
            ),
            "history_resolution_evidence": str(
                self.lastPerceptionPayload.get("history_resolution_evidence", "")
            ),
            "history_subject_evidence": str(
                self.lastPerceptionPayload.get("history_subject_evidence", "")
            ),
            "history_operation_evidence": str(
                self.lastPerceptionPayload.get("history_operation_evidence", "")
            ),
            "history_scope_evidence": str(
                self.lastPerceptionPayload.get("history_scope_evidence", "")
            ),
            "history_deliverable_evidence": str(
                self.lastPerceptionPayload.get("history_deliverable_evidence", "")
            ),
            "history_reference_kind": str(
                self.lastPerceptionPayload.get("history_reference_kind", "none")
            ),
            "history_reference_evidence": str(
                self.lastPerceptionPayload.get("history_reference_evidence", "")
            ),
            "history_artifact_subject": str(
                self.lastPerceptionPayload.get("history_artifact_subject", "")
            ),
            "integration_scope": str(
                self.lastPerceptionPayload.get("integration_scope", "none")
            ),
            "multi_source_evidence": str(
                self.lastPerceptionPayload.get("multi_source_evidence", "")
            ),
            "external_evidence_kind": str(
                self.lastPerceptionPayload.get("external_evidence_kind", "none")
            ),
            "external_evidence_request_evidence": str(
                self.lastPerceptionPayload.get(
                    "external_evidence_request_evidence", ""
                )
            ),
            "evidence_status": str(
                self.lastPerceptionPayload.get("evidence_status", "unavailable")
            ),
            "evidence_status_evidence": str(
                self.lastPerceptionPayload.get("evidence_status_evidence", "")
            ),
            "primary_operation": str(
                self.lastPerceptionPayload.get("primary_operation", "unknown")
            ),
            "primary_operation_evidence": str(
                self.lastPerceptionPayload.get("primary_operation_evidence", "")
            ),
            "final_deliverable": str(
                self.lastPerceptionPayload.get("final_deliverable", "unknown")
            ),
            "final_deliverable_evidence": str(
                self.lastPerceptionPayload.get("final_deliverable_evidence", "")
            ),
            "verification_evidence": str(
                self.lastPerceptionPayload.get("verification_evidence", "")
            ),
            "reflective_intent_kind": str(
                self.lastPerceptionPayload.get("reflective_intent_kind", "none")
            ),
            "reflective_intent_evidence": str(
                self.lastPerceptionPayload.get("reflective_intent_evidence", "")
            ),
            "task_plan_kind": str(
                self.lastPerceptionPayload.get("task_plan_kind", "none")
            ),
            "task_plan_evidence": str(
                self.lastPerceptionPayload.get("task_plan_evidence", "")
            ),
            "semantic_conflicts": ",".join(
                semanticContextConflicts(self.lastPerceptionContext)
            ) or "none",
        }

    def perceiveQuery(self, query: Any, conversation: Any = ()) -> dict[str, Any]:
        """Call the provider once and normalize its JSON into Qwestor context."""
        response = self.requireText(
            self.generate(
                self.provider,
                buildPerceptionRequest(query, conversation),
                "perception",
            ),
            "perception",
        )
        payload = extractJsonObject(response)
        if payload is None:
            raise ProviderInvocationError("perception failed: invalid_json")
        context = enforceQueryGroundedContext(
            query, normalizeContext(payload), payload, conversation
        )
        self.lastPerceptionQuery = atomText(query)
        self.lastPerceptionPayload = dict(payload)
        self.lastPerceptionContext = dict(context)
        return context

    def retrieveEvidence(self, effectKind: Any, query: Any) -> str:
        """Invoke an optional host evidence tool only for search or verification."""
        kind = atomText(effectKind)
        if kind not in {"search", "verification"} or self.evidenceTransport is None:
            self.lastEvidence = ""
            return ""
        self.lastEvidence = self.evidenceTransport.retrieve(
            kind, atomText(query)
        ).strip()
        return self.lastEvidence

    def executeEffect(
        self,
        query: Any,
        actionId: Any,
        effectKind: Any,
        styles: Any,
        stateValues: Any,
        conversation: Any = (),
    ) -> str:
        """Execute one selected Qwestor effect without changing motivational state."""
        action = atomText(actionId)
        kind = atomText(effectKind)
        if kind == "wait":
            return (
                "I’ll wait for the expected information rather than inventing progress. "
                "Once it arrives, I can continue from the preserved research state."
            )
        evidence = self.retrieveEvidence(kind, query)
        request = buildEffectRequest(
            query,
            action,
            kind,
            styles,
            stateValues,
            evidence,
            conversation,
        )
        return self.requireText(
            self.generate(self.provider, request, "effect"),
            "effect",
        )

    def assessOutcome(
        self,
        query: Any,
        response: Any,
        actionId: Any,
        effectKind: Any,
        conversation: Any = (),
    ) -> dict[str, float]:
        """Assess observable response outcomes, using conservative feedback on failure."""
        request = buildOutcomeRequest(
            query, actionId, effectKind, response, conversation
        )
        result = self.generate(self.outcomeProvider, request, "outcome")
        if not result.ok:
            return conservativeOutcome()
        payload = extractJsonObject(result.text)
        if payload is None:
            return conservativeOutcome()
        try:
            return normalizeOutcomePayload(payload)
        except (TypeError, ValueError):
            return conservativeOutcome()

    def evaluateResponse(
        self,
        query: Any,
        response: Any,
        actionId: Any,
        styles: Any,
        evidence: Any = "",
        conversation: Any = (),
    ) -> dict[str, float]:
        """Evaluate end-to-end response quality through a separately injectable provider."""
        request = buildResponseEvaluationRequest(
            query,
            response,
            actionId,
            styles,
            evidence,
            conversation,
        )
        text = self.requireText(
            self.generate(
                self.outcomeProvider,
                request,
                "response_evaluation",
            ),
            "response_evaluation",
        )
        payload = extractJsonObject(text)
        if payload is None:
            raise ProviderInvocationError("response_evaluation failed: invalid_json")
        try:
            return normalizeResponseMetrics(payload)
        except (TypeError, ValueError) as error:
            raise ProviderInvocationError(
                "response_evaluation failed: invalid_metrics"
            ) from error

    def evaluateResponseSafe(
        self,
        query: Any,
        response: Any,
        actionId: Any,
        styles: Any,
        evidence: Any = "",
        conversation: Any = (),
    ) -> dict[str, float]:
        try:
            metrics = self.evaluateResponse(
                query, response, actionId, styles, evidence, conversation
            )
            self.lastResponseEvaluationError = ""
            return metrics
        except ProviderInvocationError as error:
            self.lastResponseEvaluationError = str(error)
            print(
                f"[Live] warning={self.lastResponseEvaluationError}; "
                "continuing without response-quality scores",
                flush=True,
            )
            return {}


_DEFAULT_ADAPTER: QwestorLlmAdapter | None = None


def defaultAdapter() -> QwestorLlmAdapter:
    """Return the lazily constructed live adapter used by MeTTa bridge calls."""
    global _DEFAULT_ADAPTER
    if _DEFAULT_ADAPTER is None:
        outcomeProvider = (
            EnvironmentProviderTransport(envPrefix="OUTCOME_")
            if hasProviderConfig("OUTCOME_")
            else None
        )
        _DEFAULT_ADAPTER = QwestorLlmAdapter(
            EnvironmentProviderTransport(),
            outcomeProvider=outcomeProvider,
        )
    return _DEFAULT_ADAPTER


def setDefaultAdapter(adapter: QwestorLlmAdapter | None) -> None:
    """Inject or clear the process-local adapter for tests and host composition."""
    global _DEFAULT_ADAPTER
    _DEFAULT_ADAPTER = adapter


def resetRuntimeTrace() -> bool:
    defaultAdapter().resetRuntimeTrace()
    return True


def runtimeSummaryPairs() -> list[list[Any]]:
    return [list(item) for item in defaultAdapter().runtimeSummary().items()]


def perceptionTracePairs() -> list[list[Any]]:
    return [list(item) for item in defaultAdapter().perceptionTrace().items()]


def lastEvidenceText() -> str:
    return defaultAdapter().lastEvidence


def outcomeProviderIsIndependent() -> bool:
    return defaultAdapter().independentOutcomeProvider


def validateConfiguredProviders() -> bool:
    loadProviderConfig()
    if hasProviderConfig("OUTCOME_"):
        loadProviderConfig(prefix="OUTCOME_")
    return True


def requireIndependentOutcomeProvider() -> bool:
    if hasProviderConfig("OUTCOME_"):
        return True
    allowShared = os.environ.get(
        "QWESTOR_ALLOW_SHARED_EVALUATOR", ""
    ).strip().lower() in {"1", "true", "yes"}
    if allowShared:
        return True
    raise RuntimeError(
        "Configure OUTCOME_PROVIDER_NAME or explicitly set "
        "QWESTOR_ALLOW_SHARED_EVALUATOR=1."
    )


def setControlledEvidenceText(evidence: Any) -> bool:
    text = atomText(evidence).strip()
    defaultAdapter().evidenceTransport = StaticEvidenceTransport(text) if text else None
    return True


def perceiveQueryPairs(query: Any, conversation: Any = ()) -> list[list[Any]]:
    """Return live provider perception in canonical MeTTa pair order."""
    return contextPairs(defaultAdapter().perceiveQuery(query, conversation))


def executeEffectText(
    query: Any,
    actionId: Any,
    effectKind: Any,
    styles: Any,
    stateValues: Any,
    conversation: Any = (),
) -> str:
    """Execute a MeTTa effect request and return its user-facing text."""
    return defaultAdapter().executeEffect(
        query,
        actionId,
        effectKind,
        styles,
        stateValues,
        conversation,
    )


def assessOutcomePairs(
    query: Any,
    response: Any,
    actionId: Any,
    effectKind: Any,
    conversation: Any = (),
) -> list[list[Any]]:
    """Return assessed outcome values in the exact MeTTa schema order."""
    values = defaultAdapter().assessOutcome(
        query, response, actionId, effectKind, conversation
    )
    return [[name, values[name]] for name in OUTCOME_NAMES]


def evaluateResponsePairs(
    query: Any,
    response: Any,
    actionId: Any,
    styles: Any,
    evidence: Any = "",
    conversation: Any = (),
) -> list[list[Any]]:
    """Return independent response-quality values in canonical metric order."""
    values = defaultAdapter().evaluateResponse(
        query,
        response,
        actionId,
        styles,
        evidence,
        conversation,
    )
    return [[name, values[name]] for name in RESPONSE_METRIC_NAMES]


def evaluateResponsePairsSafe(
    query: Any,
    response: Any,
    actionId: Any,
    styles: Any,
    evidence: Any = "",
    conversation: Any = (),
) -> list[list[Any]]:
    values = defaultAdapter().evaluateResponseSafe(
        query, response, actionId, styles, evidence, conversation
    )
    return (
        [[name, values[name]] for name in RESPONSE_METRIC_NAMES]
        if values
        else []
    )
