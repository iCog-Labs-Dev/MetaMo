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
        "reasoner_proposals.metta", "reasoner_proposal_helpers.metta",
        "reasoner_integration.metta", "reasoner_engines.pl",
    )
}
ASSESSMENT_MODULES = {str(APP / "reasoner_outcome_assessment.metta")}
HOST_EVIDENCE_MODULES = {
    str(APP / name) for name in ("reasoner_host_evidence.metta", "reasoner_host_evidence.pl")
}


class ReasonerBoundaryTests(unittest.TestCase):
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
                "!(import! &self (library MetaMo applications/omegaclaw_v1/host_reasoner_contracts))\n"
            )
            edges = self.audit(entry, Path(directory) / "imports.json")
            resolved = {edge["resolved"] for edge in edges}
            self.assertIn(str(APP / "host_reasoner_contracts.metta"), resolved)
            forbidden = ((REASONER_MODULES - {str(APP / "reasoner_proposal_helpers.metta")})
                         | HOST_EVIDENCE_MODULES | ASSESSMENT_MODULES)
            self.assertFalse(resolved & forbidden)
            self.assertFalse(any(edge["resolved"].endswith(".pl")
                                 and "host_reasoner_contracts" in edge["resolved"]
                                 for edge in edges))
            self.assertFalse(any(edge["kind"] == "reasoner_engine" for edge in edges))
            self.assertNotIn(str(APP / "composition.metta"), resolved)

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

    def test_opt_in_extension_owns_proposals_and_engines(self):
        with tempfile.TemporaryDirectory(prefix="reasoner-extension-") as directory:
            entry = Path(directory) / "optional.metta"
            entry.write_text(
                "!(import! &self (library MetaMo applications/omegaclaw_v1/composition))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_integration))\n"
            )
            edges = self.audit(entry, Path(directory) / "imports.json")
            resolved = {edge["resolved"] for edge in edges}
            self.assertTrue(REASONER_MODULES <= resolved)
            proposal_edges = [e for e in edges if e["resolved"] == str(APP / "reasoner_proposals.metta")]
            self.assertEqual(len(proposal_edges), 1)
            engines = {Path(e["resolved"]).name for e in edges if e["kind"] == "reasoner_engine"}
            self.assertEqual(engines, {"lib_nars.metta", "lib_pln.metta"})

    def test_host_evidence_adapter_does_not_load_inference_engines(self):
        with tempfile.TemporaryDirectory(prefix="reasoner-host-evidence-") as directory:
            entry = Path(directory) / "host.metta"
            entry.write_text(
                "!(import! &self (library MetaMo applications/omegaclaw_v1/composition))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_proposals))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_host_evidence))\n"
            )
            edges = self.audit(entry, Path(directory) / "imports.json")
            resolved = {edge["resolved"] for edge in edges}
            self.assertTrue(HOST_EVIDENCE_MODULES <= resolved)
            self.assertFalse(any(edge["kind"] == "reasoner_engine" for edge in edges))
            proposals = [e for e in edges if e["resolved"] == str(APP / "reasoner_proposals.metta")]
            self.assertEqual(len(proposals), 1)

    def test_external_assessment_is_explicit_and_does_not_load_inference_engines(self):
        with tempfile.TemporaryDirectory(prefix="reasoner-assessment-") as directory:
            entry = Path(directory) / "assessment.metta"
            entry.write_text(
                "!(import! &self (library MetaMo applications/omegaclaw_v1/composition))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_proposals))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_host_evidence))\n"
                "!(import! &self (library MetaMo applications/omegaclaw_v1/reasoner_outcome_assessment))\n"
            )
            edges = self.audit(entry, Path(directory) / "imports.json")
            resolved = {edge["resolved"] for edge in edges}
            self.assertTrue(ASSESSMENT_MODULES | HOST_EVIDENCE_MODULES <= resolved)
            self.assertFalse(any(edge["kind"] == "reasoner_engine" for edge in edges))
            proposals = [e for e in edges if e["resolved"] == str(APP / "reasoner_proposals.metta")]
            self.assertEqual(len(proposals), 1)


if __name__ == "__main__":
    unittest.main()
