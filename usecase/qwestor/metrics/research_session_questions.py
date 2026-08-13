from __future__ import annotations

import hashlib
import json
from copy import deepcopy
from typing import Any

if __package__:
    from .session_hardcore_questions import SESSIONS as HARDCORE_SOURCE_SESSIONS
    from .session_medium_questions import SESSIONS as MEDIUM_SOURCE_SESSIONS
    from .session_questions import ACTION_RATIONALES
else:
    from session_hardcore_questions import SESSIONS as HARDCORE_SOURCE_SESSIONS
    from session_medium_questions import SESSIONS as MEDIUM_SOURCE_SESSIONS
    from session_questions import ACTION_RATIONALES


MEDIUM_SESSION_IDS = (
    "medium_mixed",
    "medium_ood",
    "medium_multisource",
)

HARDCORE_SESSION_IDS = (
    "hardcore_neural_icp",
    "hardcore_router",
    "hardcore_search",
    "hardcore_verify",
    "hardcore_decompose",
    "hardcore_synthesize",
    "hardcore_unified_ebm",
    "hardcore_toy_prototype",
    "hardcore_ood_metrics",
    "hardcore_contradiction",
    "hardcore_multisource",
    "hardcore_continuity",
    "hardcore_end_to_end",
)


def _auditedSessions(
    sourceSessions: list[dict[str, Any]],
    sessionIds: tuple[str, ...],
    suite: str,
) -> list[dict[str, Any]]:
    if len(sourceSessions) != len(sessionIds):
        raise ValueError(f"{suite} session-id count does not match its source")
    sessions = deepcopy(sourceSessions)
    seenCases: set[str] = set()
    for session, sessionId in zip(sessions, sessionIds, strict=True):
        queries = list(session.get("queries", ()))
        expected = list(session.get("expected_actions", ()))
        acceptable = [
            list(actions) for actions in session.get("acceptable_actions", ())
        ]
        if not queries or not (
            len(queries) == len(expected) == len(acceptable)
        ):
            raise ValueError(f"{sessionId} has mismatched or empty label vectors")
        rationales: list[str] = []
        for index, action in enumerate(expected, start=1):
            caseId = f"{sessionId}_{index:02d}"
            if caseId in seenCases:
                raise ValueError(f"duplicate research case id: {caseId}")
            seenCases.add(caseId)
            if action not in ACTION_RATIONALES:
                raise ValueError(f"{caseId} has unknown expected action: {action}")
            alternatives = acceptable[index - 1]
            if (
                action in alternatives
                or len(alternatives) != len(set(alternatives))
                or any(item not in ACTION_RATIONALES for item in alternatives)
            ):
                raise ValueError(f"{caseId} has invalid acceptable actions")
            rationales.append(ACTION_RATIONALES[action])
        session["session_id"] = sessionId
        session["benchmark_suite"] = suite
        session["rationales"] = rationales
    return sessions


QWESTOR_MEDIUM_SESSIONS = _auditedSessions(
    MEDIUM_SOURCE_SESSIONS,
    MEDIUM_SESSION_IDS,
    "medium",
)

QWESTOR_HARDCORE_SESSIONS = _auditedSessions(
    HARDCORE_SOURCE_SESSIONS,
    HARDCORE_SESSION_IDS,
    "hardcore",
)

QWESTOR_RESEARCH_SESSIONS = [
    *QWESTOR_MEDIUM_SESSIONS,
    *QWESTOR_HARDCORE_SESSIONS,
]


def benchmarkLabelDigest(sessions: list[dict[str, Any]]) -> str:
    manifest = []
    for session in sessions:
        for index, (query, expected, acceptable, rationale) in enumerate(
            zip(
                session["queries"],
                session["expected_actions"],
                session["acceptable_actions"],
                session["rationales"],
                strict=True,
            ),
            start=1,
        ):
            manifest.append(
                {
                    "case_id": f"{session['session_id']}_{index:02d}",
                    "query": query,
                    "expected_action": expected,
                    "acceptable_actions": acceptable,
                    "rationale": rationale,
                    "benchmark_suite": session["benchmark_suite"],
                }
            )
    payload = json.dumps(
        manifest, ensure_ascii=False, separators=(",", ":"), sort_keys=True
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


MEDIUM_LABEL_DIGEST = benchmarkLabelDigest(QWESTOR_MEDIUM_SESSIONS)
HARDCORE_LABEL_DIGEST = benchmarkLabelDigest(QWESTOR_HARDCORE_SESSIONS)

EXPECTED_MEDIUM_LABEL_DIGEST = (
    "32c06850221d9daf3b5bc047c8ef90e7a22ee40f993d4a33b6fffc0aa2949b91"
)
EXPECTED_HARDCORE_LABEL_DIGEST = (
    "34b1f1519e44f83639a206aedcdf2dd4dd804f7344854661f3ea578eea06be21"
)

if MEDIUM_LABEL_DIGEST != EXPECTED_MEDIUM_LABEL_DIGEST:
    raise ValueError("medium benchmark labels changed without updating the frozen digest")
if HARDCORE_LABEL_DIGEST != EXPECTED_HARDCORE_LABEL_DIGEST:
    raise ValueError("hardcore benchmark labels changed without updating the frozen digest")
