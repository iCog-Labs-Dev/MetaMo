from __future__ import annotations

import json
import os
from copy import deepcopy
from typing import Any

if __package__:
    from .research_session_questions import (
        HARDCORE_LABEL_DIGEST,
        MEDIUM_LABEL_DIGEST,
        QWESTOR_HARDCORE_SESSIONS,
        QWESTOR_MEDIUM_SESSIONS,
    )
    from .session_questions import (
        QWESTOR_SESSIONS as QUESTION_SESSIONS,
        SESSION_LABEL_DIGEST,
    )
else:
    from research_session_questions import (
        HARDCORE_LABEL_DIGEST,
        MEDIUM_LABEL_DIGEST,
        QWESTOR_HARDCORE_SESSIONS,
        QWESTOR_MEDIUM_SESSIONS,
    )
    from session_questions import (
        QWESTOR_SESSIONS as QUESTION_SESSIONS,
        SESSION_LABEL_DIGEST,
    )


PERCEPTION_SUITES = {
    "session": QUESTION_SESSIONS,
    "medium": QWESTOR_MEDIUM_SESSIONS,
    "hardcore": QWESTOR_HARDCORE_SESSIONS,
}

PERCEPTION_SUITE_LABEL_DIGESTS = {
    "session": SESSION_LABEL_DIGEST,
    "medium": MEDIUM_LABEL_DIGEST,
    "hardcore": HARDCORE_LABEL_DIGEST,
}


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

POLICY_TEMPLATES: dict[str, dict[str, Any]] = {
    "act_respond": {
        "context": {
            "query_type": "research_question",
            "specificity": 0.55,
            "user_expertise": 0.80,
            "ambiguity": 0.25,
            "urgency": 0.30,
            "topic_familiarity": 0.70,
        },
        "acceptable": ["act_verify"],
        "styles": ["style_thorough"],
        "queries": [
            "Explain the strongest non-RLHF alignment research direction.",
            "What promising approach could align advanced AI without RLHF?",
            "Summarize a defensible research direction for AI alignment.",
            "Describe one useful path for studying scalable oversight.",
            "Explain a promising architecture for corrigible research agents.",
            "What is a strong research direction for transparent AI reasoning?",
            "Give a careful overview of one alignment research opportunity.",
            "Which approach to machine ethics deserves deeper investigation?",
            "Explain one tractable direction for autonomous-agent alignment.",
            "Describe a research path for reliable machine self-correction.",
            "What approach could improve the honesty of research assistants?",
            "Present one promising direction for safe autonomous inquiry.",
        ],
    },
    "act_clarify": {
        "context": {
            "query_type": "research_question",
            "specificity": 0.10,
            "ambiguity": 0.95,
            "urgency": 0.15,
            "topic_familiarity": 0.25,
        },
        "acceptable": ["act_decompose"],
        "styles": [],
        "queries": [
            "Investigate whether this approach works better.",
            "Can you research that method for me?",
            "Tell me whether the result is good.",
            "Compare this with the other technique.",
            "Find out if the proposed idea is successful.",
            "Analyze the approach we discussed.",
            "Does this research direction work?",
            "Evaluate the unnamed model against the baseline.",
            "Help me improve this experiment.",
            "Study the effect of that intervention.",
            "Which of those options is best?",
            "Continue the research on this topic.",
        ],
    },
    "act_verify": {
        "context": {
            "query_type": "verification",
            "ambiguity": 0.55,
            "failure_pressure": 0.75,
            "verification": 1.0,
            "external_evidence": 0.90,
            "urgency": 0.40,
        },
        "acceptable": ["act_search"],
        "styles": ["style_cautious"],
        "queries": [
            "Verify whether the reported safety result is supported.",
            "Check this factual claim against reliable evidence.",
            "Is the paper's main conclusion actually justified?",
            "Validate the numerical result before I cite it.",
            "Confirm whether independent sources support this assertion.",
            "Audit this strong claim for evidential support.",
            "Determine whether this result has been replicated.",
            "Check the source before accepting this conclusion.",
            "Verify this high-risk recommendation.",
            "Assess whether the citation supports the stated claim.",
            "Confirm this benchmark result using external evidence.",
            "Test whether the conclusion overstates the available data.",
        ],
    },
    "act_think": {
        "context": {
            "query_type": "exploration",
            "specificity": 0.45,
            "ambiguity": 0.45,
            "reflective_intent": 0.95,
            "complexity": 0.80,
            "topic_familiarity": 0.10,
            "external_evidence": 0.80,
            "failure_pressure": 0.10,
            "urgency": 0.10,
        },
        "acceptable": ["act_decompose"],
        "styles": ["style_exploratory"],
        "queries": [
            "Explore original cross-domain hypotheses for this open problem.",
            "Think through unconventional explanations for the observation.",
            "Generate defensible new hypotheses before answering.",
            "Explore the conceptual space around this unresolved question.",
            "Develop an original mechanism that could explain these results.",
            "Reflect on alternative theories for this research problem.",
            "Look for a novel connection between these two fields.",
            "Reason through unexplored explanations without concluding yet.",
            "Explore several creative but testable hypotheses.",
            "Think deeply about a new framing for this problem.",
            "Investigate possible mechanisms at the conceptual level.",
            "Develop an exploratory research hypothesis with clear caveats.",
        ],
    },
    "act_search": {
        "context": {
            "query_type": "evidence_request",
            "specificity": 0.80,
            "ambiguity": 0.10,
            "external_evidence": 1.0,
            "verification": 0.0,
            "failure_pressure": 0.05,
            "topic_familiarity": 0.45,
            "urgency": 0.30,
        },
        "acceptable": ["act_verify"],
        "styles": [],
        "queries": [
            "Find recent papers about mechanistic interpretability.",
            "Retrieve sources on scalable oversight methods.",
            "Search for empirical studies of AI calibration.",
            "Locate evidence about autonomous research agents.",
            "Find primary sources for this alignment claim.",
            "Search the literature for relevant replication studies.",
            "Retrieve recent work on motivational agent architectures.",
            "Find datasets that could test this hypothesis.",
            "Locate authoritative sources on this technical question.",
            "Search for published counterevidence to the proposal.",
            "Find current research on goal-stability mechanisms.",
            "Retrieve papers comparing these two methods.",
        ],
    },
    "act_decompose": {
        "context": {
            "query_type": "research_plan",
            "specificity": 0.80,
            "ambiguity": 0.15,
            "task_plan": 1.0,
            "complexity": 0.90,
            "failure_pressure": 0.05,
            "topic_familiarity": 0.55,
            "urgency": 0.15,
        },
        "acceptable": ["act_think"],
        "styles": ["style_thorough"],
        "queries": [
            "Break this research project into executable stages.",
            "Create a structured plan for testing the hypothesis.",
            "Decompose the investigation into clear work packages.",
            "Plan the experiments needed to answer this question.",
            "Turn this broad objective into a research workflow.",
            "Separate this complex problem into manageable subproblems.",
            "Design a stepwise literature and experiment plan.",
            "Organize the study into milestones and decision points.",
            "Build a research plan with dependencies and validation steps.",
            "Outline the tasks required to evaluate this proposal.",
            "Decompose this multidisciplinary investigation.",
            "Create an ordered plan for reproducing the reported result.",
        ],
    },
    "act_synthesize": {
        "context": {
            "query_type": "synthesis",
            "specificity": 0.85,
            "ambiguity": 0.15,
            "multi_source": 1.0,
            "external_evidence": 0.00,
            "evidence_available": 1.00,
            "complexity": 0.80,
            "topic_familiarity": 0.60,
            "urgency": 0.20,
        },
        "acceptable": ["act_respond"],
        "styles": ["style_thorough"],
        "queries": [
            "Synthesize the findings from these competing papers.",
            "Combine these sources into one evidence-weighted conclusion.",
            "Reconcile the disagreements across the supplied studies.",
            "Integrate these results while preserving uncertainty.",
            "Compare and synthesize the evidence from all sources.",
            "Build a coherent account from these conflicting reports.",
            "Summarize the shared findings and important disagreements.",
            "Combine the theoretical and empirical evidence.",
            "Synthesize these perspectives without erasing their differences.",
            "Integrate the source claims into a qualified conclusion.",
            "Produce an evidence-weighted synthesis of these studies.",
            "Connect the findings across the supplied research materials.",
        ],
    },
    "act_wait": {
        "context": {
            "query_type": "pending_information",
            "specificity": 0.75,
            "ambiguity": 0.15,
            "additional_information_expected": 1.0,
            "urgency": 0.10,
            "failure_pressure": 0.05,
            "topic_familiarity": 0.55,
        },
        "acceptable": ["act_clarify"],
        "styles": [],
        "queries": [
            "Wait until I upload the dataset before analyzing it.",
            "Hold until the remaining experiment results arrive.",
            "Do not continue until I provide the missing paper.",
            "Pause while the external evaluation completes.",
            "Wait for the promised evidence before drawing conclusions.",
            "Keep the research state while I obtain the measurements.",
            "Pause until the next source becomes available.",
            "Wait for my clarification before continuing.",
            "Do not infer the missing values; I will send them shortly.",
            "Hold this task until the replication output is ready.",
            "Wait for the pending information rather than guessing.",
            "Pause the analysis until the requested records arrive.",
        ],
    },
}

CANONICAL_CASES = {
    "act_respond": (
        "paper_non_rlhf_alignment",
        "What are the most promising approaches to aligning superintelligent AI systems that don't rely on RLHF?",
        {
            "query_type": "research_question",
            "specificity": 0.50,
            "user_expertise": 0.80,
            "ambiguity": 0.30,
            "urgency": 0.30,
            "topic_familiarity": 0.70,
        },
    ),
    "act_clarify": (
        "ambiguous_research_request",
        "Investigate whether this approach works better.",
        {
            "query_type": "research_question",
            "specificity": 0.15,
            "ambiguity": 0.90,
            "urgency": 0.20,
            "topic_familiarity": 0.30,
        },
    ),
    "act_verify": (
        "high_risk_factual_claim",
        "Give me a definitive safety conclusion from this single unverified result.",
        {
            "query_type": "verification",
            "ambiguity": 0.55,
            "failure_pressure": 0.70,
            "verification": 1.0,
            "external_evidence": 0.90,
            "urgency": 0.40,
        },
    ),
    "act_think": (
        "bounded_breakthrough_exploration",
        "Explore original cross-domain hypotheses for this open research problem.",
        {
            "query_type": "exploration",
            "specificity": 0.45,
            "ambiguity": 0.45,
            "reflective_intent": 0.90,
            "complexity": 0.75,
            "topic_familiarity": 0.15,
            "external_evidence": 0.80,
            "failure_pressure": 0.15,
            "urgency": 0.10,
        },
    ),
    "act_search": (
        "evidence_retrieval_request",
        "Find primary evidence relevant to this research question.",
        {
            "query_type": "evidence_request",
            "specificity": 0.75,
            "ambiguity": 0.15,
            "external_evidence": 0.95,
            "verification": 0.0,
            "failure_pressure": 0.10,
            "topic_familiarity": 0.45,
            "urgency": 0.30,
        },
    ),
    "act_decompose": (
        "structured_research_plan",
        "Create a structured plan for this complex research task.",
        {
            "query_type": "research_plan",
            "specificity": 0.75,
            "ambiguity": 0.20,
            "task_plan": 0.95,
            "complexity": 0.85,
            "failure_pressure": 0.10,
            "topic_familiarity": 0.55,
            "urgency": 0.20,
        },
    ),
    "act_synthesize": (
        "multi_source_synthesis",
        "Synthesize the findings from these multiple sources.",
        {
            "query_type": "synthesis",
            "specificity": 0.80,
            "ambiguity": 0.20,
            "multi_source": 0.95,
            "external_evidence": 0.00,
            "evidence_available": 1.00,
            "complexity": 0.75,
            "topic_familiarity": 0.60,
            "urgency": 0.25,
        },
    ),
    "act_wait": (
        "pending_information_wait",
        "Wait for the additional information I will provide.",
        {
            "query_type": "pending_information",
            "specificity": 0.70,
            "ambiguity": 0.20,
            "additional_information_expected": 1.0,
            "urgency": 0.15,
            "failure_pressure": 0.05,
            "topic_familiarity": 0.55,
        },
    ),
}

VARIATIONS = (
    {},
    {"urgency": 0.03},
    {"urgency": -0.03},
    {"specificity": 0.03},
    {"specificity": -0.03},
    {"user_expertise": 0.05},
    {"topic_familiarity": 0.04},
    {"topic_familiarity": -0.04},
    {"external_evidence": 0.03},
    {"complexity": 0.03},
    {"signed_valence": 0.08},
    {"signed_valence": -0.08},
)

def _pairs(mapping: dict[str, Any]) -> list[list[Any]]:
    return [[name, value] for name, value in mapping.items()]


def _vary(context: dict[str, Any], changes: dict[str, float]) -> dict[str, Any]:
    result = deepcopy(context)
    for name, change in changes.items():
        current = float(result.get(name, 0.5 if name != "signed_valence" else 0.0))
        minimum = -1.0 if name == "signed_valence" else 0.0
        result[name] = max(minimum, min(1.0, current + change))
    return result


def policyCases() -> list[list[Any]]:
    cases: list[list[Any]] = []
    for action, template in POLICY_TEMPLATES.items():
        for index, query in enumerate(template["queries"]):
            caseId = f"{action.removeprefix('act_')}_{index + 1:02d}"
            context = _vary(template["context"], VARIATIONS[index])
            if index == 0:
                caseId, query, context = CANONICAL_CASES[action]
            cases.append(
                [
                    caseId,
                    action,
                    _pairs(context),
                    query,
                    action,
                    template["acceptable"],
                    template["styles"],
                ]
            )
    return cases


def _outcome(action: str) -> list[list[Any]]:
    values = {
        "short_help": 0.78,
        "long_help": 0.76,
        "grounding": 0.82,
        "safety": 0.94,
        "progress": 0.80,
        "novel_yield": 0.58,
        "original_yield": 0.55,
        "breakthrough_yield": 0.48,
        "coherence": 0.88,
        "social_quality": 0.86,
        "efficiency": 0.76,
        "accuracy": 0.86,
    }
    if action == "act_clarify":
        values.update(progress=0.62, efficiency=0.68, accuracy=0.92)
    elif action == "act_wait":
        values.update(short_help=0.62, progress=0.45, safety=0.98, accuracy=0.92)
    elif action == "act_think":
        values.update(novel_yield=0.86, original_yield=0.82, accuracy=0.72)
    elif action in {"act_search", "act_verify"}:
        values.update(grounding=0.94, accuracy=0.94, safety=0.96)
    elif action == "act_synthesize":
        values.update(long_help=0.90, coherence=0.94, grounding=0.90)
    return [[name, values[name]] for name in OUTCOME_NAMES]


SESSION_DEFINITIONS = (
    (
        "alignment_review",
        ("act_clarify", "act_decompose", "act_search", "act_synthesize", "act_verify", "act_respond"),
    ),
    (
        "novel_hypothesis",
        ("act_think", "act_decompose", "act_search", "act_synthesize", "act_verify", "act_respond"),
    ),
    (
        "pending_dataset",
        ("act_clarify", "act_think", "act_wait", "act_search", "act_synthesize", "act_respond"),
    ),
    (
        "replication_study",
        ("act_decompose", "act_think", "act_search", "act_verify", "act_synthesize", "act_respond"),
    ),
)


def sessionCases() -> list[list[Any]]:
    sessions: list[list[Any]] = []
    for sessionId, actions in SESSION_DEFINITIONS:
        turns = []
        for turnIndex, action in enumerate(actions):
            template = POLICY_TEMPLATES[action]
            turns.append(
                [
                    f"{sessionId}_{turnIndex + 1:02d}",
                    action,
                    _pairs(template["context"]),
                    template["queries"][turnIndex],
                    action,
                    template["acceptable"],
                    template["styles"],
                    _outcome(action),
                ]
            )
        sessions.append([sessionId, turns])
    return sessions


def _questionSessionDefinitions() -> tuple[tuple[str, tuple[Any, ...]], ...]:
    sessions = []
    for session in QUESTION_SESSIONS:
        queries = session["queries"]
        expected = session["expected_actions"]
        acceptable = session["acceptable_actions"]
        rationales = session["rationales"]
        if not (len(queries) == len(expected) == len(acceptable) == len(rationales)):
            raise ValueError(
                f"question session {session['session_id']} has mismatched label lengths"
            )
        definitions = tuple(zip(queries, expected, acceptable, rationales))
        sessions.append((session["session_id"], definitions))
    return tuple(sessions)


LIVE_SESSION_DEFINITIONS = _questionSessionDefinitions()
_LIVE_CONVERSATIONS: dict[str, list[list[str]]] = {}


def liveSessionCases() -> list[list[Any]]:
    repeats = int(os.environ.get("QWESTOR_LIVE_REPEATS", "1"))
    if repeats < 1 or repeats > 10:
        raise ValueError("QWESTOR_LIVE_REPEATS must be between 1 and 10")
    sessionLimit = int(
        os.environ.get("QWESTOR_LIVE_SESSION_LIMIT", "1")
    )
    if sessionLimit < 1 or sessionLimit > len(LIVE_SESSION_DEFINITIONS):
        raise ValueError(
            f"QWESTOR_LIVE_SESSION_LIMIT must be between 1 and {len(LIVE_SESSION_DEFINITIONS)}"
        )
    maximumTurns = max(len(definitions) for _, definitions in LIVE_SESSION_DEFINITIONS)
    turnLimit = int(os.environ.get("QWESTOR_LIVE_TURN_LIMIT", "1"))
    if turnLimit < 1 or turnLimit > maximumTurns:
        raise ValueError(
            f"QWESTOR_LIVE_TURN_LIMIT must be between 1 and {maximumTurns}"
        )
    sessions: list[list[Any]] = []
    for repeat in range(1, repeats + 1):
        for sessionId, definitions in LIVE_SESSION_DEFINITIONS[:sessionLimit]:
            repeatedId = f"{sessionId}_r{repeat}"
            turns = []
            for turnIndex, (
                query,
                expectedAction,
                acceptableActions,
                rationale,
            ) in enumerate(
                definitions[:turnLimit]
            ):
                template = POLICY_TEMPLATES[expectedAction]
                turns.append(
                    [
                        f"{repeatedId}_{turnIndex + 1:02d}",
                        f"{sessionId}_{turnIndex + 1:02d}",
                        query,
                        expectedAction,
                        acceptableActions,
                        template["styles"],
                        "",
                        None,
                        rationale,
                    ]
                )
            sessions.append([repeatedId, turns])
    return sessions


def _plainText(value: Any) -> str:
    result = str(value)
    if len(result) >= 2 and result[0] == result[-1] == '"':
        return result[1:-1]
    return result


def resetLiveConversation(sessionId: Any) -> bool:
    _LIVE_CONVERSATIONS[_plainText(sessionId)] = []
    return True


def liveConversation(sessionId: Any) -> list[list[str]]:
    return deepcopy(_LIVE_CONVERSATIONS.get(_plainText(sessionId), []))


def appendLiveConversation(
    sessionId: Any,
    query: Any,
    response: Any,
    actionId: Any = "",
    effectKind: Any = "",
    evidence: Any = "",
) -> bool:
    messages = _LIVE_CONVERSATIONS.setdefault(_plainText(sessionId), [])
    queryText = _plainText(query)
    responseText = _plainText(response)
    action = _plainText(actionId)
    if action:
        artifact = _assistantArtifact(
            action,
            queryText,
            _plainText(effectKind),
            bool(_plainText(evidence).strip()),
        )
        responseText = (
            f"{responseText}\nQWESTOR_ARTIFACT "
            f"{json.dumps(artifact, ensure_ascii=False, sort_keys=True)}"
        )
    messages.append(["user", queryText])
    messages.append(["assistant", responseText])
    return True


def _assistantArtifact(
    action: str,
    query: str,
    effectKind: str = "",
    evidenceRetrieved: bool = False,
) -> dict[str, Any]:
    artifactTypes = {
        "act_respond": "answer",
        "act_clarify": "clarification_request",
        "act_think": "analysis",
        "act_decompose": "research_plan",
        "act_search": "source_findings",
        "act_verify": "verification_assessment",
        "act_synthesize": "synthesis",
        "act_wait": "pending_information_record",
    }
    available = action not in {"act_clarify", "act_wait"}
    if action == "act_search":
        evidenceStatus = "retrieved" if evidenceRetrieved else "unavailable"
    elif action == "act_verify":
        evidenceStatus = "verified" if evidenceRetrieved else "unavailable"
    elif action == "act_synthesize":
        evidenceStatus = "available_in_history"
    else:
        evidenceStatus = "unavailable"
    return {
        "schema": "qwestor_artifact",
        "action_id": action,
        "effect_kind": effectKind or (
            "search" if action == "act_search" else
            "verification" if action == "act_verify" else
            "wait" if action == "act_wait" else
            "llm"
        ),
        "artifact_type": artifactTypes[action],
        "status": "available" if available else "unavailable",
        "subject": query,
        "evidence_status": evidenceStatus,
    }


def _canonicalAssistantMessage(action: str, query: str) -> str:
    descriptions = {
        "act_respond": (
            "I completed a direct answer. Its answer artifact is retained and available "
            "for follow-up"
        ),
        "act_clarify": (
            "I requested the essential missing input. No substantive result artifact is "
            "available until the user supplies it"
        ),
        "act_think": (
            "I completed bounded analysis. Its reasoning-result artifact is retained and "
            "available for follow-up"
        ),
        "act_decompose": (
            "I completed an ordered plan with dependencies and steps. Its plan artifact is "
            "retained and available for follow-up"
        ),
        "act_search": (
            "I completed external retrieval. Its source-backed findings artifact is retained "
            "and available for follow-up"
        ),
        "act_verify": (
            "I completed a cautious claim assessment. Its verification artifact is retained "
            "and available for follow-up"
        ),
        "act_synthesize": (
            "I completed integration of the requested inputs. Its synthesis artifact is "
            "retained and available for follow-up"
        ),
        "act_wait": (
            "I recorded that required information is pending. No result artifact is available "
            "until that information arrives"
        ),
    }
    artifact = _assistantArtifact(
        action,
        query,
        evidenceRetrieved=action in {"act_search", "act_verify"},
    )
    return (
        f"{descriptions[action]}. Request addressed: {query}\n"
        f"QWESTOR_ARTIFACT {json.dumps(artifact, ensure_ascii=False, sort_keys=True)}"
    )


def fixedConversation(
    sessionId: str,
    turnIndex: int,
    sessions: list[dict[str, Any]] | None = None,
) -> list[list[str]]:
    sourceSessions = QUESTION_SESSIONS if sessions is None else sessions
    for session in sourceSessions:
        if session["session_id"] != sessionId:
            continue
        messages: list[list[str]] = []
        for index in range(min(int(turnIndex), len(session["queries"]))):
            query = session["queries"][index]
            action = session["expected_actions"][index]
            messages.append(["user", query])
            messages.append(["assistant", _canonicalAssistantMessage(action, query)])
        return messages
    raise ValueError(f"unknown Qwestor question session: {sessionId}")


def perceptionSuiteSessions(suiteName: str) -> list[dict[str, Any]]:
    normalized = str(suiteName).strip().lower()
    if normalized not in PERCEPTION_SUITES:
        raise ValueError(
            "benchmark suite must be session, medium, or hardcore"
        )
    return PERCEPTION_SUITES[normalized]


def _allPerceptionCases(suiteName: str = "session") -> list[list[Any]]:
    cases = []
    selectedSessions = perceptionSuiteSessions(suiteName)
    for session in selectedSessions:
        sessionId = session["session_id"]
        benchmarkSuite = session.get("benchmark_suite", "session")
        benchmarkLabelDigest = PERCEPTION_SUITE_LABEL_DIGESTS[benchmarkSuite]
        for turnIndex, (
            query,
            expectedAction,
            acceptableActions,
            rationale,
        ) in enumerate(
            zip(
                session["queries"],
                session["expected_actions"],
                session["acceptable_actions"],
                session["rationales"],
            )
        ):
            template = POLICY_TEMPLATES[expectedAction]
            caseId = f"{sessionId}_{turnIndex + 1:02d}"
            cases.append(
                [
                    caseId,
                    caseId,
                    query,
                    expectedAction,
                    acceptableActions,
                    template["styles"],
                    fixedConversation(sessionId, turnIndex, selectedSessions),
                    sessionId,
                    turnIndex,
                    None,
                    rationale,
                    benchmarkSuite,
                    benchmarkLabelDigest,
                ]
            )
    return cases


def _balancedPerceptionCases(
    allCases: list[list[Any]], limit: int
) -> list[list[Any]]:
    groups: dict[str, list[list[Any]]] = {
        action: [] for action in POLICY_TEMPLATES
    }
    for case in allCases:
        groups[case[3]].append(case)
    selected: list[list[Any]] = []
    offsets = {action: 0 for action in groups}
    actionOrder = tuple(groups)
    while len(selected) < limit:
        added = False
        for action in actionOrder:
            index = offsets[action]
            if index >= len(groups[action]):
                continue
            selected.append(groups[action][index])
            offsets[action] += 1
            added = True
            if len(selected) == limit:
                break
        if not added:
            break
    return selected


def perceptionCases() -> list[list[Any]]:
    allCases = _allPerceptionCases("session")
    limit = int(
        os.environ.get("QWESTOR_PERCEPTION_CASE_LIMIT", str(len(allCases)))
    )
    if limit < 1 or limit > len(allCases):
        raise ValueError(
            f"QWESTOR_PERCEPTION_CASE_LIMIT must be between 1 and {len(allCases)}"
        )
    return _balancedPerceptionCases(allCases, limit)


def stressPerceptionCases() -> list[list[Any]]:
    suiteName = os.environ.get("QWESTOR_STRESS_SUITE", "").strip().lower()
    if suiteName not in {"medium", "hardcore"}:
        raise ValueError("QWESTOR_STRESS_SUITE must be medium or hardcore")
    allCases = _allPerceptionCases(suiteName)
    limit = int(
        os.environ.get("QWESTOR_STRESS_CASE_LIMIT", str(len(allCases)))
    )
    if limit < 1 or limit > len(allCases):
        raise ValueError(
            f"QWESTOR_STRESS_CASE_LIMIT must be between 1 and {len(allCases)}"
        )
    return _balancedPerceptionCases(allCases, limit)


def requirePerceptionBenchmarkConfiguration() -> bool:
    enabled = os.environ.get(
        "QWESTOR_RUN_PERCEPTION_BENCHMARK", ""
    ).strip().lower() in {"1", "true", "yes"}
    if not enabled:
        raise RuntimeError(
            "Set QWESTOR_RUN_PERCEPTION_BENCHMARK=1 to authorize provider calls."
        )
    return True


def requireStressBenchmarkConfiguration() -> bool:
    enabled = os.environ.get(
        "QWESTOR_RUN_STRESS_BENCHMARK", ""
    ).strip().lower() in {"1", "true", "yes"}
    if not enabled:
        raise RuntimeError(
            "Set QWESTOR_RUN_STRESS_BENCHMARK=1 to authorize provider calls."
        )
    return True


def liveProgress(sessionId: Any, turnIndex: Any, caseId: Any, stage: Any) -> bool:
    print(
        f"[Live] session={_plainText(sessionId)} "
        f"turn={int(turnIndex) + 1} case={_plainText(caseId)} "
        f"stage={_plainText(stage)}",
        flush=True,
    )
    return True


def liveBenchmarkEnabled() -> bool:
    return os.environ.get("QWESTOR_RUN_LIVE_BENCHMARK", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }


def sharedEvaluatorAllowed() -> bool:
    return os.environ.get("QWESTOR_ALLOW_SHARED_EVALUATOR", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }


def requireLiveBenchmarkConfiguration() -> bool:
    if not liveBenchmarkEnabled():
        raise RuntimeError(
            "Set QWESTOR_RUN_LIVE_BENCHMARK=1 to authorize provider calls."
        )
    return True
