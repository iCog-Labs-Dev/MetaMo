#!/usr/bin/env python3
"""Regression checks for the actual v1 launcher, using the selected local compiler."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent
WORKSPACE = Path(os.environ.get("PETTA_PATH", REPO.parent)).resolve()
LAUNCHER = REPO / "scripts/run-omegaclaw.py"


class ImportResolutionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="metamo imports ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def launch(self, entry, *args, cwd=None):
        return subprocess.run(
            [sys.executable, str(LAUNCHER), str(entry), "--workspace", str(WORKSPACE), *args],
            cwd=cwd or self.root, text=True, capture_output=True, timeout=30,
        )

    def test_context_facade_with_native_workspace_runner(self):
        # Do not use the caching launcher here: that would conceal duplicate
        # imports in the facade and leave the user's run.sh invocation broken.
        entry = REPO / "applications/omegaclaw_v1/tests/context_integration_test.metta"
        result = subprocess.run(
            ["sh", str(WORKSPACE / "run.sh"), os.path.relpath(entry, WORKSPACE), "-s"],
            cwd=WORKSPACE, text=True, capture_output=True, timeout=30,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output[-5000:])
        self.assertNotIn("❌", output)
        self.assertEqual(output.count("✅"), 77, output[-5000:])

    def test_native_reasoner_and_minimal_loop_with_bounded_stack(self):
        # Both commands bypass our import cache. The second invokes the same
        # compiler as run.sh with 64 MiB rather than its default 8 GiB stack.
        for name, count in (("minimal_loop_test", 6), ("reasoner_integration_test", 18)):
            entry = REPO / f"applications/omegaclaw_v1/tests/{name}.metta"
            for runner in (["sh", str(WORKSPACE / "run.sh")],
                           ["swipl", "--stack_limit=64m", "-q", "-s",
                            str(WORKSPACE / "src/main.pl"), "--"]):
                with self.subTest(test=name, runner=runner[0]):
                    result = subprocess.run(
                        [*runner, os.path.relpath(entry, WORKSPACE), "-s"],
                        cwd=WORKSPACE, text=True, capture_output=True, timeout=30,
                    )
                    output = result.stdout + result.stderr
                    self.assertEqual(result.returncode, 0, output[-5000:])
                    self.assertNotIn("❌", output)
                    self.assertNotIn("ERROR:", output)
                    self.assertEqual(output.count("✅"), count, output[-5000:])

    def test_nested_relative_imports_and_symlinks_load_once(self):
        nested = self.root / "nested"
        nested.mkdir()
        source = nested / "value.metta"
        source.write_text("(= (uniqueValue) 42)\n")
        (self.root / "alias.metta").symlink_to(source)
        (nested / "module.metta").write_text('!(import! &self "value.metta")\n')
        entry = self.root / "entry.metta"
        entry.write_text('!(import! &self "nested/module.metta")\n'
                         '!(import! &self "alias.metta")\n'
                         '!(test (uniqueValue) 42)\n')
        report = self.root / "imports.json"
        result = self.launch(entry, "--report", str(report))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count("✅"), 1, result.stdout)
        edges = json.loads(report.read_text())
        self.assertEqual(sum(e["resolved"] == str(source.resolve()) for e in edges), 2)

    def test_named_imports_do_not_depend_on_cwd(self):
        entry = REPO / "applications/omegaclaw_v1/tests/reasoner_integration_test.metta"
        reports = []
        for index, cwd in enumerate((self.root, REPO, WORKSPACE)):
            report = self.root / f"{index}.json"
            result = self.launch(entry, "--audit", "--report", str(report), cwd=cwd)
            self.assertEqual(result.returncode, 0, result.stderr)
            reports.append(json.loads(report.read_text()))
        self.assertEqual(reports[0], reports[1])
        self.assertEqual(reports[1], reports[2])
        engines = {e["resolved"] for e in reports[0] if e["kind"] == "reasoner_engine"}
        self.assertEqual(engines, {str(WORKSPACE / "lib" / name)
                                  for name in ("lib_nars.metta", "lib_pln.metta")})

    def test_missing_import_is_fatal_before_entry_execution(self):
        entry = self.root / "missing.metta"
        entry.write_text('!(println! "MUST-NOT-RUN")\n!(import! &self "absent")\n')
        result = self.launch(entry)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("import_source", result.stderr)
        self.assertNotIn("MUST-NOT-RUN", result.stdout)

    def test_audit_does_not_execute_application_python(self):
        (self.root / "poison.py").write_text('raise RuntimeError("application Python executed")\n')
        entry = self.root / "audit.metta"
        entry.write_text('!(import! &self "poison.py")\n')
        result = self.launch(entry, "--audit")
        self.assertEqual(result.returncode, 0, result.stderr)
        executed = self.launch(entry)
        self.assertNotEqual(executed.returncode, 0)
        self.assertIn("application Python executed", executed.stderr)

    def test_import_cycle_is_an_error_not_a_partial_module(self):
        entry = self.root / "cycle.metta"
        entry.write_text('!(import! &self "child.metta")\n')
        (self.root / "child.metta").write_text('!(import! &self "cycle.metta")\n')
        result = self.launch(entry)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cyclic_module_import", result.stderr)

    def test_cross_space_module_reimport_rejects_global_recompilation(self):
        (self.root / "value.metta").write_text('(= (globalValue) 42)\n')
        entry = self.root / "spaces.metta"
        entry.write_text('!(import! &self "value.metta")\n'
                         '!(bind! &other (new-space))\n'
                         '!(import! &other "value.metta")\n')
        result = self.launch(entry)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("module_space_conflict", result.stderr)


if __name__ == "__main__":
    unittest.main()
