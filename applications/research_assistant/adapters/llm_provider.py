"""LLM provider adapter protocol boundary.

This file is deliberately motivationally inert: no goal, modulator, action,
appraisal, or decision imports are allowed here.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class ProviderRequest:
    """Serializable provider request."""

    prompt: str
    system_instruction: str | None = None
    json_mode: bool = False
    temperature: float = 0.2


@dataclass(frozen=True)
class ProviderResult:
    """Serializable provider result."""

    ok: bool
    text: str = ""
    error_code: str = ""
    retryable: bool = False


class ProviderTransport(Protocol):
    """Fakeable transport protocol."""

    def generate(self, request: ProviderRequest) -> ProviderResult:
        """Return a provider result for *request*."""


def redact_provider_error(result: ProviderResult) -> ProviderResult:
    """Redact provider error details.

    Example:
        redact_provider_error(ProviderResult(False, error_code="secret")).error_code == "redacted"
    """
    if result.ok:
        return result
    return ProviderResult(ok=False, error_code="redacted", retryable=result.retryable)

