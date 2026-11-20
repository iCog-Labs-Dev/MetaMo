"""Readable trace output, retained-data purity and native printing integration."""
import copy
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest

APP = Path(__file__).resolve().parents[1]
REPO = APP.parents[1]
SPEC = importlib.util.spec_from_file_location("trace_support", APP / "trace_support.py")
trace = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(trace)


class TraceSupportTests(unittest.TestCase):
    def setUp(self):
        self.fields = {
            "signal-values": ["TraceValue", [
                ["TraceSignal", "failure", ["BooleanFact", False]],
                ["TraceSignal", "failure-streak", ["QuantityFact", 2, "count"]],
                ["TraceSignal", "danger", ["RatioFact", 0.8, "classifier-score"]]]],
            "contributions": ["TraceValue", [["TraceContribution", "failure", "progress", -0.24]]],
            "state-before": ["TraceValue", ["motivation", [0.7], [0.5]]],
            "state-after": ["TraceValue", ["motivation", [0.6], [0.75]]],
            "state-names": ["TraceValue", ["TraceStateNames",
                [["GoalIndex", "gInd_over", 0]], [["ModulatorIndex", "caution", 0]]]],
            "self-before": ["TraceValue", [["self-metric", "urgency", 0.5]]],
            "self-after": ["TraceValue", [["self-metric", "urgency", 0.75]]],
        }

    # Example: the formatter receives an ordinary retained tree, without a live interpreter.
    def event(self):
        ref = ["TraceCycleRef", ["OperationContext", "session-a", 7, "frame-a"]]
        return ["MetaMoTraceEvent", "CycleSelection", ref, ref,
                [["TraceField", key, value] for key, value in self.fields.items()]]

    def test_values_units_negative_contributions_and_named_changes(self):
        event = self.event()
        original = copy.deepcopy(event)
        text = trace.format_cycle(event)
        self.assertIn("Session: session-a | Cycle: 7 | Frame: frame-a", text)
        for expected in ("failure: false", "failure-streak: 2 count",
                         "danger: 0.8 classifier-score (estimate)",
                         "failure -> progress: -0.24", "goal gInd_over: 0.7 -> 0.6 (delta -0.1)",
                         "modulator caution: 0.5 -> 0.75 (delta +0.25)",
                         "self urgency: 0.5 -> 0.75 (delta +0.25)"):
            self.assertIn(expected, text)
        self.assertEqual(event, original)

    def test_empty_observations_missing_evidence_and_summaries_differ(self):
        self.fields["signal-values"] = ["TraceValue", []]
        self.fields["contributions"] = ["TraceUnavailable", "AppraisalRejected"]
        self.fields["state-before"] = ["TraceSummary", "sha256:old chars:3000 excerpt:..."]
        text = trace.format_cycle(self.event())
        self.assertIn("Factual signals:\n  none", text)
        self.assertIn("unavailable (AppraisalRejected)", text)
        self.assertIn("summarized (sha256:old", text)

    def test_unchanged_state_and_absent_cycle(self):
        self.fields["signal-values"] = ["TraceValue", []]
        self.fields["contributions"] = ["TraceValue", []]
        self.fields["state-after"] = copy.deepcopy(self.fields["state-before"])
        self.fields["self-after"] = copy.deepcopy(self.fields["self-before"])
        self.assertIn("Motivational state changes:\n  none", trace.format_cycle(self.event()))
        self.assertIn("unavailable", trace.format_cycle(["TraceUnavailable", "NoCycle"]))
        execution = self.event()
        execution[1] = "Execution"
        self.assertIn("unavailable", trace.format_cycle(execution))

    def test_output_is_bounded(self):
        self.fields["signal-values"] = ["TraceSummary", "x" * 20000]
        text = trace.format_cycle(self.event())
        self.assertLessEqual(len(text), 12000)
        self.assertTrue(text.endswith("[cycle summary truncated at 12000 characters]"))

    def test_normal_cycle_prints_retained_values_after_cleanup(self):
        result = subprocess.run([sys.executable, str(REPO / "scripts/run-omegaclaw.py"),
            str(APP / "tests/bridge_cycle_test.metta")], capture_output=True, text=True, timeout=60)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotIn("❌", output)
        self.assertNotIn("ERROR:", output)
        for label in ("MetaMo cycle summary (selection)", "Session: unavailable (legacy) | Cycle: 1 | Frame:",
                      "Factual signals:", "failure: false", "Appraisal contributions",
                      "user-waiting -> importance: +0.18", "failure -> progress: -0.24",
                      "Motivational state changes:", "(delta "):
            self.assertIn(label, output)


if __name__ == "__main__":
    unittest.main()
