"""UUID, opaque persistence and process/restart tests. Causal rules are MeTTa."""
import concurrent.futures
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid

SOURCE = Path(__file__).resolve().parents[1] / "identity_store.py"
spec = importlib.util.spec_from_file_location("identity_store", SOURCE)
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)


def allocation(value):
    match = re.fullmatch(r'\(IdentityAllocation ("[^"]+") ("[^"]+")\)', value)
    if match is None:
        raise AssertionError(value)
    return tuple(json.loads(part) for part in match.groups())


class IdentityStorageTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="identity-store-test-")
        self.path = Path(self.tmp.name) / "ledger.json"
        self.assertTrue(store.open_ledger(str(self.path)).startswith("(IdentityHost "))
        self.host = json.loads(store.producer("host"))

    def tearDown(self):
        store.close_ledger()
        self.tmp.cleanup()

    def reserve(self, cause=""):
        return allocation(store.reserve("host", "ExecutionRef", cause))

    def child(self, body):
        code = f"import sys; sys.path.insert(0, {str(SOURCE.parent)!r}); import identity_store as s; {body}"
        return subprocess.run([sys.executable, "-c", code], capture_output=True, text=True, timeout=15)

    def test_uuid_and_parallel_unique_allocation(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
            values = list(executor.map(lambda _: self.reserve(), range(24)))
        self.assertEqual(len({value[1] for value in values}), 24)
        self.assertTrue(all(uuid.UUID(identifier).version == 4 for _, identifier in values))

    def test_same_cause_reserves_one_id_across_threads_and_restart(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
            values = list(executor.map(lambda _: self.reserve("dispatch-native"), range(16)))
        self.assertEqual(len(set(values)), 1)
        store.close_ledger()
        store.open_ledger(str(self.path), self.host)
        self.assertEqual(self.reserve("dispatch-native"), values[0])
        self.assertEqual(allocation(store.lookup_cause("ExecutionRef", "dispatch-native")), values[0])

    def test_immutable_data_and_conflict(self):
        namespace, identifier = self.reserve()
        data = '(ExecutionLink (id "native") (opaque "quotes \\\" and λ"))'
        self.assertEqual(store.commit("ExecutionRef", namespace, identifier, "", data), data)
        self.assertEqual(store.commit("ExecutionRef", namespace, identifier, "", data), data)
        self.assertIn("IdentityConflict", store.commit("ExecutionRef", namespace, identifier, "", "different"))
        self.assertEqual(store.resolve("ExecutionRef", namespace, identifier), data)

    def test_native_frame_versions_are_never_replaced(self):
        native = "Frame-20260921T091500000001Z"
        self.assertEqual(store.commit("FrameRef", self.host, native, "4", "active", "entity"), "active")
        self.assertEqual(store.commit("FrameRef", self.host, native, "5", "completed", "entity"), "completed")
        self.assertIn("IdentityConflict", store.commit("FrameRef", self.host, native, "4", "replacement", "entity"))
        self.assertIn("InvalidValue", store.commit("FrameRef", self.host, native, "7", "skipped", "entity"))
        store.close_ledger()
        store.open_ledger(str(self.path), self.host)
        self.assertEqual(store.resolve("FrameRef", self.host, native, "4"), "active")
        self.assertEqual(store.resolve("FrameRef", self.host, native, "5"), "completed")

    def test_namespace_and_type_resolution(self):
        namespace, identifier = self.reserve()
        store.commit("ExecutionRef", namespace, identifier, "", "payload")
        self.assertIn("MalformedRecord", store.resolve("ObservationRef", namespace, identifier))
        self.assertIn("MissingReference", store.resolve("ExecutionRef", "another-host", identifier))
        self.assertIn("MissingReference", store.commit("ExecutionRef", namespace, "forged", "", "payload"))

    def test_missing_ledger_resume_does_not_create(self):
        store.close_ledger()
        self.path.unlink()
        self.assertIn("MissingReference", store.open_ledger(str(self.path), self.host))
        self.assertFalse(self.path.exists())

    def test_corrupt_ledger_rejected_without_overwrite(self):
        store.close_ledger()
        self.path.write_text('{"version":1}', encoding="utf-8")
        self.assertIn("MalformedRecord", store.open_ledger(str(self.path), self.host))
        self.assertEqual(self.path.read_text(), '{"version":1}')

    def test_restart_preserves_producers_and_fresh_process_resolves(self):
        producer = store.producer("metamo")
        namespace, identifier = self.reserve()
        store.commit("ExecutionRef", namespace, identifier, "", "retained")
        store.close_ledger()
        result = self.child(f's.open_ledger({str(self.path)!r}, {self.host!r}); '
                            f'assert s.producer("metamo") == {producer!r}; '
                            f'assert s.resolve("ExecutionRef", {namespace!r}, {identifier!r}) == "retained"; '
                            's.close_ledger()')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_live_second_process_cannot_open_ledger(self):
        result = self.child(f's.open_ledger({str(self.path)!r}, {self.host!r})')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("BlockingIOError", result.stderr)
        self.assertEqual(json.loads(store.producer("host")), self.host)

    def test_create_cannot_reset_and_resume_cannot_change_lineage(self):
        store.close_ledger()
        self.assertIn("IdentityConflict", store.open_ledger(str(self.path)))
        self.assertIn("IdentityConflict", store.open_ledger(str(self.path), "other-host"))
        self.assertEqual(store.open_ledger(str(self.path), self.host), f'(IdentityHost "{self.host}")')

    def test_explicit_fork_uses_new_namespace_and_cannot_resolve_old_ids(self):
        namespace, identifier = self.reserve()
        store.commit("ExecutionRef", namespace, identifier, "", "old")
        store.close_ledger()
        store.open_ledger(str(Path(self.tmp.name) / "fork.json"))
        self.assertNotEqual(json.loads(store.producer("host")), self.host)
        self.assertIn("MissingReference", store.resolve("ExecutionRef", namespace, identifier))

    def test_failed_commit_does_not_report_success_or_continue_stale_memory(self):
        namespace, identifier = self.reserve()
        with patch.object(store.os, "replace", side_effect=OSError("storage unavailable")):
            with self.assertRaises(OSError):
                store.commit("ExecutionRef", namespace, identifier, "", "uncommitted")
        self.assertIn("NotInitialized", store.resolve("ExecutionRef", namespace, identifier))
        store.close_ledger()
        store.open_ledger(str(self.path), self.host)
        self.assertIn("MissingReference", store.resolve("ExecutionRef", namespace, identifier))
        self.assertEqual(store.commit("ExecutionRef", namespace, identifier, "", "reconciled"), "reconciled")


if __name__ == "__main__":
    unittest.main()
