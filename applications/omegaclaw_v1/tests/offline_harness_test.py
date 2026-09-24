"""Checks the curated harness verdicts and real subprocess/log handling."""
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('offline_harness', REPO / 'scripts/run-omegaclaw-offline.py')
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)
PASS = 'is 1, should 1. ✅\n'


class OfflineHarnessTests(unittest.TestCase):
    def test_default_runs_all_scenarios_and_retains_failure(self):
        def scenario(name, *args):
            return {'scenario': name, 'passed': name != 'callbacks',
                    'assertions': 0, 'expected_assertions': 1,
                    'reasons': ['missing callback coverage'] if name == 'callbacks' else []}
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(harness, 'run_scenario', side_effect=scenario) as run, \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(harness.main(['--output', temp]), 1)
            self.assertEqual([call.args[0] for call in run.call_args_list],
                             ['scoring', 'modes', 'callbacks', 'invalidation'])
            report = json.loads(next(Path(temp).glob('*/summary.json')).read_text())
            self.assertFalse(report['passed'])
            self.assertEqual(len(report['results']), 4)
            self.assertEqual(report['results'][2]['reasons'], ['missing callback coverage'])

    def test_complete_assertion_contract(self):
        good = PASS * 2 + '(FullLoopFinished scoring)\n'
        self.assertTrue(harness.verdict('scoring', 2, 0, good, '', False)['passed'])
        for output in (PASS, PASS * 2, '✅\n(FullLoopFinished scoring)\n',
                       good + PASS, good + 'is 1, should 2. ❌\n'):
            with self.subTest(output=output):
                self.assertFalse(harness.verdict('scoring', 2, 0, output, '', False)['passed'])

    def test_errors_cannot_be_masked_by_passing_assertions(self):
        good = PASS + '(FullLoopFinished scoring)\n'
        for code, stdout, stderr, timeout in (
            (1, good, '', False),
            (0, good + 'ERROR: number_codes/2: float_overflow\n', '', False),
            (0, good, 'Traceback (most recent call last):\n', False),
            (0, good + '(Error import! missing)\n', '', False),
            (0, good, '', True),
        ):
            with self.subTest(code=code, stderr=stderr, timeout=timeout):
                self.assertFalse(harness.verdict('scoring', 1, code, stdout, stderr, timeout)['passed'])

    def test_process_output_and_command_are_retained(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            launcher = root / 'launcher.py'
            launcher.write_text("import sys; from pathlib import Path\n"
                                "Path(sys.argv[sys.argv.index('--report') + 1]).write_text('[]')\n"
                                "print('is 1, should 1. ✅\\n' * 59, end='')\n"
                                "print('(FullLoopFinished scoring)')\n")
            result = harness.run_scenario('scoring', root, root, 5, launcher=launcher)
            self.assertTrue(result['passed'], result)
            self.assertEqual(result['assertions'], 59)
            self.assertEqual(Path(result['stdout']).read_text().count('✅'), 59)
            self.assertEqual(Path(result['stderr']).read_text(), '')
            self.assertIn('--workspace', result['command'])
            json.dumps(result)  # Report is serializable without custom encoders.

    def test_timeout_preserves_logs_and_stops_child_effects(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            marker = root / 'child-effect'
            launcher = root / 'launcher.py'
            child = f"import time; from pathlib import Path; time.sleep(1); Path({str(marker)!r}).touch()"
            launcher.write_text(
                'import subprocess, sys, time\n'
                f'subprocess.Popen([sys.executable, "-c", {child!r}])\n'
                'print("partial cycle", flush=True)\n'
                'print("partial error", file=sys.stderr, flush=True)\n'
                'time.sleep(30)\n')
            result = harness.run_scenario('scoring', root, root, 0.3, launcher=launcher)
            self.assertFalse(result['passed'])
            self.assertTrue(result['timed_out'])
            self.assertIn('partial cycle', Path(result['stdout']).read_text())
            self.assertIn('partial error', Path(result['stderr']).read_text())
            time.sleep(1)
            self.assertFalse(marker.exists())


if __name__ == '__main__':
    unittest.main()
