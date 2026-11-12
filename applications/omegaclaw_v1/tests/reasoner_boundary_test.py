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
