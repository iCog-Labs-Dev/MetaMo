"""
Creates plots as two composite files.

Every plotted value is read from ``eval/evaluation_results.json``.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Iterable

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_RESULTS = SCRIPT_DIR / "eval" / "evaluation_results.json"
DEFAULT_OUTPUT_DIR = SCRIPT_DIR / "plots"

BLUE = "#2563EB"
CYAN = "#06B6D4"
GREEN = "#10B981"
ORANGE = "#F59E0B"
RED = "#EF4444"
PURPLE = "#8B5CF6"
PINK = "#EC4899"
GRID_COLOR = "#D9E2F2"
SERIES_COLORS = [BLUE, ORANGE, GREEN, PURPLE, PINK, CYAN, RED]


def parse_args() -> argparse.Namespace:
    """Parse command-line paths and output-resolution options."""

    parser = argparse.ArgumentParser(
        description="Generate nine evaluation plots grouped into two PNG files."
    )
    parser.add_argument(
        "--results",
        type=Path,
        default=DEFAULT_RESULTS,
        help=f"Evaluation JSON to plot (default: {DEFAULT_RESULTS})",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"Directory for the two PNG files (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument("--dpi", type=int, default=180, help="Output resolution.")
    return parser.parse_args()


def load_evaluation(path: Path) -> dict[str, Any]:
    """Load an evaluation JSON file and validate its required top-level fields."""

    try:
        with path.expanduser().open(encoding="utf-8") as source:
            data = json.load(source)
    except FileNotFoundError as exc:
        raise SystemExit(f"Evaluation file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc

    required = {
        "turn_count",
        "strict_accuracy",
        "soft_accuracy",
        "top3_hit_rate",
        "average_decision_margin",
        "predicted_action_counts",
        "expected_action_counts",
        "confusion_matrix",
        "sessions",
    }
    missing = sorted(required.difference(data))
    if missing:
        raise SystemExit(f"{path} is missing required fields: {', '.join(missing)}")
    if not isinstance(data["sessions"], dict) or not data["sessions"]:
        raise SystemExit(f"{path} does not contain any session results")
    return data


def short_session_name(session_id: str) -> str:
    """Convert a session identifier such as ``session_a`` into ``A``."""

    name = session_id.removeprefix("session_")
    return name.upper() if len(name) <= 3 else name


def action_name(action: str) -> str:
    """Remove the ``act_`` prefix from an action name for display."""
    return action.removeprefix("act_")


def action_order(evaluation: dict[str, Any]) -> list[str]:
    """Return the sorted union of actions present anywhere in an evaluation."""

    actions: set[str] = set()
    actions.update(evaluation.get("expected_action_counts", {}))
    actions.update(evaluation.get("predicted_action_counts", {}))
    for expected, predictions in evaluation.get("confusion_matrix", {}).items():
        actions.add(expected)
        actions.update(predictions)
    return sorted(actions)


def session_order(evaluation: dict[str, Any]) -> list[str]:
    """Return session identifiers in the order stored in the results file."""
    return list(evaluation["sessions"])


def finite_number(value: Any, default: float = 0.0) -> float:
    """Convert a metric to float while replacing JSON null values safely."""

    return default if value is None else float(value)


def style_axis(axis: plt.Axes, *, y_grid: bool = True) -> None:
    axis.spines[["top", "right"]].set_visible(False)
    if y_grid:
        axis.grid(axis="y", color=GRID_COLOR, linewidth=0.7, alpha=0.7)
        axis.set_axisbelow(True)


def label_percent_bars(axis: plt.Axes, bars: Iterable[Any]) -> None:
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


def recall_by_action(evaluation: dict[str, Any], actions: list[str]) -> list[float]:
    """Calculate recall for each action from expected counts and the matrix diagonal."""

    matrix = evaluation["confusion_matrix"]
    expected_counts = evaluation["expected_action_counts"]
    return [
        (
            finite_number(matrix.get(action, {}).get(action))
            / finite_number(expected_counts.get(action), 0.0)
            if finite_number(expected_counts.get(action), 0.0)
            else 0.0
        )
        for action in actions
    ]


def plot_overall_metrics(axis: plt.Axes, evaluation: dict[str, Any]) -> None:
    """Plot the run's strict accuracy, soft accuracy, and top-three hit rate."""

    labels = ["Strict\naccuracy", "Soft\naccuracy", "Top-3\nhit rate"]
    values = [
        finite_number(evaluation["strict_accuracy"]),
        finite_number(evaluation["soft_accuracy"]),
        finite_number(evaluation["top3_hit_rate"]),
    ]
    bars = axis.bar(labels, values, color=[BLUE, ORANGE, GREEN])
    label_percent_bars(axis, bars)
    axis.set_ylim(0, 1.12)
    axis.set_ylabel("Score")
    axis.set_title(f"Overall Evaluation Metrics (n={evaluation['turn_count']} turns)")
    style_axis(axis)


def plot_accuracy_summary(axis: plt.Axes, evaluation: dict[str, Any]) -> None:
    """Plot a focused comparison of strict and soft accuracy for the current run."""

    labels = ["Strict\naccuracy", "Soft\naccuracy"]
    values = [
        finite_number(evaluation["strict_accuracy"]),
        finite_number(evaluation["soft_accuracy"]),
    ]
    x = np.arange(len(labels))
    bars = axis.bar(x, values, 0.55, color=[BLUE, ORANGE])
    label_percent_bars(axis, bars)
    axis.set_title("Overall Strict and Soft Accuracy")
    axis.set_xticks(x, labels)
    axis.set_ylim(0, 1.12)
    axis.set_ylabel("Score")
    style_axis(axis)


def plot_action_distribution(axis: plt.Axes, evaluation: dict[str, Any]) -> None:
    """Compare expected and predicted turn counts for every observed action."""

    actions = action_order(evaluation)
    x = np.arange(len(actions))
    expected = [evaluation["expected_action_counts"].get(a, 0) for a in actions]
    predicted = [evaluation["predicted_action_counts"].get(a, 0) for a in actions]
    axis.bar(x - 0.2, expected, 0.4, color=CYAN, label="Expected")
    axis.bar(x + 0.2, predicted, 0.4, color=PURPLE, label="Predicted")
    axis.set_xticks(x, [action_name(a) for a in actions], rotation=25, ha="right")
    axis.set_ylabel("Turn count")
    axis.set_title("Expected vs. Predicted Action Distribution")
    axis.legend(frameon=False, fontsize=8)
    style_axis(axis)


def plot_action_recall(axis: plt.Axes, evaluation: dict[str, Any]) -> None:
    """Plot dynamically calculated recall for each expected action."""

    actions = action_order(evaluation)
    x = np.arange(len(actions))
    recall = recall_by_action(evaluation, actions)
    colors = [SERIES_COLORS[index % len(SERIES_COLORS)] for index in range(len(actions))]
    axis.bar(x, recall, 0.55, color=colors)
    axis.set_title("Per-Action Recall")
    axis.set_xticks(x, [action_name(a) for a in actions], rotation=25, ha="right")
    axis.set_ylim(0, 1.12)
    axis.set_ylabel("Recall (correct / expected)")
    style_axis(axis)


def plot_confusion_matrix(axis: plt.Axes, evaluation: dict[str, Any]) -> None:
    """Render expected-versus-predicted counts as an annotated heat map."""

    actions = action_order(evaluation)
    matrix = np.array(
        [
            [evaluation["confusion_matrix"].get(row, {}).get(column, 0) for column in actions]
            for row in actions
        ],
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
    labels = [action_name(action) for action in actions]
    axis.set_xticks(range(len(actions)), labels, rotation=35, ha="right")
    axis.set_yticks(range(len(actions)), labels)
    axis.set_xlabel("Predicted action")
    axis.set_ylabel("Expected action")
    axis.set_title("Confusion Matrix — Expected vs. Predicted")
    axis.figure.colorbar(image, ax=axis, fraction=0.046, pad=0.04, label="Turn count")


def plot_session_accuracy(axis: plt.Axes, evaluation: dict[str, Any]) -> None:
    """Plot strict accuracy and turn count for every session."""

    sessions = session_order(evaluation)
    metrics = evaluation["sessions"]
    values = [finite_number(metrics[s]["strict_accuracy"]) for s in sessions]
    counts = [int(metrics[s]["turn_count"]) for s in sessions]
    colors = [SERIES_COLORS[index % len(SERIES_COLORS)] for index in range(len(sessions))]
    bars = axis.bar(range(len(sessions)), values, color=colors)
    for bar, count in zip(bars, counts):
        axis.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 0.015,
            f"n={count}",
            ha="center",
            va="bottom",
            fontsize=7,
        )
    overall = finite_number(evaluation["strict_accuracy"])
    axis.axhline(overall, color=RED, linestyle="--", linewidth=1.3)
    axis.text(
        len(sessions) - 0.45,
        overall + 0.02,
        f"overall {overall:.1%}",
        ha="right",
        fontsize=8,
    )
    axis.set_xticks(range(len(sessions)), [short_session_name(s) for s in sessions])
    axis.set_ylim(0, 1.14)
    axis.set_ylabel("Strict accuracy")
    axis.set_title("Strict Accuracy by Session")
    style_axis(axis)


def plot_session_metrics(axis: plt.Axes, evaluation: dict[str, Any]) -> None:
    """Compare strict, soft, and top-three metrics side by side per session."""

    sessions = session_order(evaluation)
    metrics = evaluation["sessions"]
    x = np.arange(len(sessions))
    width = 0.27
    series = [
        ("strict_accuracy", "Strict accuracy", BLUE),
        ("soft_accuracy", "Soft accuracy", ORANGE),
        ("top3_hit_rate", "Top-3 hit rate", GREEN),
    ]
    for offset, (field, label, color) in zip((-width, 0, width), series):
        axis.bar(
            x + offset,
            [finite_number(metrics[s][field]) for s in sessions],
            width,
            color=color,
            label=label,
        )
    axis.set_xticks(x, [short_session_name(s) for s in sessions])
    axis.set_ylim(0, 1.14)
    axis.set_ylabel("Score")
    axis.set_title("Strict vs. Soft Accuracy vs. Top-3 Hit Rate by Session")
    axis.legend(frameon=False, fontsize=8, ncols=3, loc="lower center")
    style_axis(axis)


def plot_session_margins(axis: plt.Axes, evaluation: dict[str, Any]) -> None:
    """Plot average top-one/top-two decision margins across sessions."""

    sessions = session_order(evaluation)
    values = [
        finite_number(evaluation["sessions"][s]["average_decision_margin"])
        for s in sessions
    ]
    x = np.arange(len(sessions))
    axis.plot(
        x,
        values,
        color=PURPLE,
        marker="o",
        markerfacecolor=PINK,
        markeredgecolor=PURPLE,
        linewidth=2.0,
    )
    overall = finite_number(evaluation["average_decision_margin"])
    axis.axhline(overall, color=ORANGE, linestyle="--", linewidth=1.3)
    axis.text(
        len(sessions) - 0.45,
        overall + max(values + [0.01]) * 0.03,
        f"overall {overall:.3f}",
        ha="right",
        fontsize=8,
        color="#555555",
    )
    axis.set_xticks(x, [short_session_name(s) for s in sessions])
    axis.set_ylabel("Average decision margin")
    axis.set_title("Average Top-1/Top-2 Decision Margin by Session")
    style_axis(axis)


def plot_session_outcomes(axis: plt.Axes, evaluation: dict[str, Any]) -> None:
    """Plot strictly correct and incorrect turn counts as stacked session bars."""

    sessions = session_order(evaluation)
    x = np.arange(len(sessions))
    correct = [int(evaluation["sessions"][s]["strict_correct"]) for s in sessions]
    totals = [int(evaluation["sessions"][s]["turn_count"]) for s in sessions]
    incorrect = [total - right for total, right in zip(totals, correct)]
    axis.bar(x, correct, color=GREEN, label="Strictly correct")
    axis.bar(x, incorrect, bottom=correct, color=RED, label="Incorrect")
    axis.set_ylabel("Turn count")
    axis.set_title("Correct and Incorrect Turns by Session")
    axis.legend(frameon=False, fontsize=8)
    axis.set_xticks(x, [short_session_name(s) for s in sessions])
    style_axis(axis)


def save_figures(
    evaluation: dict[str, Any],
    output_dir: Path,
    dpi: int,
) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)

    session_path = output_dir / "per_session_analysis.png"
    session_figure, session_axes = plt.subplots(2, 2, figsize=(20, 12))
    plot_session_accuracy(session_axes[0, 0], evaluation)
    plot_session_metrics(session_axes[0, 1], evaluation)
    plot_session_margins(session_axes[1, 0], evaluation)
    plot_session_outcomes(session_axes[1, 1], evaluation)
    session_figure.suptitle("Per-Session Evaluation Analysis", fontsize=19, y=0.995)
    session_figure.tight_layout(rect=(0, 0, 1, 0.975), h_pad=3.0, w_pad=2.0)
    session_figure.savefig(session_path, dpi=dpi, bbox_inches="tight")
    plt.close(session_figure)

    overall_path = output_dir / "overall_action_analysis.png"
    overall_figure = plt.figure(figsize=(20, 18))
    grid = overall_figure.add_gridspec(3, 2, height_ratios=(1, 1, 1.35))
    plot_overall_metrics(overall_figure.add_subplot(grid[0, 0]), evaluation)
    plot_accuracy_summary(overall_figure.add_subplot(grid[0, 1]), evaluation)
    plot_action_distribution(overall_figure.add_subplot(grid[1, 0]), evaluation)
    plot_action_recall(overall_figure.add_subplot(grid[1, 1]), evaluation)
    plot_confusion_matrix(overall_figure.add_subplot(grid[2, :]), evaluation)
    overall_figure.suptitle("Overall and Per-Action Evaluation Analysis", fontsize=19, y=0.995)
    overall_figure.tight_layout(rect=(0, 0, 1, 0.98), h_pad=3.0, w_pad=2.0)
    overall_figure.savefig(overall_path, dpi=dpi, bbox_inches="tight")
    plt.close(overall_figure)

    return session_path, overall_path


def main() -> None:
    args = parse_args()
    if args.dpi <= 0:
        raise SystemExit("--dpi must be greater than zero")
    evaluation = load_evaluation(args.results)
    paths = save_figures(evaluation, args.output_dir, args.dpi)
    print("Created:")
    for path in paths:
        print(f"  plots/{path.name}")


if __name__ == "__main__":
    main()
