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
    (quote (HostReasonerRuntime "admission-test" probeCollect probeNotify () 0.8))) True)
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
