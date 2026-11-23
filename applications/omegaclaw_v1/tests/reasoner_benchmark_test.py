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

    def test_invalid_initial_controls_and_observations_are_rejected(self):
        for key, value in (('motivation', {'goals': {'help_user': True}}),
                           ('host', {'frame_mode': 'Sleep'}), ('budgets', {'frame': -1}),
                           ('operations', ['read-file', 'read-file']),
                           ('observations', [{'cycle': 0, 'file_content': 'later'}]),
                           ('observations', [{'cycle': 1, 'semantics': {'danger': 1.1}}])):
            broken = copy.deepcopy(self.scenario)
            broken['initial_state'][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                formats.validate_scenario(broken)

    def test_episode_carry_requires_explicit_supported_state(self):
        maximum = self.scenario['resource_limits']['max_cycles']
        self.scenario['episodes'] = dict(cycles=[1, maximum - 1], carry=list(formats.CARRIED_STATE))
        formats.validate_scenario(self.scenario)
        for policy in (dict(cycles=[maximum], carry=['engine_state']),
                       dict(cycles=[1, maximum - 1], carry=[]),
                       dict(cycles=[0, maximum], carry=list(formats.CARRIED_STATE)),
                       dict(cycles=[maximum + 1], carry=[])):
            broken = dict(self.scenario, episodes=policy)
            with self.subTest(policy=policy), self.assertRaises(ValueError):
                formats.validate_scenario(broken)

    def test_calibration_roles_and_task_oracles_are_explicit(self):
        self.scenario['episodes'] = dict(cycles=[2, 2], carry=list(formats.CARRIED_STATE), roles=['evaluation', 'calibration'])
        with self.assertRaises(ValueError):
            formats.validate_scenario(self.scenario)
        del self.scenario['episodes']
        self.scenario['evaluation'] = dict(checks=[dict(cycle=1, oracle='model-says-success')])
        with self.assertRaises(ValueError):
            formats.validate_scenario(self.scenario)

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


class BenchmarkMeasurementTests(unittest.TestCase):
    def setUp(self):
        self.result = json.loads((APP / 'tests/fixtures/reasoner_benchmark/result.example.json').read_text())

    # Example: pooled success is 4/5, not the mean of 75% and 100%; failures remain listed.
    def test_aggregate_uses_counts_and_keeps_failed_runs(self):
        first = self.measured_result('first', ['passed', 'passed', 'passed', 'failed'])
        second = self.measured_result('second', ['passed'])
        second.update(status='timed_out', error='deadline expired')
        group = runner.metrics.aggregate([first, second])[0]
        self.assertEqual(group['task_outcomes']['positive_percent'], 80)
        self.assertEqual(group['run_statuses'], {'completed': 1, 'timed_out': 1})
        self.assertEqual(group['task_outcomes']['verified'], 5)

    # Example: unknown or reset telemetry cannot become an observed zero.
    def test_empty_coverage_and_reset_counters_remain_unavailable(self):
        self.assertIsNone(runner.metrics.outcome_counts([], 'passed', 'failed')['positive_percent'])
        delta = runner.metrics.counter_delta({'engine_steps_reserved': 0}, {'engine_steps_reserved': 2})
        self.assertEqual(delta['status'], 'unavailable')
        summary = runner.metrics.resource_summary([delta])
        self.assertIsNone(summary['engine_steps_reserved'])
        self.assertEqual(summary['unavailable_cycles'], 1)

    # Example: retained outcome samples can exist in a run that later times out.
    def measured_result(self, identity, statuses):
        result = copy.deepcopy(self.result)
        result.update(run_id=identity, status='completed', error=None)
        tasks = [dict(status=status, split='evaluation') for status in statuses]
        sample = runner.metrics.score_split('evaluation', [], tasks, [], [])
        result['measurements'] = dict(scorer_sha256='test-method', by_split={'evaluation': sample})
        return result


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
                self.check_native_sequence(result, directory, self.read_selection_sequence(runs[0][1]))
                self.assertEqual(result['measurements']['version'], runner.metrics.SCORER_VERSION)
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
        # Preserve run-specific host IDs/paths, while comparing the shared starting values.
        comparable = [{key: value for key, value in initial.items() if key != 'host_snapshot'} for initial in initials]
        self.assertTrue(all(initial == comparable[0] for initial in comparable))
        self.assertEqual(len(combinations), 9)

    # Example: compare concrete read behavior without rewriting retained run-specific identities.
    def read_selection_sequence(self, directory):
        rows = runner.metrics.read_trajectory(directory)
        return [(row['observation'][1][2], row['observation'][1][3][:1], row['observation'][2]) for row in rows]

    # Example: the normal callback must belong to the exact selected operation in every cycle.
    def check_native_sequence(self, result, directory, expected):
        self.assertEqual(result['status'], 'completed', (directory / 'stderr.log').read_text())
        self.assertEqual(self.read_selection_sequence(directory), expected)
        rows = runner.metrics.read_trajectory(directory)
        self.assertIn('NewTask', rows[0]['admission'])
        for row in rows:
            _, decision, observed, outcome, _, _ = row['observation']
            self.assertEqual(outcome[1], decision)
            self.assertEqual(outcome[4], observed)
            if decision[3]:
                self.assertEqual(decision[3], ['read-file', row['world_before']['path']])
            self.assertEqual(row['reliability_before'], row['reliability_after'])
            if result['scenario']['adapter']['id'] != 'disabled':
                self.assertIn(type(row['reliability_before']), (int, float))

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
        rows = runner.metrics.read_trajectory(directory)
        self.assertTrue(all(row['reliability_before'] == row['reliability_after'] == 0.75 for row in rows))

    # Example: synthetic adapter edits survive continuous episodes, never another configuration.
    def test_continuous_learning_is_retained_only_within_its_run(self):
        self.scenario['episodes'] = dict(cycles=[2, 2], carry=list(formats.CARRIED_STATE))
        variants = [self.learning_variant(enabled) for enabled in (True, False, True)]
        runs = runner.run_matrix(self.scenario, variants, output=self.root)
        for (result, directory), enabled in zip(runs, (True, False, True)):
            self.check_learning_run(result, directory, enabled)
        records = [result['runtime_configuration']['isolation'] for result, _ in runs]
        for key in ('pid', 'run_id', 'memory', 'runtime'):
            self.assertEqual(len({record[key] for record in records}), 3)

    # Example: the probe declares its own engine/version and a normal supported feedback path.
    def learning_variant(self, enabled):
        variant = json.loads((APP / 'tests/fixtures/reasoner_benchmark/rule.matrix.json').read_text())[0]
        variant['adapter'].update(id='benchmark-learning-probe', engine_version='learning-probe-1',
            configuration_version='learning-probe-config-1',
            registration='tests/fixtures/reasoner_benchmark/learning_probe.metta')
        variant['configuration']['learning'] = enabled
        return variant

    # Example: initial stores are clean, while episode two sees the same run's earlier effects.
    def check_learning_run(self, result, directory, enabled):
        self.assertEqual(result['status'], 'completed', (directory / 'stderr.log').read_text())
        rows = [json.loads(line) for line in (directory / 'output/learning-probe.jsonl').read_text().splitlines()]
        self.assertEqual((rows[0]['value'], rows[0]['reliability'], rows[0]['memory']), (0, 0.75, None))
        self.assertEqual(rows[0]['pending'], [])
        self.assertEqual(rows[0]['parameters'][0][-1], 0.175)
        self.assertEqual(len({row['context'][1] for row in rows}), 1)
        boundary = next(row for row in rows if row['context'][2] == 3)
        self.check_learning_continuity([rows[0], boundary], enabled)
        trajectory = [json.loads(line) for line in (directory / 'output/trajectory.jsonl').read_text().splitlines()]
        self.assertEqual([row['episode'] for row in trajectory], [1, 1, 2, 2])
        self.assertEqual([row['episode_cycle'] for row in trajectory], [1, 2, 1, 2])
        self.assertEqual(result['runtime_configuration']['isolation']['episodes'], self.scenario['episodes'])

    # Example: budgets and evidence continue; disabled learning leaves adaptive stores untouched.
    def check_learning_continuity(self, rows, enabled):
        self.assertTrue(rows[-1]['pending'])
        before = rows[0]['host'][4][1]
        after = rows[-1]['host'][4][1]
        self.assertNotEqual(before, after)
        if enabled:
            self.assertGreater(rows[-1]['value'], 0)
            self.assertEqual(rows[-1]['reliability'], 0.42)
            self.assertEqual(rows[-1]['parameters'][0][-1], 0.2)
            self.assertEqual(rows[-1]['memory'], rows[-1]['value'])
        else:
            self.assertTrue(all(row['value'] == 0 and row['memory'] is None for row in rows))

    # Example: calibration and evaluation keep separate task/resource denominators.
    def test_measured_native_and_shadow_runs_have_separate_role_totals(self):
        self.scenario['episodes'] = dict(cycles=[2, 2], carry=list(formats.CARRIED_STATE), roles=['calibration', 'evaluation'])
        self.scenario['evaluation']['checks'].append(dict(cycle=3, oracle='read-file-content-v1'))
        runs = runner.run_matrix(self.scenario, runner.matrix.builtin_variants(self.scenario)[:2], output=self.root)
        for index, (result, directory) in enumerate(runs):
            self.check_measured_run(result, index != 0)
            self.check_independent_policy_audit(directory)
        groups = json.loads((self.root / 'summary.json').read_text())['groups']
        self.assertEqual({(row['mode'], row['split']) for row in groups},
                         {('native', 'calibration'), ('native', 'evaluation'), ('shadow', 'calibration'), ('shadow', 'evaluation')})
        self.assertTrue(all(row['configuration']['influence_cap'] == 0 for row in groups))

    # Example: unknown engine instructions and provider tokens are never replaced by configured limits.
    def check_measured_run(self, result, engine):
        self.assertEqual(result['status'], 'completed')
        for role in ('calibration', 'evaluation'):
            sample = result['measurements']['by_split'][role]
            self.assertEqual(sample['task_outcomes']['positive_percent'], 100)
            self.assertEqual(sample['policy_compliance']['negative_percent'], 0)
            self.assertGreater(sample['latency']['mean_ms'], 0)
            self.assertIsNone(sample['resources']['engine_instructions'])
            self.assertEqual(sample['resources']['reasoner_provider_calls_reserved'], 0)
            if engine:
                self.assertGreater(sample['resources']['engine_steps_reserved'], 0)
                expected_coverage = 0 if sample['prediction_quality']['total'] else None
                self.assertEqual(sample['prediction_quality']['coverage_percent'], expected_coverage)
                self.assertIsNone(sample['prediction_quality']['positive_percent'])

    # Example: tampered authorization is detected independently, while blocked execution is not a violation.
    def check_independent_policy_audit(self, directory):
        rows = runner.metrics.read_trajectory(directory)
        sample = copy.deepcopy(rows[0])
        self.assertEqual(runner.metrics.check_policy(sample)['status'], 'passed')
        sample['observation'][4][4][1][0][3] = sample['observation'][4][4][1][0][2] + 1
        self.assertEqual(runner.metrics.check_policy(sample)['reason'], 'BudgetOverrun')
        sample = copy.deepcopy(rows[0])
        sample['host_before'][1][3][1] = []
        self.assertEqual(runner.metrics.check_policy(sample)['status'], 'failed')
        sample['observation'][2][1] = 'Blocked'
        self.assertEqual(runner.metrics.check_policy(sample)['status'], 'ungraded')
        sample['observation'][3] = []
        self.assertEqual(runner.metrics.check_task(sample, dict(cycle=1, oracle='read-file-content-v1'))['status'], 'ungraded')

    # Example: selected exact predictions can be confirmed/refuted; unobserved alternatives stay ungraded.
    def test_prediction_grades_coverage_and_scoring_are_read_only(self):
        variant = self.exact_variant()
        for content, expected in (('observed local file content', 100), ('changed world', 0)):
            self.scenario['initial_state']['file_content'] = content
            result, directory = runner.run_matrix(self.scenario, [variant], output=self.root)[0]
            self.assertEqual(result['status'], 'completed', (directory / 'stderr.log').read_text())
            sample = result['measurements']['by_split']['evaluation']
            self.assertEqual(sample['task_outcomes']['positive_percent'], 100)
            self.assertEqual(sample['prediction_quality']['positive_percent'], expected)
            self.assertGreater(sample['prediction_quality']['ungraded'], 0)
            self.assertGreater(sample['prediction_quality']['verified'], 0)
            self.check_scoring_is_read_only(result, directory)

    # Example: this adapter is a deterministic prediction double, not an engine quality benchmark.
    def exact_variant(self):
        variant = self.learning_variant(False)
        variant['adapter'].update(id='benchmark-exact', engine_version='exact-fixture-1',
            configuration_version='exact-config-1', registration='tests/fixtures/reasoner_benchmark/exact_result_adapter.metta')
        return variant

    # Example: rescoring immutable artifacts must not change output, runtime or provider observations.
    def check_scoring_is_read_only(self, result, directory):
        paths = list((directory / 'output').glob('*'))
        before = {path: path.read_bytes() for path in paths}
        measured = runner.metrics.measure(result, directory)
        self.assertEqual(measured, result['measurements'])
        self.assertEqual(before, {path: path.read_bytes() for path in paths})
        self.check_ungraded_prediction_cases(json.loads((directory / 'output/reasoner-evidence.json').read_text()))
        evidence = json.loads((directory / 'output/reasoner-evidence.json').read_text())
        first = next(iter(runner.metrics.unique_proposals(evidence)[0].values()))
        changed = copy.deepcopy(first)
        changed[4][1][10] = ['ExpectedCandidateOutcome', 'respond']
        self.assertEqual(runner.metrics.compare_prediction(changed, None)['status'], 'ungraded')

    # Example: missing, uncertain, conflicting and custom-comparator evidence must not produce a grade.
    def check_ungraded_prediction_cases(self, evidence):
        proposals, _ = runner.metrics.unique_proposals(evidence)
        key, envelope = next((key, value) for key, value in proposals.items()
                             if runner.metrics.matching_receipt(value, evidence['receipts']))
        self.assertEqual(runner.metrics.compare_prediction(envelope, None)['status'], 'ungraded')
        self.assertEqual(runner.metrics.score_proposal(key, envelope, {key}, evidence)['status'], 'ungraded')
        receipt = copy.deepcopy(runner.metrics.matching_receipt(envelope, evidence['receipts']))
        receipt[3][3] = 'Uncertain'
        self.assertEqual(runner.metrics.compare_prediction(envelope, receipt)['status'], 'ungraded')
        invocation = runner.metrics.fields(runner.metrics.fields(envelope)['invocation'])
        route = ['HostReasonerComparator', ['adapter', invocation['adapter']],
                 ['configuration-version', invocation['configuration-version']], ['schema', 'ExpectedOperationResult'],
                 ['version', 'custom-1'], ['function', 'customComparator']]
        self.assertFalse(runner.metrics.comparator_supported(envelope, [route]))

    def test_uncalibrated_positive_influence_fails_and_next_variant_runs(self):
        variants = runner.matrix.builtin_variants(self.scenario)
        advisory = copy.deepcopy(variants[3])
        advisory['configuration']['influence_cap'] = 0.05
        runs = runner.run_matrix(self.scenario, [advisory, variants[0]], output=self.root)
        self.assertEqual([result['status'] for result, _ in runs], ['failed', 'completed'])
        result, directory = runs[0]
        self.assertIn('predictive evidence', result['error'])
        groups = json.loads((self.root / 'summary.json').read_text())['groups']
        failed = next(group for group in groups if group['mode'] == 'advisory')
        self.assertEqual(failed['run_statuses'], {'failed': 1})
        self.assertIsNone(failed['task_outcomes']['positive_percent'])
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
        (self.root / 'output/trajectory.jsonl').write_text(
            json.dumps({'cycle_ref': '(TraceCycleRef interrupted-session 1)'}) + '\n{partial')
        result = dict(schema_version=1, run_id='interrupted-run', scenario=self.scenario,
            status='timed_out', error='deadline expired', elapsed_ms=1,
            trace_references=[], measurements={})
        runner._retain_runtime_report(result, self.root)
        self.assertEqual(result['status'], 'timed_out')
        self.assertEqual(result['error'], 'deadline expired')
        self.assertIn('source_report_error', result['runtime_configuration'])
        self.assertEqual(len(result['trace_references']), 1)
        formats.validate_result(result)

    def test_unsupported_scenario_and_invalid_matrix_are_not_silently_ignored(self):
        self.scenario['initial_state']['memory'] = 'carry-unconfigured-memory'
        result, _ = runner.run_matrix(self.scenario, [runner.matrix.builtin_variants(self.scenario)[0]], output=self.root)[0]
        self.assertEqual(result['status'], 'unavailable')
        with self.assertRaises(ValueError):
            runner.run_matrix(self.scenario, [{'adapter': {}}], output=self.root)

    def test_controlled_initial_state_inputs_world_observations_and_seed(self):
        self.scenario['configuration']['seed'] = 37
        self.scenario['initial_state'].update(
            host=dict(root_mode='Slow', frame_mode='Slow', status='Active', priority=0.7, posture='Rumination'),
            motivation=dict(goals={'help_user': 0.25}, modulators={'caution': 0.2}, self={'energy': 0.6}),
            budgets={'global': 4, 'frame': 4}, operations=['read-file'], file_content='initial world',
            inputs=['Inspect the file', None, 'follow-up: inspect it again', 'follow-up: proceed'],
            observations=[{'cycle': 1, 'file_content': 'first observation', 'semantics': {'danger': 0.1}},
                          {'cycle': 3, 'file_content': 'later observation', 'confirmation': 0.1},
                          {'cycle': 4, 'confirmation': 0.9}])
        variants = runner.matrix.builtin_variants(self.scenario)[:2]
        runs = runner.run_matrix(self.scenario, variants, output=self.root)
        initials = []
        for result, directory in runs:
            self.assertEqual(result['status'], 'completed', (directory / 'stderr.log').read_text())
            initial = json.loads((directory / 'output/initial-state.json').read_text())
            initials.append(initial)
            self.assertEqual(initial['seed']['requested'], 37)
            self.assertEqual(initial['seed']['applied_to'], ['python', 'prolog'])
            self.assertEqual(initial['seed']['python_hash'], '37')
            self.assertEqual(initial['motivation'][1][2], 0.25)
            self.assertEqual(initial['motivation'][2][1], 0.2)
            self.assertIn(['self-metric', 'energy', 0.6], initial['self_model'])
            self.assertEqual((initial['frame_mode'], initial['priority'], initial['posture']), ('Slow', 0.7, 'Rumination'))
            accounts = initial['host_snapshot'][4][1]
            self.assertEqual([account[2] for account in accounts], [4, 4])
            trajectory = [json.loads(line) for line in (directory / 'output/trajectory.jsonl').read_text().splitlines()]
            self.assertEqual(len(trajectory), 4)
            self.assertEqual([ref['cycle_ref'] for ref in result['trace_references']],
                             [row['cycle_ref'] for row in trajectory])
            self.assertIn('first observation', trajectory[0]['dispatch_result'])
            self.assertIn('later observation', trajectory[2]['dispatch_result'])
            self.assertIn('FollowUp', trajectory[2]['admission'])
            self.assertIn('danger', trajectory[0]['factual_signals'])
            self.assertIn('execution-request', trajectory[3]['factual_signals'])
            self.assertIn('SessionObservationRef', trajectory[0]['factual_signals'])
            self.assertTrue(result['runtime_configuration']['observed_source_versions']['v1'])
        for key in ('motivation', 'self_model', 'seed', 'task'):
            self.assertEqual(initials[0][key], initials[1][key])

    def test_exhausted_budget_does_not_reuse_a_previous_callback(self):
        self.scenario['initial_state'].update(budgets={'global': 1, 'frame': 1}, operations=['read-file'])
        result, directory = runner.run_matrix(self.scenario,
            [runner.matrix.builtin_variants(self.scenario)[0]], output=self.root)[0]
        self.assertEqual(result['status'], 'completed', (directory / 'stderr.log').read_text())
        rows = [json.loads(line) for line in (directory / 'output/trajectory.jsonl').read_text().splitlines()]
        self.assertIn('Executed Feasible', rows[0]['dispatch_result'])
        self.assertIn('BudgetExhausted', rows[1]['cycle_trace'])
        self.assertNotEqual(rows[1]['outcome'], rows[0]['outcome'])
        self.assertIn('DispatchUnavailable MissingDecision', rows[1]['outcome'])
        self.assertNotIn('observed local file content', rows[1]['outcome'])
        self.assertNotEqual(rows[0]['dispatch_result'], rows[1]['dispatch_result'])

    def test_separate_operation_paths_retain_their_own_outcomes(self):
        variants = [runner.matrix.builtin_variants(self.scenario)[0]]
        first, directory_a = runner.run_matrix(self.scenario, variants, output=self.root)[0]
        self.scenario['initial_state']['operations'] = ['show-current-frame']
        second, directory_b = runner.run_matrix(self.scenario, variants, output=self.root)[0]
        self.assertEqual((first['status'], second['status']), ('completed', 'completed'))
        a = [json.loads(row) for row in (directory_a / 'output/trajectory.jsonl').read_text().splitlines()]
        b = [json.loads(row) for row in (directory_b / 'output/trajectory.jsonl').read_text().splitlines()]
        self.assertNotEqual(a[0]['selection'], b[0]['selection'])
        self.assertNotEqual(a[0]['dispatch_result'], b[0]['dispatch_result'])
        self.assertEqual(second['runtime_configuration']['dispatch_result'], b[0]['dispatch_result'])
        self.assertNotIn('observed local file content', b[0]['dispatch_result'])


if __name__ == '__main__':
    unittest.main()
