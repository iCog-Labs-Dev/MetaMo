"""Readable trace output, retained-data purity and native printing integration."""
import copy
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
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
            "decision-ref": ["TraceValue", ["TraceDecisionRef", ["OperationContext", "session-a", 7, "frame-a"],
                ["DispatchTicket", "original-ticket"]]],
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

    # Example: construct observer fixtures without invoking any operational service.
    def observation(self, stage, identity, values):
        return ["MetaMoTraceEvent", stage, identity, self.event()[2],
                [["TraceField", key, ["TraceValue", value]] for key, value in values.items()]]

    def test_dispatch_and_budget_observations_correlate_by_original_ticket(self):
        ticket = ["DispatchTicket", "original-ticket"]
        result = ["DispatchResult", "Executed", "Feasible", "observed file"]
        execution = self.observation("Execution", self.fields["decision-ref"][1], {"status": "Success", "result": result})
        account = ["BudgetAccountId", "host", "Global", "commands", "units"]
        budget = self.observation("BudgetSettlement", ["TraceBudgetRef", ticket, "BudgetSettled"], {
            "settlement": ["BudgetSettled", ticket, [["AccountCost", account, 1]]],
            "actual-costs": [["AccountCost", account, 1]], "dispatch-result": result,
            "accounts-before": [["BudgetAccount", account, 10, 2, 1, "Open", 3]],
            "accounts-after": [["BudgetAccount", account, 10, 3, 0, "Open", 4]]})
        history = [execution, budget]
        original = copy.deepcopy(history)
        text = trace.format_cycle(self.event(), history)
        self.assertIn("Accepted host callback status: Success", text)
        self.assertIn("Invocation returned: \"observed file\"", text)
        self.assertIn("spent 2 -> 3, reserved 1 -> 0, available 7", text)
        wrong = copy.deepcopy(history)
        wrong[0][2][2][1] = "another-ticket"
        wrong[1][2][1][1] = "another-ticket"
        unobserved = trace.format_cycle(self.event(), wrong)
        self.assertIn("pending observation", unobserved)
        self.assertNotIn("spent 2 -> 3", unobserved)
        self.assertEqual(history, original)

    def test_uncertain_dispatch_keeps_unknown_usage_and_reservation(self):
        ticket = ["DispatchTicket", "original-ticket"]
        result = ["DispatchResult", "Unobserved", "ExecutionUncertain", "none"]
        execution = self.observation("Execution", self.fields["decision-ref"][1], {"status": "Unobserved", "result": result})
        budget = self.observation("BudgetSettlement", ["TraceBudgetRef", ticket, "BudgetAccountingPending"], {
            "settlement": ["BudgetAccountingPending", ticket, "UsageUnknown"], "actual-costs": "Unknown",
            "accounts-before": [], "accounts-after": [], "dispatch-result": result})
        text = trace.format_cycle(self.event(), [execution, budget])
        self.assertIn("Result unavailable: execution is uncertain", text)
        self.assertIn("Usage: pending reconciliation; reservation remains held", text)
        self.assertNotIn("Observed actual costs: 0", text)

    def test_rejected_alternative_does_not_borrow_primary_grade(self):
        primary = ["TraceProposalRef", "invocation-a", "proposal-a"]
        alternative = ["TraceProposalRef", "invocation-a", "proposal-b"]
        primary_key = '(TraceProposalRef "invocation-a" "proposal-a")'
        alternative_key = '(TraceProposalRef "invocation-a" "proposal-b")'
        values = {"source": "llm", "candidate": "respond", "target": "current-frame", "confidence": 0.8,
                  "claim": ["LLMClaim", "claim"], "support": ["LLMSupport", "support"],
                  "evidence": ["EvidenceReferences", ["observation-1"]], "prediction": ["ExpectedOperationResult", "observed"]}
        proposal = self.observation("ReasonerProposal", primary, dict(values, **{"proposal-key": primary_key}))
        rejected = self.observation("ReasonerProposal", alternative, dict(values, **{"proposal-key": alternative_key}))
        admission = self.observation("ReasonerAdmission", "invocation-a", {"decisions": [
            ["TraceProposalAdmission", "proposal-a", "Accepted", "Feasible", primary_key],
            ["TraceProposalAdmission", "proposal-b", "Rejected", "CandidateUnavailable", alternative_key]]})
        grade = self.observation("Assessment", ["ReasonerOutcomeRef", "session-a", "original-ticket"], {
            "proposal-ref": primary, "proposal-key": primary_key,
            "comparison": ["ReasonerPredictionComparison", "Confirmed", 1.0]})
        text = trace.format_cycle(self.event(), [grade, admission, rejected, proposal])
        self.assertEqual(text.count("observed Confirmed; grade=1.0"), 1)
        self.assertIn("(Rejected CandidateUnavailable)", text)
        self.assertIn("unavailable (no assessment retained for this proposal); ungraded", text)
        self.assertIn("prediction: (ExpectedOperationResult observed)", text)
        # Symbol and string IDs can look identical after conversion to Python.
        rejected[2] = copy.deepcopy(primary)
        key_field = next(row for row in rejected[4] if row[1] == "proposal-key")
        key_field[2] = ["TraceValue", '(TraceProposalRef "invocation-a" proposal-a)']
        alias_text = trace.format_cycle(self.event(), [grade, rejected, proposal])
        self.assertEqual(alias_text.count("Outcome grade: observed Confirmed; grade=1.0"), 1)
        self.assertIn("unavailable (no assessment retained for this proposal); ungraded", alias_text)

    def test_pending_and_applied_updates_keep_origin_and_application_context(self):
        outcome = ["ReasonerOutcomeRef", "session-a", "original-ticket"]
        later = ["OperationContext", "session-a", 8, "frame-a"]
        changes = [["TraceParameterChange", ["AppraisalWeight", "progress-made", "opportunity", "BooleanIndicator"], 0.12, 0.14]]
        pending = self.observation("ParameterUpdate", ["TraceParameterRef", outcome, "Pending"], {
            "status": "Pending", "queued-at": self.event()[2][1], "status-at": [], "changes": changes})
        self.assertIn("Application pending", trace.format_cycle(self.event(), [pending]))
        self.assertIn("Proposed change", trace.format_cycle(self.event(), [pending]))
        applied = self.observation("ParameterUpdate", ["TraceParameterRef", outcome, "Applied"], {
            "status": "Applied", "queued-at": self.event()[2][1], "status-at": later,
            "changes": changes, "learner": ["HostReasonerParameterLearner", "adapter-a", "config-a", "v1", "derive"]})
        text = trace.format_cycle(self.event(), [applied, pending])
        self.assertIn("Applied change", text)
        self.assertIn("session-a 8 frame-a", text)
        self.assertNotIn("Application pending", text)

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
        self.assertIn('Constitutional posture: Rumination -> Sleep (transitioned)', output)
        self.assertIn('Selected candidate: none', output)

    def test_real_acceptance_prints_selection_denial_no_action_and_uncertain_callback(self):
        result = subprocess.run([sys.executable, str(REPO / 'scripts/run-omegaclaw.py'),
            str(APP / 'tests/increment1_local_acceptance_test.metta')],
            capture_output=True, text=True, timeout=60)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotIn('❌', output)
        self.assertNotIn('ERROR:', output)
        # Explicit printing and one queued flush per scenario; the second flush is empty.
        summaries = output.split('=== MetaMo cycle summary (selection) ===')[1:]
        self.assertEqual(len(summaries), 8, output)
        for selection in summaries[:2]:
            self.assertIn('Selected candidate: respond', selection)
            self.assertIn('Selected concrete operation: (send ', selection)
            self.assertIn('pending observation', selection)
        for idle in summaries[2:4]:
            self.assertIn('Selected candidate: none', idle)
            self.assertIn('Admitted candidates: none', idle)
            self.assertIn('Selected concrete operation: ()', idle)
            self.assertIn('Retained dispatch ticket: (DispatchUnavailable MissingDecision)', idle)
        for denied in summaries[4:6]:
            self.assertIn('Rejected respond: EgressDenied', denied)
            self.assertIn('Selected candidate: none', denied)
        for uncertain in summaries[6:]:
            self.assertIn('Accepted host callback status: Unobserved', uncertain)
            self.assertIn('Result unavailable: execution is uncertain', uncertain)
            self.assertIn('Usage: pending reconciliation; reservation remains held', uncertain)
            self.assertNotIn('Observed actual costs: 0', uncertain)

    def test_pending_references_emit_once_per_cycle_with_a_whole_batch_limit(self):
        cycle = self.event()
        execution = self.observation('Execution', self.fields['decision-ref'][1], {'status': 'Success'})
        pending = [['TraceEventRef', row[1], row[2]] for row in (execution, cycle)]
        history = [execution, cycle]
        original = copy.deepcopy(history)
        text = trace.render_pending(history, pending)
        self.assertEqual(text.count('MetaMo cycle summary (selection)'), 1)
        self.assertIn('Accepted host callback status: Success', text)
        self.assertEqual(trace.render_pending(history, []), '')
        self.assertEqual(trace.render_pending(history, [['TraceEventRef', 'Execution', 'wrong']]), '')
        limited = trace.render_pending(history, pending, 256)
        self.assertEqual(len(limited), 256)
        self.assertTrue(limited.endswith('[trace output truncated at 256 characters]'))
        self.assertEqual(history, original)

    def test_startup_controls_normal_cycle_and_callback_printing(self):
        for scenario in ('answer', 'trace'):
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                entry = Path(directory) / 'trace_runtime.metta'
                fixture = APP / 'tests/fixtures/conversational_response_loop.metta'
                entry.write_text(f'(= (conversationScenario) "{scenario}")\n'
                                 f'!(import! &self {fixture})\n'
                                 '!(test (!= (metaMoTraceEvents) ()) True)\n'
                                 '!(test (get-state &trace-print-pending) ())\n'
                                 '!(flushMetaMoTrace)\n')
                result = subprocess.run([sys.executable, str(REPO / 'scripts/run-omegaclaw.py'),
                                         str(entry)], capture_output=True, text=True, timeout=90)
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output)
                self.assertNotIn('❌', output)
                self.assertNotIn('ERROR:', output)
                self.assertEqual(output.count('✅'), 6, output)
                self.assertNotIn('MOTIVATION-CONTEXT-BLOCK', output)
                self.assertNotIn('MetaMoDispatchTrace', output)
                if scenario == 'trace':
                    self.assertIn('MetaMo cycle summary (selection)', output)
                    self.assertIn('Accepted host callback status: Success', output)
                    self.assertIn('Budget settlement effects', output)
                else:
                    self.assertNotIn('MetaMo cycle summary (selection)', output)


if __name__ == "__main__":
    unittest.main()
