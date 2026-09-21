"""Determinism, input validation, and isolation of the optional-service doubles."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest

FIXTURES = Path(__file__).resolve().parent / "fixtures/offline_services"


def load(name):
    spec = importlib.util.spec_from_file_location("fixture_" + name, FIXTURES / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class OfflineServicesTest(unittest.TestCase):
    def setUp(self):
        self.composer = load("frame_relation")

    def compose(self, token, k=5):
        return self.composer.cfv2_compose_frame_relations(
            "((Frame (frameID " + token + ")))", token,
            "(RelatedButSeparate Unrelated)", '"Offline"', k)

    def test_first_frame_and_relation_direction(self):
        self.assertEqual(self.compose("frame-a"), "()")
        value = self.compose("frame-b")
        self.assertIn("(FrameID-1 frame-b) (FrameID-2 frame-a)", value)
        self.assertIn("(Class RelatedButSeparate)", value)
        self.assertEqual(self.composer.call_count(), 2)

    def test_replay_and_reset_are_deterministic(self):
        self.compose('"frame-a"')
        value = self.compose('"frame-b"')
        self.assertEqual(self.compose('"frame-b"'), value)
        self.composer.reset()
        self.assertEqual(self.composer.call_count(), 0)
        self.assertEqual(self.compose('"frame-a"'), "()")
        self.assertEqual(self.compose('"frame-b"'), value)

    def test_retrieval_bound(self):
        for n in range(8):
            self.compose("frame-" + str(n))
        self.assertEqual(self.compose("frame-new", 100).count("(Relation "), 5)
        self.assertEqual(self.compose("frame-new", 2).count("(Relation "), 2)
        self.assertEqual(self.compose("frame-new", 0), "()")

    def test_unexpected_inputs_fail_explicitly(self):
        with self.assertRaises(ValueError):
            self.compose("bad) (injection")
        with self.assertRaises(ValueError):
            self.composer.cfv2_compose_frame_relations("()", "frame", "()", "Offline")
        with self.assertRaises(ValueError):
            self.composer.cfv2_compose_frame_relations("(Frame x)", "frame", "RelatedButSeparate", "OpenAI")

    def test_semantic_provider_contract(self):
        llm = load("lib_llm_ext")
        self.assertEqual(llm.extractSemantics("Offline", "message"), "()")
        self.assertEqual(llm.executionConfirmationScore("Offline", "message", "task"), 0.0)
        self.assertEqual(llm.call_count("semantics"), 1)
        self.assertEqual(llm.call_count("confirmation"), 1)
        llm.reset()
        self.assertEqual(llm.call_count("semantics"), 0)
        with self.assertRaises(ValueError):
            llm.extractSemantics("OpenAI", "message")

    def test_guard_blocks_services_and_network_in_isolated_process(self):
        code = """
import offline_guard, socket
offline_guard.install()
for name in ('chromadb', 'openai', 'google.genai', 'sentence_transformers', 'torch'):
    try:
        __import__(name)
    except ImportError as error:
        assert 'optional service forbidden' in str(error)
    else:
        raise AssertionError(name)
try:
    socket.create_connection(('127.0.0.1', 1))
except RuntimeError as error:
    assert 'network forbidden' in str(error)
else:
    raise AssertionError('network was permitted')
assert offline_guard.optional_modules_absent()
"""
        result = subprocess.run([sys.executable, "-c", code], cwd=FIXTURES,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
