"""Post-run scoring of retained evidence; never invokes a reasoner or updates learning."""
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path

from reasoner_benchmark_formats import episode_policy
from reasoner_benchmark_policy import check_policy, fields
from reasoner_benchmark_export import read_trajectory, evidence_status, discover_runs, run_index, write_archive

SCORER_VERSION = 'retained-evidence-v1'


# Example: a phase is assigned by declared episode bounds, never by observed success.
def split_for_cycle(scenario, cycle):
    policy = episode_policy(scenario)
    for count, role in zip(policy['cycles'], policy.get('roles', ['evaluation'] * len(policy['cycles']))):
        cycle -= count
        if cycle <= 0:
            return role
    raise ValueError('cycle exceeds episode bounds')


# Example: missing or uncertain callbacks leave a task check ungraded, not automatically failed.
def check_task(row, check):
    base = dict(cycle=check['cycle'], oracle=check['oracle'])
    if not row or not row.get('observation') or not row.get('world_before'):
        return dict(base, status='ungraded', reason='MissingIndependentEvidence')
    _, decision, result, outcome, _, _ = row['observation']
    if not outcome or outcome[1] != decision or outcome[4] != result:
        return dict(base, status='ungraded', reason='UncorrelatedCallback')
    if result[1] not in ('Executed', 'Blocked'):
        return dict(base, status='ungraded', reason='UncertainExecution')
    passed = verified_read(decision, result, outcome, row['world_before'])
    return dict(base, status='passed' if passed else 'failed', reason='IndependentFileRead',
                cycle_ref=row['cycle_ref'], ticket=decision[4])


# Example: a model's success claim cannot replace the exact handler result and independently read file.
def verified_read(decision, result, outcome, world):
    return (world['exists'] and decision[3] == ['read-file', world['path']]
            and outcome[2] == ['attempted-command', decision[3]] and outcome[3] == 'Success'
            and result == ['DispatchResult', 'Executed', 'Feasible', world['content']])


# Example: conflicting repeated identities remain ungraded rather than inflating coverage.
def unique_proposals(evidence):
    proposals = {}
    conflicts = set()
    for batch in evidence.get('admissions', []):
        for admission in batch[3]:
            envelope = admission[1]
            key = (batch[2], fields(envelope)['proposal'][1])
            if key in proposals and proposals[key] != envelope:
                conflicts.add(key)
            proposals[key] = envelope
    return proposals, conflicts


# Example: only the exact retained primary receives an observed-outcome comparison.
def matching_receipt(envelope, receipts):
    matches = [row for row in receipts if row[2][4] and row[2][4][1] == envelope]
    return matches[0] if len(matches) == 1 else None


# Example: supported exact-result comparisons use the immutable executed callback payload.
def compare_prediction(envelope, receipt):
    prediction = fields(envelope)['proposal'][10]
    if not isinstance(prediction, list) or len(prediction) != 2 or prediction[0] != 'ExpectedOperationResult':
        return dict(status='ungraded', reason='UnsupportedPrediction')
    registration = fields(fields(envelope)['registration'])
    if 'ExpectedOperationResult' not in fields(registration['capabilities'])['prediction-schemas']:
        return dict(status='ungraded', reason='UndeclaredPrediction')
    if not receipt:
        return dict(status='ungraded', reason='NoObservedAlternative')
    outcome = receipt[3]
    if outcome[3] not in ('Success', 'Failure') or outcome[4][1:3] != ['Executed', 'Feasible']:
        return dict(status='ungraded', reason='UncertainExecution')
    correct = prediction[1] == outcome[4][3]
    confidence = fields(envelope)['proposal'][8]
    return dict(status='confirmed' if correct else 'refuted', grade=int(correct), squared_error=(confidence - int(correct)) ** 2,
                reason='exact-operation-result-1', outcome_ref=receipt[1])


# Example: a custom configured comparator is not silently replaced by a benchmark comparator.
def comparator_supported(envelope, routes):
    invocation = fields(fields(envelope)['invocation'])
    matches = [fields(route) for route in routes if fields(route)['adapter'] == invocation['adapter']
               and fields(route)['configuration-version'] == invocation['configuration-version']
               and fields(route)['schema'] == 'ExpectedOperationResult']
    return not matches or (len(matches) == 1 and matches[0]['function'] == 'compareReasonerOperationResult'
                           and matches[0]['version'] == 'exact-operation-result-1')


# Example: identity conflicts and unsupported routing are distinct ungraded cases.
def score_proposal(key, envelope, conflicts, evidence):
    if key in conflicts:
        return dict(status='ungraded', reason='ConflictingProposalIdentity')
    if not comparator_supported(envelope, evidence.get('comparator_routes', [])):
        return dict(status='ungraded', reason='UnsupportedComparator')
    return compare_prediction(envelope, matching_receipt(envelope, evidence.get('receipts', [])))


# Example: a rejected alternative remains visible in ungraded coverage.
def score_predictions(evidence, scenario):
    proposals, conflicts = unique_proposals(evidence)
    scores = []
    for key, envelope in proposals.items():
        invocation = fields(fields(envelope)['invocation'])
        comparison = score_proposal(key, envelope, conflicts, evidence)
        scores.append(dict(comparison, invocation=key[0], proposal=key[1],
                           split=split_for_cycle(scenario, invocation['cycle'])))
    return scores


# Example: empty denominators are unavailable percentages, not perfect or zero accuracy.
def percent(numerator, denominator):
    return 100 * numerator / denominator if denominator else None


# Example: coverage and quality have different denominators, both retained explicitly.
def outcome_counts(rows, positive, negative):
    counts = Counter(row['status'] for row in rows)
    verified = counts[positive] + counts[negative]
    return dict(total=len(rows), verified=verified, positive=counts[positive], negative=counts[negative],
                status_counts={name: counts[name] for name in (positive, negative, 'ungraded')},
                denominators=dict(coverage_percent=len(rows), positive_percent=verified, negative_percent=verified, ungraded_percent=len(rows)),
                ungraded=counts['ungraded'], coverage_percent=percent(verified, len(rows)),
                positive_percent=percent(counts[positive], verified), negative_percent=percent(counts[negative], verified),
                ungraded_percent=percent(counts['ungraded'], len(rows)),
                ungraded_reasons=dict(Counter(row.get('reason', 'Unavailable') for row in rows if row['status'] == 'ungraded')))


# Example: confidence error is measured only where a binary outcome was actually verified.
def prediction_summary(rows):
    result = outcome_counts(rows, 'confirmed', 'refuted')
    errors = [row['squared_error'] for row in rows if 'squared_error' in row]
    result['mean_squared_error'] = sum(errors) / len(errors) if errors else None
    grades = [row['grade'] for row in rows if 'grade' in row]
    result.update(mean_grade=sum(grades) / len(grades) if grades else None,
                  grade_distribution=dict(Counter(str(grade) for grade in grades)))
    result['denominators'].update(mean_grade=len(grades), mean_squared_error=len(errors))
    return result


# Example: nearest-rank percentiles are computed over observed cycle wall times only.
def latency_summary(values):
    values = sorted(values)
    if not values:
        return dict(count=0, mean_ms=None, p50_ms=None, p95_ms=None)
    return dict(count=len(values), mean_ms=sum(values) / len(values),
                p50_ms=values[math.ceil(len(values) * 0.5) - 1],
                p95_ms=values[math.ceil(len(values) * 0.95) - 1])


# Example: cumulative counters are differenced once before grouping calibration/evaluation.
def resource_deltas(rows):
    previous = {}
    deltas = []
    for row in rows:
        observation = row.get('observation')
        if not observation:
            continue
        _, steps, calls, reservations = observation[5]
        current = dict(engine_steps_reserved=steps, reasoner_provider_calls_reserved=calls,
                       engine_reservations=reservations, offline_classifier_calls=sum(row['offline_classifier_calls'].values()))
        deltas.append(dict(split=row['split'], **counter_delta(current, previous)))
        previous = current
    return deltas


# Example: a counter reset is unavailable telemetry, never negative usage or a fabricated zero.
def counter_delta(current, previous):
    values = {key: value - previous.get(key, 0) for key, value in current.items()}
    return dict(status='unavailable', reason='CounterReset') if any(value < 0 for value in values.values()) else dict(values, status='observed')


# Example: resource totals describe observed reservations, while unavailable tokens/costs stay explicit.
def resource_summary(rows):
    names = ('engine_steps_reserved', 'reasoner_provider_calls_reserved', 'engine_reservations', 'offline_classifier_calls')
    valid = [row for row in rows if row['status'] == 'observed']
    return dict(observed_cycles=len(valid), unavailable_cycles=len(rows) - len(valid),
                **{name: sum(row[name] for row in valid) if valid else None for name in names},
                engine_instructions=None, provider_tokens=None, provider_cost=None)


# Example: scoring can finish even when no reasoner receipt artifact was produced.
def read_evidence(directory):
    path = directory / 'output/reasoner-evidence.json'
    try:
        return json.loads(path.read_text()) if path.is_file() else {}
    except ValueError:
        return {}


# Example: separate role totals prevent calibration observations from becoming evaluation scores.
def score_split(role, rows, tasks, predictions, resources):
    selected = [row for row in rows if row['split'] == role]
    task_rows = [row for row in tasks if row['split'] == role]
    prediction_rows = [row for row in predictions if row['split'] == role]
    policies = [dict(check_policy(row), cycle=row['cycle'], cycle_ref=row['cycle_ref']) for row in selected]
    latencies = [row['latency_ms'] for row in selected if row.get('latency_ms') is not None]
    return dict(tasks=task_rows, predictions=prediction_rows, policies=policies, latencies_ms=latencies,
                task_outcomes=outcome_counts(task_rows, 'passed', 'failed'),
                prediction_quality=prediction_summary(prediction_rows),
                policy_compliance=outcome_counts(policies, 'passed', 'failed'), latency=latency_summary(latencies),
                resources=resource_summary([row for row in resources if row['split'] == role]))


# Example: changing the independent policy auditor also changes the recorded scoring version hash.
def scorer_fingerprint():
    root = Path(__file__).parent
    names = ('reasoner_benchmark_metrics.py', 'reasoner_benchmark_policy.py', 'reasoner_benchmark_formats.py', 'reasoner_benchmark_export.py')
    return hashlib.sha256(b''.join((root / name).read_bytes() for name in names)).hexdigest()


# Example: scoring reads run-owned artifacts after the child exits; no feedback API is called.
def measure(result, directory):
    rows = read_trajectory(directory)
    by_cycle = {row['cycle']: row for row in rows}
    scenario = result['scenario']
    tasks = [dict(check_task(by_cycle.get(check['cycle']), check), split=split_for_cycle(scenario, check['cycle']))
             for check in scenario.get('evaluation', {}).get('checks', [])]
    predictions = score_predictions(read_evidence(directory), scenario)
    resources = resource_deltas(rows)
    roles = set(episode_policy(scenario).get('roles', ['evaluation']))
    return dict(version=SCORER_VERSION, scorer_sha256=scorer_fingerprint(),
                run_elapsed_ms=result['elapsed_ms'], evidence=evidence_status(result, directory), by_split={role: score_split(role, rows, tasks, predictions, resources)
                                                            for role in sorted(roles)})


# Example: run-specific entry paths do not hide a changed imported implementation.
def source_fingerprint(result):
    sources = result.get('runtime_configuration', {}).get('source_sha256', {})
    hashes = sorted(value for path, value in sources.items() if result['run_id'] not in path)
    return hashlib.sha256(json.dumps(hashes).encode()).hexdigest() if hashes else None


# Example: grouping retains scenario/adapter/configuration identity while aggregating repeated seeds.
def group_identity(result, role):
    scenario = result['scenario']
    config = {key: value for key, value in scenario['configuration'].items() if key != 'seed'}
    identity = dict(scenario={key: value for key, value in scenario.items() if key not in ('configuration',)},
                    configuration=config, split=role, sources=result.get('runtime_configuration', {}).get('observed_source_versions'),
                    source_fingerprint=source_fingerprint(result), scorer=result.get('measurements', {}).get('scorer_sha256'))
    return json.dumps(identity, sort_keys=True)


# Example: each resource reports how many runs actually measured it, including partial failures.
def aggregate_resources(samples):
    names = ('engine_steps_reserved', 'reasoner_provider_calls_reserved', 'engine_reservations', 'offline_classifier_calls')
    return {name: dict(observed_total=sum(sample['resources'][name] or 0 for sample in samples)
                      if any(sample['resources'][name] is not None for sample in samples) else None,
                      measured_runs=sum(sample['resources'][name] is not None for sample in samples),
                      observed_cycles=sum(sample['resources']['observed_cycles'] for sample in samples),
                      unavailable_cycles=sum(sample['resources']['unavailable_cycles'] for sample in samples)) for name in names}


# Example: unavailable evidence remains visible even when no proposal could be counted.
def aggregate_evidence(entries):
    evidence = [result.get('measurements', {}).get('evidence', {}) for result, _ in entries]
    return dict(trajectory=dict(Counter(item.get('trajectory', {}).get('state', 'unavailable') for item in evidence)),
                reasoner=dict(Counter(item.get('reasoner', 'unavailable') for item in evidence)),
                export_window=dict(Counter('complete' if item.get('export_window_complete') else 'incomplete' for item in evidence)))


# Example: percentages are recomputed from raw counts, never averaged across runs.
def aggregate_group(entries):
    samples = [sample for _, sample in entries]
    result = entries[0][0]
    config = result['scenario']['configuration']
    mode = 'advisory' if config['influence'] else 'shadow' if config['collection'] else 'native'
    return dict(scenario_id=result['scenario']['scenario_id'], adapter=result['scenario']['adapter'], mode=mode,
                configuration={key: value for key, value in config.items() if key != 'seed'}, runs=len(entries),
                source_fingerprint=source_fingerprint(result), scorer_sha256=result['measurements']['scorer_sha256'],
                source_versions=result.get('runtime_configuration', {}).get('observed_source_versions'),
                run_ids=[row['run_id'] for row, _ in entries], seeds=[row['scenario']['configuration']['seed'] for row, _ in entries],
                run_statuses=dict(Counter(row['status'] for row, _ in entries)), evidence_at_scoring=aggregate_evidence(entries),
                resources=aggregate_resources(samples),
                task_outcomes=outcome_counts([item for sample in samples for item in sample['tasks']], 'passed', 'failed'),
                prediction_quality=prediction_summary([item for sample in samples for item in sample['predictions']]),
                policy_compliance=outcome_counts([item for sample in samples for item in sample['policies']], 'passed', 'failed'),
                latency=latency_summary([value for sample in samples for value in sample['latencies_ms']]))


# Example: failed configurations remain counted in their own mode and calibration/evaluation group.
def aggregate(results):
    groups = defaultdict(list)
    for result in results:
        for role, sample in result.get('measurements', {}).get('by_split', {}).items():
            groups[group_identity(result, role)].append((result, sample))
    return [dict(aggregate_group(entries), split=json.loads(key)['split']) for key, entries in sorted(groups.items())]


# Report definitions apply to each group and per-run measurement; counts remain alongside rates.
DENOMINATORS = {
    'task_success': 'task_outcomes.positive / task_outcomes.verified; declared checks with conclusive independent evidence',
    'prediction_coverage': 'prediction_quality.verified / prediction_quality.total; unique retained invocation/proposal identities',
    'prediction_accuracy': 'prediction_quality.positive / prediction_quality.verified; observed confirmed/refuted predictions only',
    'ungraded_coverage': 'ungraded / total; missing, uncertain and unsupported cases remain ungraded',
    'mean_grade': 'sum of numerical grades / denominators.mean_grade',
    'mean_squared_error': 'sum of graded confidence errors / denominators.mean_squared_error',
    'empty_population': 'A zero denominator yields null. Missing artifacts leave population completeness unknown.'}


# Example: summary.json and its portable archive reference each run's original trace.
def write_report(results, output, directories=None):
    output = Path(output)
    directories = discover_runs(output)[1] if directories is None else directories
    report = dict(version=SCORER_VERSION, reporter_sha256=scorer_fingerprint(), groups=aggregate(results),
                  runs=run_index(results, directories), denominators=DENOMINATORS,
                  rejected_input_reports=[path.name for path in sorted(output.glob('input-errors-*.json'))],
                  note='Each run retains its own decisions and outcomes; missing rows are never backfilled. Prediction agreement is not selection causation.')
    (output / 'summary.json').write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')
    write_archive(output, directories)


# Example: CLI exports retain unreadable/missing results in the run index, outside numerical scoring.
def summarize_directory(output):
    results, directories = discover_runs(output)
    write_report(results, output, directories)
