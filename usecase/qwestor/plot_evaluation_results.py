from __future__ import annotations

import argparse
import importlib.util
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_RESULTS = SCRIPT_DIR / "metrics" / "artifacts" / "perception_results.jsonl"
DEFAULT_OUTPUT_DIR = SCRIPT_DIR / "metrics" / "artifacts" / "perception" / "plots"

BLUE = "#2563EB"
CYAN = "#06B6D4"
GREEN = "#10B981"
ORANGE = "#F59E0B"
RED = "#EF4444"
PURPLE = "#8B5CF6"
PINK = "#EC4899"
GRID_COLOR = "#D9E2F2"


def loadEvaluationModule():
    path = SCRIPT_DIR / "metrics" / "eval.py"
    spec = importlib.util.spec_from_file_location("qwestor_plot_evaluation", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load Qwestor evaluator from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


EVALUATION = loadEvaluationModule()


def parseArgs() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Plot Qwestor action and session evaluation results."
    )
    parser.add_argument(
        "--results",
        type=Path,
        default=DEFAULT_RESULTS,
        help=f"Qwestor JSONL records (default: {DEFAULT_RESULTS})",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"PNG destination (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument("--dpi", type=int, default=180, help="Output resolution.")
    return parser.parse_args()


def loadEvaluation(path: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    try:
        records = EVALUATION.load_records(path.expanduser())
    except (FileNotFoundError, EVALUATION.EvaluationFormatError) as error:
        raise SystemExit(f"Cannot load Qwestor evaluation records: {error}") from error
    summary = EVALUATION.summarize(records)
    if "action_selection" not in summary:
        raise SystemExit("The records contain no expected-action labels")
    if "sessions" not in summary:
        raise SystemExit("The records contain no session identifiers")
    return records, summary


def actionName(action: str) -> str:
    return action.removeprefix("act_")


def sessionName(sessionId: str) -> str:
    name = sessionId.removeprefix("session_")
    if "_r" in name:
        base, repeat = name.rsplit("_r", 1)
        return f"{base.upper()}\nr{repeat}"
    return name.upper() if len(name) <= 3 else name


def styleAxis(axis: plt.Axes, *, yGrid: bool = True) -> None:
    axis.spines[["top", "right"]].set_visible(False)
    if yGrid:
        axis.grid(axis="y", color=GRID_COLOR, linewidth=0.7, alpha=0.7)
        axis.set_axisbelow(True)


def labelPercentBars(axis: plt.Axes, bars: Iterable[Any]) -> None:
    for bar in bars:
        height = float(bar.get_height())
        axis.text(
            bar.get_x() + bar.get_width() / 2,
            height + 0.018,
            f"{height:.1%}",
            ha="center",
            va="bottom",
            fontsize=8,
        )


def actionOrder(records: list[dict[str, Any]]) -> list[str]:
    return sorted(
        {record["action_id"] for record in records}
        | {record["expected_action"] for record in records}
    )


def sessionOrder(records: list[dict[str, Any]]) -> list[str]:
    return list(dict.fromkeys(record["session_id"] for record in records))


def recordsBySession(
    records: list[dict[str, Any]],
) -> dict[str, list[dict[str, Any]]]:
    grouped = {sessionId: [] for sessionId in sessionOrder(records)}
    for record in records:
        grouped[record["session_id"]].append(record)
    for sessionRecords in grouped.values():
        sessionRecords.sort(key=lambda item: item["turn_index"])
    return grouped


def plotOverallMetrics(axis: plt.Axes, summary: dict[str, Any]) -> None:
    selection = summary["action_selection"]
    values = [
        selection["strict_accuracy"],
        selection["soft_accuracy"],
        selection["top3_hit_rate"],
    ]
    bars = axis.bar(
        ["Strict\naccuracy", "Soft\naccuracy", "Top-3\nhit rate"],
        values,
        color=[BLUE, ORANGE, GREEN],
    )
    labelPercentBars(axis, bars)
    axis.set_ylim(0, 1.12)
    axis.set_ylabel("Score")
    axis.set_title(f"Overall action metrics (n={summary['case_count']} turns)")
    styleAxis(axis)


def plotSelectionDiagnostics(axis: plt.Axes, summary: dict[str, Any]) -> None:
    selection = summary["action_selection"]
    sessions = summary["sessions"]
    labels = ["Macro F1", "Expected action\navailable", "Complete\nsessions"]
    values = [
        selection["macro_f1"],
        selection["expected_action_available_rate"],
        sessions["complete_success_rate"],
    ]
    bars = axis.bar(labels, values, color=[PURPLE, CYAN, PINK])
    labelPercentBars(axis, bars)
    axis.set_ylim(0, 1.12)
    axis.set_ylabel("Rate")
    axis.set_title("Selection and complete-session diagnostics")
    styleAxis(axis)


def plotActionDistribution(
    axis: plt.Axes, records: list[dict[str, Any]], actions: list[str]
) -> None:
    expected = Counter(record["expected_action"] for record in records)
    predicted = Counter(record["action_id"] for record in records)
    x = np.arange(len(actions))
    axis.bar(x - 0.2, [expected[a] for a in actions], 0.4, color=CYAN, label="Expected")
    axis.bar(x + 0.2, [predicted[a] for a in actions], 0.4, color=PURPLE, label="Predicted")
    axis.set_xticks(x, [actionName(action) for action in actions], rotation=25, ha="right")
    axis.set_ylabel("Turn count")
    axis.set_title("Expected vs. predicted action distribution")
    axis.legend(frameon=False, fontsize=8)
    styleAxis(axis)


def plotPerActionMetrics(
    axis: plt.Axes, summary: dict[str, Any], actions: list[str]
) -> None:
    metrics = summary["action_selection"]["per_action"]
    x = np.arange(len(actions))
    width = 0.25
    axis.bar(x - width, [metrics[a]["precision"] for a in actions], width, color=BLUE, label="Precision")
    axis.bar(x, [metrics[a]["recall"] for a in actions], width, color=ORANGE, label="Recall")
    axis.bar(x + width, [metrics[a]["f1"] for a in actions], width, color=GREEN, label="F1")
    axis.set_xticks(x, [actionName(action) for action in actions], rotation=25, ha="right")
    axis.set_ylim(0, 1.12)
    axis.set_ylabel("Score")
    axis.set_title("Per-action precision, recall, and F1")
    axis.legend(frameon=False, fontsize=8, ncols=3)
    styleAxis(axis)


def plotConfusionMatrix(
    axis: plt.Axes, summary: dict[str, Any], actions: list[str]
) -> None:
    confusion = summary["action_selection"]["confusion_matrix"]
    matrix = np.array(
        [[confusion.get(row, {}).get(column, 0) for column in actions] for row in actions],
        dtype=int,
    )
    image = axis.imshow(matrix, cmap="YlGnBu", aspect="auto")
    threshold = matrix.max() / 2 if matrix.size else 0
    for row in range(matrix.shape[0]):
        for column in range(matrix.shape[1]):
            value = matrix[row, column]
            if value:
                axis.text(
                    column,
                    row,
                    str(value),
                    ha="center",
                    va="center",
                    fontsize=8,
                    color="white" if value > threshold else "black",
                )
    labels = [actionName(action) for action in actions]
    axis.set_xticks(range(len(actions)), labels, rotation=35, ha="right")
    axis.set_yticks(range(len(actions)), labels)
    axis.set_xlabel("Predicted action")
    axis.set_ylabel("Expected action")
    axis.set_title("Confusion matrix")
    axis.figure.colorbar(image, ax=axis, fraction=0.046, pad=0.04, label="Turn count")


def plotSessionAccuracy(
    axis: plt.Axes,
    records: list[dict[str, Any]],
    summary: dict[str, Any],
) -> None:
    sessions = sessionOrder(records)
    bySession = summary["sessions"]["by_session"]
    values = [bySession[name]["strict_accuracy"] or 0.0 for name in sessions]
    bars = axis.bar(range(len(sessions)), values, color=BLUE)
    for bar, sessionId in zip(bars, sessions):
        axis.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 0.015,
            f"n={bySession[sessionId]['turn_count']}",
            ha="center",
            va="bottom",
            fontsize=7,
        )
    overall = summary["action_selection"]["strict_accuracy"]
    axis.axhline(overall, color=RED, linestyle="--", linewidth=1.3, label=f"overall {overall:.1%}")
    axis.set_xticks(range(len(sessions)), [sessionName(name) for name in sessions])
    axis.set_ylim(0, 1.14)
    axis.set_ylabel("Strict accuracy")
    axis.set_title("Strict accuracy by session")
    axis.legend(frameon=False, fontsize=8)
    styleAxis(axis)


def plotSessionMetrics(
    axis: plt.Axes,
    records: list[dict[str, Any]],
    summary: dict[str, Any],
) -> None:
    sessions = sessionOrder(records)
    bySession = summary["sessions"]["by_session"]
    x = np.arange(len(sessions))
    width = 0.27
    for offset, field, label, color in (
        (-width, "strict_accuracy", "Strict", BLUE),
        (0, "soft_accuracy", "Soft", ORANGE),
        (width, "top3_hit_rate", "Top-3", GREEN),
    ):
        axis.bar(
            x + offset,
            [bySession[name][field] or 0.0 for name in sessions],
            width,
            color=color,
            label=label,
        )
    axis.set_xticks(x, [sessionName(name) for name in sessions])
    axis.set_ylim(0, 1.14)
    axis.set_ylabel("Score")
    axis.set_title("Session action metrics")
    axis.legend(frameon=False, fontsize=8, ncols=3)
    styleAxis(axis)


def plotSessionMargins(axis: plt.Axes, records: list[dict[str, Any]]) -> None:
    grouped = recordsBySession(records)
    sessions = list(grouped)
    values = [
        sum(record["winner_margin"] for record in grouped[name]) / len(grouped[name])
        for name in sessions
    ]
    x = np.arange(len(sessions))
    axis.plot(x, values, color=PURPLE, marker="o", markerfacecolor=PINK, linewidth=2.0)
    overall = sum(record["winner_margin"] for record in records) / len(records)
    axis.axhline(overall, color=ORANGE, linestyle="--", linewidth=1.3, label=f"overall {overall:.3f}")
    axis.set_xticks(x, [sessionName(name) for name in sessions])
    axis.set_ylabel("Average winner margin")
    axis.set_title("Decision confidence by session")
    axis.legend(frameon=False, fontsize=8)
    styleAxis(axis)


def plotSessionOutcomes(axis: plt.Axes, records: list[dict[str, Any]]) -> None:
    grouped = recordsBySession(records)
    sessions = list(grouped)
    strict = []
    acceptable = []
    incorrect = []
    for name in sessions:
        exact = sum(record["action_id"] == record["expected_action"] for record in grouped[name])
        softOnly = sum(
            record["action_id"] != record["expected_action"]
            and record["action_id"] in record.get("acceptable_actions", ())
            for record in grouped[name]
        )
        strict.append(exact)
        acceptable.append(softOnly)
        incorrect.append(len(grouped[name]) - exact - softOnly)
    x = np.arange(len(sessions))
    axis.bar(x, strict, color=GREEN, label="Exact")
    axis.bar(x, acceptable, bottom=strict, color=ORANGE, label="Acceptable")
    axis.bar(
        x,
        incorrect,
        bottom=np.array(strict) + np.array(acceptable),
        color=RED,
        label="Incorrect",
    )
    axis.set_xticks(x, [sessionName(name) for name in sessions])
    axis.set_ylabel("Turn count")
    axis.set_title("Exact, acceptable, and incorrect turns")
    axis.legend(frameon=False, fontsize=8)
    styleAxis(axis)


def saveFigures(
    records: list[dict[str, Any]],
    summary: dict[str, Any],
    outputDir: Path,
    dpi: int,
) -> tuple[Path, Path]:
    outputDir.mkdir(parents=True, exist_ok=True)
    actions = actionOrder(records)

    sessionPath = outputDir / "per_session_analysis.png"
    sessionFigure, sessionAxes = plt.subplots(2, 2, figsize=(20, 12))
    plotSessionAccuracy(sessionAxes[0, 0], records, summary)
    plotSessionMetrics(sessionAxes[0, 1], records, summary)
    plotSessionMargins(sessionAxes[1, 0], records)
    plotSessionOutcomes(sessionAxes[1, 1], records)
    sessionFigure.suptitle("Qwestor per-session evaluation", fontsize=19, y=0.995)
    sessionFigure.tight_layout(rect=(0, 0, 1, 0.975), h_pad=3.0, w_pad=2.0)
    sessionFigure.savefig(sessionPath, dpi=dpi, bbox_inches="tight")
    plt.close(sessionFigure)

    overallPath = outputDir / "overall_action_analysis.png"
    overallFigure = plt.figure(figsize=(20, 18))
    grid = overallFigure.add_gridspec(3, 2, height_ratios=(1, 1, 1.35))
    plotOverallMetrics(overallFigure.add_subplot(grid[0, 0]), summary)
    plotSelectionDiagnostics(overallFigure.add_subplot(grid[0, 1]), summary)
    plotActionDistribution(overallFigure.add_subplot(grid[1, 0]), records, actions)
    plotPerActionMetrics(overallFigure.add_subplot(grid[1, 1]), summary, actions)
    plotConfusionMatrix(overallFigure.add_subplot(grid[2, :]), summary, actions)
    overallFigure.suptitle("Qwestor overall action evaluation", fontsize=19, y=0.995)
    overallFigure.tight_layout(rect=(0, 0, 1, 0.98), h_pad=3.0, w_pad=2.0)
    overallFigure.savefig(overallPath, dpi=dpi, bbox_inches="tight")
    plt.close(overallFigure)
    return sessionPath, overallPath


def main() -> None:
    args = parseArgs()
    if args.dpi <= 0:
        raise SystemExit("--dpi must be greater than zero")
    records, summary = loadEvaluation(args.results)
    paths = saveFigures(records, summary, args.output_dir, args.dpi)
    print("Created:")
    for path in paths:
        print(f"  {path}")


if __name__ == "__main__":
    main()
