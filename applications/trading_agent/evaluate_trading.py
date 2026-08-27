import json
import math
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
EVAL_DIR = APP_DIR / "eval"
RESULTS_PATH = EVAL_DIR / "evaluation_results.json"

NUM = r"([-+]?[\d.]+(?:[eE][-+]?\d+)?)"
TRADER_STEP_RE = re.compile(
    rf"\(TRADER scenario (\w+) step (\d+) price {NUM} action (\w+) emotion \((\w+) {NUM}\)"
    rf" feelings \({NUM} {NUM} {NUM} {NUM}\)"
    rf" valence {NUM} securing {NUM} gInd {NUM} gTrans {NUM} value {NUM}\)"
)
TRADER_FINAL_RE = re.compile(rf"\(TRADER FINAL scenario (\w+) value {NUM}\)")
BASELINE_FINAL_RE = re.compile(rf"\(BASELINE FINAL scenario (\w+) value {NUM}\)")
BASELINE_STEP_RE = re.compile(rf"\(BASELINE scenario (\w+) step (\d+) price {NUM} action (\w+) value {NUM}\)")
TRADE_ACTIONS = ("buy", "sell", "reduce")


def stripAnsi(text):
    """Removes ANSI color codes so terminal output parses cleanly."""
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def runPetta(runner, mettaFile):
    """Runs one MeTTa file through the PeTTa runner and returns its output."""
    result = subprocess.run(
        ["sh", str(runner), str(APP_DIR / mettaFile)],
        capture_output=True, text=True, timeout=3600,
    )
    return stripAnsi(result.stdout)


def evaluateAgent(agentText):
    """Builds the per-scenario evaluation from the MetaMo agent's atoms."""
    scenarios = {}
    for m in TRADER_STEP_RE.finditer(agentText):
        (scenario, step, price, action, emotion, intensity,
         happy, sad, angry, fear, valence, securing, gInd, gTrans, value) = m.groups()
        entry = scenarios.setdefault(scenario, {
            "trades": [], "steps": 0, "emotionCounts": {},
            "minValence": 1.0, "maxFear": 0.0, "values": [], "prices": [],
        })
        entry["steps"] += 1
        entry["values"].append(float(value))
        entry["prices"].append(float(price))
        entry["emotionCounts"][emotion] = entry["emotionCounts"].get(emotion, 0) + 1
        entry["minValence"] = min(entry["minValence"], float(valence))
        entry["maxFear"] = max(entry["maxFear"], float(fear))
        if action in TRADE_ACTIONS:
            entry["trades"].append({
                "step": int(step), "action": action, "price": float(price),
            })
    for m in TRADER_FINAL_RE.finditer(agentText):
        scenario, value = m.groups()
        scenarios.setdefault(scenario, {})["finalValue"] = float(value)
    for data in scenarios.values():
        enrichScenarioMetrics(data)
    return scenarios


def evaluateBaseline(baselineText):
    """Builds the per-scenario evaluation from the baseline atoms."""
    scenarios = {}
    for m in BASELINE_STEP_RE.finditer(baselineText):
        scenario, step, price, action, value = m.groups()
        entry = scenarios.setdefault(scenario, {
            "trades": [], "steps": 0, "values": [], "prices": [],
        })
        entry["steps"] += 1
        entry["values"].append(float(value))
        entry["prices"].append(float(price))
        if action in TRADE_ACTIONS:
            entry["trades"].append({
                "step": int(step), "action": action, "price": float(price),
            })
    for m in BASELINE_FINAL_RE.finditer(baselineText):
        scenario, value = m.groups()
        scenarios.setdefault(scenario, {})["finalValue"] = float(value)
    for data in scenarios.values():
        enrichScenarioMetrics(data)
    return scenarios


def maxDrawdown(values):
    """Computes max drawdown from a value curve."""
    peak = 100.0
    maxDrawdownValue = 0.0
    for value in values:
        peak = max(peak, value)
        if peak > 0.0:
            maxDrawdownValue = max(maxDrawdownValue, (peak - value) / peak)
    return maxDrawdownValue


def enrichScenarioMetrics(data):
    """Adds non-annualized return, risk, and activity metrics."""
    values = data.get("values", [])
    prices = data.get("prices", [])
    finalValue = data.get("finalValue", values[-1] if values else 0.0)
    tradeCount = len(data.get("trades", []))
    drawdown = maxDrawdown(values)
    portfolioReturns = []
    previous = 100.0
    for value in values:
        if previous > 0.0:
            portfolioReturns.append((value - previous) / previous)
        previous = value
    meanReturn = sum(portfolioReturns) / len(portfolioReturns) if portfolioReturns else 0.0
    variance = (
        sum((value - meanReturn) ** 2 for value in portfolioReturns) / len(portfolioReturns)
        if portfolioReturns else 0.0
    )
    volatility = math.sqrt(variance)
    downside = [min(value, 0.0) for value in portfolioReturns]
    downsideDeviation = math.sqrt(
        sum(value * value for value in downside) / len(downside)
    ) if downside else 0.0
    data["finalValue"] = finalValue
    data["returnPct"] = (finalValue - 100.0) / 100.0
    data["maxDrawdown"] = drawdown
    data["tradeCount"] = tradeCount
    data["minValue"] = min(values) if values else finalValue
    data["maxValue"] = max(values) if values else finalValue
    data["volatility"] = volatility
    data["sharpePerStep"] = meanReturn / volatility if volatility > 1e-12 else 0.0
    data["sortinoPerStep"] = meanReturn / downsideDeviation if downsideDeviation > 1e-12 else 0.0
    data["returnToDrawdown"] = data["returnPct"] / drawdown if drawdown > 1e-12 else None
    buyHoldValues = [100.0 * price / prices[0] for price in prices] if prices and prices[0] > 0.0 else [100.0]
    data["buyHoldFinal"] = buyHoldValues[-1]
    data["buyHoldReturn"] = (data["buyHoldFinal"] - 100.0) / 100.0
    data["buyHoldDrawdown"] = maxDrawdown(buyHoldValues)


def buildResults(agentText, baselineText, source):
    """Puts both evaluations together with a summary."""
    agent = evaluateAgent(agentText)
    baseline = evaluateBaseline(baselineText)
    baselineFinals = {scenario: data.get("finalValue", 0.0) for scenario, data in baseline.items()}
    summary = {
        "benchmark": "same_signal_without_metamo",
        "meanAgentReturn": 0.0,
        "meanBaselineReturn": 0.0,
        "meanBuyHoldReturn": 0.0,
        "meanAgentDrawdown": 0.0,
        "meanBaselineDrawdown": 0.0,
        "meanBuyHoldDrawdown": 0.0,
        "wins": {},
    }
    agentReturns = []
    baselineReturns = []
    buyHoldReturns = []
    agentDrawdowns = []
    baselineDrawdowns = []
    buyHoldDrawdowns = []
    for scenario, data in agent.items():
        agentFinal = data.get("finalValue", 0.0)
        baseData = baseline.get(scenario, {})
        baseFinal = baseData.get("finalValue", 0.0)
        data["excessVsSignal"] = (agentFinal - baseFinal) / 100.0
        agentReturns.append(data.get("returnPct", 0.0))
        baselineReturns.append(baseData.get("returnPct", 0.0))
        buyHoldReturns.append(data.get("buyHoldReturn", 0.0))
        agentDrawdowns.append(data.get("maxDrawdown", 0.0))
        baselineDrawdowns.append(baseData.get("maxDrawdown", 0.0))
        buyHoldDrawdowns.append(data.get("buyHoldDrawdown", 0.0))
        if abs(agentFinal - baseFinal) < 1e-9:
            summary["wins"][scenario] = "tie"
        else:
            summary["wins"][scenario] = "MetaMo" if agentFinal > baseFinal else "signal"
    count = len(agentReturns)
    if count:
        summary["meanAgentReturn"] = sum(agentReturns) / count
        summary["meanBaselineReturn"] = sum(baselineReturns) / count
        summary["meanBuyHoldReturn"] = sum(buyHoldReturns) / count
        summary["meanAgentDrawdown"] = sum(agentDrawdowns) / count
        summary["meanBaselineDrawdown"] = sum(baselineDrawdowns) / count
        summary["meanBuyHoldDrawdown"] = sum(buyHoldDrawdowns) / count
    return {
        "generatedAt": datetime.now().isoformat(timespec="seconds"),
        "source": source,
        "agent": agent,
        "baseline": baseline,
        "baselineFinals": baselineFinals,
        "summary": summary,
    }


def printSummary(results):
    """Prints the summary table a person actually wants to read."""
    print(
        f"{'scenario':<12} {'MetaMo':>8} {'signal':>9} {'passive':>9} {'cash':>7} "
        f"{'excess':>8} {'dd(m/s/p)':>19} {'trades':>9} {'winner':>8}"
    )
    for scenario, data in results["agent"].items():
        agentFinal = data.get("finalValue", 0.0)
        baseData = results["baseline"].get(scenario, {})
        baseFinal = baseData.get("finalValue", 0.0)
        trades = " ".join(f"{t['action']}@{t['price']}" for t in data.get("trades", []))
        print(
            f"{scenario:<12} {agentFinal:>8.2f} {baseFinal:>9.2f} {data.get('buyHoldFinal', 100.0):>9.2f} {100.0:>7.2f}  "
            f"{data.get('excessVsSignal', 0.0):>+7.1%} "
            f"{data.get('maxDrawdown', 0.0):>5.1%}/{baseData.get('maxDrawdown', 0.0):>5.1%}/{data.get('buyHoldDrawdown', 0.0):<5.1%} "
            f"{data.get('tradeCount', 0):>4}/{baseData.get('tradeCount', 0):<4} "
            f"{results['summary']['wins'][scenario]:>8} {trades}"
        )
    print(
        f"{'mean return':<12} {results['summary']['meanAgentReturn']:>8.1%} "
        f"{results['summary']['meanBaselineReturn']:>9.1%} "
        f"{results['summary']['meanBuyHoldReturn']:>9.1%}"
    )
    print(
        f"{'mean DD':<12} {results['summary']['meanAgentDrawdown']:>8.1%} "
        f"{results['summary']['meanBaselineDrawdown']:>9.1%} "
        f"{results['summary']['meanBuyHoldDrawdown']:>9.1%}"
    )


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "run":
        agentText = runPetta(sys.argv[2], "cli.metta")
        baselineText = runPetta(sys.argv[2], "baseline_cli.metta")
        source = "petta-run"
    elif len(sys.argv) >= 4 and sys.argv[1] == "logs":
        agentText = stripAnsi(Path(sys.argv[2]).read_text())
        baselineText = stripAnsi(Path(sys.argv[3]).read_text())
        source = "saved-logs"
    else:
        print(__doc__)
        sys.exit(1)

    results = buildResults(agentText, baselineText, source)
    EVAL_DIR.mkdir(parents=True, exist_ok=True)
    with RESULTS_PATH.open("w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)
        f.write("\n")
    printSummary(results)
    print(f"\nwrote {RESULTS_PATH}")


if __name__ == "__main__":
    main()
