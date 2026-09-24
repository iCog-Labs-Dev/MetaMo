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

    def test_failed_assertion_retains_real_cycle_and_dispatch_traces(self):
        # Execute the real offline path, then deliberately fail an assertion.
        # The interpreter stops before completion: earlier traces must survive.
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            entry = root / 'failed_trace_test.metta'
            fixture = harness.TESTS / 'fixtures/boundary_loop.metta'
            entry.write_text(
                f'!(import! &self {json.dumps(str(fixture))})\n'
                '!(test (boundaryStart) 1)\n'
                '!(test (boundaryProvision "allowed") 1)\n'
                '!(test (boundaryCycle failure-trace) 1)\n'
                '!(test (fullLoopDispatch failure-trace (coreLoopDispatchBegin)\n'
                '   (selectedHostCommand))\n'
                '   (DispatchResult Executed Feasible "observed local file content"))\n'
                '!(test (boundaryCallback failure-trace (get-state &last-operation-outcome))\n'
                '   OutcomeDuplicate)\n'
                '!(py-call (host_config_fixture.cleanup))\n'
                '!(test 1 2)\n'
                '!(fullLoopFinish failure-trace)\n')
            with patch.object(harness, 'SCENARIOS', {'failure-trace': (str(entry), 6)}), \
                 contextlib.redirect_stdout(io.StringIO()):
                code = harness.main(['--output', str(root / 'reports'), '--timeout', '30'])

            self.assertEqual(code, 1)
            report = json.loads(next((root / 'reports').glob('*/summary.json')).read_text())
            self.assertFalse(report['passed'])
            self.assertEqual(len(report['results']), 1)
            result = report['results'][0]
            output = Path(result['stdout']).read_text()
            stderr = Path(result['stderr']).read_text()
            self.assertFalse(result['passed'])
            self.assertEqual(result['returncode'], 1, output + stderr)
            self.assertFalse(result['timed_out'])
            self.assertEqual(result['assertions'], 5)
            self.assertIn('failed assertion', result['reasons'])
            self.assertIn('missing scenario completion marker', result['reasons'])
            for marker in ('FullLoopCycleBegin', 'FullLoopCycle',
                           'FullLoopDispatch', 'FullLoopCallback'):
                self.assertIn(f'({marker} failure-trace ', output)
            self.assertIn('(snapshot (FrameStateBundle ', output)
            self.assertIn('(operation (OperationDecision ', output)
            self.assertIn('(outcome (OperationOutcome ', output)
            self.assertIn('is 1, should 2. ❌', output)
            self.assertNotIn('(FullLoopFinished failure-trace)', output)
            self.assertTrue(Path(result['stderr']).is_file())
            self.assertTrue(json.loads(Path(result['imports']).read_text()))
            self.assertIn(str(fixture), result['imported_source_sha256'])
            self.assertEqual(result['imported_source_sha256'][str(fixture)],
                             harness.source_hash(fixture))


if __name__ == '__main__':
    unittest.main()
