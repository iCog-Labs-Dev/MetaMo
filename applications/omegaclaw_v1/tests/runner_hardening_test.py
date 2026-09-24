"""Exercise runner verdicts and real process timeout handling without services."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("metamo_runner", REPO / "scripts/run-tests.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
PASS = "is 1, should 1. ✅ \n"


class RunnerHardeningTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="metamo-runner-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.entry = self.root / "example_test.metta"
        self.entry.write_text("!(test 1 1)\n")

    def verdict(self, stdout=PASS, stderr="", code=0):
        return runner.summarize_result(self.entry,
            subprocess.CompletedProcess([], code, stdout, stderr))[0]

    def test_success(self):
        self.assertTrue(self.verdict())

    def test_missing_multiline_and_same_line_assertions(self):
        self.entry.write_text('!(\n test 1 1) !(test 2 2)\n'
                              '; !(test 3 3)\n!(println! "!(test 4 4)")\n')
        self.assertEqual(runner.count_test_forms(self.entry), 2)
        self.assertFalse(self.verdict())
        self.assertTrue(self.verdict(PASS * 2))

    def test_no_assertions_or_only_printed_emoji(self):
        self.assertFalse(self.verdict("✅\n"))
        self.entry.write_text("(= (unused) 1)\n")
        self.assertFalse(self.verdict(""))

    def test_missing_imported_assertion(self):
        child = self.root / "child.metta"
        child.write_text("!(test 1 1)\n!(test 2 2)\n")
        self.entry.write_text('!(import! &self "child.metta")\n'
                              '!(import! &self "child.metta")\n')
        self.assertEqual(runner.count_test_forms(self.entry), 2)
        self.assertFalse(self.verdict(PASS))
        self.assertTrue(self.verdict(PASS * 2))

    def test_failure_marker_and_nonzero_exit(self):
        self.assertFalse(self.verdict(PASS + "is 1, should 2. ❌\n"))
        self.assertFalse(self.verdict(code=2))

    def test_expected_error_data_is_not_an_interpreter_failure(self):
        output = ('is (Error handler failed), should (Error handler failed). ✅\n'
                  '(FullLoopDispatch (result (Error handler failed)))\n')
        self.assertTrue(self.verdict(output))
        self.assertFalse(self.verdict(output + '(Error import! missing-source)\n'))

    def test_import_examples_inside_strings_are_not_dependencies(self):
        (self.root / 'child.metta').write_text('!(test 2 2)\n')
        self.entry.write_text('!(test 1 1)\n'
                             '!(println! "!(import! &self child.metta)")\n')
        self.assertEqual(runner.count_test_forms(self.entry), 1)

    def test_named_relative_and_symlink_imports_count_once(self):
        child = self.root / 'child.metta'
        child.write_text('!(test 2 2)\n')
        (self.root / 'alias.metta').symlink_to(child)
        self.entry.write_text('!(import! &self (library MetaMo child))\n'
                             '!(import! &self "child.metta")\n'
                             '!(import! &self alias.metta)\n')
        with patch.object(runner, 'REPO', self.root):
            self.assertEqual(runner.count_test_forms(self.entry), 1)

    def test_zero_exit_interpreter_and_import_errors(self):
        for diagnostic in ("ERROR: source_sink missing does not exist\n",
                           "(Error import! missing-source)\n",
                           "Traceback (most recent call last):\nRuntimeError: failed\n"):
            for stream in ("stdout", "stderr"):
                with self.subTest(diagnostic=diagnostic, stream=stream):
                    self.assertFalse(self.verdict(
                        PASS + diagnostic if stream == "stdout" else PASS,
                        diagnostic if stream == "stderr" else ""))

    def test_timeout_retains_both_streams_and_kills_descendants(self):
        sentinel = self.root / "child-survived"
        child = "import time,pathlib; time.sleep(1); pathlib.Path(%r).touch()" % str(sentinel)
        parent = ("import subprocess,sys,time; "
                  "subprocess.Popen([sys.executable, '-c', %r]); "
                  "print('before timeout', flush=True); "
                  "print('diagnostic on stderr', file=sys.stderr, flush=True); "
                  "time.sleep(10)") % child
        with self.assertRaises(subprocess.TimeoutExpired) as caught:
            runner.run_captured([sys.executable, "-c", parent], cwd=self.root,
                                env=os.environ.copy(), timeout=0.3)
        self.assertIn("before timeout", caught.exception.stdout)
        self.assertIn("diagnostic on stderr", caught.exception.stderr)
        time.sleep(1)
        self.assertFalse(sentinel.exists())

    def test_timeout_bytes_are_reported_as_failure(self):
        args = ["run-tests.py", "--root", str(self.root),
                "--petta-runner", str(REPO.parent / "run.sh")]
        output = io.StringIO()
        error = subprocess.TimeoutExpired("fake", 1, output=b"partial stdout", stderr=b"partial stderr")
        with patch.object(sys, "argv", args), patch.object(runner, "run_test_file", side_effect=error), contextlib.redirect_stdout(output):
            self.assertEqual(runner.main(), 1)
        self.assertIn("partial stdout", output.getvalue())
        self.assertIn("partial stderr", output.getvalue())

    def test_real_cli_nonzero_even_with_pass_marker(self):
        fake = self.root / "run.sh"
        fake.write_text("printf 'is 1, should 1. ✅ \\n'\nprintf 'ERROR: failed import\\n' >&2\nexit 0\n")
        result = subprocess.run([sys.executable, str(REPO / "scripts/run-tests.py"),
                                 "--root", str(self.root), "--petta-runner", str(fake)],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("failed import", result.stdout)

    def test_actual_failed_import(self):
        self.entry.write_text('!(test 1 1)\n!(import! &self "missing-module")\n')
        result = subprocess.run([sys.executable, str(REPO / "scripts/run-omegaclaw.py"), str(self.entry)],
                                capture_output=True, text=True, timeout=15)
        self.assertFalse(runner.summarize_result(self.entry, result)[0])
        self.assertIn("import_source", result.stderr)

    def test_real_cli_timeout_fails_and_prints_diagnostics(self):
        fake = self.root / "run.sh"
        fake.write_text("printf 'is 1, should 1. ✅ \\n'\n"
                        "printf 'before timeout\\n'\n"
                        "printf 'timeout stderr\\n' >&2\n"
                        "sleep 10\n")
        result = subprocess.run([sys.executable, str(REPO / "scripts/run-tests.py"),
                                 "--root", str(self.root), "--petta-runner", str(fake),
                                 "--timeout", "1"], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("timed out after 1s", result.stdout)
        self.assertIn("before timeout", result.stdout)
        self.assertIn("timeout stderr", result.stdout)

    def test_actual_interpreter_error_after_passing_assertion(self):
        self.entry.write_text("!(test 1 1)\n!(/ 1 0)\n")
        result = subprocess.run([sys.executable, str(REPO / "scripts/run-omegaclaw.py"), str(self.entry)],
                                capture_output=True, text=True, timeout=15)
        self.assertIn("✅", result.stdout)
        self.assertFalse(runner.summarize_result(self.entry, result)[0])


if __name__ == "__main__":
    unittest.main()
