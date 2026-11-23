"""Benchmark format checks require no host, engine, provider or external service."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

APP = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('benchmark_formats', APP / 'tools/reasoner_benchmark_formats.py')
formats = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(formats)
sys.path.insert(0, str(APP / 'tools'))
import benchmark_reasoners as runner


class BenchmarkFormatTests(unittest.TestCase):
    def setUp(self):
        root = APP / 'tests/fixtures/reasoner_benchmark'
        self.scenario = json.loads((root / 'scenario.example.json').read_text())
        self.result = json.loads((root / 'result.example.json').read_text())

    def test_examples_round_trip_without_mutation(self):
        for value, validate in ((self.scenario, formats.validate_scenario),
                                (self.result, formats.validate_result)):
            original = copy.deepcopy(value)
            self.assertEqual(validate(json.loads(json.dumps(value))), original)
            self.assertEqual(value, original)
        self.assertTrue((APP / self.scenario['initial_state']['fixture']).is_file())

    def test_registered_adapter_and_independent_controls(self):
        self.scenario['adapter'].update(id='custom-rule-adapter', adapter_version='v1', engine_version='rules-v2')
        controls = self.scenario['configuration']
        for enabled in ('collection', 'influence', 'assessment', 'learning'):
            with self.subTest(enabled=enabled):
                controls.update(collection=False, influence=False, assessment=False, learning=False)
                controls[enabled] = True
                formats.validate_scenario(self.scenario)

    def test_bad_versions_controls_and_limits_are_rejected(self):
        cases = [dict(self.scenario, schema_version=True), dict(self.scenario, schema_version=2)]
        for group, key, value in (
                ('adapter', 'engine_version', 'invented-native-version'),
                ('configuration', 'collection', True), ('configuration', 'learning', 'false'),
                ('configuration', 'influence_cap', 0.2), ('configuration', 'seed', True),
                ('resource_limits', 'max_cycles', 0), ('resource_limits', 'max_elapsed_ms', -1),
                ('initial_state', 'observations', {})):
            case = copy.deepcopy(self.scenario)
            case[group][key] = value
            cases.append(case)
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ValueError):
                formats.validate_scenario(case)

    def test_failed_and_ungraded_results_remain_representable(self):
        for status in ('failed', 'timed_out', 'unavailable', 'completed'):
            self.result.update(status=status, error=None if status == 'completed' else 'observed run failure')
            formats.validate_result(self.result)
            self.assertEqual(self.result['measurements'], {})

    def test_causal_references_preserve_native_identity_text(self):
        reference = {'artifact': 'runs/run-1/trace.jsonl', 'stage': 'Execution',
            'identity': '(TraceDecisionRef (OperationContext "session-1" 2 Frame-A) (DispatchTicket "ticket-1"))',
            'cycle_ref': '(TraceCycleRef (OperationContext "session-1" 2 Frame-A))'}
        self.result['trace_references'] = [reference]
        self.assertEqual(formats.validate_result(self.result)['trace_references'], [reference])
        for field in reference:
            broken = copy.deepcopy(self.result)
            del broken['trace_references'][0][field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                formats.validate_result(broken)

    def test_result_failures_are_not_zero_success_or_silent_completion(self):
        for key, value in (('run_id', ''), ('status', 'success'), ('error', None),
                           ('elapsed_ms', False), ('measurements', {'latency': float('nan')})):
            broken = dict(self.result, **{key: value})
            with self.subTest(key=key), self.assertRaises(ValueError):
                formats.validate_result(broken)


class BenchmarkRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='benchmark-process-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.scenario = json.loads((APP / 'tests/fixtures/reasoner_benchmark/scenario.example.json').read_text())
        self.scenario['resource_limits']['max_elapsed_ms'] = 15000

    # Example: temporary drivers are test doubles for future executable benchmark scenarios.
    def entry(self, text):
        path = self.root / 'entry.metta'
        path.write_text(text)
        return path

    def test_fresh_process_memory_and_outputs_with_real_native_dispatch(self):
        probe = self.root / 'benchmark_probe.py'
        probe.write_text('''import json, os
from pathlib import Path
def record():
    import helper
    memory = Path(os.environ['OMEGACLAW_BENCHMARK_MEMORY'])
    marker = memory / 'previous-run'
    assert not marker.exists()
    marker.write_text('owned by this process')
    history = Path(helper.history_path('must-not-use-shared-history'))
    assert history.read_text() == ''
    history.write_text('isolated history')
    scenario = json.loads(Path(os.environ['OMEGACLAW_BENCHMARK_SCENARIO']).read_text())
    output = Path(os.environ['OMEGACLAW_BENCHMARK_OUTPUT'])
    (output / 'probe.json').write_text(json.dumps(dict(pid=os.getpid(), cwd=os.getcwd(),
        memory=str(memory), history=str(history), scenario=scenario['scenario_id'],
        host_config=os.environ.get('OMEGACLAW_HOST_CONFIG'))))
    return 1
''')
        entry = self.entry(f'''!(import! &self (library lib_import))
!(import! &self (library MetaMo applications/omegaclaw_v1/tests/fixtures/boundary_loop))
!(import! &self {probe})
!(test (boundaryStart) 1)
!(test (boundaryProvision "allowed") 1)
!(test (boundaryCycle benchmark) 1)
!(test (fullLoopDispatch benchmark (coreLoopDispatchBegin) (selectedHostCommand))
    (DispatchResult Executed Feasible "observed local file content"))
!(test (py-call (benchmark_probe.record)) 1)
!(py-call (host_config_fixture.cleanup))
''')
        probes = []
        for _ in range(2):
            with patch.dict(os.environ, {'OMEGACLAW_HOST_CONFIG': '/must-not-inherit-live-config'}):
                result, directory = runner.run_comparison(self.scenario, entry, output=self.root / 'runs')
            self.assertEqual(result['status'], 'completed', (directory / 'stderr.log').read_text())
            self.assertEqual(result, json.loads((directory / 'result.json').read_text()))
            probes.append(json.loads((directory / 'output/probe.json').read_text()))
            self.assertTrue((directory / 'imports.json').is_file())
            self.assertEqual(result['trace_references'], [])
            self.assertEqual(result['measurements'], {})
        self.assertNotEqual(probes[0]['pid'], probes[1]['pid'])
        for field in ('cwd', 'memory', 'history'):
            self.assertNotEqual(probes[0][field], probes[1][field])
        self.assertTrue(all(probe['host_config'] is None for probe in probes))

    def test_failed_assertion_and_missing_entry_retain_results_and_logs(self):
        entry = self.entry('!(test 1 2)\n')
        for source in (entry, self.root / 'missing.metta'):
            result, directory = runner.run_comparison(self.scenario, source, output=self.root / 'runs')
            self.assertEqual(result['status'], 'failed')
            self.assertTrue(result['error'])
            self.assertTrue((directory / 'stdout.log').is_file())
            self.assertTrue((directory / 'stderr.log').is_file())
            formats.validate_result(json.loads((directory / 'result.json').read_text()))

    def test_unavailable_process_is_a_retained_result(self):
        with patch.object(runner.subprocess, 'Popen', side_effect=OSError('launcher unavailable')):
            result, directory = runner.run_comparison(self.scenario, self.root / 'entry.metta')
        self.addCleanup(shutil.rmtree, directory)
        self.assertEqual(result['status'], 'unavailable')
        self.assertIn('launcher unavailable', (directory / 'stderr.log').read_text())
        self.assertTrue((directory / 'result.json').is_file())

    def test_timeout_stops_launcher_descendants_and_keeps_partial_output(self):
        probe = self.root / 'timeout_probe.py'
        marker = self.root / 'escaped-child'
        probe.write_text(f'''import subprocess, sys, time
def run():
    print('before timeout', flush=True)
    subprocess.Popen([sys.executable, '-c', {repr('import time; from pathlib import Path; time.sleep(2); Path(' + repr(str(marker)) + ').touch()')}])
    time.sleep(30)
    return 1
''')
        entry = self.entry(f'!(import! &self {probe})\n!(py-call (timeout_probe.run))\n')
        self.scenario['resource_limits']['max_elapsed_ms'] = 1000
        result, directory = runner.run_comparison(self.scenario, entry, output=self.root / 'runs')
        self.assertEqual(result['status'], 'timed_out')
        self.assertIn('before timeout', (directory / 'stdout.log').read_text())
        time.sleep(2)
        self.assertFalse(marker.exists(), 'descendant survived timeout')
        formats.validate_result(json.loads((directory / 'result.json').read_text()))

    def test_cli_continues_after_a_failed_comparison(self):
        entry = self.entry('!(test 1 2)\n')
        scenario = self.root / 'scenario.json'
        scenario.write_text(json.dumps(self.scenario))
        invalid = self.root / 'invalid.json'
        invalid.write_text('{invalid-json')
        output = self.root / 'runs'
        process = subprocess.run([sys.executable, str(APP / 'tools/benchmark_reasoners.py'),
            str(scenario), str(invalid), str(scenario), '--entry', str(entry), '--output', str(output)],
            capture_output=True, text=True, timeout=30)
        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        records = [json.loads(path.read_text()) for path in output.glob('*/result.json')]
        self.assertEqual(len(records), 2)
        self.assertTrue(all(record['status'] == 'failed' for record in records))
        self.assertNotEqual(records[0]['run_id'], records[1]['run_id'])
        rejected = json.loads(next(output.glob('input-errors-*.json')).read_text())
        self.assertEqual(rejected[0]['input'], str(invalid.resolve()))


class BenchmarkMatrixTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='benchmark-matrix-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.scenario = json.loads((APP / 'tests/fixtures/reasoner_benchmark/read.scenario.json').read_text())

    def test_native_nars_pln_matched_modes_and_learning_controls(self):
        original = copy.deepcopy(self.scenario)
        runs = runner.run_matrix(self.scenario, output=self.root)
        self.assertEqual(len(runs), 9)
        self.assertEqual(self.scenario, original)
        initials = []
        combinations = set()
        baseline_result = runs[0][0]['runtime_configuration']['dispatch_result']
        for result, directory in runs:
            with self.subTest(directory=directory):
                self.assertEqual(result['status'], 'completed',
                    (directory / 'stdout.log').read_text()[-2000:] + (directory / 'stderr.log').read_text())
                audit = result['runtime_configuration']
                initials.append(json.loads((directory / 'output/initial-state.json').read_text()))
                combinations.add((audit['selection'], audit['mode'], audit['effective_controls']['learning']))
                self.assertEqual(result['scenario']['initial_state'], original['initial_state'])
                self.assertEqual(result['scenario']['resource_limits'], original['resource_limits'])
                self.assertEqual(audit['dispatch_result'], baseline_result)
                self.assertEqual(result['measurements'], {})
                self.assertTrue(audit['source_sha256'])
                self.assertEqual(audit['capabilities']['feedback'], [])
                if audit['selection'] == 'disabled':
                    self.assertEqual(audit['intake_cycles'], 0)
                    self.assertFalse(any(path.endswith(('lib_nars.metta', 'lib_pln.metta'))
                                         for path in audit['source_sha256']))
                else:
                    self.assertIn('Proposals', audit['intake_statuses'])
                    self.assertGreater(audit['retained_proposals'], 0)
                    self.assertGreater(audit['observed_outcomes'], 0)
                    self.assertIn('propose-candidate', audit['capabilities']['proposal-kinds'])
                    if audit['mode'] == 'advisory':
                        self.assertEqual(audit['influence_setting'][2][3], 0)
        self.assertTrue(all(initial == initials[0] for initial in initials))
        self.assertEqual(len(combinations), 9)

    def test_additional_registered_adapter_reports_actual_capabilities(self):
        variants = json.loads((APP / 'tests/fixtures/reasoner_benchmark/rule.matrix.json').read_text())
        result, directory = runner.run_matrix(self.scenario, variants, output=self.root)[0]
        self.assertEqual(result['status'], 'completed', (directory / 'stderr.log').read_text())
        audit = result['runtime_configuration']
        self.assertEqual(audit['selection'], 'benchmark-rule')
        self.assertEqual(audit['capabilities']['feedback'], ['Decision', 'Observation'])
        self.assertEqual(audit['capabilities']['candidates'], ['respond'])
        self.assertTrue(audit['effective_controls']['learning'])
        self.assertGreater(audit['retained_proposals'], 0)
        self.assertFalse(audit['assessment_feedback_supported'])

    def test_uncalibrated_positive_influence_fails_and_next_variant_runs(self):
        variants = runner.matrix.builtin_variants(self.scenario)
        advisory = copy.deepcopy(variants[3])
        advisory['configuration']['influence_cap'] = 0.05
        runs = runner.run_matrix(self.scenario, [advisory, variants[0]], output=self.root)
        self.assertEqual([result['status'] for result, _ in runs], ['failed', 'completed'])
        result, directory = runs[0]
        self.assertIn('predictive evidence', result['error'])
        self.assertFalse(result['runtime_configuration']['complete'])
        self.assertIn('propose-candidate', result['runtime_configuration']['capabilities']['proposal-kinds'])

    def test_missing_registration_remains_an_unavailable_comparison(self):
        variant = json.loads((APP / 'tests/fixtures/reasoner_benchmark/rule.matrix.json').read_text())[0]
        variant['adapter']['registration'] = 'missing-adapter.metta'
        result, directory = runner.run_matrix(self.scenario, [variant], output=self.root)[0]
        self.assertEqual(result['status'], 'unavailable')
        self.assertTrue((directory / 'result.json').is_file())

    def test_engine_version_mismatch_is_not_a_successful_comparison(self):
        variant = json.loads((APP / 'tests/fixtures/reasoner_benchmark/rule.matrix.json').read_text())[0]
        variant['adapter']['engine_version'] = 'another-engine-version'
        result, _ = runner.run_matrix(self.scenario, [variant], output=self.root)[0]
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['runtime_configuration']['engine_version'], 'rule-fixture-1')

    def test_timeout_truncated_audits_do_not_discard_the_result(self):
        (self.root / 'output').mkdir()
        (self.root / 'output/runtime-configuration.json').write_text('{partial')
        (self.root / 'imports.json').write_text('[partial')
        result = dict(schema_version=1, run_id='interrupted-run', scenario=self.scenario,
            status='timed_out', error='deadline expired', elapsed_ms=1,
            trace_references=[], measurements={})
        runner._retain_runtime_report(result, self.root)
        self.assertEqual(result['status'], 'timed_out')
        self.assertEqual(result['error'], 'deadline expired')
        self.assertIn('source_report_error', result['runtime_configuration'])
        formats.validate_result(result)

    def test_unsupported_scenario_and_invalid_matrix_are_not_silently_ignored(self):
        self.scenario['configuration']['seed'] = 7
        result, _ = runner.run_matrix(self.scenario, [runner.matrix.builtin_variants(self.scenario)[0]], output=self.root)[0]
        self.assertEqual(result['status'], 'unavailable')
        with self.assertRaises(ValueError):
            runner.run_matrix(self.scenario, [{'adapter': {}}], output=self.root)


if __name__ == '__main__':
    unittest.main()
