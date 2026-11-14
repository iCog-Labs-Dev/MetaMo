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
ASSESSMENT_MODULES = {str(APP / "reasoners/reasoner_outcome_assessment.metta")}
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
                         | HOST_EVIDENCE_MODULES | ASSESSMENT_MODULES)
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
"""
        after = r"""
!(test (size-atom (hostReasonerReceipts)) 1)
!(test (get-state &receipts-at-notification) (hostReasonerReceipts))
!(test (hostReasonerAssessments) ())
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
!(test (assessHostReasonerProposalOutcome (get-state &selected-envelope) (get-state &receipt-id))
    (get-state &first-assessment))
!(test (size-atom (hostReasonerAssessments)) 1)
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
    (ReasonerRuntimeError UnsupportedInfluence))
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

    def test_default_composition_and_live_startup_exclude_reasoner_extension(self):
        with tempfile.TemporaryDirectory(prefix="reasoner-boundary-") as directory:
            for name in ("composition.metta", "run.metta"):
                with self.subTest(entry=name):
                    edges = self.audit(APP / name, Path(directory) / "imports.json")
                    resolved = {edge["resolved"] for edge in edges}
                    self.assertFalse(resolved & (REASONER_MODULES | HOST_EVIDENCE_MODULES | ASSESSMENT_MODULES))
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
            self.assertFalse(any(edge["kind"] == "reasoner_engine" for edge in edges))
            proposals = [e for e in edges if e["resolved"] == str(APP / "reasoners/reasoner_proposals.metta")]
            self.assertEqual(len(proposals), 1)


if __name__ == "__main__":
    unittest.main()
