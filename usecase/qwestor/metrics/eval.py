from __future__ import annotations

import argparse
import csv
import json
import math
from collections import Counter, defaultdict
from html import escape
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_ID = "qwestor"
ACTION_NAMES = (
    "act_clarify",
    "act_search",
    "act_think",
    "act_respond",
    "act_decompose",
    "act_verify",
    "act_synthesize",
    "act_wait",
)
NORMATIVE_NAMES = ("beneficial", "honesty", "safety")
OVERGOAL_NAMES = ("individuation", "transcendence")
GOAL_NAMES = (
    "individuation",
    "transcendence",
    "beneficial",
    "honesty",
    "safety",
    "help_short",
    "help_long",
    "knowledge",
    "novelty",
    "originality",
    "success_moderate",
    "success_breakthrough",
    "coherence",
    "social",
    "efficiency",
    "accuracy",
    "hallucinate",
    "redundant",
    "rabbit_hole",
    "premature",
)
MODULATOR_NAMES = (
    "valence",
    "arousal",
    "approach",
    "resolution",
    "threshold",
    "securing",
    "urgency",
    "risk_aversion",
    "error_tolerance",
    "failure_wariness",
    "user_expertise",
    "topic_familiarity",
    "creativity",
)
STATE_NAMES = GOAL_NAMES + MODULATOR_NAMES
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
RESPONSE_METRIC_NAMES = (
    "helpfulness",
    "factuality",
    "grounding",
    "citation_correctness",
    "uncertainty_calibration",
    "safety",
    "action_adherence",
    "style_adherence",
    "hallucination",
    "redundancy",
    "rabbit_hole",
    "premature_conclusion",
)
DESIRABLE_RESPONSE_METRIC_NAMES = RESPONSE_METRIC_NAMES[:8]
FAILURE_RESPONSE_METRIC_NAMES = RESPONSE_METRIC_NAMES[8:]
RUNTIME_NUMERIC_NAMES = (
    "latency_ms",
    "input_tokens",
    "output_tokens",
    "cost_usd",
    "provider_calls",
    "failed_provider_calls",
)


class EvaluationFormatError(ValueError):
    pass


def _text(value: Any) -> str:
    result = str(value)
    if len(result) >= 2 and result[0] == result[-1] == '"':
        return result[1:-1]
    return result


def _number(value: Any, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise EvaluationFormatError(f"{field} must be numeric")
    result = float(value)
    if not math.isfinite(result):
        raise EvaluationFormatError(f"{field} must be finite")
    return result


def _unit_number(value: Any, field: str) -> float:
    result = _number(value, field)
    if not 0.0 <= result <= 1.0:
        raise EvaluationFormatError(f"{field} must lie in [0, 1]")
    return result


def _texts(value: Any) -> list[str]:
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes)):
        return [_text(item) for item in value]
    text = _text(value).strip()
    if text.startswith("(") and text.endswith(")"):
        text = text[1:-1]
    return [
        token.strip('"')
        for token in text.replace("(", " ").replace(")", " ").split()
        if token.strip('"')
    ]


def _pairs(value: Any) -> dict[str, Any]:
    if isinstance(value, Mapping):
        return {_text(key): item for key, item in value.items()}
    if not isinstance(value, Sequence) or isinstance(value, (str, bytes)):
        raise EvaluationFormatError("named values must be pairs")
    result: dict[str, Any] = {}
    for pair in value:
        if not isinstance(pair, Sequence) or len(pair) != 2:
            raise EvaluationFormatError("named values must be two-item pairs")
        result[_text(pair[0])] = pair[1]
    return result


def _response_composite(metrics: Mapping[str, float]) -> float:
    return (
        sum(metrics[name] for name in DESIRABLE_RESPONSE_METRIC_NAMES)
        + sum(1.0 - metrics[name] for name in FAILURE_RESPONSE_METRIC_NAMES)
    ) / len(RESPONSE_METRIC_NAMES)


def _exact_unit_mapping(value: Any, names: Sequence[str], field: str) -> dict[str, float]:
    pairs = _pairs(value)
    if set(pairs) != set(names):
        raise EvaluationFormatError(f"{field} must contain exactly the canonical fields")
    return {
        name: _unit_number(pairs[name], f"{field}.{name}")
        for name in names
    }


def state_from_vectors(goals: Sequence[Any], modulators: Sequence[Any]) -> dict[str, float]:
    if len(goals) != len(GOAL_NAMES) or len(modulators) != len(MODULATOR_NAMES):
        raise EvaluationFormatError("state vectors have invalid dimensions")
    return {
        name: _unit_number(value, f"state.{name}")
        for name, value in zip(STATE_NAMES, [*goals, *modulators])
    }


def normalize_record(record: Mapping[str, Any]) -> dict[str, Any]:
    required = {
        "schema_id",
        "case_id",
        "action_id",
        "winner_margin",
        "features",
        "state",
        "scores",
        "diagnostics",
    }
    optional = {
        "expected_action",
        "acceptable_actions",
        "selected_styles",
        "expected_styles",
        "response",
        "response_metrics",
        "runtime",
        "perception_trace",
        "session_id",
        "turn_index",
        "case_group",
        "state_before",
        "state_after",
        "previous_outcome",
        "outcome",
        "benchmark_version",
        "label_rationale",
        "evaluation_split",
        "benchmark_suite",
        "benchmark_label_digest",
    }
    if (
        not isinstance(record, Mapping)
        or not required.issubset(record)
        or not set(record).issubset(required | optional)
    ):
        raise EvaluationFormatError("evaluation record has an invalid shape")
    schema_id = _text(record["schema_id"])
    if schema_id != SCHEMA_ID:
        raise EvaluationFormatError(f"unsupported schema id: {schema_id}")
    state = _pairs(record["state"])
    for name in NORMATIVE_NAMES + OVERGOAL_NAMES:
        if name not in state:
            raise EvaluationFormatError(f"state is missing {name}")
        state[name] = _number(state[name], f"state.{name}")
    features = {
        name: _number(value, f"features.{name}")
        if isinstance(value, (int, float)) and not isinstance(value, bool)
        else _text(value)
        for name, value in _pairs(record["features"]).items()
    }
    scores = {
        name: _number(value, f"scores.{name}")
        for name, value in _pairs(record["scores"]).items()
    }
    diagnostics = _pairs(record["diagnostics"])
    for name in (
        "boundary_pressure",
        "projection_distance",
        "lax_error",
        "accepted_alpha",
    ):
        diagnostics[name] = _number(diagnostics.get(name), f"diagnostics.{name}")
    for name in ("lax_holds", "contractive", "safe_after"):
        value = diagnostics.get(name)
        if not isinstance(value, bool):
            value = _text(value).lower() == "true"
        diagnostics[name] = value
    if "base_alpha" in diagnostics:
        diagnostics["base_alpha"] = _number(
            diagnostics["base_alpha"], "diagnostics.base_alpha"
        )
    if "safe_before" in diagnostics:
        value = diagnostics["safe_before"]
        if not isinstance(value, bool):
            value = _text(value).lower() == "true"
        diagnostics["safe_before"] = value
    normalized = {
        "schema_id": schema_id,
        "case_id": _text(record["case_id"]),
        "action_id": _text(record["action_id"]),
        "winner_margin": _number(record["winner_margin"], "winner_margin"),
        "features": features,
        "state": state,
        "scores": scores,
        "diagnostics": diagnostics,
    }
    if "expected_action" in record:
        normalized["expected_action"] = _text(record["expected_action"])
        normalized["acceptable_actions"] = _texts(
            record.get("acceptable_actions", ())
        )
    if "selected_styles" in record or "expected_styles" in record:
        normalized["selected_styles"] = _texts(record.get("selected_styles", ()))
        normalized["expected_styles"] = _texts(record.get("expected_styles", ()))
    if "response" in record:
        normalized["response"] = _text(record["response"])
    if "response_metrics" in record:
        metricPairs = _pairs(record["response_metrics"])
        if set(metricPairs) != set(RESPONSE_METRIC_NAMES):
            raise EvaluationFormatError(
                "response metrics must contain exactly the canonical fields"
            )
        normalized["response_metrics"] = {
            name: _unit_number(metricPairs[name], f"response_metrics.{name}")
            for name in RESPONSE_METRIC_NAMES
        }
    if "runtime" in record:
        runtime = _pairs(record["runtime"])
        normalizedRuntime: dict[str, Any] = {}
        for name, value in runtime.items():
            if name in RUNTIME_NUMERIC_NAMES:
                number = _number(value, f"runtime.{name}")
                if number < 0.0:
                    raise EvaluationFormatError(
                        f"runtime.{name} must be non-negative"
                    )
                normalizedRuntime[name] = number
            else:
                normalizedRuntime[name] = _text(value)
        normalized["runtime"] = normalizedRuntime
    if "perception_trace" in record:
        trace = _pairs(record["perception_trace"])
        normalized["perception_trace"] = {
            name: _text(value) for name, value in trace.items()
        }
    if "session_id" in record:
        normalized["session_id"] = _text(record["session_id"])
    if "turn_index" in record:
        turnIndex = record["turn_index"]
        if isinstance(turnIndex, bool) or not isinstance(turnIndex, (int, float)):
            raise EvaluationFormatError("turn_index must be a non-negative integer")
        if int(turnIndex) != turnIndex or turnIndex < 0:
            raise EvaluationFormatError("turn_index must be a non-negative integer")
        normalized["turn_index"] = int(turnIndex)
    if "case_group" in record:
        normalized["case_group"] = _text(record["case_group"])
    if "benchmark_version" in record:
        normalized["benchmark_version"] = _text(record["benchmark_version"])
    if "label_rationale" in record:
        normalized["label_rationale"] = _text(record["label_rationale"])
    if "evaluation_split" in record:
        evaluationSplit = _text(record["evaluation_split"])
        if evaluationSplit not in {"development", "holdout"}:
            raise EvaluationFormatError(
                "evaluation_split must be development or holdout"
            )
        normalized["evaluation_split"] = evaluationSplit
    if "benchmark_suite" in record:
        benchmarkSuite = _text(record["benchmark_suite"]).strip()
        if not benchmarkSuite:
            raise EvaluationFormatError("benchmark_suite must not be empty")
        normalized["benchmark_suite"] = benchmarkSuite
    if "benchmark_label_digest" in record:
        benchmarkLabelDigest = _text(record["benchmark_label_digest"]).strip().lower()
        if (
            len(benchmarkLabelDigest) != 64
            or any(character not in "0123456789abcdef" for character in benchmarkLabelDigest)
        ):
            raise EvaluationFormatError(
                "benchmark_label_digest must be a lowercase SHA-256 digest"
            )
        normalized["benchmark_label_digest"] = benchmarkLabelDigest
    if "state_before" in record:
        normalized["state_before"] = _exact_unit_mapping(
            record["state_before"], STATE_NAMES, "state_before"
        )
    if "state_after" in record:
        normalized["state_after"] = _exact_unit_mapping(
            record["state_after"], STATE_NAMES, "state_after"
        )
    if "previous_outcome" in record:
        previous = _pairs(record["previous_outcome"])
        normalized["previous_outcome"] = (
            {}
            if not previous
            else _exact_unit_mapping(previous, OUTCOME_NAMES, "previous_outcome")
        )
    if "outcome" in record:
        normalized["outcome"] = _exact_unit_mapping(
            record["outcome"], OUTCOME_NAMES, "outcome"
        )
    return normalized


def reset_results(path: str | Path) -> bool:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("", encoding="utf-8")
    return True


def record_case(
    path: str | Path,
    schema_id: Any,
    case_id: Any,
    action_id: Any,
    winner_margin: float,
    features: Sequence[Sequence[Any]],
    state: Sequence[Sequence[Any]],
    scores: Sequence[Sequence[Any]],
    diagnostics: Sequence[Sequence[Any]],
    expected_action: Any | None = None,
    acceptable_actions: Sequence[Any] = (),
    selected_styles: Sequence[Any] = (),
    expected_styles: Sequence[Any] = (),
    response: Any | None = None,
    response_metrics: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    runtime: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    session_id: Any | None = None,
    turn_index: int | None = None,
    case_group: Any | None = None,
    state_before: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    state_after: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    previous_outcome: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    outcome: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    benchmark_version: Any | None = None,
    label_rationale: Any | None = None,
    perception_trace: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    evaluation_split: Any | None = None,
    benchmark_suite: Any | None = None,
    benchmark_label_digest: Any | None = None,
) -> bool:
    rawRecord: dict[str, Any] = {
        "schema_id": _text(schema_id),
        "case_id": _text(case_id),
        "action_id": _text(action_id),
        "winner_margin": winner_margin,
        "features": features,
        "state": state,
        "scores": scores,
        "diagnostics": diagnostics,
    }
    if expected_action is not None:
        rawRecord["expected_action"] = expected_action
        rawRecord["acceptable_actions"] = acceptable_actions
    if selected_styles or expected_styles:
        rawRecord["selected_styles"] = selected_styles
        rawRecord["expected_styles"] = expected_styles
    if response is not None:
        rawRecord["response"] = response
    if response_metrics is not None:
        rawRecord["response_metrics"] = response_metrics
    if runtime is not None:
        rawRecord["runtime"] = runtime
    if session_id is not None:
        rawRecord["session_id"] = session_id
    if turn_index is not None:
        rawRecord["turn_index"] = turn_index
    if case_group is not None:
        rawRecord["case_group"] = case_group
    if state_before is not None:
        rawRecord["state_before"] = state_before
    if state_after is not None:
        rawRecord["state_after"] = state_after
    if previous_outcome is not None:
        rawRecord["previous_outcome"] = previous_outcome
    if outcome is not None:
        rawRecord["outcome"] = outcome
    if benchmark_version is not None:
        rawRecord["benchmark_version"] = benchmark_version
    if label_rationale is not None:
        rawRecord["label_rationale"] = label_rationale
    if perception_trace is not None:
        rawRecord["perception_trace"] = perception_trace
    if evaluation_split is not None:
        rawRecord["evaluation_split"] = evaluation_split
    if benchmark_suite is not None:
        rawRecord["benchmark_suite"] = benchmark_suite
    if benchmark_label_digest is not None:
        rawRecord["benchmark_label_digest"] = benchmark_label_digest
    record = normalize_record(rawRecord)
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True))
        handle.write("\n")
    return True


def record_session_case(
    path: str | Path,
    schema_id: Any,
    case_id: Any,
    action_id: Any,
    winner_margin: float,
    features: Sequence[Sequence[Any]],
    state: Sequence[Sequence[Any]],
    scores: Sequence[Sequence[Any]],
    diagnostics: Sequence[Sequence[Any]],
    expected_action: Any,
    acceptable_actions: Sequence[Any],
    selected_styles: Sequence[Any],
    expected_styles: Sequence[Any],
    session_id: Any,
    turn_index: int,
    case_group: Any,
    state_before_goals: Sequence[Any],
    state_before_modulators: Sequence[Any],
    state_after_goals: Sequence[Any],
    state_after_modulators: Sequence[Any],
    previous_outcome: Sequence[Sequence[Any]],
    outcome: Sequence[Sequence[Any]],
    response: Any | None = None,
    response_metrics: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    runtime: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    benchmark_version: Any | None = None,
    label_rationale: Any | None = None,
    perception_trace: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    evaluation_split: Any | None = None,
    benchmark_suite: Any | None = None,
    benchmark_label_digest: Any | None = None,
) -> bool:
    return record_case(
        path,
        schema_id,
        case_id,
        action_id,
        winner_margin,
        features,
        state,
        scores,
        diagnostics,
        expected_action,
        acceptable_actions,
        selected_styles,
        expected_styles,
        response,
        response_metrics or None,
        runtime,
        session_id,
        turn_index,
        case_group,
        state_from_vectors(state_before_goals, state_before_modulators),
        state_from_vectors(state_after_goals, state_after_modulators),
        previous_outcome,
        outcome,
        benchmark_version,
        label_rationale,
        perception_trace,
        evaluation_split,
        benchmark_suite,
        benchmark_label_digest,
    )


def record_policy_case(
    path: str | Path,
    schema_id: Any,
    case_id: Any,
    case_group: Any,
    action_id: Any,
    winner_margin: float,
    features: Sequence[Sequence[Any]],
    state: Sequence[Sequence[Any]],
    scores: Sequence[Sequence[Any]],
    diagnostics: Sequence[Sequence[Any]],
    expected_action: Any,
    acceptable_actions: Sequence[Any],
    selected_styles: Sequence[Any],
    expected_styles: Sequence[Any],
    session_id: Any | None = None,
    turn_index: int | None = None,
    benchmark_version: Any | None = None,
    label_rationale: Any | None = None,
    runtime: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    perception_trace: Sequence[Sequence[Any]] | Mapping[str, Any] | None = None,
    benchmark_suite: Any | None = None,
    benchmark_label_digest: Any | None = None,
    evaluation_split: Any | None = None,
) -> bool:
    return record_case(
        path,
        schema_id,
        case_id,
        action_id,
        winner_margin,
        features,
        state,
        scores,
        diagnostics,
        expected_action,
        acceptable_actions,
        selected_styles,
        expected_styles,
        session_id=session_id,
        turn_index=turn_index,
        case_group=case_group,
        benchmark_version=benchmark_version,
        label_rationale=label_rationale,
        runtime=runtime,
        perception_trace=perception_trace,
        evaluation_split=evaluation_split,
        benchmark_suite=benchmark_suite,
        benchmark_label_digest=benchmark_label_digest,
    )


def load_records(path: str | Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for line_number, line in enumerate(
        Path(path).read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line.strip():
            continue
        try:
            records.append(normalize_record(json.loads(line)))
        except (json.JSONDecodeError, EvaluationFormatError) as exc:
            raise EvaluationFormatError(
                f"invalid evaluation record on line {line_number}"
            ) from exc
    if not records:
        raise EvaluationFormatError("evaluation input contains no records")
    return records


def _distribution(values: Sequence[float]) -> dict[str, Any]:
    if not values:
        return {"count": 0, "minimum": None, "mean": None, "maximum": None}
    return {
        "count": len(values),
        "minimum": min(values),
        "mean": sum(values) / len(values),
        "maximum": max(values),
    }


def _soft_score(record: Mapping[str, Any]) -> float:
    if record["action_id"] == record["expected_action"]:
        return 1.0
    if record["action_id"] in record.get("acceptable_actions", ()):
        return 0.8
    return 0.0


def _top_three_hit(record: Mapping[str, Any]) -> bool:
    ranking = sorted(
        record["scores"],
        key=record["scores"].get,
        reverse=True,
    )[:3]
    return record["expected_action"] in ranking


def _compactSelectionMetrics(
    records: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    observedActions = sorted(
        {record["expected_action"] for record in records}
        | {record["action_id"] for record in records}
    )
    actionF1 = []
    for action in observedActions:
        truePositive = sum(
            record["expected_action"] == action and record["action_id"] == action
            for record in records
        )
        falsePositive = sum(
            record["expected_action"] != action and record["action_id"] == action
            for record in records
        )
        falseNegative = sum(
            record["expected_action"] == action and record["action_id"] != action
            for record in records
        )
        precision = (
            truePositive / (truePositive + falsePositive)
            if truePositive + falsePositive
            else 0.0
        )
        recall = (
            truePositive / (truePositive + falseNegative)
            if truePositive + falseNegative
            else 0.0
        )
        actionF1.append(
            2.0 * precision * recall / (precision + recall)
            if precision + recall
            else 0.0
        )
    return {
        "case_count": len(records),
        "strict_accuracy": sum(
            record["action_id"] == record["expected_action"] for record in records
        )
        / len(records),
        "soft_accuracy": sum(_soft_score(record) for record in records)
        / len(records),
        "top3_hit_rate": sum(_top_three_hit(record) for record in records)
        / len(records),
        "macro_f1": sum(actionF1) / len(actionF1),
        "expected_action_available_rate": sum(
            record["expected_action"] in record["scores"] for record in records
        )
        / len(records),
    }


def _mappings_close(
    left: Mapping[str, float], right: Mapping[str, float], tolerance: float = 1e-9
) -> bool:
    return set(left) == set(right) and all(
        abs(left[name] - right[name]) <= tolerance for name in left
    )


def summarize(records: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
    normalized = [normalize_record(record) for record in records]
    if not normalized:
        raise EvaluationFormatError("cannot summarize an empty evaluation")
    actions = Counter(record["action_id"] for record in normalized)
    margins = [record["winner_margin"] for record in normalized]
    diagnostics = [record["diagnostics"] for record in normalized]
    state_minima = {
        name: min(record["state"][name] for record in normalized)
        for name in NORMATIVE_NAMES + OVERGOAL_NAMES
    }
    result: dict[str, Any] = {
        "schema_id": SCHEMA_ID,
        "case_count": len(normalized),
        "action_counts": dict(sorted(actions.items())),
        "winner_margin": {
            "minimum": min(margins),
            "mean": sum(margins) / len(margins),
            "maximum": max(margins),
        },
        "minimum_state_values": state_minima,
        "safe_after_rate": sum(item["safe_after"] for item in diagnostics)
        / len(diagnostics),
        "lax_law_rate": sum(item["lax_holds"] for item in diagnostics)
        / len(diagnostics),
        "contractive_rate": sum(item["contractive"] for item in diagnostics)
        / len(diagnostics),
        "projection_interventions": sum(
            item["projection_distance"] > 1e-12 for item in diagnostics
        ),
    }
    benchmarkVersions = sorted(
        {
            record["benchmark_version"]
            for record in normalized
            if record.get("benchmark_version")
        }
    )
    if benchmarkVersions:
        result["benchmark_versions"] = benchmarkVersions
    benchmarkLabelDigests = sorted(
        {
            record["benchmark_label_digest"]
            for record in normalized
            if record.get("benchmark_label_digest")
        }
    )
    if benchmarkLabelDigests:
        result["benchmark_label_digests"] = benchmarkLabelDigests
    result["projection_intervention_rate"] = (
        result["projection_interventions"] / len(diagnostics)
    )
    laxErrors = [item["lax_error"] for item in diagnostics]
    result["lax_error"] = {
        "minimum": min(laxErrors),
        "mean": sum(laxErrors) / len(laxErrors),
        "maximum": max(laxErrors),
    }
    withBaseAlpha = [
        item
        for item in diagnostics
        if "base_alpha" in item and item["base_alpha"] > 0.0
    ]
    if withBaseAlpha:
        result["alpha_backoff_rate"] = sum(
            item["accepted_alpha"] + 1e-12 < item["base_alpha"]
            for item in withBaseAlpha
        ) / len(withBaseAlpha)
        result["accepted_alpha_ratio_mean"] = sum(
            item["accepted_alpha"] / item["base_alpha"]
            for item in withBaseAlpha
        ) / len(withBaseAlpha)
    withSafeBefore = [item for item in diagnostics if "safe_before" in item]
    if withSafeBefore:
        result["safe_before_rate"] = sum(
            item["safe_before"] for item in withSafeBefore
        ) / len(withSafeBefore)

    labeled = [record for record in normalized if record.get("expected_action")]
    if labeled:
        strictCorrect = sum(
            record["action_id"] == record["expected_action"] for record in labeled
        )
        softTotal = sum(_soft_score(record) for record in labeled)
        top3Hits = sum(_top_three_hit(record) for record in labeled)
        confusion: dict[str, Counter[str]] = defaultdict(Counter)
        for record in labeled:
            confusion[record["expected_action"]][record["action_id"]] += 1
        observedActions = sorted(
            {record["expected_action"] for record in labeled}
            | {record["action_id"] for record in labeled}
        )
        perAction = {}
        for action in observedActions:
            truePositive = sum(
                record["expected_action"] == action and record["action_id"] == action
                for record in labeled
            )
            falsePositive = sum(
                record["expected_action"] != action and record["action_id"] == action
                for record in labeled
            )
            falseNegative = sum(
                record["expected_action"] == action and record["action_id"] != action
                for record in labeled
            )
            support = truePositive + falseNegative
            precision = (
                truePositive / (truePositive + falsePositive)
                if truePositive + falsePositive
                else 0.0
            )
            recall = truePositive / support if support else 0.0
            f1 = (
                2.0 * precision * recall / (precision + recall)
                if precision + recall
                else 0.0
            )
            perAction[action] = {
                "support": support,
                "precision": precision,
                "recall": recall,
                "f1": f1,
            }
        correctMargins = [
            record["winner_margin"]
            for record in labeled
            if record["action_id"] == record["expected_action"]
        ]
        incorrectMargins = [
            record["winner_margin"]
            for record in labeled
            if record["action_id"] != record["expected_action"]
        ]
        candidateCounts = [len(record["scores"]) for record in labeled]
        expectedAvailable = [
            record["expected_action"] in record["scores"] for record in labeled
        ]
        result["action_selection"] = {
            "labeled_case_count": len(labeled),
            "strict_accuracy": strictCorrect / len(labeled),
            "soft_accuracy": softTotal / len(labeled),
            "top3_hit_rate": top3Hits / len(labeled),
            "expected_action_available_rate": sum(expectedAvailable) / len(labeled),
            "expected_action_unavailable_count": len(labeled) - sum(expectedAvailable),
            "candidate_count": _distribution(candidateCounts),
            "winner_margin_by_correctness": {
                "correct": _distribution(correctMargins),
                "incorrect": _distribution(incorrectMargins),
            },
            "per_action": perAction,
            "macro_precision": sum(
                metrics["precision"] for metrics in perAction.values()
            )
            / len(perAction),
            "macro_recall": sum(metrics["recall"] for metrics in perAction.values())
            / len(perAction),
            "macro_f1": sum(metrics["f1"] for metrics in perAction.values())
            / len(perAction),
            "confusion_matrix": {
                expected: dict(sorted(predicted.items()))
                for expected, predicted in sorted(confusion.items())
            },
        }
        splitRecords: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for record in labeled:
            if record.get("evaluation_split"):
                splitRecords[record["evaluation_split"]].append(record)
        if splitRecords:
            result["evaluation_splits"] = {
                name: _compactSelectionMetrics(records)
                for name, records in sorted(splitRecords.items())
            }
        suiteRecords: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for record in labeled:
            if record.get("benchmark_suite"):
                suiteRecords[record["benchmark_suite"]].append(record)
        if suiteRecords:
            result["benchmark_suites"] = {
                name: _compactSelectionMetrics(records)
                for name, records in sorted(suiteRecords.items())
            }

    groupedCases: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in normalized:
        if record.get("case_group"):
            groupedCases[record["case_group"]].append(record)
    repeatedGroups = [records for records in groupedCases.values() if len(records) > 1]
    if repeatedGroups:
        result["robustness"] = {
            "group_count": len(repeatedGroups),
            "prediction_consistency_rate": sum(
                len({record["action_id"] for record in records}) == 1
                for records in repeatedGroups
            )
            / len(repeatedGroups),
            "mean_majority_agreement": sum(
                max(Counter(record["action_id"] for record in records).values())
                / len(records)
                for records in repeatedGroups
            )
            / len(repeatedGroups),
        }

    sessions: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in normalized:
        if record.get("session_id"):
            sessions[record["session_id"]].append(record)
    if sessions:
        perSession: dict[str, Any] = {}
        completeSuccesses = 0
        stateContinuityChecks = 0
        stateContinuityPasses = 0
        outcomeContinuityChecks = 0
        outcomeContinuityPasses = 0
        for sessionId, records in sorted(sessions.items()):
            ordered = sorted(records, key=lambda item: item.get("turn_index", -1))
            sessionLabeled = [
                record for record in ordered if record.get("expected_action")
            ]
            strict = [
                record["action_id"] == record["expected_action"]
                for record in sessionLabeled
            ]
            complete = bool(strict) and all(strict)
            completeSuccesses += complete
            perSession[sessionId] = {
                "turn_count": len(ordered),
                "strict_accuracy": sum(strict) / len(strict) if strict else None,
                "soft_accuracy": (
                    sum(_soft_score(record) for record in sessionLabeled)
                    / len(sessionLabeled)
                    if sessionLabeled
                    else None
                ),
                "top3_hit_rate": (
                    sum(_top_three_hit(record) for record in sessionLabeled)
                    / len(sessionLabeled)
                    if sessionLabeled
                    else None
                ),
                "complete_success": complete,
            }
            for previous, current in zip(ordered, ordered[1:]):
                if "state_after" in previous and "state_before" in current:
                    stateContinuityChecks += 1
                    stateContinuityPasses += _mappings_close(
                        previous["state_after"], current["state_before"]
                    )
                if "outcome" in previous and "previous_outcome" in current:
                    outcomeContinuityChecks += 1
                    outcomeContinuityPasses += _mappings_close(
                        previous["outcome"], current["previous_outcome"]
                    )
        result["sessions"] = {
            "session_count": len(sessions),
            "complete_success_rate": completeSuccesses / len(sessions),
            "state_continuity_rate": (
                stateContinuityPasses / stateContinuityChecks
                if stateContinuityChecks
                else None
            ),
            "outcome_continuity_rate": (
                outcomeContinuityPasses / outcomeContinuityChecks
                if outcomeContinuityChecks
                else None
            ),
            "by_session": perSession,
        }

    withStateTransitions = [
        record
        for record in normalized
        if "state_before" in record and "state_after" in record
    ]
    if withStateTransitions:
        perCoordinate = {
            name: _distribution(
                [
                    abs(record["state_after"][name] - record["state_before"][name])
                    for record in withStateTransitions
                ]
            )
            for name in STATE_NAMES
        }
        allChanges = [
            abs(record["state_after"][name] - record["state_before"][name])
            for record in withStateTransitions
            for name in STATE_NAMES
        ]
        result["state_dynamics"] = {
            "transition_count": len(withStateTransitions),
            "absolute_change": _distribution(allChanges),
            "by_coordinate": perCoordinate,
        }

    styleLabeled = [
        record for record in normalized if record.get("expected_styles")
    ]
    if styleLabeled:
        result["style_selection"] = {
            "labeled_case_count": len(styleLabeled),
            "primary_accuracy": sum(
                bool(record.get("selected_styles"))
                and record["selected_styles"][0] == record["expected_styles"][0]
                for record in styleLabeled
            )
            / len(styleLabeled),
            "coverage_rate": sum(
                set(record["expected_styles"]).issubset(record.get("selected_styles", ()))
                for record in styleLabeled
            )
            / len(styleLabeled),
        }

    qualityRecords = [
        record["response_metrics"]
        for record in normalized
        if "response_metrics" in record
    ]
    if qualityRecords:
        compositeScores = [_response_composite(metrics) for metrics in qualityRecords]
        result["response_quality"] = {
            "evaluated_case_count": len(qualityRecords),
            "mean": {
                name: sum(metrics[name] for metrics in qualityRecords)
                / len(qualityRecords)
                for name in RESPONSE_METRIC_NAMES
            },
            "composite": {
                "minimum": min(compositeScores),
                "mean": sum(compositeScores) / len(compositeScores),
                "maximum": max(compositeScores),
            },
        }

    runtimeRecords = [
        record["runtime"] for record in normalized if "runtime" in record
    ]
    if runtimeRecords:
        numericSummary = {}
        for name in RUNTIME_NUMERIC_NAMES:
            values = [
                runtime[name] for runtime in runtimeRecords if name in runtime
            ]
            if values:
                numericSummary[name] = {
                    "mean": sum(values) / len(values),
                    "total": sum(values),
                }
        result["runtime"] = {
            "evaluated_case_count": len(runtimeRecords),
            "numeric": numericSummary,
        }
    return result


def _svg_document(title: str, labels: list[str], values: list[float]) -> str:
    width = 760
    height = 360
    left = 90
    right = 30
    top = 55
    bottom = 90
    plot_width = width - left - right
    plot_height = height - top - bottom
    maximum = max(max(values), 1e-9)
    gap = plot_width / max(len(values), 1)
    bar_width = gap * 0.62
    elements = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        f'<text x="{width / 2}" y="28" text-anchor="middle" font-family="sans-serif" font-size="18">{title}</text>',
        f'<line x1="{left}" y1="{top + plot_height}" x2="{width - right}" y2="{top + plot_height}" stroke="#333"/>',
    ]
    for index, (label, value) in enumerate(zip(labels, values, strict=True)):
        bar_height = plot_height * value / maximum
        x = left + index * gap + (gap - bar_width) / 2
        y = top + plot_height - bar_height
        elements.append(
            f'<rect x="{x:.2f}" y="{y:.2f}" width="{bar_width:.2f}" height="{bar_height:.2f}" fill="#365f91"/>'
        )
        elements.append(
            f'<text x="{x + bar_width / 2:.2f}" y="{y - 7:.2f}" text-anchor="middle" font-family="sans-serif" font-size="12">{value:.4f}</text>'
        )
        elements.append(
            f'<text x="{x + bar_width / 2:.2f}" y="{top + plot_height + 22}" text-anchor="end" transform="rotate(-28 {x + bar_width / 2:.2f} {top + plot_height + 22})" font-family="sans-serif" font-size="11">{label}</text>'
        )
    elements.append("</svg>")
    return "\n".join(elements) + "\n"


def _confusion_matrix_svg(selection: Mapping[str, Any]) -> str:
    matrix = selection["confusion_matrix"]
    actions = sorted(
        set(matrix)
        | {
            predicted
            for predictions in matrix.values()
            for predicted in predictions
        }
    )
    cell = 54
    left = 150
    top = 130
    width = left + cell * len(actions) + 30
    height = top + cell * len(actions) + 45
    maximum = max(
        [value for row in matrix.values() for value in row.values()] or [1]
    )
    elements = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        f'<text x="{width / 2}" y="28" text-anchor="middle" font-family="sans-serif" font-size="18">Action confusion matrix</text>',
        '<text x="18" y="75" font-family="sans-serif" font-size="12">Expected</text>',
        f'<text x="{left + cell * len(actions) / 2}" y="52" text-anchor="middle" font-family="sans-serif" font-size="12">Predicted</text>',
    ]
    for column, action in enumerate(actions):
        x = left + column * cell + cell / 2
        elements.append(
            f'<text x="{x:.2f}" y="{top - 10}" text-anchor="end" transform="rotate(-35 {x:.2f} {top - 10})" font-family="sans-serif" font-size="10">{escape(action)}</text>'
        )
    for row, expected in enumerate(actions):
        y = top + row * cell
        elements.append(
            f'<text x="{left - 8}" y="{y + cell / 2 + 4:.2f}" text-anchor="end" font-family="sans-serif" font-size="10">{escape(expected)}</text>'
        )
        for column, predicted in enumerate(actions):
            value = int(matrix.get(expected, {}).get(predicted, 0))
            intensity = value / maximum
            shade = round(245 - 155 * intensity)
            x = left + column * cell
            elements.append(
                f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" fill="rgb({shade},{shade},{255})" stroke="#ffffff"/>'
            )
            elements.append(
                f'<text x="{x + cell / 2}" y="{y + cell / 2 + 5}" text-anchor="middle" font-family="sans-serif" font-size="13">{value}</text>'
            )
    elements.append("</svg>")
    return "\n".join(elements) + "\n"


def summaryText(records: Iterable[Mapping[str, Any]]) -> str:
    summary = summarize(records)
    def formatRate(value: Any) -> str:
        return "n/a" if value is None else f"{value:.4f}"

    lines = [f"Qwestor evaluation: {summary['case_count']} cases"]
    selection = summary.get("action_selection")
    if selection:
        lines.append(
            "Policy: "
            f"strict={selection['strict_accuracy']:.4f}, "
            f"soft={selection['soft_accuracy']:.4f}, "
            f"top3={selection['top3_hit_rate']:.4f}, "
            f"macro_f1={selection['macro_f1']:.4f}, "
            f"expected_available={selection['expected_action_available_rate']:.4f}"
        )
    for splitName, split in summary.get("evaluation_splits", {}).items():
        lines.append(
            f"Split {splitName}: n={split['case_count']}, "
            f"strict={split['strict_accuracy']:.4f}, "
            f"soft={split['soft_accuracy']:.4f}, "
            f"top3={split['top3_hit_rate']:.4f}, "
            f"macro_f1={split['macro_f1']:.4f}, "
            f"expected_available={split['expected_action_available_rate']:.4f}"
        )
    for suiteName, suite in summary.get("benchmark_suites", {}).items():
        lines.append(
            f"Suite {suiteName}: n={suite['case_count']}, "
            f"strict={suite['strict_accuracy']:.4f}, "
            f"soft={suite['soft_accuracy']:.4f}, "
            f"top3={suite['top3_hit_rate']:.4f}, "
            f"macro_f1={suite['macro_f1']:.4f}, "
            f"expected_available={suite['expected_action_available_rate']:.4f}"
        )
    margin = summary["winner_margin"]
    lines.append(
        f"Margin: min={margin['minimum']:.4f}, mean={margin['mean']:.4f}, max={margin['maximum']:.4f}"
    )
    if "sessions" in summary:
        sessions = summary["sessions"]
        lines.append(
            "Sessions: "
            f"count={sessions['session_count']}, "
            f"complete={sessions['complete_success_rate']:.4f}, "
            f"state_continuity={formatRate(sessions['state_continuity_rate'])}, "
            f"outcome_continuity={formatRate(sessions['outcome_continuity_rate'])}"
        )
    if "response_quality" in summary:
        quality = summary["response_quality"]
        lines.append(
            f"Response quality: n={quality['evaluated_case_count']}, composite={quality['composite']['mean']:.4f}"
        )
    if "runtime" in summary:
        runtime = summary["runtime"]["numeric"]
        latency = runtime.get("latency_ms", {}).get("total", 0.0)
        cost = runtime.get("cost_usd", {}).get("total", 0.0)
        lines.append(f"Runtime: latency_ms={latency:.2f}, cost_usd={cost:.6f}")
    return "\n".join(lines)


def summaryTextFromFile(path: str | Path) -> str:
    return summaryText(load_records(path))


def write_artifacts(
    records: Iterable[Mapping[str, Any]], output_dir: str | Path
) -> dict[str, str]:
    normalized = [normalize_record(record) for record in records]
    summary = summarize(normalized)
    destination = Path(output_dir)
    destination.mkdir(parents=True, exist_ok=True)
    summary_path = destination / "summary.json"
    cases_path = destination / "cases.csv"
    margins_path = destination / "winner_margins.svg"
    safeguards_path = destination / "minimum_safeguards.svg"
    action_metrics_path = destination / "action_metrics.svg"
    confusion_path = destination / "confusion_matrix.svg"
    summary_path.write_text(
        json.dumps(summary, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    with cases_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "session_id",
                "turn_index",
                "case_id",
                "case_group",
                "benchmark_version",
                "benchmark_suite",
                "benchmark_label_digest",
                "evaluation_split",
                "label_rationale",
                "expected_action",
                "action_id",
                "action_correct",
                "expected_action_available",
                "candidate_count",
                "winner_margin",
                "selected_styles",
                "expected_styles",
                "primary_style_correct",
                "response_quality_composite",
                "latency_ms",
                "cost_usd",
                "boundary_pressure",
                "projection_distance",
                "safe_after",
            ]
        )
        for record in normalized:
            expectedAction = record.get("expected_action", "")
            selectedStyles = record.get("selected_styles", ())
            expectedStyles = record.get("expected_styles", ())
            primaryStyleCorrect: bool | str = ""
            if expectedStyles:
                primaryStyleCorrect = bool(selectedStyles) and (
                    selectedStyles[0] == expectedStyles[0]
                )
            qualityComposite: float | str = ""
            if "response_metrics" in record:
                qualityComposite = _response_composite(record["response_metrics"])
            runtime = record.get("runtime", {})
            writer.writerow(
                [
                    record.get("session_id", ""),
                    record.get("turn_index", ""),
                    record["case_id"],
                    record.get("case_group", ""),
                    record.get("benchmark_version", ""),
                    record.get("benchmark_suite", ""),
                    record.get("benchmark_label_digest", ""),
                    record.get("evaluation_split", ""),
                    record.get("label_rationale", ""),
                    expectedAction,
                    record["action_id"],
                    record["action_id"] == expectedAction
                    if expectedAction
                    else "",
                    expectedAction in record["scores"] if expectedAction else "",
                    len(record["scores"]),
                    record["winner_margin"],
                    " ".join(selectedStyles),
                    " ".join(expectedStyles),
                    primaryStyleCorrect,
                    qualityComposite,
                    runtime.get("latency_ms", ""),
                    runtime.get("cost_usd", ""),
                    record["diagnostics"]["boundary_pressure"],
                    record["diagnostics"]["projection_distance"],
                    record["diagnostics"]["safe_after"],
                ]
            )
    margins_path.write_text(
        _svg_document(
            "Qwestor winner margins",
            [record["case_id"] for record in normalized],
            [record["winner_margin"] for record in normalized],
        ),
        encoding="utf-8",
    )
    safeguards_path.write_text(
        _svg_document(
            "Minimum normative and overgoal values",
            list(summary["minimum_state_values"]),
            list(summary["minimum_state_values"].values()),
        ),
        encoding="utf-8",
    )
    artifacts = {
        "summary": str(summary_path),
        "cases": str(cases_path),
        "winner_margins": str(margins_path),
        "minimum_safeguards": str(safeguards_path),
    }
    if "action_selection" in summary:
        selection = summary["action_selection"]
        action_metrics_path.write_text(
            _svg_document(
                "Qwestor action-selection metrics",
                ["strict", "soft", "top-3", "macro F1", "expected available"],
                [
                    selection["strict_accuracy"],
                    selection["soft_accuracy"],
                    selection["top3_hit_rate"],
                    selection["macro_f1"],
                    selection["expected_action_available_rate"],
                ],
            ),
            encoding="utf-8",
        )
        confusion_path.write_text(
            _confusion_matrix_svg(selection),
            encoding="utf-8",
        )
        artifacts["action_metrics"] = str(action_metrics_path)
        artifacts["confusion_matrix"] = str(confusion_path)
    if "sessions" in summary:
        session_path = destination / "session_accuracy.svg"
        sessionItems = summary["sessions"]["by_session"]
        session_path.write_text(
            _svg_document(
                "Strict accuracy by session",
                list(sessionItems),
                [item["strict_accuracy"] or 0.0 for item in sessionItems.values()],
            ),
            encoding="utf-8",
        )
        artifacts["session_accuracy"] = str(session_path)
    if "benchmark_suites" in summary:
        suite_path = destination / "suite_accuracy.svg"
        suiteItems = summary["benchmark_suites"]
        suite_path.write_text(
            _svg_document(
                "Strict accuracy by benchmark suite",
                list(suiteItems),
                [item["strict_accuracy"] for item in suiteItems.values()],
            ),
            encoding="utf-8",
        )
        artifacts["suite_accuracy"] = str(suite_path)
    return artifacts


def evaluate_file(path: str | Path, output_dir: str | Path) -> dict[str, str]:
    return write_artifacts(load_records(path), output_dir)


def generate_artifacts(path: str | Path, output_dir: str | Path) -> bool:
    evaluate_file(path, output_dir)
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    artifacts = evaluate_file(args.input, args.output)
    print(json.dumps(artifacts, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
