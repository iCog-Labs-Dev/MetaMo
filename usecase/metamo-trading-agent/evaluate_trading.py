#!/usr/bin/env python3
"""Evaluation pipeline for the trading use case, synced with the PeTTa code.

Every metric here is computed inside the PeTTa run by the MetaMo framework
itself: the agents print one atom per step (action, portfolio value,
dominant emotion, the four feeling intensities, valence, securing and the
two overgoals). This script never recomputes anything. It only launches the
runs, parses the printed atoms and writes a results JSON, following the
same pattern as usecase/metrics/qwestor_eval.py.

Usage:

  python3 evaluate_trading.py run /path/to/PeTTa/run.sh
      Runs both agents through PeTTa and evaluates the fresh output.
      The MetaMo agent takes a few minutes.

  python3 evaluate_trading.py logs agent_log.txt baseline_log.txt
      Evaluates already saved run logs.

Writes eval/evaluation_results.json next to this script and prints a
summary table.
"""

import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

USECASE_DIR = Path(__file__).resolve().parent
EVAL_DIR = USECASE_DIR / "eval"
RESULTS_PATH = EVAL_DIR / "evaluation_results.json"

NUM = r"([-+]?[\d.]+(?:[eE][-+]?\d+)?)"
TRADER_STEP_RE = re.compile(
    rf"\(TRADER scenario (\w+) step (\d+) price {NUM} action (\w+) emotion \((\w+) {NUM}\)"
    rf" feelings \({NUM} {NUM} {NUM} {NUM}\)"
    rf" valence {NUM} securing {NUM} gInd {NUM} gTrans {NUM} value {NUM}\)"
)
TRADER_FINAL_RE = re.compile(rf"\(TRADER FINAL scenario (\w+) value {NUM}\)")
BASELINE_FINAL_RE = re.compile(rf"\(BASELINE FINAL scenario (\w+) value {NUM}\)")


def stripAnsi(text):
    """Removes ANSI color codes so terminal output parses cleanly."""
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def runPetta(runner, mettaFile):
    """Runs one MeTTa file through the PeTTa runner and returns its output."""
    result = subprocess.run(
        ["sh", str(runner), str(USECASE_DIR / mettaFile)],
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
            "minValence": 1.0, "maxFear": 0.0,
        })
        entry["steps"] += 1
        entry["emotionCounts"][emotion] = entry["emotionCounts"].get(emotion, 0) + 1
        entry["minValence"] = min(entry["minValence"], float(valence))
        entry["maxFear"] = max(entry["maxFear"], float(fear))
        if action in ("buy", "sell"):
            entry["trades"].append({
                "step": int(step), "action": action, "price": float(price),
            })
    for m in TRADER_FINAL_RE.finditer(agentText):
        scenario, value = m.groups()
        scenarios.setdefault(scenario, {})["finalValue"] = float(value)
    return scenarios


def buildResults(agentText, baselineText, source):
    """Puts both evaluations together with a summary."""
    agent = evaluateAgent(agentText)
    baseline = (lambda text: {m.group(1): float(m.group(2)) for m in BASELINE_FINAL_RE.finditer(text)})(baselineText)

    summary = {"agentTotal": 0.0, "baselineTotal": 0.0, "wins": {}}
    for scenario, data in agent.items():
        agentFinal = data.get("finalValue", 0.0)
        baseFinal = baseline.get(scenario, 0.0)
        summary["agentTotal"] += agentFinal
        summary["baselineTotal"] += baseFinal
        summary["wins"][scenario] = "agent" if agentFinal > baseFinal else "baseline"
    return {
        "generatedAt": datetime.now().isoformat(timespec="seconds"),
        "source": source,
        "agent": agent,
        "baselineFinals": baseline,
        "summary": summary,
    }


def printSummary(results):
    """Prints the summary table a person actually wants to read."""
    print(f"{'scenario':<12} {'agent':>8} {'baseline':>9}  winner   trades")
    for scenario, data in results["agent"].items():
        agentFinal = data.get("finalValue", 0.0)
        baseFinal = results["baselineFinals"].get(scenario, 0.0)
        trades = " ".join(f"{t['action']}@{t['price']}" for t in data.get("trades", []))
        print(f"{scenario:<12} {agentFinal:>8.2f} {baseFinal:>9.2f}  "
              f"{results['summary']['wins'][scenario]:<8} {trades}")
    print(f"{'total':<12} {results['summary']['agentTotal']:>8.2f} "
          f"{results['summary']['baselineTotal']:>9.2f}")


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "run":
        agentText = runPetta(sys.argv[2], "trading_agent.metta")
        baselineText = runPetta(sys.argv[2], "trading_baseline.metta")
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
