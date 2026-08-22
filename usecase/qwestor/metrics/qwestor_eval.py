from __future__ import annotations

import importlib.util
import json
import os
import re
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[3]
QWESTOR_DIR = Path(__file__).resolve().parents[1]
LOGS_DIR = QWESTOR_DIR / "eval"
RAW_RESULTS_PATH = LOGS_DIR / "raw_runs.json"
EVALUATION_RESULTS_PATH = LOGS_DIR / "evaluation_results.json"

SCORE_RE = re.compile(
    r"\(?\s*action-score\s+([^\s()]+)\s+([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)\s*\)?"
)


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    with tmp_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp_path, path)


def _display_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def _atom_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        text = text[1:-1]
    return text


def _to_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        text = _atom_text(value)
        if text is None:
            return None
        try:
            return float(text)
        except ValueError:
            return None


def _score_entry_from_sequence(entry: Any) -> dict[str, Any] | None:
    if not isinstance(entry, (list, tuple)) or len(entry) < 3:
        return None

    tag = _atom_text(entry[0])
    if tag != "action-score":
        return None

    action = _atom_text(entry[1])
    score = _to_float(entry[2])
    if action is None or score is None:
        return None
    return {"action": action, "score": round(score, 6)}


def _score_entries_from_text(text: str) -> list[dict[str, Any]]:
    entries = []
    for match in SCORE_RE.finditer(text):
        entries.append(
            {
                "action": match.group(1),
                "score": round(float(match.group(2)), 6),
            }
        )
    return entries


def normalize_score_entries(score_entries: Any) -> list[dict[str, Any]]:
    if isinstance(score_entries, str):
        return _score_entries_from_text(score_entries)

    entries: list[dict[str, Any]] = []
    if isinstance(score_entries, (list, tuple)):
        for entry in score_entries:
            parsed = _score_entry_from_sequence(entry)
            if parsed is not None:
                entries.append(parsed)
                continue
            entries.extend(_score_entries_from_text(str(entry)))
    else:
        entries.extend(_score_entries_from_text(str(score_entries)))

    return entries


def normalize_pair_entries(entries: Any) -> dict[str, Any]:
    normalized: dict[str, Any] = {}
    if not isinstance(entries, (list, tuple)):
        return normalized

    for entry in entries:
        if not isinstance(entry, (list, tuple)) or len(entry) < 2:
            continue

        key = _atom_text(entry[0])
        if key is None:
            continue

        value = _to_float(entry[1])
        normalized[key] = value if value is not None else _atom_text(entry[1])

    return normalized


def normalize_stimulus(stimulus: Any) -> dict[str, float]:
    text = str(stimulus)
    values = [
        float(match)
        for match in re.findall(
            r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?",
            text,
        )
    ]
    keys = ("novelty", "conduciveness", "risk", "effort")
    return {
        key: round(value, 6)
        for key, value in zip(keys, values[: len(keys)])
    }


def _load_session_specs() -> list[dict[str, Any]]:
    session_file = QWESTOR_DIR / "tests" / "session_short.py"
    if not session_file.exists():
        return []

    spec = importlib.util.spec_from_file_location("session_short_eval", session_file)
    if spec is None or spec.loader is None:
        return []

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return list(getattr(module, "SESSIONS", []))


def _expected_for_turn(
    session_id: str,
    query: str,
    session_specs: list[dict[str, Any]] | None = None,
) -> tuple[str | None, list[str], str | None]:
    specs = session_specs if session_specs is not None else _load_session_specs()
    for session in specs:
        if session.get("session_id") != session_id:
            continue

        queries = session.get("queries", [])
        for idx, candidate_query in enumerate(queries):
            if candidate_query != query:
                continue

            expected_actions = session.get("expected_actions", [])
            acceptable_actions = session.get("acceptable_actions", [])
            expected = expected_actions[idx] if idx < len(expected_actions) else None
            acceptable = acceptable_actions[idx] if idx < len(acceptable_actions) else []
            return expected, list(acceptable or []), session.get("name")

    return None, [], None


def _evaluate_turn(
    turn: dict[str, Any],
    session_specs: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    expected, acceptable, session_name = _expected_for_turn(
        str(turn.get("session_id", "")),
        str(turn.get("query", "")),
        session_specs,
    )
    predicted = turn.get("predicted_action")

    if expected is None:
        strict_correct = None
        soft_score = None
    else:
        strict_correct = 1 if predicted == expected else 0
        soft_score = 1.0 if strict_correct else (0.8 if predicted in acceptable else 0.0)

    top3 = sorted(
        turn.get("action_scores", []),
        key=lambda item: item.get("score", float("-inf")),
        reverse=True,
    )[:3]
    decision_margin = None
    if len(top3) >= 2:
        decision_margin = round(top3[0]["score"] - top3[1]["score"], 6)

    turn.update(
        {
            "session_name": session_name,
            "expected_action": expected,
            "acceptable_actions": acceptable,
            "strict_correct": strict_correct,
            "soft_score": soft_score,
            "top3": top3,
            "decision_margin": decision_margin,
        }
    )
    return turn


def _metrics_for(turns: list[dict[str, Any]]) -> dict[str, Any]:
    labeled = [turn for turn in turns if turn.get("expected_action") is not None]
    strict_total = sum(int(turn.get("strict_correct") or 0) for turn in labeled)
    soft_total = sum(float(turn.get("soft_score") or 0.0) for turn in labeled)
    margins = [
        float(turn["decision_margin"])
        for turn in labeled
        if turn.get("decision_margin") is not None
    ]

    turn_count = len(labeled)
    predicted_counts = Counter(
        str(turn.get("predicted_action", ""))
        for turn in labeled
        if turn.get("predicted_action")
    )
    expected_counts = Counter(
        str(turn.get("expected_action", ""))
        for turn in labeled
        if turn.get("expected_action")
    )
    top3_hits = sum(
        1
        for turn in labeled
        if turn.get("expected_action")
        in {entry.get("action") for entry in turn.get("top3", [])}
    )
    confusion: dict[str, Counter[str]] = defaultdict(Counter)
    for turn in labeled:
        expected = str(turn.get("expected_action", ""))
        predicted = str(turn.get("predicted_action", ""))
        if expected and predicted:
            confusion[expected][predicted] += 1

    return {
        "turn_count": turn_count,
        "strict_correct": strict_total,
        "strict_accuracy": round(strict_total / turn_count, 6) if turn_count else None,
        "soft_accuracy": round(soft_total / turn_count, 6) if turn_count else None,
        "top3_hit_rate": round(top3_hits / turn_count, 6) if turn_count else None,
        "average_decision_margin": round(sum(margins) / len(margins), 6)
        if margins
        else None,
        "predicted_action_counts": dict(sorted(predicted_counts.items())),
        "expected_action_counts": dict(sorted(expected_counts.items())),
        "confusion_matrix": {
            expected: dict(sorted(predicted.items()))
            for expected, predicted in sorted(confusion.items())
        },
        "unlabeled_turn_count": len(turns) - turn_count,
    }


def _build_evaluation(raw_turns: list[dict[str, Any]]) -> dict[str, Any]:
    session_specs = _load_session_specs()
    evaluated_turns = [_evaluate_turn(dict(turn), session_specs) for turn in raw_turns]
    by_session: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for turn in evaluated_turns:
        by_session[turn.get("session_id", "unknown")].append(turn)

    return {
        "generated_at": _now(),
        "source_results_file": _display_path(RAW_RESULTS_PATH),
        **_metrics_for(evaluated_turns),
        "sessions": {
            session_id: _metrics_for(session_turns)
            for session_id, session_turns in sorted(by_session.items())
        },
        "turns": evaluated_turns,
    }


def record_turn(
    session_id: Any,
    query: Any,
    predicted_action: Any,
    answer: Any,
    score_entries: Any,
    context_entries: Any = None,
    stimulus: Any = None,
) -> bool:
    session_id_text = _atom_text(session_id) or ""
    query_text = _atom_text(query) or ""
    predicted_text = _atom_text(predicted_action) or ""

    action_scores = normalize_score_entries(score_entries)
    raw_data = _read_json(
        RAW_RESULTS_PATH,
        {
            "generated_at": _now(),
            "description": "Raw Qwestor loop turn records captured from qwestorLoop and qwestorLoopFromList.",
            "turns": [],
        },
    )

    turn = {
        "timestamp": _now(),
        "session_id": session_id_text,
        "query": query_text,
        "predicted_action": predicted_text,
        "answer": _atom_text(answer) or "",
        "action_scores": action_scores,
    }

    context = normalize_pair_entries(context_entries)
    if context:
        turn["context"] = context

    normalized_stimulus = normalize_stimulus(stimulus)
    if normalized_stimulus:
        turn["stimulus"] = normalized_stimulus

    raw_data.setdefault("turns", []).append(turn)
    raw_data["generated_at"] = _now()

    _write_json(RAW_RESULTS_PATH, raw_data)
    _write_json(EVALUATION_RESULTS_PATH, _build_evaluation(raw_data["turns"]))
    return True
