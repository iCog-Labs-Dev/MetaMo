from __future__ import annotations

from typing import Any, Protocol

from applications.research_assistant.adapters.llm_provider import (
    ProviderResult,
    ProviderTransport,
)
from usecase.qwestor.adapters.prompt_builder import (
    OUTCOME_NAMES,
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
from usecase.qwestor.adapters.provider_transport import EnvironmentProviderTransport
from usecase.qwestor.context_parser import (
    contextPairs,
    extractJsonObject,
    normalizeContext,
)


class ProviderInvocationError(RuntimeError):
    pass


class EvidenceTransport(Protocol):
    """Retrieve host evidence for search and verification effects."""

    def retrieve(self, effectKind: str, query: str) -> str:
        """Return evidence text without making motivational decisions."""


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

    def requireText(self, result: ProviderResult, operation: str) -> str:
        """Return successful text or raise a stable adapter-level failure."""
        if not result.ok:
            code = result.error_code or "provider_error"
            raise ProviderInvocationError(f"{operation} failed: {code}")
        text = result.text.strip()
        if not text:
            raise ProviderInvocationError(f"{operation} failed: empty_response")
        return text

    def perceiveQuery(self, query: Any) -> dict[str, Any]:
        """Call the provider once and normalize its JSON into Qwestor context."""
        response = self.requireText(
            self.provider.generate(buildPerceptionRequest(query)),
            "perception",
        )
        payload = extractJsonObject(response)
        if payload is None:
            raise ProviderInvocationError("perception failed: invalid_json")
        return normalizeContext(payload)

    def retrieveEvidence(self, effectKind: Any, query: Any) -> str:
        """Invoke an optional host evidence tool only for search or verification."""
        kind = atomText(effectKind)
        if kind not in {"search", "verification"} or self.evidenceTransport is None:
            return ""
        return self.evidenceTransport.retrieve(kind, atomText(query)).strip()

    def executeEffect(
        self,
        query: Any,
        actionId: Any,
        effectKind: Any,
        styles: Any,
        stateValues: Any,
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
        )
        return self.requireText(self.provider.generate(request), "effect")

    def assessOutcome(
        self,
        query: Any,
        response: Any,
        actionId: Any,
        effectKind: Any,
    ) -> dict[str, float]:
        """Assess observable response outcomes, using conservative feedback on failure."""
        request = buildOutcomeRequest(query, actionId, effectKind, response)
        result = self.outcomeProvider.generate(request)
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
    ) -> dict[str, float]:
        """Evaluate end-to-end response quality through a separately injectable provider."""
        request = buildResponseEvaluationRequest(
            query,
            response,
            actionId,
            styles,
            evidence,
        )
        text = self.requireText(
            self.outcomeProvider.generate(request),
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


_DEFAULT_ADAPTER: QwestorLlmAdapter | None = None


def defaultAdapter() -> QwestorLlmAdapter:
    """Return the lazily constructed live adapter used by MeTTa bridge calls."""
    global _DEFAULT_ADAPTER
    if _DEFAULT_ADAPTER is None:
        _DEFAULT_ADAPTER = QwestorLlmAdapter(EnvironmentProviderTransport())
    return _DEFAULT_ADAPTER


def setDefaultAdapter(adapter: QwestorLlmAdapter | None) -> None:
    """Inject or clear the process-local adapter for tests and host composition."""
    global _DEFAULT_ADAPTER
    _DEFAULT_ADAPTER = adapter


def perceiveQueryPairs(query: Any) -> list[list[Any]]:
    """Return live provider perception in canonical MeTTa pair order."""
    return contextPairs(defaultAdapter().perceiveQuery(query))


def executeEffectText(
    query: Any,
    actionId: Any,
    effectKind: Any,
    styles: Any,
    stateValues: Any,
) -> str:
    """Execute a MeTTa effect request and return its user-facing text."""
    return defaultAdapter().executeEffect(
        query,
        actionId,
        effectKind,
        styles,
        stateValues,
    )


def assessOutcomePairs(
    query: Any,
    response: Any,
    actionId: Any,
    effectKind: Any,
) -> list[list[Any]]:
    """Return assessed outcome values in the exact MeTTa schema order."""
    values = defaultAdapter().assessOutcome(query, response, actionId, effectKind)
    return [[name, values[name]] for name in OUTCOME_NAMES]


def evaluateResponsePairs(
    query: Any,
    response: Any,
    actionId: Any,
    styles: Any,
    evidence: Any = "",
) -> list[list[Any]]:
    """Return independent response-quality values in canonical metric order."""
    values = defaultAdapter().evaluateResponse(
        query,
        response,
        actionId,
        styles,
        evidence,
    )
    return [[name, values[name]] for name in RESPONSE_METRIC_NAMES]
