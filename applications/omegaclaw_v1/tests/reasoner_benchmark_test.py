"""Benchmark format checks require no host, engine, provider or external service."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

APP = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('benchmark_formats', APP / 'tools/reasoner_benchmark_formats.py')
formats = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(formats)


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


if __name__ == '__main__':
    unittest.main()
