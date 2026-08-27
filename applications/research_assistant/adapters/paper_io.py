"""Paper IO adapter protocol boundary.

Filesystem traversal, hashing, clocks, identifiers, extraction, and atomic
persistence live here or behind injected test fakes, not in MeTTa logic.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class PaperIoRequest:
    """Serializable paper IO request."""

    operation: str
    path: str


@dataclass(frozen=True)
class PaperIoResult:
    """Serializable paper IO result."""

    ok: bool
    payload: str = ""
    error_code: str = ""


class PaperIoTransport(Protocol):
    """Fakeable paper IO transport."""

    def execute(self, request: PaperIoRequest) -> PaperIoResult:
        """Execute a paper IO request."""

