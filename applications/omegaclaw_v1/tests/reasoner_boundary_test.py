"""Audit optional reasoner dependencies without starting providers or channels."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

APP = Path(__file__).resolve().parents[1]
METAMO = APP.parents[1]
LAUNCHER = METAMO / "scripts/run-omegaclaw.py"
REASONER_MODULES = {
    str(APP / name) for name in (
        "reasoners/reasoner_proposals.metta", "reasoners/reasoner_proposal_helpers.metta",
        "reasoners/reasoner_integration.metta", "reasoners/reasoner_engines.pl", "reasoners/reasoner_fact_translation.metta",
    )
}
ASSESSMENT_MODULES = {str(APP / name) for name in (
    "reasoners/reasoner_outcome_assessment.metta", "reasoners/host_reasoner_comparators.metta",
)}
PARAMETER_MODULES = {str(APP / "reasoners/host_reasoner_parameter_updates.metta")}
INFLUENCE_MODULES = {str(APP / "reasoners/host_reasoner_influence.metta")}
HOST_EVIDENCE_MODULES = {
    str(APP / name) for name in ("reasoners/reasoner_host_evidence.metta", "reasoners/reasoner_host_evidence.pl")
}


class ReasonerBoundaryTests(unittest.TestCase):
    def run_entry(self, source, *arguments):
        with tempfile.TemporaryDirectory(prefix="reasoner-startup-") as directory:
            entry = Path(directory) / "startup.metta"
            entry.write_text(source)
            result = subprocess.run(
                [sys.executable, str(LAUNCHER), str(entry), *arguments],
                capture_output=True, text=True, timeout=60,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotIn("❌", result.stdout + result.stderr)
            self.assertIn("✅", result.stdout)

    def audit(self, entry, report):
        result = subprocess.run(
            [sys.executable, str(LAUNCHER), str(entry), "--audit", "--report", str(report)],
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(report.read_text())

    def test_adapter_contracts_load_without_reasoner_state_or_engines(self):
        with tempfile.TemporaryDirectory(prefix="reasoner-contracts-") as directory:
            entry = Path(directory) / "contracts.metta"
            entry.write_text(
                "!(import! &self (library lib_import))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_contracts))\n"
            )
            edges = self.audit(entry, Path(directory) / "imports.json")
            resolved = {edge["resolved"] for edge in edges}
            self.assertIn(str(APP / "reasoners/host_reasoner_contracts.metta"), resolved)
            forbidden = ((REASONER_MODULES - {str(APP / "reasoners/reasoner_proposal_helpers.metta")})
                         | HOST_EVIDENCE_MODULES | ASSESSMENT_MODULES | PARAMETER_MODULES | INFLUENCE_MODULES)
            self.assertFalse(resolved & forbidden)
            self.assertFalse(any(edge["resolved"].endswith(".pl")
                                 and "host_reasoner_contracts" in edge["resolved"]
                                 for edge in edges))
            self.assertFalse(any(edge["kind"] == "reasoner_engine" for edge in edges))
            self.assertNotIn(str(APP / "composition.metta"), resolved)

    def test_fact_translation_is_pure_and_does_not_load_host_or_engines(self):
        with tempfile.TemporaryDirectory(prefix="reasoner-translation-") as directory:
            entry = Path(directory) / "translation.metta"
            entry.write_text(
                "!(import! &self (library lib_import))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_contracts))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_fact_translation))\n"
            )
            edges = self.audit(entry, Path(directory) / "imports.json")
            resolved = {edge["resolved"] for edge in edges}
            self.assertIn(str(APP / "reasoners/reasoner_fact_translation.metta"), resolved)
            forbidden = {str(APP / name) for name in (
                "composition.metta", "bridge.metta", "signal_observations.metta",
                "reasoners/reasoner_proposals.metta", "reasoners/reasoner_integration.metta", "reasoners/reasoner_engines.pl",
            )}
            self.assertFalse(resolved & (forbidden | HOST_EVIDENCE_MODULES | ASSESSMENT_MODULES))
            self.assertFalse(any(edge["kind"] == "reasoner_engine" for edge in edges))
            self.assertFalse(any("OmegaClaw-Core" in path for path in resolved))
        self.run_entry(
            "!(import! &self (library lib_import))\n"
            "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_contracts))\n"
            "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_fact_translation))\n"
            "!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_contracts))\n"
            "!(test (let $invocation (reasonerContractFixture invocation) "
            "(translateReasonerAdmittedView nars "
            "(quote (ReasonerAdmittedView (invocation $invocation) (signals ()) (native-facts ()))) 0.9)) "
            "(ReasonerTranslatedFacts (invocation (reasonerContractFixture invocation)) (engine nars) (facts ())))\n"
            "!(test (case (catch (get-state &host-reasoner-cycles)) (((Error $_ $_) True) ($_ False))) True)\n"
            "!(test (case (catch (get-state &reasoner-proposal-events)) "
            "(((Error $_ $_) True) ($_ False))) True)\n"
        )

    def test_enabled_coordinator_collects_and_routes_real_loop_feedback_once(self):
        source = (
            "!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_runtime))\n"
            + r"""!(test (registerHostReasoner
    (reasonerContractSet (quote (source)) llm
        (reasonerContractSet (quote (adapter)) "probe" (reasonerContractFixture registration)))
    (quote probeLoad)) True)
!(test (configureHostReasonerRuntime "probe"
    (quote (HostReasonerRuntime "probe-1" probeCollect probeNotify () 0.8))) True)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment True) (learning True))) True)
!(test (selectHostReasoner "probe") True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(test (boundaryCycle reasoner) 1)
!(test (get-state &probe-count) 1)
!(test (size-atom (hostReasonerCycles)) 1)
!(test (size-atom (get-state &probe-notifications)) 1)
!(test (fullLoopDispatch reasoner (coreLoopDispatchBegin) (selectedHostCommand))
    (DispatchResult Executed Feasible "observed local file content"))
!(test (size-atom (get-state &probe-notifications)) 2)

!(test (mrcValue (index-atom (car-atom (hostReasonerCycles)) 3) 3) Proposals)
!(test (index-atom (car-atom (hostReasonerCycles)) 5) (get-state &selected-operation-decision))
!(test (index-atom (car-atom (hostReasonerCycles)) 6) (get-state &last-operation-outcome))
!(test (ingestOperationOutcome (get-state &last-operation-outcome)) OutcomeDuplicate)
!(test (size-atom (get-state &probe-notifications)) 2)
!(test (hostReasonerRuntime Decision (get-state &selected-operation-decision)) True)
!(test (size-atom (get-state &probe-notifications)) 2)
!(test (size-atom (mrcValue (index-atom (car-atom (hostReasonerCycles)) 2) 13)) 1)
!(test (signalValueIn (mrcValue (get-state &probe-view) 2) failure) (BooleanFact False))
!(test (signalValueIn (mrcValue (get-state &probe-view) 2) user-waiting) (BooleanFact True))
!(test (size-atom (reasonerProposalEvents)) 0)
!(test (size-atom (reasonerProposalOutcomes)) 0)
"""
        )
        self.run_entry(source, "reasoner=probe")

    def test_builtin_adapters_collect_through_normal_cycle_with_real_inference(self):
        source = r"""!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/boundary_loop))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner))
!(test (startHostReasoner (argk "reasoner")) True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(bind! &builtin-frame (new-state (get-state &cfv2-current-frame-id)))
!(bind! &builtin-source (new-state (argk "reasoner")))
!(bind! &builtin-implication (new-state (if (== (argk "reasoner") nars) ==> Implication)))
!(test (let* (
    ($frame (get-state &builtin-frame)) ($source (get-state &builtin-source))
    ($implication (get-state &builtin-implication)))
    (configureHostReasonerRuntime (repr $source)
        (quote (HostReasonerRuntime "native-test-1" collectBuiltinHostReasoner noHostReasonerFeedback
            ((ReasonerNativeFact $source (Sentence
                (($implication (SignalHolds $frame user-waiting) (Recommend $frame respond)) (stv 1 0.9))
                ((ObservationRef "trusted-rule-config" "respond-1"))))) 0.8)))) True)
!(test (configureHostReasonerControls (repr (argk "reasoner"))
    (HostReasonerControls (collection True) (influence False) (assessment False) (learning False))) True)
!(test (boundaryCycle builtin) 1)
!(test (size-atom (hostReasonerCycles)) 1)
!(test (mrcValue (index-atom (car-atom (hostReasonerCycles)) 3) 3) Proposals)
!(test (getProposalSource (mrcValue (car-atom (index-atom (car-atom (hostReasonerCycles)) 4)) 4))
    (argk "reasoner"))
"""
        for engine in ("nars", "pln"):
            with self.subTest(engine=engine):
                self.run_entry(source, f"reasoner={engine}")

    def test_coordinator_timeout_keeps_native_selection_and_ungraded_empty_advice(self):
        source = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_runtime))
!(import_prolog_function sleep)
(= (timeoutCollect $invocation $view $actions) (progn (sleep 0.1) (probeCollect $invocation $view $actions)))
!(test (registerHostReasoner
    (reasonerContractSet (quote (limits timeout-ms)) 10
        (reasonerContractSet (quote (source)) llm
            (reasonerContractSet (quote (adapter)) "probe" (reasonerContractFixture registration))))
    (quote probeLoad)) True)
!(test (configureHostReasonerRuntime "probe"
    (quote (HostReasonerRuntime "timeout-test" timeoutCollect probeNotify () 0.8))) True)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment True) (learning True))) True)
!(test (selectHostReasoner "probe") True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(test (boundaryCycle timeout) 1)
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) respond)
!(test (size-atom (hostReasonerCycles)) 1)
!(test (mrcValue (index-atom (car-atom (hostReasonerCycles)) 3) 3) Timeout)
!(test (index-atom (car-atom (hostReasonerCycles)) 4) ())
!(test (get-state &probe-count) 0)
!(test (size-atom (reasonerProposalOutcomes)) 0)
"""
        self.run_entry(source, "reasoner=probe")
        mode_timeout = source.replace('!(test (selectHostReasoner "probe") True)',
            '!(test (configureHostReasonerModeIntake "probe") True)\n!(test (selectHostReasoner "probe") True)')
        mode_timeout = mode_timeout.replace('(size-atom (hostReasonerCycles)) 1',
                                            '(size-atom (hostReasonerCycles)) 2')
        mode_timeout += r"""
!(test (constitutionalMode) Engaged)
!(test (mrcValue (index-atom (hostReasonerCycleForPhase (get-state &operation-context) ModeIntake) 3) 3) Timeout)
"""
        self.run_entry(mode_timeout, "reasoner=probe")

    def test_invalid_intake_is_empty_and_does_not_change_native_selection(self):
        source = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_runtime))
(= (invalidCollect $invocation $view $actions)
    (reasonerContractSet (quote (invocation-id)) "another-invocation"
        (probeCollect $invocation $view $actions)))
!(test (registerHostReasoner
    (reasonerContractSet (quote (source)) llm
        (reasonerContractSet (quote (adapter)) "probe" (reasonerContractFixture registration)))
    (quote probeLoad)) True)
!(test (configureHostReasonerRuntime "probe"
    (quote (HostReasonerRuntime "invalid-test" invalidCollect probeNotify () 0.8))) True)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment True) (learning True))) True)
!(test (selectHostReasoner "probe") True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(test (boundaryCycle invalid) 1)
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) respond)
!(test (mrcValue (index-atom (car-atom (hostReasonerCycles)) 3) 3) InvalidOutput)
!(test (index-atom (car-atom (hostReasonerCycles)) 4) ())
!(test (size-atom (reasonerProposalOutcomes)) 0)
"""
        self.run_entry(source, "reasoner=probe")

    def test_mode_and_candidate_intake_share_publication_at_distinct_decision_boundaries(self):
        source = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_runtime))
!(test (registerHostReasoner
    (reasonerContractSet (quote (capabilities))
        (quote (ReasonerCapabilities
            (proposal-kinds (propose-candidate request-mode-change)) (candidates (respond defer))
            (prediction-schemas ("ExpectedOperationResult" "ExpectedModeTransition"))
            (feedback (Decision Observation))))
        (reasonerContractSet (quote (source)) llm
            (reasonerContractSet (quote (adapter)) "probe" (reasonerContractFixture registration))))
    (quote probeLoad)) True)
!(test (configureHostReasonerRuntime "probe"
    (quote (HostReasonerRuntime "phase-test" phaseProbeCollect probeNotify () 0.8))) True)
!(test (configureHostReasonerModeIntake "probe") True)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment True) (learning True))) True)
!(test (selectHostReasoner "probe") True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(test (boundaryCycle phases) 1)
!(test (size-atom (get-state &probe-phase-inputs)) 2)
!(bind! &candidate-input (new-state (index-atom (get-state &probe-phase-inputs) 0)))
!(bind! &mode-input (new-state (index-atom (get-state &probe-phase-inputs) 1)))
!(bind! &candidate-invocation (new-state (index-atom (get-state &candidate-input) 0)))
!(bind! &mode-invocation (new-state (index-atom (get-state &mode-input) 0)))
!(test (mrcValue (get-state &candidate-invocation) 10) CandidateIntake)
!(test (mrcValue (get-state &mode-invocation) 10) ModeIntake)
!(test (!= (mrcValue (get-state &candidate-invocation) 1) (mrcValue (get-state &mode-invocation) 1)) True)
!(test (mrcValue (get-state &candidate-invocation) 8) (mrcValue (get-state &mode-invocation) 8))
!(test (mrcValue (get-state &candidate-invocation) 13) (mrcValue (get-state &mode-invocation) 13))
!(test (mrcValue (index-atom (get-state &candidate-input) 1) 2)
    (mrcValue (index-atom (get-state &mode-input) 1) 2))
!(test (index-atom (get-state &mode-input) 2) ())
!(test (index-atom (get-state &candidate-input) 2) (get-state &operation-admitted-actions))
!(test (map-atom (index-atom (get-state &candidate-input) 2) $action (actionId $action)) (respond))
!(test (index-atom (get-state &candidate-input) 4) ())
!(test (hostReasonerModeAlreadyObserved (get-state &operation-context)) True)
!(test (case (index-atom (get-state &mode-input) 3)
    (((ModeObservation $context $_ $_ $_ $_ $_) (!= $context (get-state &operation-context))) ($_ True))) True)
!(test (index-atom (get-state &candidate-input) 3) (lastModeObservation))
!(test (size-atom (hostReasonerCycles)) 2)
!(test (index-atom (hostReasonerCycleForPhase (get-state &operation-context) ModeIntake) 5) (lastModeObservation))
!(test (index-atom (hostReasonerCycleFor (get-state &operation-context)) 5) (get-state &selected-operation-decision))
!(test (mrcValue (index-atom (hostReasonerCycleForPhase (get-state &operation-context) ModeIntake) 3) 3) Proposals)
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) respond)
!(test (constitutionalMode) Engaged)
!(test (size-atom (get-state &probe-notifications)) 2)
!(test (hostReasonerRuntime ModeCollect (activeFrameBundle)) True)
!(test (hostReasonerRuntime Collect ((activeFrameBundle) (get-state &operation-admitted-actions))) True)
!(test (hostReasonerRuntime ModeObserved (lastModeObservation)) True)
!(test (size-atom (get-state &probe-phase-inputs)) 2)
!(test (size-atom (get-state &probe-notifications)) 2)
!(test (configureHostReasonerModeIntake "probe") (ReasonerRuntimeError AlreadyInvoked))
!(test (fullLoopDispatch phases (coreLoopDispatchBegin) (selectedHostCommand))
    (DispatchResult Executed Feasible "observed local file content"))
!(test (size-atom (get-state &probe-notifications)) 3)
!(test (index-atom (hostReasonerCycleForPhase (get-state &operation-context) ModeIntake) 6) ())
!(test (index-atom (hostReasonerCycleFor (get-state &operation-context)) 6) (get-state &last-operation-outcome))
"""
        self.run_entry(source, "reasoner=probe")
        # An adapter declaring only mode changes does not receive a candidate query.
        mode_only = source[:source.index('!(test (size-atom (get-state &probe-phase-inputs)) 2)')]
        mode_only = mode_only.replace('(proposal-kinds (propose-candidate request-mode-change))',
                                      '(proposal-kinds (request-mode-change))')
        mode_only += r"""
!(test (size-atom (get-state &probe-phase-inputs)) 1)
!(test (size-atom (hostReasonerCycles)) 1)
!(test (hostReasonerCycleFor (get-state &operation-context)) ())
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) respond)
"""
        self.run_entry(mode_only, "reasoner=probe")

    def test_late_mode_intake_cannot_attach_prediction_to_observed_transition(self):
        source = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_runtime))
!(test (registerHostReasoner
    (reasonerContractSet (quote (source)) llm
        (reasonerContractSet (quote (adapter)) "probe" (reasonerContractFixture registration)))
    (quote probeLoad)) True)
!(test (configureHostReasonerRuntime "probe"
    (quote (HostReasonerRuntime "late-test" probeCollect probeNotify () 0.8))) True)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment True) (learning True))) True)
!(test (selectHostReasoner "probe") True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(test (boundaryCycle candidate-only) 1)
!(test (get-state &probe-count) 1)
!(test (size-atom (hostReasonerCycles)) 1)
;; Simulate late delivery at the trusted boundary despite startup configuration fencing.
!(change-state! &host-reasoner-mode-intake ("probe"))
!(test (hostReasonerRuntime ModeCollect (activeFrameBundle)) (ReasonerRuntimeError LateModeIntake))
!(test (hostReasonerRuntime ModeObserved (lastModeObservation)) True)
!(test (get-state &probe-count) 1)
!(test (size-atom (hostReasonerCycles)) 1)
!(test (hostReasonerCycleForPhase (get-state &operation-context) ModeIntake) ())
;; First candidate intake is also closed after selection; no replacement invocation.
!(change-state! &host-reasoner-cycles ())
!(test (hostReasonerRuntime Collect ((activeFrameBundle) (get-state &operation-admitted-actions)))
    (ReasonerRuntimeError LateCandidateIntake))
!(test (get-state &probe-count) 1)
!(test (hostReasonerCycles) ())
"""
        self.run_entry(source, "reasoner=probe")

    def test_runtime_limits_and_changed_ownership_preserve_native_path(self):
        setup = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_runtime))
!(test (registerHostReasoner
    (reasonerContractSet (quote (source)) llm
        (reasonerContractSet (quote (adapter)) "probe" (reasonerContractFixture registration)))
    (quote probeLoad)) True)
!(test (configureHostReasonerRuntime "probe"
    (quote (HostReasonerRuntime "limit-test" checkedCollect probeNotify () 0.8))) True)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment True) (learning True))) True)
!(test (selectHostReasoner "probe") True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(test (boundaryCycle limits) 1)
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) respond)
!(test (size-atom (reasonerProposalOutcomes)) 0)
"""
        callbacks = {
            "provider": r"""
!(bind! &provider-count (new-state 0))
(= (providerProbe) (progn (change-state! &provider-count 1) answer))
(= (checkedCollect $i $v $a)
    (progn (reasonerRuntimeProvider providerProbe () "USD" 0) (probeCollect $i $v $a)))
""",
            "steps": r"""
!(import_prolog_function reasonerRuntimeEngine)
(= (checkedCollect $i $v $a)
    (progn (reasonerRuntimeEngine 100 1 1) (reasonerRuntimeEngine 1 1 1) (probeCollect $i $v $a)))
""",
            "commitment": r"""
(= (checkedCollect $i $v $a)
    (progn (commitmentFixtureApply
        (quote (CommitmentEvent "replaced-during-inference" "boundary-task" 0
            (Superseded "successor" "New task" "User replaced task"))))
        (probeCollect $i $v $a)))
""",
        }
        imports, rest = setup.split('!(test (registerHostReasoner', 1)
        for kind, callback in callbacks.items():
            source = imports + callback + '!(test (registerHostReasoner' + rest
            if kind == "commitment":
                source += '!(test (hostReasonerCycles) ())\n'
            else:
                source += r"""
!(test (mrcValue (index-atom (car-atom (hostReasonerCycles)) 3) 3) InvalidOutput)
!(test (index-atom (car-atom (hostReasonerCycles)) 4) ())
!(test (get-state &probe-count) 0)
"""
            if kind == "provider":
                source += '!(test (get-state &provider-count) 0)\n'
            with self.subTest(limit=kind):
                self.run_entry(source, "reasoner=probe")

    def test_expired_or_wrong_session_invocation_does_not_call_adapter(self):
        source = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_runtime))
!(test (registerHostReasoner
    (reasonerContractSet (quote (source)) llm
        (reasonerContractSet (quote (adapter)) "probe" (reasonerContractFixture registration)))
    (quote probeLoad)) True)
!(test (configureHostReasonerRuntime "probe"
    (quote (HostReasonerRuntime "expiry-test" probeCollect probeNotify () 0.8))) True)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment True) (learning True))) True)
!(test (selectHostReasoner "probe") True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(test (boundaryCycle expiry) 1)
!(bind! &expired-invocation (new-state (reasonerContractSet (quote (deadline-ms)) 0
    (index-atom (car-atom (hostReasonerCycles)) 2))))
!(test (reasonerRuntimeCollect (get-state &expired-invocation) probeCollect ())
    (ReasonerRuntimeError Timeout))
!(test (reasonerRuntimeCollect
    (reasonerContractSet (quote (session)) "another-session" (get-state &expired-invocation)) probeCollect ())
    (ReasonerRuntimeError StaleInvocation))
!(test (get-state &probe-count) 1)
!(collapse (translatePredicate (mutex_lock omegaclaw_dispatch)))
!(test (reasonerRuntimeCollect (get-state &expired-invocation) probeCollect ())
    (ReasonerRuntimeError DispatchLocked))
!(collapse (translatePredicate (mutex_unlock omegaclaw_dispatch)))
"""
        source += r'!(test (let (HostReasonerCycle $context $i $r $p $d $o) (car-atom (hostReasonerCycles)) (retainHostReasonerCycle (quote (HostReasonerCycle $context $i $r $p $d "' + 'x' * 1201 + r'")))) (ReasonerRuntimeError AuditLimit))' + "\n"
        source += '!(test (size-atom (hostReasonerCycles)) 1)\n'
        self.run_entry(source, "reasoner=probe")

    def test_proposal_admission_uses_native_bindings_policy_and_score(self):
        source = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_runtime))
!(bind! &admission-rows (new-state ()))
!(bind! &admission-provider (new-state ()))
!(bind! &selection-at-notification (new-state ()))
;; Inspect the audit at feedback delivery, before the ordinary dispatcher runs.
(= (admissionNotify $stage $i $payload)
    (progn
        (if (== $stage Decision)
            (change-state! &selection-at-notification (hostReasonerSelections)) True)
        (probeNotify $stage $i $payload)))
;; Keep the exact rows returned during normal capture; no second ticket allocation.
(= (captureAdmissionRows $bundle)
    (let* (($provider (get-state &admission-provider))
           ($rows (eval ($provider (quote $bundle)))))
        (progn (change-state! &admission-rows $rows) $rows)))
!(test (registerHostReasoner
    (reasonerContractSet (quote (source)) llm
        (reasonerContractSet (quote (adapter)) "probe" (reasonerContractFixture registration)))
    (quote probeLoad)) True)
!(test (configureHostReasonerRuntime "probe"
    (quote (HostReasonerRuntime "admission-test" probeCollect admissionNotify () 0.8))) True)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment True) (learning True))) True)
!(test (selectHostReasoner "probe") True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(change-state! &admission-provider (get-state &operation-provider))
!(change-state! &operation-provider captureAdmissionRows)
!(bind! &admission-state (new-state (motivosToMetamoState)))
!(test (boundaryCycle admission) 1)
!(test (size-atom (hostReasonerAdmissions)) 1)
!(bind! &admission-items (new-state (index-atom (car-atom (hostReasonerAdmissions)) 3)))
!(test (size-atom (get-state &admission-items)) 1)
!(bind! &proposal-admission (new-state (index-atom (car-atom (get-state &admission-items)) 2)))
!(test (getStatus (get-state &proposal-admission)) Accepted)
!(test (getReason (get-state &proposal-admission)) Feasible)
!(test (getScore (get-state &proposal-admission))
    (omegaclawScoreForBundle (activeFrameBundle) (get-state &admission-state) (candidateToAction respond)))
!(test (index-atom (car-atom (hostReasonerAdmissions)) 2)
    (mrcValue (index-atom (hostReasonerCycleFor (get-state &operation-context)) 2) 1))
!(test (mrcValue (index-atom (car-atom (get-state &admission-items)) 1) 4)
    (index-atom (get-state &proposal-admission) 3))
!(test (get-state &last-operation-outcome) ())
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) respond)
!(test (hostReasonerRuntime Admit ((activeFrameBundle) (get-state &admission-rows)
    (get-state &admission-state) (get-state &operation-admitted-actions)))
    (ReasonerAdmittedActions (get-state &operation-admitted-actions)))
!(test (size-atom (hostReasonerAdmissions)) 1)
!(test (size-atom (hostReasonerSelections)) 1)
!(test (get-state &selection-at-notification) (hostReasonerSelections))
!(bind! &selection-audit (new-state (car-atom (hostReasonerSelections))))
!(bind! &primary-audit (new-state (index-atom (get-state &selection-audit) 4)))
!(test (index-atom (get-state &selection-audit) 1) (get-state &operation-context))
!(test (index-atom (get-state &selection-audit) 3) (get-state &selected-operation-decision))
!(test (index-atom (get-state &primary-audit) 0) HostReasonerPrimary)
!(test (index-atom (get-state &primary-audit) 3) ShadowAgreement)
!(test (index-atom (get-state &primary-audit) 1)
    (index-atom (car-atom (get-state &admission-items)) 1))
!(test (index-atom (get-state &primary-audit) 2) (get-state &selected-host-operation))
!(bind! &selection-invocation (new-state (index-atom (hostReasonerCycleFor (get-state &operation-context)) 2)))
!(test (reasonerRuntimeSelectionCurrent (get-state &selection-invocation)
    (get-state &selected-host-operation) (get-state &selected-operation-decision)) True)
!(test (let (HostOperation $candidate $command $p $g $f $_) (get-state &selected-host-operation)
    (reasonerRuntimeSelectionCurrent (get-state &selection-invocation)
        (quote (HostOperation $candidate $command $p $g $f (DispatchTicket "other-ticket")))
        (get-state &selected-operation-decision))) False)
!(test (let (HostOperation $candidate $_ $p $g $f $ticket) (get-state &selected-host-operation)
    (reasonerRuntimeSelectionCurrent (get-state &selection-invocation)
        (quote (HostOperation $candidate (show-current-frame) $p $g $f $ticket))
        (get-state &selected-operation-decision))) False)
!(test (hostReasonerRuntime Decision (get-state &selected-operation-decision)) True)
!(test (size-atom (hostReasonerSelections)) 1)
!(test (fullLoopDispatch admission (coreLoopDispatchBegin) (selectedHostCommand))
    (DispatchResult Executed Feasible "observed local file content"))
!(test (reasonerRuntimeSelectionCurrent (get-state &selection-invocation)
    (get-state &selected-host-operation) (get-state &selected-operation-decision)) False)
!(test (hostReasonerPrimary (get-state &selection-invocation)
    (get-state &selected-operation-decision) (get-state &admission-items)) ())
!(test (hostReasonerSelections) (get-state &selection-at-notification))
"""
        self.run_entry(source, "reasoner=probe")
        denied = source[:source.index('!(test (getStatus (get-state &proposal-admission)) Accepted)')]
        denied += r"""
!(test (getStatus (get-state &proposal-admission)) Rejected)
!(test (let (GateDecision Rejected $reason)
    (hostOperationGate (activeFrameBundle) respond (get-state &admission-rows))
    (getReason (get-state &proposal-admission)))
    (getReason (get-state &proposal-admission)))
!(test (getScore (get-state &proposal-admission)) 0.0)
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) none)
!(test (get-state &last-operation-outcome) ())
!(test (index-atom (car-atom (hostReasonerSelections)) 4) ())
"""
        for variant in ("permission-denied", "budget-denied", "empty", "ambiguous"):
            scenario = denied.replace('(boundaryProvision "allowed")',
                f'(boundaryProvision "{variant if variant != "ambiguous" else "allowed"}")')
            if variant == "ambiguous":
                scenario = scenario.replace('($rows (eval ($provider (quote $bundle))))',
                    '($rows (let $single (eval ($provider (quote $bundle))) (append $single $single)))')
            with self.subTest(variant=variant):
                self.run_entry(scenario, "reasoner=probe")
        duplicate = source.replace('"admission-test" probeCollect', '"admission-test" duplicateCollect')
        fixture_end = duplicate.index('\n', duplicate.index('!(import!')) + 1
        duplicate = duplicate[:fixture_end] + r"""
;; Distinct proposals for one candidate retain two decisions but only one pool entry.
(= (duplicateCollect $i $v $a)
    (let* (($id (mrcValue $i 1)) ($adapter (mrcValue $i 2)) ($refs (mrcValue $i 13)))
        (quote (ReasonerIntakeResult (invocation-id $id) (adapter $adapter)
            (status Proposals)
            (proposals (
                (ReasonerMotivationalProposal first-id llm propose-candidate current-frame respond
                    claim support 0.8 (EvidenceReferences $refs) prediction)
                (ReasonerMotivationalProposal second-id llm propose-candidate current-frame respond
                    claim support 1.0 (EvidenceReferences $refs) prediction)))
            (diagnostics ())))))
""" + duplicate[fixture_end:]
        duplicate = duplicate.replace('(size-atom (get-state &admission-items)) 1',
                                      '(size-atom (get-state &admission-items)) 2')
        duplicate += r"""
!(test (map-atom (get-state &admission-items) $entry (getStatus (index-atom $entry 2))) (Accepted Accepted))
!(test (getScore (index-atom (index-atom (get-state &admission-items) 0) 2))
    (getScore (index-atom (index-atom (get-state &admission-items) 1) 2)))
"""
        self.run_entry(duplicate, "reasoner=probe")

    def attribution_setup(self, collector="probeCollect"):
        """Pause a real host publication after intake/admission and before selection."""
        return r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_reasoner_runtime))
!(import_prolog_functions_from_file
    (library MetaMo applications/omegaclaw_v1/tests/fixtures/commitments.pl)
    (commitmentFixtureTickets commitmentFixtureEpoch))
!(test (registerHostReasoner
    (reasonerContractSet (quote (source)) llm
        (reasonerContractSet (quote (adapter)) "probe" (reasonerContractFixture registration)))
    (quote probeLoad)) True)
!(test (configureHostReasonerRuntime "probe"
    (quote (HostReasonerRuntime "attribution-test" COLLECTOR probeNotify () 0.8))) True)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment True) (learning True))) True)
!(test (selectHostReasoner "probe") True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(bind! &test-bundle (new-state (prepareTaskStateForMetaMo)))
!(refreshSignals (get-state &test-bundle))
!(bind! &test-rows (new-state (captureCandidateOperations (get-state &test-bundle))))
!(bind! &test-state (new-state (motivosToMetamoState)))
!(generateCandidates (get-state &test-bundle))
!(bind! &test-native (new-state
    (let (CandidatePruning (admitted $base) (rejected $_))
        (pruneActionsForBundle (get-state &test-bundle) (candidatesToActions))
        (let (CandidatePruning (admitted $native) (rejected $_))
            (admitCapturedOperations (get-state &test-bundle) $base (get-state &test-rows)) $native))))
!(test (map-atom (get-state &test-native) $a (actionId $a)) (respond))
!(change-state! &operation-admitted-actions (get-state &test-native))
!(hostReasonerRuntime Collect ((get-state &test-bundle) (get-state &test-native)))
!(bind! &test-intake (new-state (hostReasonerCycleFor (get-state &operation-context))))
!(bind! &test-invocation (new-state (index-atom (get-state &test-intake) 2)))
!(bind! &test-pool (new-state
    (let (ReasonerAdmittedActions $pool)
        (hostReasonerRuntime Admit ((get-state &test-bundle) (get-state &test-rows)
            (get-state &test-state) (get-state &test-native))) $pool)))
!(test (get-state &test-pool) (get-state &test-native))
!(test (get-state &selected-operation-decision) ())
!(bind! &test-tickets (new-state (commitmentFixtureTickets)))
!(bind! &test-epoch (new-state (commitmentFixtureEpoch)))
!(bind! &test-ticket (new-state (index-atom (car-atom (get-state &test-rows)) 6)))
!(test (size-atom (get-state &test-tickets)) 1)
""".replace("COLLECTOR", collector)

    def attribution_select(self, expected_primary="()", result='(DispatchResult Executed Feasible "observed local file content")'):
        """Use native scheduling/scoring and dispatch the original captured ticket."""
        return r"""
!(bind! &test-choice (new-state
    (let (decisionResult $action $_)
        (omegaclawDecideAdmittedForBundle (get-state &test-bundle)
            (get-state &test-state) (get-state &test-pool)) $action)))
!(test (actionId (get-state &test-choice)) respond)
!(retainSelectedOperation (actionId (get-state &test-choice)) (get-state &test-rows))
!(test (selectedHostTicket) (get-state &test-ticket))
!(bind! &test-decision (new-state (get-state &selected-operation-decision)))
!(test (hostReasonerRuntime Decision (get-state &test-decision)) True)
!(test (get-state &selected-operation-decision) (get-state &test-decision))
!(test (selectedHostTicket) (get-state &test-ticket))
!(test (commitmentFixtureTickets) (get-state &test-tickets))
!(test (index-atom (car-atom (hostReasonerSelections)) 4) PRIMARY)
!(test (index-atom (hostReasonerCycleFor (get-state &operation-context)) 5) (get-state &test-decision))
!(test (dispatchSelectedHostCommand (get-state &test-ticket) (selectedHostCommand)) RESULT)
!(test (selectedHostTicket) (get-state &test-ticket))
!(test (commitmentFixtureTickets) (get-state &test-tickets))
""".replace("PRIMARY", expected_primary).replace("RESULT", result)

    def test_failed_attribution_preserves_native_ticket_and_execution(self):
        setup = self.attribution_setup()
        # Break the retained advice binding, leaving the real native rows untouched.
        for field, replacement in (("ticket", '(DispatchTicket "unrelated")'),
                                   ("command", '(show-current-frame)')):
            mutation = r"""
!(test (getStatus (index-atom (car-atom (index-atom (car-atom (hostReasonerAdmissions)) 3)) 2)) Accepted)
!(let* (
    ((HostReasonerAdmissions $context $id ((HostReasonerProposalAdmission $e $d
        (HostOperation $candidate $command $p $g $f $ticket)))) (car-atom (hostReasonerAdmissions)))
    ($changed (quote (HostOperation $candidate COMMAND $p $g $f TICKET)))
    ($batch (quote (HostReasonerAdmissions $context $id ((HostReasonerProposalAdmission $e $d $changed)))))
) (change-state! &host-reasoner-admissions ($batch)))
""".replace("COMMAND", replacement if field == "command" else "$command").replace(
                "TICKET", replacement if field == "ticket" else "$ticket")
            with self.subTest(binding=field):
                self.run_entry(setup + mutation + self.attribution_select(), "reasoner=probe")

    def test_conflicting_proposal_identity_is_rejected_without_changing_native_choice(self):
        callback = r"""
;; One invocation cannot assign the same proposal ID to two different predictions.
(= (conflictingCollect $i $v $a)
    (let* (($raw (probeCollect $i $v $a))
           ($first (car-atom (mrcValue $raw 4)))
           ((ReasonerMotivationalProposal $id $source $kind $target $candidate $claim $support $confidence $refs $_) $first)
           ($other (quote (ReasonerMotivationalProposal $id $source $kind $target $candidate
               $claim $support $confidence $refs conflicting-prediction))))
        (reasonerContractSet (quote (proposals)) ($first $other) $raw)))
"""
        setup = self.attribution_setup("conflictingCollect")
        first_line = setup.index('\n', setup.index('!(import!')) + 1
        setup = setup[:first_line] + callback + setup[first_line:]
        checks = r"""
!(test (mrcValue (index-atom (get-state &test-intake) 3) 3) InvalidOutput)
!(test (index-atom (get-state &test-intake) 4) ())
!(test (index-atom (car-atom (hostReasonerAdmissions)) 3) ())
!(test (commitmentFixtureEpoch) (get-state &test-epoch))
"""
        self.run_entry(setup + checks + self.attribution_select(), "reasoner=probe")

    def test_changed_commitment_between_intake_and_selection_cannot_rescue_stale_ticket(self):
        source = self.attribution_setup() + r"""
!(test (getStatus (index-atom (car-atom (index-atom (car-atom (hostReasonerAdmissions)) 3)) 2)) Accepted)
!(test (commitmentFixtureApply
    (quote (CommitmentEvent "replace-after-intake" "boundary-task" 0
        (Superseded "successor" "New task" "User replaced task"))))
    (CommitmentApplied "replace-after-intake" "boundary-task" Superseded 1))
!(test (reasonerRuntimeCurrent (get-state &test-invocation)) False)
!(test (> (commitmentFixtureEpoch) (get-state &test-epoch)) True)
"""
        self.run_entry(source + self.attribution_select(result="(DispatchResult Blocked StaleSnapshot none)"),
                       "reasoner=probe")

    def test_competing_invocation_cannot_reattribute_the_same_native_ticket(self):
        source = self.attribution_setup() + r"""
!(bind! &test-primary (new-state
    (let (HostReasonerProposalAdmission $e $_ $op)
        (car-atom (index-atom (car-atom (hostReasonerAdmissions)) 3))
        (quote (HostReasonerPrimary $e $op ShadowAgreement)))))
"""
        selection, dispatch = self.attribution_select("(get-state &test-primary)").split(
            '!(test (dispatchSelectedHostCommand', 1)
        source += selection + r"""
!(bind! &original-selection-audit (new-state (hostReasonerSelections)))
!(bind! &competing-invocation (new-state
    (reasonerContractSet (quote (invocation-id)) "competing-invocation" (get-state &test-invocation))))
!(test (validateReasonerInvocation (get-state &competing-invocation))
    (ReasonerContractValid ReasonerInvocation 1))
;; Reusing a proposal's local ID in another invocation cannot share its ticket.
!(let* (
    ((HostReasonerAdmissions $context $_ ((HostReasonerProposalAdmission $e $d $op)))
        (car-atom (hostReasonerAdmissions)))
    ($other (bindReasonerProposalInvocation (mrcValue $e 1) (get-state &competing-invocation)
        (mrcValue $e 3) (mrcValue $e 4)))
    ($batch (quote (HostReasonerAdmissions $context "competing-invocation"
        ((HostReasonerProposalAdmission $other $d $op)))))
) (change-state! &host-reasoner-admissions (cons-atom $batch (hostReasonerAdmissions))))
!(test (let (HostReasonerProposalAdmission $e $_ $_)
    (car-atom (index-atom (car-atom (hostReasonerAdmissions)) 3))
    (validateReasonerInvokedProposal $e)) (ReasonerContractValid ReasonerInvokedProposal 1))
!(test (retainHostReasonerSelectionAudit (get-state &competing-invocation) (get-state &test-decision)) True)
!(test (hostReasonerRuntime Decision (get-state &test-decision)) True)
!(test (hostReasonerSelections) (get-state &original-selection-audit))
!(test (commitmentFixtureTickets) (get-state &test-tickets))
""" + '!(test (dispatchSelectedHostCommand' + dispatch
        self.run_entry(source, "reasoner=probe")

    def test_callback_receipts_survive_slot_replacement_and_assessment_is_explicit(self):
        callbacks = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_outcome_assessment))
!(bind! &receipts-at-notification (new-state ()))
!(bind! &legacy-comparator-calls (new-state 0))
;; Callback inspection must see the receipt already captured, with no assessment.
(= (receiptNotify $stage $i $payload)
    (progn (if (== $stage Observation)
        (change-state! &receipts-at-notification (hostReasonerReceipts)) True)
        (probeNotify $stage $i $payload)))
;; A legacy global evaluator must not replace the trusted schema route.
(= (legacyComparatorTrap $prediction $actual)
    (progn (change-state! &legacy-comparator-calls 1) (ReasonerPredictionComparison Confirmed 0.4)))
(= (receiptCollect $i $v $a)
    (let* (($raw (probeCollect $i $v $a)) ($refs (mrcValue $i 13))
        ($proposals (quote (
            (ReasonerMotivationalProposal selected llm propose-candidate current-frame respond
                claim support 0.8 (EvidenceReferences $refs) (ExpectedOperationResult EXPECTED))
            (ReasonerMotivationalProposal rejected llm propose-candidate current-frame defer
                claim support 0.8 (EvidenceReferences $refs) (ExpectedOperationResult "unobserved alternative")))))
    ) (reasonerContractSet (quote (proposals)) $proposals $raw)))
"""
        setup = self.attribution_setup("receiptCollect").replace(
            '"attribution-test" receiptCollect probeNotify', '"attribution-test" receiptCollect receiptNotify')
        setup = setup.replace('(reasonerContractFixture registration)',
            '(reasonerContractSet (quote (capabilities candidates)) (respond defer) (reasonerContractFixture registration))')
        insert = setup.index('\n', setup.index('!(import!')) + 1
        setup = setup[:insert] + callbacks + setup[insert:]
        before = r"""
!(bind! &selected-envelope (new-state
    (index-atom (index-atom (index-atom (car-atom (hostReasonerAdmissions)) 3) 0) 1)))
!(bind! &rejected-envelope (new-state
    (index-atom (index-atom (index-atom (car-atom (hostReasonerAdmissions)) 3) 1) 1)))
!(test (getStatus (index-atom (index-atom (index-atom (car-atom (hostReasonerAdmissions)) 3) 1) 2)) Rejected)
!(bind! &test-primary (new-state
    (let (HostReasonerProposalAdmission $e $_ $op)
        (car-atom (index-atom (car-atom (hostReasonerAdmissions)) 3))
        (quote (HostReasonerPrimary $e $op ShadowAgreement)))))
!(bind! &receipt-id (new-state
    (let (OperationContext $session $_ $_) (get-state &operation-context)
        (let (DispatchTicket $id) (get-state &test-ticket) (ReasonerOutcomeRef $session $id)))))
!(test (hostReasonerReceipts) ())
!(test (assessHostReasonerProposalOutcome (get-state &selected-envelope) (get-state &receipt-id))
    (ReasonerAssessmentRejected MissingReceipt))
!(change-state! &reasoner-prediction-comparator legacyComparatorTrap)
!(bind! &reliability-before (new-state (reasonerSourceReliability llm)))
!(test (size-atom (filter-atom (metaMoTraceEvents) $row (== (index-atom $row 1) ReasonerProposal))) 2)
!(test (size-atom (filter-atom (metaMoTraceEvents) $row (== (index-atom $row 1) ReasonerAdmission))) 1)
"""
        after = r"""
!(test (size-atom (hostReasonerReceipts)) 1)
!(test (get-state &receipts-at-notification) (hostReasonerReceipts))
!(test (hostReasonerAssessments) ())
!(bind! &first-execution-trace (new-state (car-atom (metaMoTraceEvents))))
!(test (index-atom (get-state &first-execution-trace) 1) Execution)
!(test (filter-atom (metaMoTraceEvents) $event (== (index-atom $event 1) Assessment)) ())
!(bind! &first-receipt (new-state (hostReasonerReceiptFor (get-state &receipt-id))))
!(test (index-atom (get-state &first-receipt) 3) (get-state &last-operation-outcome))
!(test (retainHostReasonerReceipt (get-state &test-invocation) (get-state &first-receipt)
    (get-state &receipt-id)) True)
!(test (let (HostReasonerReceipt $id $selection $_) (get-state &first-receipt)
    (retainHostReasonerReceipt (get-state &test-invocation)
        (quote (HostReasonerReceipt $id $selection ())) $id)) (ReasonerRuntimeError ConflictingReceipt))
!(test (ingestOperationOutcome (get-state &last-operation-outcome)) OutcomeDuplicate)
!(test (hostReasonerRuntime Observation (get-state &last-operation-outcome)) True)
!(test (size-atom (hostReasonerReceipts)) 1)
!(test (assessHostReasonerProposalOutcome (get-state &rejected-envelope) (get-state &receipt-id))
    (ReasonerAssessmentDeferred NoObservedAlternative))
!(test (hostReasonerAssessments) ())
;; A real later callback replaces the host slot, but cannot replace the first receipt.
!(test (boundaryCycle next-receipt) 1)
!(test (fullLoopDispatch next-receipt (coreLoopDispatchBegin) (selectedHostCommand))
    (DispatchResult Executed Feasible "observed local file content"))
!(test (size-atom (hostReasonerReceipts)) 2)
!(test (!= (get-state &last-operation-outcome) (index-atom (get-state &first-receipt) 3)) True)
!(test (hostReasonerReceiptFor (get-state &receipt-id)) (get-state &first-receipt))
!(test (hostReasonerAssessments) ())
!(bind! &first-assessment (new-state
    (assessHostReasonerProposalOutcome (get-state &selected-envelope) (get-state &receipt-id))))
!(test (index-atom (get-state &first-assessment) 4) COMPARISON)
!(bind! &first-assessment-trace (new-state (car-atom (metaMoTraceEvents))))
!(test (index-atom (get-state &first-assessment-trace) 1) Assessment)
!(test (index-atom (get-state &first-assessment-trace) 2) (get-state &receipt-id))
!(test (index-atom (get-state &first-assessment-trace) 3)
    (index-atom (get-state &first-execution-trace) 3))
!(test (!= (index-atom (get-state &first-assessment-trace) 3)
    (TraceCycleRef (get-state &operation-context))) True)
!(test (traceEventField (get-state &first-assessment-trace) decision-ref)
    (TraceValue (index-atom (get-state &first-execution-trace) 2)))
!(test (traceEventField (get-state &first-assessment-trace) comparison) (TraceValue COMPARISON))
!(test (traceEventField (get-state &first-assessment-trace) proposal-ref)
    (TraceValue (TraceProposalRef (mrcValue (get-state &test-invocation) 1)
        (getProposalId (mrcValue (get-state &selected-envelope) 4)))))
!(test (let $reference (TraceProposalRef (mrcValue (get-state &test-invocation) 1)
        (getProposalId (mrcValue (get-state &selected-envelope) 4)))
    (let $proposals (filter-atom (metaMoTraceEvents) $row
        (tpAllTrue ((== (index-atom $row 1) ReasonerProposal) (== (index-atom $row 2) $reference))))
        (traceEventField (car-atom $proposals) proposal-key)))
    (traceEventField (get-state &first-assessment-trace) proposal-key))
!(test (traceEventField (get-state &first-execution-trace) assessment) (TraceUnavailable NotAssessed))
!(test (assessHostReasonerProposalOutcome (get-state &selected-envelope) (get-state &receipt-id))
    (get-state &first-assessment))
!(test (size-atom (hostReasonerAssessments)) 1)
!(test (size-atom (filter-atom (metaMoTraceEvents) $event (== (index-atom $event 1) Assessment))) 1)
!(test (car-atom (metaMoTraceEvents)) (get-state &first-assessment-trace))
!(test (reasonerSourceReliability llm) (get-state &reliability-before))
!(test (get-state &legacy-comparator-calls) 0)
!(test (hostReasonerReceiptFor (get-state &receipt-id)) (get-state &first-receipt))
"""
        selection, dispatch = self.attribution_select("(get-state &test-primary)").split(
            '!(test (dispatchSelectedHostCommand', 1)
        forged = r"""
;; Matching decision labels alone cannot replace the actual accepted Core callback.
!(test (let* (($d (get-state &selected-operation-decision)) ($c (selectedHostCommand))
    ($fake (quote (OperationOutcome $d (attempted-command $c) Success
        (DispatchResult Executed Feasible "invented result")))))
    (hostReasonerRuntime Observation $fake)) (ReasonerRuntimeError InvalidReceipt))
!(test (index-atom (hostReasonerCycleFor (get-state &operation-context)) 6) ())
!(test (hostReasonerReceipts) ())
!(test (size-atom (get-state &probe-notifications)) 1)
"""
        source = setup + before + selection + forged + '!(test (dispatchSelectedHostCommand' + dispatch + after
        for expected, comparison in (
            ('"observed local file content"', '(ReasonerPredictionComparison Confirmed 1.0)'),
            ('"another result"', '(ReasonerPredictionComparison Refuted 0.0)'),
        ):
            with self.subTest(expected=expected):
                self.run_entry(source.replace('EXPECTED', expected).replace('COMPARISON', comparison),
                               "reasoner=probe")

    def test_blocked_receipt_is_retained_without_grading(self):
        source = self.attribution_setup() + r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_outcome_assessment))
!(bind! &blocked-envelope (new-state
    (index-atom (car-atom (index-atom (car-atom (hostReasonerAdmissions)) 3)) 1)))
!(commitmentFixtureApply (quote (CommitmentEvent "replace-before-dispatch" "boundary-task" 0
    (Superseded "successor" "New task" "User replaced task"))))
""" + self.attribution_select(result="(DispatchResult Blocked StaleSnapshot none)") + r"""
!(test (size-atom (hostReasonerReceipts)) 1)
!(test (index-atom (car-atom (hostReasonerReceipts)) 3) (get-state &last-operation-outcome))
!(test (assessHostReasonerProposalOutcome (get-state &blocked-envelope)
    (index-atom (car-atom (hostReasonerReceipts)) 1)) (ReasonerAssessmentDeferred InsufficientEvidence))
!(test (hostReasonerAssessments) ())
"""
        self.run_entry(source, "reasoner=probe")

    def test_unsupported_and_uncertain_predictions_remain_ungraded(self):
        for uncertain in (False, True):
            setup = self.attribution_setup()
            imports = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_outcome_assessment))
!(import_prolog_functions_from_file
    (library MetaMo applications/omegaclaw_v1/tests/fixtures/dispatch.pl) (hostReceiptFixtureUncertain))
!(bind! &budget-test-effects (new-state 0))
"""
            insert = setup.index('\n', setup.index('!(import!')) + 1
            setup = setup[:insert] + imports + setup[insert:]
            source = setup + r"""
!(bind! &test-primary (new-state
    (let (HostReasonerProposalAdmission $e $_ $op)
        (car-atom (index-atom (car-atom (hostReasonerAdmissions)) 3))
        (quote (HostReasonerPrimary $e $op ShadowAgreement)))))
""" + self.attribution_select("(get-state &test-primary)",
                "(DispatchResult Unobserved ExecutionUncertain none)" if uncertain
                else '(DispatchResult Executed Feasible "observed local file content")') + r"""
!(test (size-atom (hostReasonerReceipts)) 1)
!(test (assessHostReasonerProposalOutcome (index-atom (get-state &test-primary) 1)
    (index-atom (car-atom (hostReasonerReceipts)) 1)) (ReasonerAssessmentDeferred REASON))
!(test (hostReasonerAssessments) ())
"""
            with self.subTest(uncertain=uncertain):
                if uncertain:
                    source = source.replace('(dispatchSelectedHostCommand (get-state &test-ticket) (selectedHostCommand))',
                        '(hostReceiptFixtureUncertain (get-state &test-ticket) (selectedHostCommand))')
                    source += '!(test (get-state &budget-test-effects) 1)\n'
                self.run_entry(source.replace('REASON', 'InsufficientEvidence' if uncertain
                                              else 'UnsupportedPrediction'), "reasoner=probe")

    def test_stage_controls_default_off_and_collection_does_not_enable_feedback(self):
        setup = self.attribution_setup()
        configure = '!(test (configureHostReasonerControls "probe"\n    (HostReasonerControls (collection True) (influence False) (assessment True) (learning True))) True)\n'
        setup = setup[:setup.index('!(bind! &test-bundle')].replace(configure, '')
        source = setup + r"""
!(test (hostReasonerControlsFor "probe")
    (HostReasonerControls (collection False) (influence False) (assessment False) (learning False)))
!(test (boundaryCycle disabled-stages) 1)
!(test (get-state &probe-count) 0)
!(test (hostReasonerCycles) ())
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection False) (influence False) (assessment True) (learning True))) True)
!(test (configureHostReasonerStartupControls) True)
!(test (hostReasonerControlsFor "probe")
    (HostReasonerControls (collection False) (influence False) (assessment True) (learning True)))
!(test (boundaryCycle still-no-collection) 1)
!(test (get-state &probe-count) 0)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment False) (learning False))) True)
!(test (boundaryCycle collection-only) 1)
!(test (get-state &probe-count) 1)
!(test (get-state &probe-notifications) ())
!(test (fullLoopDispatch collection-only (coreLoopDispatchBegin) (selectedHostCommand))
    (DispatchResult Executed Feasible "observed local file content"))
!(test (size-atom (hostReasonerReceipts)) 1)
!(test (get-state &probe-notifications) ())
!(bind! &controls-before (new-state (hostReasonerControlsFor "probe")))
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence False) (assessment False) (learning True)))
    (ReasonerRuntimeError AlreadyInvoked))
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence True) (assessment False) (learning False)))
    (ReasonerRuntimeError MissingPredictiveEvidence))
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection "True") (influence False) (assessment False) (learning False)))
    (ReasonerRuntimeError InvalidControls))
!(test (hostReasonerControlsFor "probe") (get-state &controls-before))
"""
        self.run_entry(source, "reasoner=probe")

    def test_collection_without_influence_does_not_add_an_advised_candidate(self):
        source = self.attribution_setup().replace(
            '(get-state &test-state) (get-state &test-native))) $pool)))',
            '(get-state &test-state) ())) $pool)))').replace(
            '!(test (get-state &test-pool) (get-state &test-native))', '!(test (get-state &test-pool) ())')
        source += r"""
!(test (getStatus (index-atom (car-atom (index-atom (car-atom (hostReasonerAdmissions)) 3)) 2)) Accepted)
"""
        self.run_entry(source, "reasoner=probe")

    def test_startup_stage_flags_are_independent_and_default_disabled(self):
        base = '!(import! &self (library MetaMo applications/omegaclaw_v1/tests/host_startup_test))\n'
        for collection, assessment, learning in ((False, False, False), (True, False, False),
                                                  (False, True, True)):
            source = base + f'!(test (hostReasonerControlsFor "nars") (HostReasonerControls (collection {collection}) (influence False) (assessment {assessment}) (learning {learning})))\n'
            source += f'!(test (> (size-atom (hostReasonerCycles)) 0) {collection})\n'
            arguments = ["reasoner=nars"]
            if any((collection, assessment, learning)):
                arguments += [f"reasoner-collection={collection}", f"reasoner-assessment={assessment}",
                              f"reasoner-learning={learning}"]
            with self.subTest(collection=collection, assessment=assessment, learning=learning):
                self.run_entry(source, *arguments)

    def test_assessment_preview_and_learning_are_independent_and_feedback_is_capability_gated(self):
        callback = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_outcome_assessment))
;; A declared operation prediction can be assessed without training the adapter.
(= (controlledCollect $i $v $a)
    (let* (($raw (probeCollect $i $v $a)) ($refs (mrcValue $i 13))
        ($p (quote (ReasonerMotivationalProposal predicted llm propose-candidate current-frame respond
            claim support 0.8 (EvidenceReferences $refs) (ExpectedOperationResult "observed local file content")))))
        (reasonerContractSet (quote (proposals)) ($p) $raw)))
"""
        for assessment, learning, assessment_feedback in ((False, True, True), (True, False, True),
                                                          (True, True, True), (True, True, False)):
            source = self.attribution_setup("controlledCollect")
            insert = source.index('\n', source.index('!(import!')) + 1
            source = source[:insert] + callback + source[insert:]
            source = source.replace('(assessment True) (learning True)',
                f'(assessment {assessment}) (learning {learning})')
            if not assessment_feedback:
                source = source.replace('(reasonerContractFixture registration)',
                    '(reasonerContractSet (quote (capabilities feedback)) (Decision Observation) (reasonerContractFixture registration))')
            source += r"""
!(bind! &test-primary (new-state
    (let (HostReasonerProposalAdmission $e $_ $op)
        (car-atom (index-atom (car-atom (hostReasonerAdmissions)) 3))
        (quote (HostReasonerPrimary $e $op ShadowAgreement)))))
""" + self.attribution_select("(get-state &test-primary)") + r"""
!(bind! &outcome-ref (new-state (index-atom (car-atom (hostReasonerReceipts)) 1)))
!(bind! &reliability-before (new-state (reasonerSourceReliability llm)))
!(bind! &preview (new-state (assessHostReasonerProposalOutcome
    (index-atom (get-state &test-primary) 1) (get-state &outcome-ref))))
!(test (reasonerSourceReliability llm) (get-state &reliability-before))
!(test (hostReasonerLearning) ())
"""
            if not assessment:
                source += r"""
!(test (get-state &preview) (ReasonerAssessmentDeferred AssessmentDisabled))
!(test (learnHostReasonerOutcome (get-state &outcome-ref)) (ReasonerAssessmentDeferred MissingAssessment))
"""
            elif not learning:
                source += r"""
!(test (index-atom (get-state &preview) 4) (ReasonerPredictionComparison Confirmed 1.0))
!(test (learnHostReasonerOutcome (get-state &outcome-ref)) (ReasonerAssessmentDeferred LearningDisabled))
!(test (get-state &probe-notifications) ())
"""
            else:
                source += r"""
!(bind! &expected-reliability (new-state (reasonerSourceReliabilityAfterGrade llm 1.0)))
!(bind! &learned (new-state (learnHostReasonerOutcome (get-state &outcome-ref))))
!(test (index-atom (get-state &learned) 0) HostReasonerLearning)
!(test (reasonerSourceReliability llm) (get-state &expected-reliability))
!(test (index-atom (get-state &learned) 3) (get-state &reliability-before))
!(test (learnHostReasonerOutcome (get-state &outcome-ref)) (get-state &learned))
!(test (size-atom (hostReasonerLearning)) 1)
"""
                source += f'!(test (size-atom (get-state &probe-notifications)) {3 if assessment_feedback else 2})\n'
            with self.subTest(assessment=assessment, learning=learning, assessment_feedback=assessment_feedback):
                self.run_entry(source, "reasoner=probe")

    def comparator_setup(self, register=True):
        """Use a declared custom schema through actual intake, selection and dispatch."""
        definitions = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_outcome_assessment))
(: PredictedPayloadType Type)
(: PredictedPayload (-> Expression PredictedPayloadType))
!(bind! &routed-calls (new-state 0))
!(bind! &global-calls (new-state 0))
!(bind! &routed-input (new-state ()))
!(bind! &global-during-comparison (new-state ()))
!(bind! &routed-result (new-state (ReasonerPredictionComparison Confirmed 0.75)))
;; Record the actual quoted comparator input, without reading current host slots.
(= (routedComparator $prediction $actual)
    (progn (change-state! &routed-calls (+ (get-state &routed-calls) 1))
        (change-state! &global-during-comparison (get-state &reasoner-prediction-comparator))
        (change-state! &routed-input (quote ($prediction $actual))) (get-state &routed-result)))
;; Changing a legacy global comparator must have no effect on this adapter's route.
(= (globalComparatorTrap $prediction $actual)
    (progn (change-state! &global-calls 1) (ReasonerPredictionComparison Refuted 0.0)))
(= (routedCollect $i $v $a)
    (let* (($raw (probeCollect $i $v $a)) ($refs (mrcValue $i 13))
        ($p (quote (ReasonerMotivationalProposal predicted llm propose-candidate current-frame respond
            claim support 0.8 (EvidenceReferences $refs) (PredictedPayload "expected")))))
        (reasonerContractSet (quote (proposals)) ($p) $raw)))
"""
        source = self.attribution_setup("routedCollect").replace('(reasonerContractFixture registration)',
            '(reasonerContractSet (quote (capabilities prediction-schemas)) ("PredictedPayload") (reasonerContractFixture registration))')
        insert = source.index('\n', source.index('!(import!')) + 1
        source = source[:insert] + definitions + source[insert:]
        if register:
            source = source.replace('!(bind! &test-bundle', r"""
!(test (configureHostReasonerComparator "probe" "PredictedPayload" "calibration-v1" routedComparator) True)
!(bind! &test-bundle""")
        source += r"""
!(bind! &test-primary (new-state
    (let (HostReasonerProposalAdmission $e $_ $op)
        (car-atom (index-atom (car-atom (hostReasonerAdmissions)) 3))
        (quote (HostReasonerPrimary $e $op ShadowAgreement)))))
""" + self.attribution_select("(get-state &test-primary)") + r"""
!(bind! &routed-envelope (new-state (index-atom (get-state &test-primary) 1)))
!(bind! &routed-receipt (new-state (car-atom (hostReasonerReceipts))))
!(bind! &routed-id (new-state (index-atom (get-state &routed-receipt) 1)))
!(bind! &routed-reliability (new-state (reasonerSourceReliability llm)))
!(change-state! &reasoner-prediction-comparator globalComparatorTrap)
"""
        return source

    def test_comparators_resolve_retained_adapter_schema_and_version_without_global_swaps(self):
        source = self.comparator_setup() + r"""
;; Another adapter can register the same schema without changing this invocation's route.
!(test (registerHostReasoner (reasonerContractSet (quote (adapter)) "other"
    (reasonerContractSet (quote (configuration-version)) "other-config" (hostReasonerRegistration)))
    (quote probeLoad)) True)
!(test (configureHostReasonerComparator "other" "PredictedPayload" "other-v2" globalComparatorTrap) True)
!(test (hostReasonerComparatorFor "probe" "other-config" "PredictedPayload") ())
!(test (hostReasonerPredictionComparator
    (reasonerContractSet (quote (invocation configuration-version)) "other-config"
        (get-state &routed-envelope))) ())
!(test (configureHostReasonerComparator "probe" "Undeclared" "v1" routedComparator)
    (ReasonerAssessmentRejected InvalidComparator))
!(bind! &routed-assessment (new-state
    (assessHostReasonerProposalOutcome (get-state &routed-envelope) (get-state &routed-id))))
!(bind! &retained-route (new-state (index-atom (get-state &routed-assessment) 3)))
!(test (mrcValue (get-state &retained-route) 1) "probe")
!(test (mrcValue (get-state &retained-route) 2) "config-1")
!(test (mrcValue (get-state &retained-route) 3) "PredictedPayload")
!(test (mrcValue (get-state &retained-route) 4) "calibration-v1")
!(test (mrcValue (get-state &retained-route) 5) routedComparator)
!(test (get-state &routed-input) ((PredictedPayload "expected") "observed local file content"))
!(test (index-atom (get-state &routed-assessment) 4) (ReasonerPredictionComparison Confirmed 0.75))
!(test (configureHostReasonerComparator "probe" "PredictedPayload" "calibration-v1" routedComparator) True)
!(test (configureHostReasonerComparator "probe" "PredictedPayload" "new-v2" globalComparatorTrap)
    (ReasonerAssessmentRejected ComparatorAlreadyInvoked))
!(change-state! &routed-result (ReasonerPredictionComparison Refuted 0.0))
!(test (assessHostReasonerProposalOutcome (get-state &routed-envelope) (get-state &routed-id))
    (get-state &routed-assessment))
!(test (get-state &routed-calls) 1)
!(test (get-state &global-calls) 0)
!(test (get-state &global-during-comparison) globalComparatorTrap)
!(test (get-state &reasoner-prediction-comparator) globalComparatorTrap)
!(test (reasonerSourceReliability llm) (get-state &routed-reliability))
"""
        self.run_entry(source, "reasoner=probe")

    def test_malformed_and_unresolved_comparator_grades_preserve_evidence_and_allow_retry(self):
        cases = [
            ('(ReasonerPredictionComparison Confirmed "0.75")', "InvalidComparison"),
            ('(ReasonerPredictionComparison Confirmed -0.1)', "InvalidComparison"),
            ('(ReasonerPredictionComparison Refuted 1.1)', "InvalidComparison"),
            ('(ReasonerPredictionComparison Unresolved 0.0)', "InvalidComparison"),
            ('(ReasonerPredictionComparison Confirmed Ungraded)', "InvalidComparison"),
            ('(ReasonerPredictionComparison Confirmed 1.0 extra)', "InvalidComparison"),
            ('(ReasonerPredictionComparison Unresolved Ungraded)', "InsufficientEvidence"),
        ]
        for number in ("1.0Inf", "-1.0Inf", "1.5NaN"):
            cases.append((f'(let $_ (translatePredicate (atom_number "{number}" $n)) (ReasonerPredictionComparison Confirmed $n))',
                          "InvalidComparison"))
        for comparison, reason in cases:
            kind = "Deferred" if reason == "InsufficientEvidence" else "Rejected"
            source = self.comparator_setup() + f'!(change-state! &routed-result {comparison})\n'
            source += f'!(test (assessHostReasonerProposalOutcome (get-state &routed-envelope) (get-state &routed-id)) (ReasonerAssessment{kind} {reason}))\n'
            source += r"""
!(test (hostReasonerAssessments) ())
!(test (hostReasonerLearning) ())
!(test (learnHostReasonerOutcome (get-state &routed-id)) (ReasonerAssessmentDeferred MissingAssessment))
!(test (hostReasonerReceiptFor (get-state &routed-id)) (get-state &routed-receipt))
!(test (reasonerSourceReliability llm) (get-state &routed-reliability))
!(test (size-atom (get-state &probe-notifications)) 2)
!(change-state! &routed-result (ReasonerPredictionComparison Confirmed 0.75))
!(test (index-atom (assessHostReasonerProposalOutcome (get-state &routed-envelope) (get-state &routed-id)) 4)
    (ReasonerPredictionComparison Confirmed 0.75))
!(test (get-state &routed-calls) 2)
!(test (get-state &global-calls) 0)
"""
            with self.subTest(comparison=comparison):
                self.run_entry(source, "reasoner=probe")

    def test_unsupported_comparator_route_cannot_be_installed_after_observation(self):
        source = self.comparator_setup(register=False) + r"""
!(test (assessHostReasonerProposalOutcome (get-state &routed-envelope) (get-state &routed-id))
    (ReasonerAssessmentDeferred UnsupportedPrediction))
!(test (configureHostReasonerComparator "probe" "PredictedPayload" "late-v1" routedComparator)
    (ReasonerAssessmentRejected ComparatorAlreadyInvoked))
!(test (hostReasonerAssessments) ())
!(test (get-state &routed-calls) 0)
!(test (get-state &global-calls) 0)
"""
        self.run_entry(source, "reasoner=probe")

    def test_conflicting_assessments_and_learning_feedback_cannot_replace_committed_results(self):
        source = self.comparator_setup() + r"""
!(bind! &routed-assessment (new-state
    (assessHostReasonerProposalOutcome (get-state &routed-envelope) (get-state &routed-id))))
!(bind! &routed-learning (new-state (learnHostReasonerOutcome (get-state &routed-id))))
!(bind! &learned-reliability (new-state (reasonerSourceReliability llm)))
!(bind! &learning-invocation (new-state (mrcValue (get-state &routed-envelope) 2)))
!(test (learnHostReasonerOutcome (get-state &routed-id)) (get-state &routed-learning))
!(test (commitHostReasonerLearning (get-state &routed-assessment) (get-state &learning-invocation))
    (get-state &routed-learning))
!(test (retainHostReasonerAssessment (get-state &routed-id) (get-state &routed-envelope)
    (index-atom (get-state &routed-assessment) 3) (ReasonerPredictionComparison Refuted 0.0))
    (ReasonerAssessmentRejected ConflictingAssessment))
!(test (let (HostReasonerAssessment $id $e $route $_) (get-state &routed-assessment)
    (commitHostReasonerLearning
        (quote (HostReasonerAssessment $id $e $route (ReasonerPredictionComparison Refuted 0.0)))
        (get-state &learning-invocation))) (ReasonerAssessmentRejected ConflictingLearning))
!(test (hostReasonerAssessments) ((get-state &routed-assessment)))
!(test (hostReasonerLearning) ((get-state &routed-learning)))
!(test (reasonerSourceReliability llm) (get-state &learned-reliability))
!(test (size-atom (get-state &probe-notifications)) 3)
!(test (hostReasonerReceiptFor (get-state &routed-id)) (get-state &routed-receipt))
!(test (get-state &routed-calls) 1)
"""
        self.run_entry(source, "reasoner=probe")

    def parameter_setup(self, configure=True):
        """Supply a test-only calibrated rule, not a built-in grade-to-parameter formula."""
        source = self.comparator_setup()
        definitions = r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_parameter_updates))
!(bind! &parameter-learner-calls (new-state 0))
!(bind! &parameter-learner-input (new-state ()))
!(bind! &parameter-test-changes (new-state (
    (HostReasonerParameterChange (AppraisalWeight stalled-progress importance BooleanIndicator)
        0.175 0.2 "offline calibrated appraisal rule")
    (HostReasonerParameterChange (ModeThreshold wake execution-request classifier-score Enter)
        0.0 0.05 "offline calibrated wake rule"))))
;; Test policy receives retained grades and the allowed current parameter snapshot.
(= (parameterTestLearner $assessment $parameters)
    (progn
        (change-state! &parameter-learner-calls (+ (get-state &parameter-learner-calls) 1))
        (change-state! &parameter-learner-input (quote ($assessment $parameters)))
        (get-state &parameter-test-changes)))
;; Snapshot fixed preemption, threat evidence and safety appraisal rows.
(= (parameterProtectedRegistry)
    (let* (
        ($priorities (collapse (match &self (SchedulingPriority $c $p) (SchedulingPriority $c $p))))
        ($rules (modeTransitionRules))
        ($threat (modeSignalRules threat))
        ($safety (collapse (match &self (SignalAppraisalRule danger $d $t $c)
            (SignalAppraisalRule danger $d $t $c))))
    ) (quote ($priorities $rules $threat $safety))))
"""
        setup = definitions
        if configure:
            setup += '!(test (configureHostReasonerParameterLearner "probe" "calibrated-fixture-v1" parameterTestLearner) True)\n'
        source = source.replace('!(bind! &test-bundle', setup + '!(bind! &test-bundle')
        source += r"""
!(bind! &parameter-grade (new-state
    (assessHostReasonerProposalOutcome (get-state &routed-envelope) (get-state &routed-id))))
!(bind! &fixed-registry (new-state (parameterProtectedRegistry)))
!(test (hostReasonerParameterValue (car-atom (hostReasonerParameterRows
    (AppraisalWeight stalled-progress importance BooleanIndicator)))) 0.175)
!(test (hostReasonerParameterValue (car-atom (hostReasonerParameterRows
    (ModeThreshold wake execution-request classifier-score Enter)))) 0.0)
"""
        return source

    def test_parameter_learning_is_queued_once_and_applied_at_the_next_native_cycle(self):
        source = self.parameter_setup() + r"""
!(bind! &parameter-batch (new-state (deriveHostReasonerParameterUpdates (get-state &routed-id))))
!(test (index-atom (get-state &parameter-batch) 0) HostReasonerParameterBatch)
!(test (index-atom (get-state &parameter-batch) 1) (get-state &routed-id))
!(test (index-atom (index-atom (get-state &parameter-batch) 2) 3) "calibrated-fixture-v1")
!(test (index-atom (get-state &parameter-batch) 5) Pending)
!(test (let $rows (filter-atom (metaMoTraceEvents) $row (== (index-atom $row 1) ParameterUpdate))
    (traceEventField (car-atom $rows) status)) (TraceValue Pending))
!(test (index-atom (get-state &parameter-learner-input) 0) (get-state &parameter-grade))
!(test (size-atom (index-atom (get-state &parameter-learner-input) 1)) 3)
!(test (deriveHostReasonerParameterUpdates (get-state &routed-id)) (get-state &parameter-batch))
!(test (get-state &parameter-learner-calls) 1)
!(applyHostReasonerParameterUpdates (get-state &operation-context))
!(test (hostReasonerParameterValue (car-atom (hostReasonerParameterRows
    (AppraisalWeight stalled-progress importance BooleanIndicator)))) 0.175)
!(test (hostReasonerParameterValue (car-atom (hostReasonerParameterRows
    (ModeThreshold wake execution-request classifier-score Enter)))) 0.0)
!(test (hostReasonerLearning) ())
!(test (reasonerSourceReliability llm) (get-state &routed-reliability))
!(test (size-atom (get-state &probe-notifications)) 2)
!(test (boundaryCycle apply-parameters) 1)
!(test (index-atom (car-atom (hostReasonerParameterBatches)) 5) Applied)
!(test (index-atom (car-atom (hostReasonerParameterBatches)) 6) (get-state &operation-context))
!(test (let $rows (filter-atom (metaMoTraceEvents) $row (== (index-atom $row 1) ParameterUpdate))
    (traceEventField (car-atom $rows) status)) (TraceValue Applied))
!(test (size-atom (filter-atom (metaMoTraceEvents) $row (== (index-atom $row 1) ParameterUpdate))) 2)
!(test (printLastCycleSummary) True)
!(test (hostReasonerParameterValue (car-atom (hostReasonerParameterRows
    (AppraisalWeight stalled-progress importance BooleanIndicator)))) 0.2)
!(test (tpContains (modeSignalRules wake)
    (ModeRatioTrigger wake execution-request classifier-score 0.05 0.0)) True)
!(test (let $rows (appraiseFactualSignal
    (FactualSignal (kind stalled-progress) (value (BooleanFact True))
        (provenance ((SessionObservationRef "parameter-test" 0)))))
    (mrcValue (car-atom (filter-atom $rows $row (== (mrcValue $row 2) importance))) 5)) 0.2)
!(test (parameterProtectedRegistry) (get-state &fixed-registry))
!(test (applyHostReasonerParameterUpdates (get-state &operation-context)) (ParameterUpdateRejected LateBoundary))
!(test (boundaryCycle keep-parameters) 1)
!(test (size-atom (hostReasonerParameterBatches)) 1)
!(test (index-atom (car-atom (hostReasonerParameterBatches)) 5) Applied)
!(test (get-state &parameter-learner-calls) 1)
!(test (reasonerSourceReliability llm) (get-state &routed-reliability))
"""
        self.run_entry(source, "reasoner=probe")

    def test_invalid_parameter_batches_leave_registry_evidence_and_learning_unchanged(self):
        cases = [
            '((HostReasonerParameterChange (AppraisalWeight stalled-progress importance BooleanIndicator) 0.175 0.3 "too large"))',
            '((HostReasonerParameterChange (AppraisalWeight stalled-progress importance BooleanIndicator) 0.175 0.4 "outside range"))',
            '((HostReasonerParameterChange (AppraisalWeight stalled-progress importance BooleanIndicator) 0.1 0.12 "stale"))',
            '((HostReasonerParameterChange (ModeThreshold threat danger classifier-score Enter) 0.0 0.05 "forbidden"))',
            '((HostReasonerParameterChange (AppraisalWeight danger risk IdentityRatio) 0.8 0.79 "fixed safety"))',
            '((HostReasonerParameterChange (AppraisalWeight stalled-progress importance BooleanIndicator) 0.175 "0.2" "not numeric"))',
            '((HostReasonerParameterChange (AppraisalWeight stalled-progress importance BooleanIndicator) 0.175 0.2 ""))',
            '((HostReasonerParameterChange (AppraisalWeight stalled-progress importance BooleanIndicator) 0.175 0.2 "first") (HostReasonerParameterChange (AppraisalWeight stalled-progress importance BooleanIndicator) 0.175 0.19 "duplicate"))',
            '(ReasonerRuntimeError Timeout)',
        ]
        for number in ("1.0Inf", "-1.0Inf", "1.5NaN"):
            cases.append(f'(let $_ (translatePredicate (atom_number "{number}" $n)) ((HostReasonerParameterChange (AppraisalWeight stalled-progress importance BooleanIndicator) 0.175 $n "nonfinite")))')
        for changes in cases:
            source = self.parameter_setup() + f'!(change-state! &parameter-test-changes {changes})\n' + r"""
!(test (deriveHostReasonerParameterUpdates (get-state &routed-id)) (ParameterUpdateRejected InvalidChanges))
!(test (hostReasonerParameterBatches) ())
!(test (hostReasonerParameterValue (car-atom (hostReasonerParameterRows
    (AppraisalWeight stalled-progress importance BooleanIndicator)))) 0.175)
!(test (parameterProtectedRegistry) (get-state &fixed-registry))
!(test (hostReasonerLearning) ())
!(test (reasonerSourceReliability llm) (get-state &routed-reliability))
!(test (hostReasonerReceiptFor (get-state &routed-id)) (get-state &routed-receipt))
"""
            with self.subTest(changes=changes):
                self.run_entry(source, "reasoner=probe")

    def test_stale_parameters_reject_the_entire_pending_batch(self):
        source = self.parameter_setup() + r"""
!(deriveHostReasonerParameterUpdates (get-state &routed-id))
!(remove-atom &self (SignalAppraisalRule stalled-progress importance BooleanIndicator 0.175))
!(add-atom &self (SignalAppraisalRule stalled-progress importance BooleanIndicator 0.19))
!(test (boundaryCycle stale-parameters) 1)
!(test (index-atom (car-atom (hostReasonerParameterBatches)) 5) StaleParameter)
!(test (hostReasonerParameterValue (car-atom (hostReasonerParameterRows
    (AppraisalWeight stalled-progress importance BooleanIndicator)))) 0.19)
!(test (hostReasonerParameterValue (car-atom (hostReasonerParameterRows
    (ModeThreshold wake execution-request classifier-score Enter)))) 0.0)
!(test (parameterProtectedRegistry) (get-state &fixed-registry))
"""
        self.run_entry(source, "reasoner=probe")

    def test_parameter_derivation_requires_explicit_learner_and_learning_permission(self):
        source = self.parameter_setup(configure=False) + r"""
!(test (deriveHostReasonerParameterUpdates (get-state &routed-id)) (ParameterUpdateDeferred NoLearner))
!(test (configureHostReasonerParameterLearner "probe" "late-v1" parameterTestLearner)
    (ParameterUpdateRejected AlreadyInvoked))
!(test (hostReasonerParameterBatches) ())
!(test (get-state &parameter-learner-calls) 0)
"""
        self.run_entry(source, "reasoner=probe")
        source = self.parameter_setup().replace('(assessment True) (learning True)', '(assessment True) (learning False)')
        source += r"""
!(test (deriveHostReasonerParameterUpdates (get-state &routed-id)) (ParameterUpdateDeferred LearningDisabled))
!(test (hostReasonerParameterBatches) ())
!(test (get-state &parameter-learner-calls) 0)
!(test (boundaryCycle parameter-learning-disabled) 1)
"""
        self.run_entry(source, "reasoner=probe")

    def test_parameter_batches_do_not_stack_pending_steps_or_cross_sessions(self):
        source = self.parameter_setup() + r"""
;; Gather another real assessment before queueing either, preserving the original values.
!(test (boundaryCycle second-parameter-grade) 1)
!(test (fullLoopDispatch second-parameter-grade (coreLoopDispatchBegin) (selectedHostCommand))
    (DispatchResult Executed Feasible "observed local file content"))
!(bind! &second-id (new-state (index-atom (car-atom (hostReasonerReceipts)) 1)))
!(assessHostReasonerProposalOutcome
    (index-atom (index-atom (car-atom (hostReasonerSelections)) 4) 1) (get-state &second-id))
!(deriveHostReasonerParameterUpdates (get-state &routed-id))
!(test (deriveHostReasonerParameterUpdates (get-state &second-id))
    (ParameterUpdateRejected PendingConflictOrLimit))
!(test (size-atom (hostReasonerParameterBatches)) 1)
!(test (hostReasonerParameterValue (car-atom (hostReasonerParameterRows
    (AppraisalWeight stalled-progress importance BooleanIndicator)))) 0.175)
!(initOperationSession)
!(test (boundaryCycle new-parameter-session) 1)
!(test (index-atom (car-atom (hostReasonerParameterBatches)) 5) StaleSession)
!(test (hostReasonerParameterValue (car-atom (hostReasonerParameterRows
    (AppraisalWeight stalled-progress importance BooleanIndicator)))) 0.175)
!(test (parameterProtectedRegistry) (get-state &fixed-registry))
"""
        self.run_entry(source, "reasoner=probe")

    def test_parameter_learner_can_defer_without_proposing_a_change(self):
        source = self.parameter_setup() + r"""
!(change-state! &parameter-test-changes ())
!(test (deriveHostReasonerParameterUpdates (get-state &routed-id)) (ParameterUpdateDeferred NoChanges))
!(test (hostReasonerParameterBatches) ())
!(test (parameterProtectedRegistry) (get-state &fixed-registry))
"""
        self.run_entry(source, "reasoner=probe")

    def influence_setup(self):
        """Calibrate with three distinct, real shadow dispatch receipts."""
        source = self.comparator_setup()
        # All tests use the production intake/ownership/receipt/comparator path.
        source = source.replace('(reasonerContractFixture registration)',
            '(reasonerContractSet (quote (capabilities candidates)) (respond ask-clarification) '
            '(reasonerContractFixture registration))')
        source += r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_influence))
!(test (index-atom (assessHostReasonerProposalOutcome
    (get-state &routed-envelope) (get-state &routed-id)) 4)
    (ReasonerPredictionComparison Confirmed 0.75))
"""
        for cycle in (2, 3):
            source += f'!(test (boundaryCycle shadow-{cycle}) 1)\n'
            source += f'!(test (fullLoopDispatch shadow-{cycle} (coreLoopDispatchBegin) (selectedHostCommand))\n'
            source += r"""    (DispatchResult Executed Feasible "observed local file content"))
!(test (let* (($receipt (car-atom (hostReasonerReceipts)))
    ($envelope (car-atom (index-atom (hostReasonerCycleFor (get-state &operation-context)) 4))))
    (index-atom (assessHostReasonerProposalOutcome $envelope (index-atom $receipt 1)) 4))
    (ReasonerPredictionComparison Confirmed 0.75))
"""
        source += r"""
!(bind! &influence-ids (new-state (map-atom (hostReasonerAssessments) $row (index-atom $row 1))))
!(test (size-atom (get-state &influence-ids)) 3)
!(test (reasonerSourceReliability llm) (get-state &routed-reliability))
!(test (size-atom (get-state &host-reasoner-influence-decisions)) 0)
"""
        return source

    def test_influence_requires_distinct_predictive_evidence_and_explicit_cap(self):
        source = self.influence_setup() + r"""
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence True) (assessment True) (learning True)))
    (ReasonerRuntimeError MissingPredictiveEvidence))
!(test (configureHostReasonerInfluence "probe" 0.11 (get-state &influence-ids))
    (ReasonerRuntimeError InvalidInfluenceConfig))
!(test (configureHostReasonerInfluence "probe" -0.1 (get-state &influence-ids))
    (ReasonerRuntimeError InvalidInfluenceConfig))
!(test (let $id (car-atom (get-state &influence-ids))
    (configureHostReasonerInfluence "probe" 0.1 ($id $id $id)))
    (ReasonerRuntimeError MissingPredictiveEvidence))
!(test (configureHostReasonerInfluence "other" 0.1 (get-state &influence-ids))
    (ReasonerRuntimeError InvalidInfluenceConfig))
!(test (get-state &host-reasoner-influence-settings) ())
!(test (configureHostReasonerInfluence "probe" 0.1 (get-state &influence-ids)) True)
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence True) (assessment True) (learning True))) True)
!(test (index-atom (hostReasonerInfluenceSettingFor "probe") 2) ())
!(test (index-atom (index-atom (hostReasonerInfluenceSettingFor "probe") 3) 3) 0.1)
;; Historical cycles and assessments are unchanged by authorization.
!(test (size-atom (hostReasonerAssessments)) 3)
!(test (map-atom (hostReasonerSelections) $row (index-atom (index-atom $row 4) 3))
    (ShadowAgreement ShadowAgreement ShadowAgreement))
!(test (boundaryCycle influence) 1)
!(test (index-atom (index-atom (hostReasonerInfluenceSettingFor "probe") 2) 3) 0.1)
!(test (size-atom (get-state &host-reasoner-influence-decisions)) 1)
!(test (index-atom (index-atom (car-atom (hostReasonerSelections)) 4) 3) AdvisoryAgreement)
!(test (reasonerSourceReliability llm) (get-state &routed-reliability))
"""
        self.run_entry(source, "reasoner=probe")

    def influence_competition_setup(self, cap=0.1):
        """Use real native competitors; duplicate advice has a stable maximum."""
        source = self.influence_setup()
        source = source.replace('(= (routedCollect $i $v $a)', r"""
!(bind! &influence-candidate (new-state respond))
(= (routedCollect $i $v $a)""")
        source = source.replace('($p (quote (ReasonerMotivationalProposal predicted',
            '($candidate (get-state &influence-candidate))\n'
            '        ($p (quote (ReasonerMotivationalProposal predicted')
        source = source.replace('current-frame respond\n            claim support 0.8',
            'current-frame $candidate\n            claim support 0.8')
        source = source.replace('(reasonerContractSet (quote (proposals)) ($p) $raw)',
            r"""(reasonerContractSet (quote (proposals))
            (if (== $candidate respond) ($p)
                ($p (ReasonerMotivationalProposal strongest llm propose-candidate current-frame
                    $candidate claim support 1.0 (EvidenceReferences $refs) (PredictedPayload "expected"))
                    (ReasonerMotivationalProposal tied llm propose-candidate current-frame
                    $candidate claim support 1.0 (EvidenceReferences $refs) (PredictedPayload "expected")))) $raw)""")
        source += r"""
;; Consume the preceding callback normally before comparing another decision.
!(test (boundaryCycle consume) 1)
!(test (boundaryProvision "interactive") 1)
!(change-state! &new-msg-flag False)
!(change-state! &influence-candidate ask-clarification)
"""
        source += f'!(test (configureHostReasonerInfluence "probe" {cap} (get-state &influence-ids)) True)\n'
        source += r"""
!(test (configureHostReasonerControls "probe"
    (HostReasonerControls (collection True) (influence True) (assessment True) (learning True))) True)
"""
        return source

    def test_bounded_influence_changes_only_native_competitors_and_retains_exact_primary(self):
        source = self.influence_competition_setup() + r"""
!(writeBackMetamoState (motivation
    (0.1 0.1 0.1 0.1 0.1 0.35 0.1 0.1 0.1 0.1 0.1)
    (0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5)))
!(test (boundaryCycle advised) 1)
!(test (map-atom (get-state &operation-admitted-actions) $a (actionId $a)) (respond ask-clarification))
!(bind! &influence-trace (new-state (get-state &host-reasoner-influence-trace)))
!(test (actionId (index-atom (get-state &influence-trace) 5)) respond)
!(test (actionId (index-atom (get-state &influence-trace) 6)) ask-clarification)
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) ask-clarification)
!(bind! &influence-primary (new-state (index-atom (car-atom (hostReasonerSelections)) 4)))
!(test (index-atom (get-state &influence-primary) 3) AdvisoryChangedSelection)
!(test (getProposalId (mrcValue (index-atom (get-state &influence-primary) 1) 4)) strongest)
!(test (index-atom (get-state &influence-primary) 2) (get-state &selected-host-operation))
!(test (index-atom (index-atom (get-state &influence-primary) 2) 6) (selectedHostTicket))
!(bind! &influence-view (new-state (get-state &host-reasoner-influence-view)))
!(test (size-atom (index-atom (get-state &influence-view) 4)) 1)
!(test (fsNumberIn (hostReasonerInfluenceBonus (get-state &influence-view) ask-clarification) 0.074999 0.075001) True)
!(test (hostReasonerInfluenceBonus (get-state &influence-view) respond) 0)
!(test (hostReasonerInfluenceBonus (get-state &influence-view) learn) 0)
!(test (size-atom (index-atom (car-atom (hostReasonerAdmissions)) 3)) 3)
;; Repeated lifecycle notifications and bimonad probes retain the original choice.
!(test (hostReasonerRuntime CycleBegin (get-state &operation-context)) True)
!(test (get-state &host-reasoner-influence-trace) (get-state &influence-trace))
!(test (configureHostReasonerInfluence "probe" 0 ()) True)
!(test (fsNumberIn (hostReasonerInfluenceBonus (get-state &influence-view) ask-clarification) 0.074999 0.075001) True)
!(test (index-atom (index-atom (hostReasonerInfluenceSettingFor "probe") 2) 3) 0.1)
!(test (let $result (dispatchSelectedHostCommand (selectedHostTicket) (selectedHostCommand))
    (case $result (((DispatchResult Executed Feasible $_) True) ($_ False)))) True)
!(test (index-atom (car-atom (hostReasonerReceipts)) 1)
    (let (OperationContext $session $_ $_) (get-state &operation-context)
        (let (DispatchTicket $id) (selectedHostTicket) (ReasonerOutcomeRef $session $id))))
!(test (boundaryCycle zero-next-cycle) 1)
!(test (index-atom (index-atom (hostReasonerInfluenceSettingFor "probe") 2) 3) 0)
!(test (get-state &host-reasoner-influence-view) ())
"""
        self.run_entry(source, "reasoner=probe")

    def test_zero_influence_and_saturated_ties_preserve_native_selection(self):
        for cap in (0, 0.1):
            source = self.influence_competition_setup(cap) + r"""
!(test (boundaryCycle tied) 1)
!(test (map-atom (get-state &operation-admitted-actions) $a (actionId $a)) (respond ask-clarification))
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) respond)
!(test (index-atom (car-atom (hostReasonerSelections)) 4) ())
!(test (omegaclawSelectionScoreForBundle (activeFrameBundle)
    (motivosToMetamoState) (candidateToAction respond))
    (omegaclawScoreForBundle (activeFrameBundle) (motivosToMetamoState) (candidateToAction respond)))
!(test (reasonerSourceReliability llm) (get-state &routed-reliability))
"""
            if cap == 0:
                source += r"""
!(test (get-state &host-reasoner-influence-view) ())
!(test (get-state &host-reasoner-influence-trace) ())
!(test (get-state &host-reasoner-influence-decisions) ())
"""
            else:
                source += r"""
!(bind! &tie-trace (new-state (get-state &host-reasoner-influence-trace)))
!(test (map-atom (index-atom (get-state &tie-trace) 4) $row (index-atom $row 4)) (1.0 1.0))
!(test (actionId (index-atom (get-state &tie-trace) 5)) respond)
!(test (actionId (index-atom (get-state &tie-trace) 6)) respond)
;; A changed publication immediately removes the usable contribution.
!(bind! &stale-next-publication (new-state (prepareTaskStateForMetaMo)))
!(test (hostReasonerInfluenceViewFor (activeFrameBundle)) ())
!(test (hostReasonerInfluencedScore (activeFrameBundle) (candidateToAction ask-clarification) 0.4) 0.4)
"""
            with self.subTest(cap=cap):
                self.run_entry(source, "reasoner=probe")

    def test_low_quality_or_missing_receipts_cannot_authorize_influence(self):
        source = self.influence_setup().replace("0.75", "0.5") + r"""
!(test (configureHostReasonerInfluence "probe" 0.1 (get-state &influence-ids))
    (ReasonerRuntimeError MissingPredictiveEvidence))
!(test (configureHostReasonerInfluence "probe" 0.1 (missing-a missing-b missing-c))
    (ReasonerRuntimeError MissingPredictiveEvidence))
!(test (get-state &host-reasoner-influence-settings) ())
;; A zero cap requires no predictive claim and still grants no learning.
!(test (configureHostReasonerInfluence "probe" 0 ()) True)
"""
        self.run_entry(source, "reasoner=probe")

    def test_aggregate_influence_is_capped_across_distinct_candidates(self):
        source = self.influence_competition_setup().replace(
            '$candidate claim support 1.0 (EvidenceReferences $refs) (PredictedPayload "expected")))) $raw)',
            '$candidate claim support 1.0 (EvidenceReferences $refs) (PredictedPayload "expected"))\n'
            '                    (ReasonerMotivationalProposal agreeing llm propose-candidate current-frame\n'
            '                    respond claim support 1.0 (EvidenceReferences $refs) (PredictedPayload "expected")))) $raw)')
        source += r"""
!(test (boundaryCycle aggregate) 1)
!(bind! &aggregate-view (new-state (get-state &host-reasoner-influence-view)))
!(test (size-atom (index-atom (get-state &aggregate-view) 4)) 2)
!(test (fsNumberIn (hostReasonerInfluenceBonus (get-state &aggregate-view) respond) 0.037499 0.037501) True)
!(test (hostReasonerInfluenceBonus (get-state &aggregate-view) respond)
    (hostReasonerInfluenceBonus (get-state &aggregate-view) ask-clarification))
!(test (<= (sum (map-atom (index-atom (get-state &aggregate-view) 4) $row
    (hostReasonerInfluenceBonus (get-state &aggregate-view) (index-atom $row 1)))) 0.1) True)
!(test (policyOutputOperation (get-state &last-meta-mo-policy-output)) respond)
!(test (index-atom (index-atom (car-atom (hostReasonerSelections)) 4) 3) AdvisoryAgreement)
"""
        self.run_entry(source, "reasoner=probe")

    def test_selected_engine_dependency_allows_explicitly_registered_maintenance_worker(self):
        # Real selected engine identity; the accounting worker tests dependency routing, not native learning.
        self.run_entry(r"""
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/boundary_loop))
!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner))
!(import_prolog_functions_from_file
    (library MetaMo applications/omegaclaw_v1/tests/fixtures/host_maintenance.pl)
    (maintenanceFixtureQueue maintenanceFixtureDependency maintenanceFixtureTotal))
!(test (startHostReasoner nars) True)
!(test (boundaryStart) 1)
!(test (boundaryProvision "maintenance") 1)
!(test (maintenanceFixtureDependency "nars") True)
!(test (maintenanceFixtureQueue "engine-dependent" ((MemoryRentCharge "memory-a" 4)))
    (MaintenanceQueued "engine-dependent"))
!(change-state! &new-msg-flag False)
!(remove-atom &self (ModeTransitionParameters Sleep 1 0 0))
!(add-atom &self (ModeTransitionParameters Sleep 1 20 0))
!(remove-atom &self (ModeTransitionOption urgent-bypass True))
!(add-atom &self (ModeTransitionOption urgent-bypass False))
!(setConstitutionalMode Sleep)
!(test (boundaryCycle explicit-dependency) 1)
!(test (signalTrueIn (lastFactualSignals) sweep-handler-available) True)
!(test (fullLoopDispatch dependency (coreLoopDispatchBegin) (selectedHostCommand))
    (DispatchResult Executed Feasible (MaintenanceCompleted memory-rent "engine-dependent" 1 (MemoryRentAccounted 4))))
!(test (maintenanceFixtureTotal) 4)
!(test (hostReasonerCycles) ())
""", "reasoner=nars")

    def test_default_composition_and_live_startup_exclude_reasoner_extension(self):
        with tempfile.TemporaryDirectory(prefix="reasoner-boundary-") as directory:
            for name in ("composition.metta", "run.metta"):
                with self.subTest(entry=name):
                    edges = self.audit(APP / name, Path(directory) / "imports.json")
                    resolved = {edge["resolved"] for edge in edges}
                    self.assertFalse(resolved & (REASONER_MODULES | HOST_EVIDENCE_MODULES | ASSESSMENT_MODULES | PARAMETER_MODULES | INFLUENCE_MODULES))
                    self.assertFalse(any(edge["kind"] == "reasoner_engine" for edge in edges))
                    # The native decision and policy path still loads.
                    self.assertIn(str(APP / "omegaclaw_decision.metta"), resolved)
                    self.assertIn(str(APP / "contexts/context_policy.metta"), resolved)

    def test_disabled_normal_startup_allocates_no_reasoner_audit_or_engines(self):
        source = (
            "!(import! &self (library MetaMo applications/omegaclaw_v1/tests/host_startup_test))\n"
            "!(test (case (catch (get-state &host-reasoner-cycles)) (((Error $_ $_) True) ($_ False))) True)\n"
            "!(test (case (catch (get-state &reasoner-proposal-events)) "
            "(((Error $_ $_) True) ($_ False))) True)\n"
            "!(test (case (catch (collapse (translatePredicate (metamo_engine_loaded $engine)))) "
            "(((Error $_ $_) True) ($_ False))) True)\n"
        )
        for arguments in ((), ("reasoner=disabled",)):
            with self.subTest(arguments=arguments):
                self.run_entry(source, *arguments)

    def test_selected_adapter_loads_and_derives_through_normal_startup(self):
        for engine, implication in (("nars", "==>"), ("pln", "Implication")):
            with self.subTest(engine=engine):
                self.run_entry(
                    "!(import! &self (library MetaMo applications/omegaclaw_v1/tests/host_startup_test))\n"
                    f"!(test (hostReasonerRegistration) (builtinHostReasoner {engine}))\n"
                    "!(test (initializeHostReasoner) True)\n"
                    f"!(test (getProposalSource (reasonerInferProposal {engine} p Frame-A "
                    "(quote ((Sentence ((Failed Frame-A) (stv 1.0 0.9)) (obs-1)) "
                    f"(Sentence (({implication} (Failed Frame-A) (Recommend Frame-A repair-failure)) "
                    "(stv 1.0 0.9)) (rule-1)))) repair-failure "
                    f'(quote (ExpectedOperationResult "ok")) (InferenceLimits 8 10 40))) {engine})\n',
                    f"reasoner={engine}",
                )

    def test_unknown_and_ambiguous_startup_selections_reject(self):
        for arguments, reason in (
            (("reasoner=unknown",), "UnknownAdapter"),
            (("reasoner=nars", "reasoner=pln"), "InvalidSelection"),
        ):
            with self.subTest(arguments=arguments):
                self.run_entry(
                    "!(import! &self (library lib_import))\n"
                    "!(import! &self (library OmegaClaw-Core src/utils))\n"
                    "!(import! &self (library MetaMo applications/omegaclaw_v1/host_startup))\n"
                    f"!(test (initializeHostReasoner) (ReasonerStartupRejected {reason}))\n",
                    *arguments,
                )

    def test_opt_in_extension_owns_proposals_and_engines(self):
        with tempfile.TemporaryDirectory(prefix="reasoner-extension-") as directory:
            entry = Path(directory) / "optional.metta"
            entry.write_text(
                "!(import! &self (library MetaMo applications/omegaclaw_v1/composition))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_integration))\n"
            )
            edges = self.audit(entry, Path(directory) / "imports.json")
            resolved = {edge["resolved"] for edge in edges}
            self.assertTrue(REASONER_MODULES <= resolved)
            proposal_edges = [e for e in edges if e["resolved"] == str(APP / "reasoners/reasoner_proposals.metta")]
            self.assertEqual(len(proposal_edges), 1)
            engines = {Path(e["resolved"]).name for e in edges if e["kind"] == "reasoner_engine"}
            self.assertEqual(engines, {"lib_nars.metta", "lib_pln.metta"})

    def test_host_evidence_adapter_does_not_load_inference_engines(self):
        with tempfile.TemporaryDirectory(prefix="reasoner-host-evidence-") as directory:
            entry = Path(directory) / "host.metta"
            entry.write_text(
                "!(import! &self (library MetaMo applications/omegaclaw_v1/composition))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_proposals))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_host_evidence))\n"
            )
            edges = self.audit(entry, Path(directory) / "imports.json")
            resolved = {edge["resolved"] for edge in edges}
            self.assertTrue(HOST_EVIDENCE_MODULES <= resolved)
            self.assertFalse(any(edge["kind"] == "reasoner_engine" for edge in edges))
            proposals = [e for e in edges if e["resolved"] == str(APP / "reasoners/reasoner_proposals.metta")]
            self.assertEqual(len(proposals), 1)

    def test_external_assessment_is_explicit_and_does_not_load_inference_engines(self):
        with tempfile.TemporaryDirectory(prefix="reasoner-assessment-") as directory:
            entry = Path(directory) / "assessment.metta"
            entry.write_text(
                "!(import! &self (library MetaMo applications/omegaclaw_v1/composition))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_proposals))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_host_evidence))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_outcome_assessment))\n"
            )
            edges = self.audit(entry, Path(directory) / "imports.json")
            resolved = {edge["resolved"] for edge in edges}
            self.assertTrue(ASSESSMENT_MODULES | HOST_EVIDENCE_MODULES <= resolved)
            self.assertFalse(PARAMETER_MODULES & resolved)
            self.assertFalse(any(edge["kind"] == "reasoner_engine" for edge in edges))
            proposals = [e for e in edges if e["resolved"] == str(APP / "reasoners/reasoner_proposals.metta")]
            self.assertEqual(len(proposals), 1)
            entry.write_text(entry.read_text() +
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_parameter_updates))\n")
            parameter_edges = self.audit(entry, Path(directory) / "parameters.json")
            self.assertTrue(PARAMETER_MODULES <= {edge["resolved"] for edge in parameter_edges})
            self.assertFalse(any(edge["kind"] == "reasoner_engine" for edge in parameter_edges))


if __name__ == "__main__":
    unittest.main()
