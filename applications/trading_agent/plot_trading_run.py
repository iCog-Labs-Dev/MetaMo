import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

NUM = r"([-+]?[\d.]+(?:[eE][-+]?\d+)?)"
TRADER_RE = re.compile(
    rf"\(TRADER scenario (\w+) step (\d+) price {NUM} action (\w+) emotion \((\w+) {NUM}\)"
    rf" feelings \({NUM} {NUM} {NUM} {NUM}\)"
    rf" valence {NUM} securing {NUM} gInd {NUM} gTrans {NUM} value {NUM}\)"
)
BASELINE_RE = re.compile(rf"\(BASELINE scenario (\w+) step (\d+) price {NUM} action (\w+) value {NUM}\)")

EMOTION_COLORS = {
    "happy": "goldenrod",
    "sad": "steelblue",
    "angry": "firebrick",
    "fear": "purple",
    "neutral": "gray",
}
EMOTION_GAMMA = 0.6  # dominance threshold from openpsi/config.metta
TRADE_ACTIONS = ("buy", "sell", "reduce")
TRADE_STYLES = {
    "buy": {"marker": "^", "color": "green", "label": "BUY"},
    "sell": {"marker": "v", "color": "red", "label": "SELL"},
    "reduce": {"marker": "D", "color": "darkorange", "label": "REDUCE"},
}


def stripAnsi(text):
    """Removes ANSI color codes so logs saved from a terminal parse cleanly."""
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def parseTraderLog(path):
    """Reads the MetaMo agent log into a list of one dict per step."""
    rows = []
    for match in TRADER_RE.finditer(stripAnsi(Path(path).read_text())):
        (scenario, step, price, action, emotion, intensity,
         fHappy, fSad, fAngry, fFear,
         valence, securing, gInd, gTrans, value) = match.groups()
        rows.append({
            "scenario": scenario,
            "step": int(step),
            "price": float(price),
            "action": action,
            "emotion": emotion,
            "intensity": float(intensity),
            "happy": float(fHappy),
            "sad": float(fSad),
            "angry": float(fAngry),
            "fear": float(fFear),
            "valence": float(valence),
            "securing": float(securing),
            "gInd": float(gInd),
            "gTrans": float(gTrans),
            "value": float(value),
        })
    return rows


def plotPress(scenario, trader, outPath):
    """The presentation figure. It shows the price with the agent's real
    decisions marked, the agent's emotional state as a background color for
    every step, and the feeling layer's intensity curves below. Everything
    comes from the agent's own run log, nothing is placed by hand."""
    steps = [r["step"] for r in trader]
    prices = [r["price"] for r in trader]

    fig, (axPrice, axFeel) = plt.subplots(
        2, 1, figsize=(12.5, 7.5), sharex=True,
        gridspec_kw={"height_ratios": [2.6, 1.0]}
    )

    # emotional state as background tint, one band per step
    seenEmotions = []
    for row in trader:
        color = EMOTION_COLORS.get(row["emotion"], "gray")
        axPrice.axvspan(row["step"] - 0.5, row["step"] + 0.5,
                        color=color, alpha=0.16, linewidth=0)
        if row["emotion"] not in seenEmotions:
            seenEmotions.append(row["emotion"])

    axPrice.plot(steps, prices, color="#222222", linewidth=1.9, zorder=3)

    # the agent's actual decisions
    for row in trader:
        if row["action"] in TRADE_STYLES:
            style = TRADE_STYLES[row["action"]]
            yOffset = -22 if row["action"] == "buy" else 14
            axPrice.scatter(row["step"], row["price"], marker=style["marker"],
                            color=style["color"], s=190, zorder=4, edgecolors="white")
            axPrice.annotate(style["label"], (row["step"], row["price"]),
                             textcoords="offset points", xytext=(0, yOffset),
                             ha="center", fontsize=11, fontweight="bold", color=style["color"])

    finalValue = trader[-1]["value"]
    axPrice.annotate(
                     f"final: {finalValue:.2f}  DD: {maxDrawdown(trader):.1%}  "
                     f"trades: {tradeCount(trader)}  (start 100)",
                     xy=(0.02, 0.05), xycoords="axes fraction", fontsize=11,
                     bbox=dict(boxstyle="round", facecolor="white", alpha=0.85))

    handles = []
    for action in TRADE_ACTIONS:
        if any(row["action"] == action for row in trader):
            style = TRADE_STYLES[action]
            handles.append(
                plt.Line2D([], [], marker=style["marker"], linestyle="",
                           color=style["color"], markersize=11,
                           markeredgecolor="white",
                           label=f"{style['label']} (agent decision)")
            )
    handles.append(
        plt.Line2D([], [], color="#222222", linewidth=1.9,
                   label="price (no marker = hold)")
    )
    for e in seenEmotions:
        handles.append(plt.Rectangle((0, 0), 1, 1,
                                     color=EMOTION_COLORS.get(e, "gray"),
                                     alpha=0.35,
                                     label=f"background: agent feels {e}"))
    axPrice.legend(handles=handles, loc="upper right", fontsize=9.5,
                   framealpha=0.92)
    axPrice.set_ylabel("price", fontsize=12)
    axPrice.set_title(f"MetaMo trading agent - decisions and emotional state ({scenario})",
                      fontsize=14)
    axPrice.grid(alpha=0.25)

    # genuine emotion intensities from the OpenPSI feeling layer
    for name in ("happy", "sad", "angry", "fear"):
        axFeel.plot(steps, [r[name] for r in trader],
                    label=name, color=EMOTION_COLORS[name], linewidth=1.7)
    axFeel.axhline(EMOTION_GAMMA, color="black", linestyle="--", linewidth=0.9)
    axFeel.text(steps[0], EMOTION_GAMMA + 0.02, f"dominance threshold γ = {EMOTION_GAMMA}",
                fontsize=9)
    axFeel.set_ylim(0, 1.0)
    axFeel.set_ylabel("emotion intensity (feeling layer)", fontsize=11)
    axFeel.set_xlabel("time step", fontsize=12)
    axFeel.legend(loc="center right", fontsize=10, ncol=4)
    axFeel.grid(alpha=0.25)

    fig.tight_layout()
    fig.savefig(outPath, dpi=200)
    plt.close(fig)


def parseBaselineLog(path):
    """Reads the baseline log into a list of one dict per step."""
    rows = []
    for match in BASELINE_RE.finditer(stripAnsi(Path(path).read_text())):
        scenario, step, price, action, value = match.groups()
        rows.append({
            "scenario": scenario,
            "step": int(step),
            "price": float(price),
            "action": action,
            "value": float(value),
        })
    return rows


def maxDrawdown(rows):
    """Computes max drawdown from parsed portfolio values."""
    peak = 100.0
    drawdown = 0.0
    for row in rows:
        value = row["value"]
        peak = max(peak, value)
        if peak > 0.0:
            drawdown = max(drawdown, (peak - value) / peak)
    return drawdown


def tradeCount(rows):
    """Counts portfolio-changing actions."""
    return sum(1 for row in rows if row["action"] in TRADE_ACTIONS)


def valueLabel(name, rows):
    """Builds a compact portfolio label for chart legends."""
    return (
        f"{name} final {rows[-1]['value']:.2f}, "
        f"DD {maxDrawdown(rows):.1%}, trades {tradeCount(rows)}"
    )


def tradeMarkers(axis, rows, marker_kwargs, hollow=False):
    """Draws portfolio-changing trade markers for one agent on a price axis."""
    for action in TRADE_ACTIONS:
        points = [(r["step"], r["price"]) for r in rows if r["action"] == action]
        if points:
            style = TRADE_STYLES[action]
            kwargs = dict(marker_kwargs)
            if hollow:
                kwargs.setdefault("facecolors", "none")
                kwargs.setdefault("edgecolors", style["color"])
            else:
                kwargs.setdefault("color", style["color"])
            axis.scatter(*zip(*points), marker=style["marker"], **kwargs)


def tradeLegendHandles(rows, prefix, hollow=False):
    """Builds legend handles for the trade actions actually present."""
    handles = []
    for action in TRADE_ACTIONS:
        if any(row["action"] == action for row in rows):
            style = TRADE_STYLES[action]
            kwargs = {
                "marker": style["marker"],
                "linestyle": "",
                "markersize": 10,
                "label": f"{prefix} {action}",
            }
            if hollow:
                kwargs["markerfacecolor"] = "none"
                kwargs["markeredgecolor"] = style["color"]
                kwargs["color"] = style["color"]
            else:
                kwargs["color"] = style["color"]
            handles.append(plt.Line2D([], [], **kwargs))
    return handles


def plotComparison(scenario, trader, baseline, outPath):
    """Price chart with both agents' trades and both portfolio value curves."""
    steps = [r["step"] for r in trader]
    prices = [r["price"] for r in trader]

    fig, (axPrice, axValue) = plt.subplots(2, 1, figsize=(9, 6.5), sharex=True)

    axPrice.plot(steps, prices, color="black", linewidth=1.2, label="price")
    tradeMarkers(axPrice, trader, dict(s=110, zorder=3, label=None))
    tradeMarkers(axPrice, baseline, dict(s=110, zorder=2, linewidths=1.5), hollow=True)
    axPrice.set_ylabel("price")
    axPrice.set_title(f"{scenario}: MetaMo risk controller vs raw signal")
    markerHandles = (
        tradeLegendHandles(trader, "MetaMo")
        + tradeLegendHandles(baseline, "signal", hollow=True)
    )
    axPrice.legend(handles=markerHandles, loc="best", fontsize=9, ncol=2,
                   framealpha=0.9)
    axPrice.grid(alpha=0.3)

    axValue.plot(steps, [r["value"] for r in trader],
                 label=valueLabel("MetaMo", trader), linewidth=1.6)
    axValue.plot([r["step"] for r in baseline], [r["value"] for r in baseline], "--",
                 label=valueLabel("signal", baseline), linewidth=1.4)
    buyHoldValues = [100.0 * price / prices[0] for price in prices]
    axValue.plot(steps, buyHoldValues, ":", color="black",
                 label=f"passive final {buyHoldValues[-1]:.2f}", linewidth=1.2)
    axValue.axhline(100.0, color="gray", linewidth=0.8, alpha=0.6)
    axValue.set_xlabel("step")
    axValue.set_ylabel("portfolio value")
    axValue.legend()
    axValue.grid(alpha=0.3)

    fig.tight_layout()
    fig.savefig(outPath, dpi=150)
    plt.close(fig)


def plotDynamics(scenario, trader, outPath):
    """The agent's internal MetaMo state per step, lined up with the price."""
    steps = [r["step"] for r in trader]

    fig, (axPrice, axMods, axGoals, axEmotion) = plt.subplots(
        4, 1, figsize=(9, 10), sharex=True
    )

    axPrice.plot(steps, [r["price"] for r in trader], color="black", linewidth=1.2)
    tradeMarkers(axPrice, trader, dict(s=110, zorder=3))
    axPrice.set_ylabel("price")
    axPrice.set_title(f"{scenario}: MetaMo trading agent internal dynamics")
    axPrice.legend(handles=tradeLegendHandles(trader, "agent"),
                   loc="best", fontsize=9)
    axPrice.grid(alpha=0.3)

    axMods.plot(steps, [r["valence"] for r in trader], label="valence", linewidth=1.5)
    axMods.plot(steps, [r["securing"] for r in trader], label="securing", linewidth=1.5)
    axMods.set_ylabel("modulators")
    axMods.set_ylim(0, 1.05)
    axMods.legend(loc="lower left")
    axMods.grid(alpha=0.3)

    axGoals.plot(steps, [r["gInd"] for r in trader], label="gInd (individuation)", linewidth=1.5)
    axGoals.plot(steps, [r["gTrans"] for r in trader], label="gTrans (transcendence)", linewidth=1.5)
    axGoals.set_ylabel("overgoals")
    axGoals.set_ylim(0, 1.05)
    axGoals.legend(loc="center left")
    axGoals.grid(alpha=0.3)

    colors = [EMOTION_COLORS.get(r["emotion"], "gray") for r in trader]
    axEmotion.scatter(steps, [r["intensity"] for r in trader], c=colors, s=45, zorder=3)
    axEmotion.axhline(EMOTION_GAMMA, color="black", linestyle="--", linewidth=0.9,
                      label=f"dominance threshold γ={EMOTION_GAMMA}")
    seen = []
    for row in trader:
        if row["emotion"] not in seen:
            seen.append(row["emotion"])
    handles = [plt.Line2D([], [], marker="o", linestyle="", color=EMOTION_COLORS.get(e, "gray"), label=e)
               for e in seen]
    handles.append(plt.Line2D([], [], linestyle="--", color="black", label=f"γ = {EMOTION_GAMMA}"))
    axEmotion.legend(handles=handles, loc="lower right", ncol=len(handles))
    axEmotion.set_ylabel("dominant emotion\nintensity")
    axEmotion.set_xlabel("step")
    axEmotion.set_ylim(0, 1.0)
    axEmotion.grid(alpha=0.3)

    fig.tight_layout()
    fig.savefig(outPath, dpi=150)
    plt.close(fig)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    traderLog, baselineLog = sys.argv[1], sys.argv[2]
    outDir = Path(sys.argv[3]) if len(sys.argv) > 3 else Path(".")
    outDir.mkdir(parents=True, exist_ok=True)

    trader = parseTraderLog(traderLog)
    baseline = parseBaselineLog(baselineLog)
    if not trader or not baseline:
        print(f"parsed {len(trader)} trader rows and {len(baseline)} baseline rows - check the log files")
        sys.exit(1)

    scenarios = []
    for row in trader:
        if row["scenario"] not in scenarios:
            scenarios.append(row["scenario"])
    for scenario in scenarios:
        traderRows = [r for r in trader if r["scenario"] == scenario]
        baselineRows = [r for r in baseline if r["scenario"] == scenario]
        if not baselineRows:
            print(f"no baseline rows for scenario {scenario}, skipping comparison")
            continue
        comparisonPath = outDir / f"trading_agent_vs_baseline_{scenario}.png"
        dynamicsPath = outDir / f"trading_agent_dynamics_{scenario}.png"
        pressPath = outDir / f"trading_agent_press_{scenario}.png"
        plotComparison(scenario, traderRows, baselineRows, comparisonPath)
        plotDynamics(scenario, traderRows, dynamicsPath)
        plotPress(scenario, traderRows, pressPath)
        print(f"wrote {comparisonPath}")
        print(f"wrote {dynamicsPath}")
        print(f"wrote {pressPath}")


if __name__ == "__main__":
    main()
