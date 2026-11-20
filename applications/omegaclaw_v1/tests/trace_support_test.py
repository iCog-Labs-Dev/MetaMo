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
            "mode-explanation": ["TraceValue", ["TraceModeExplanation",
                ["ModeTransitionState", "Engaged", 1, "none", 0, 0],
                ["ModeTransitionState", "Rumination", 0, "none", 0, 0],
                ["ModeTransitionRule", "recovery", "Rumination", 30], "Rumination",
                [["TraceModeRule", ["ModeTransitionRule", "recovery", "Rumination", 30], True,
                  [["TraceModeTrigger", "repeated-failure", "IsTrue"]]]],
                ["ModeTimingEvidence", ["current", "Engaged", ["ModeTiming", 1, 0, 0]],
                 ["target", "Rumination", ["ModeTiming", 1, 0, 0]],
                 ["urgent-bypass", True, True], ["checks", 1, True, True, True]]]],
            "frame-mode": ["TraceValue", "Slow"],
            "scheduling": ["TraceValue", ["TraceScheduling", 2,
                [["TraceCandidate", "respond", "Interactive", 5, True],
                 ["TraceCandidate", "learn", "Engaged", 3, "false"]]]],
            "rejected": ["TraceValue", [["CandidateRejection", "execute-skill", "PermissionDenied"]]],
            "selection": ["TraceValue", ["TraceSelectionExplanation",
                ["decision", "respond", "execute", "execute", 0.9],
                ["TraceSelection", "respond", "respond", [["TraceNativeScore", "respond", 0.6]]]]],
            "decision": ["TraceValue", ["OperationDecision", ["OperationContext", "session-a", 7, "frame-a"],
                "respond", ["read-file", "/tmp/input file"], ["DispatchTicket", "original-ticket"]]],
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

    def test_modes_admission_precedence_scores_and_retained_operation_are_distinct(self):
        text = trace.format_cycle(self.event())
        for expected in ("Constitutional posture: Engaged -> Rumination (transitioned)",
                         "ContextFrames frame mode (Fast/Slow): Slow",
                         "transition priority=30", "Matched triggers: repeated-failure IsTrue",
                         "entry confirmed=true", "urgent bypass=true",
                         "Admitted respond: scheduling class=Interactive, rank=5; competes",
                         "Admitted learn: scheduling class=Engaged, rank=3; deferred",
                         "admission preserved", "Rejected execute-skill: PermissionDenied",
                         "Operation directive: execute; action mode: execute",
                         "Decision-time native score respond: 0.6", "Published score after state update: 0.9",
                         'Selected concrete operation: (read-file "/tmp/input file")',
                         "Retained dispatch ticket: (DispatchTicket original-ticket)"):
            self.assertIn(expected, text)

    def test_pending_mode_and_no_scored_selection_are_explicit(self):
        mode = self.fields["mode-explanation"][1]
        mode[2][1] = "Engaged"
        mode[6][3] = ["urgent-bypass", False, False]
        mode[6][4] = ["checks", 1, False, False, True]
        self.fields["selection"][1][2] = []
        self.fields["decision"] = ["TraceValue", []]
        text = trace.format_cycle(self.event())
        self.assertIn("Engaged -> Engaged (retained)", text)
        self.assertIn("Transition pending:", text)
        self.assertIn("Decision-time native scores: unavailable", text)
        self.assertIn("Selected concrete operation: none retained", text)

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
                      "Motivational state changes:", "(delta ", "Constitutional posture:",
                      "frame-present IsTrue", "Engaged -> Rumination (transitioned)",
                      "ContextFrames frame mode (Fast/Slow): Fast", "scheduling class=Interactive",
                      "Operation directive: execute", "Decision-time native score respond:"):
            self.assertIn(label, output)


if __name__ == "__main__":
    unittest.main()
