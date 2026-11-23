"""Matched configuration expansion and read-only observation of normal runtime APIs."""
import hashlib
import json
import os
from pathlib import Path
import re
import time

from reasoner_benchmark_formats import episode_policy

APP = Path(__file__).resolve().parents[1]


# Example: advisory with cap zero is labelled separately from pure shadow collection.
def mode(configuration):
    if configuration['influence']:
        return 'advisory'
    return 'shadow' if configuration['collection'] else 'disabled'


# Example: each engine is compared in shadow/advisory mode with learning independently off/on.
def builtin_variants(base):
    variants = [dict(adapter=dict(id='disabled', adapter_version=None, engine_version=None,
                                 configuration_version='native-1'),
                     configuration=dict(base['configuration'], collection=False, influence=False,
                                        assessment=False, learning=False, influence_cap=0))]
    version = hashlib.sha256((APP / 'reasoners/host_reasoner.metta').read_bytes()).hexdigest()
    for adapter in ('nars', 'pln'):
        for advisory in (False, True):
            for learning in (False, True):
                variants.append(dict(adapter=dict(id=adapter, adapter_version=version,
                    engine_version='local-libraries', configuration_version='builtin-1'),
                    configuration=dict(base['configuration'], collection=True, influence=advisory,
                        learning=learning, influence_cap=0)))
    return variants


# Example: capture native capability declarations rather than a hard-coded engine feature table.
def record_initial(motivation, self_model, task, frame_mode, host, status, priority, posture, root_mode):
    scenario = _scenario()
    path = Path(os.environ['OMEGACLAW_BENCHMARK_OUTPUT']) / 'initial-state.json'
    path.write_text(json.dumps(dict(motivation=motivation, self_model=self_model,
        task=task, frame_mode=frame_mode, host_snapshot=host, status=status,
        priority=priority, posture=posture, root_mode=root_mode,
        seed=dict(requested=scenario['configuration']['seed'],
                  applied_to=['python', 'prolog'] if scenario['configuration']['seed'] is not None else [],
                  python_hash=os.environ.get('PYTHONHASHSEED', 'unspecified'),
                  engine='no independent seed API exposed by current adapters')), indent=2))
    return 1


# Example: cycle three starts episode two when the declared lengths are [2, 2].
def episode_position(cycle, scenario):
    remaining = cycle
    for number, count in enumerate(episode_policy(scenario)['cycles'], 1):
        if remaining <= count:
            roles = episode_policy(scenario).get('roles', ['evaluation'] * len(episode_policy(scenario)['cycles']))
            return dict(episode=number, episode_cycle=remaining, split=roles[number - 1])
        remaining -= count
    raise ValueError('cycle exceeds declared episodes')


# Example: each child reports its actual process and private resource locations.
def isolation_record(scenario):
    return dict(comparison='fresh-process', pid=os.getpid(),
        run_id=os.environ['OMEGACLAW_BENCHMARK_RUN_ID'],
        memory=os.environ['OMEGACLAW_BENCHMARK_MEMORY'],
        runtime=os.getcwd(), episodes=episode_policy(scenario),
        boundary='continuous-session' if len(episode_policy(scenario)['cycles']) > 1 else 'single-episode')


_cycle_start = None


# Example: start timing and capture the world before normal selection and dispatch.
def begin_cycle(host, reliability):
    global _cycle_start
    import benchmark_world
    _cycle_start = dict(started=time.perf_counter(), host=host, world=benchmark_world.inspect_file(), reliability=reliability)
    return 1


# Example: latency includes normal cycle/dispatch, while oracle inputs precede execution.
def cycle_measurements(observation, reliability):
    import lib_llm_ext
    initial = _cycle_start or {}
    calls = {kind: lib_llm_ext.call_count(kind) for kind in ('confirmation', 'semantics')}
    return dict(observation=observation, reliability_before=initial.get('reliability'), reliability_after=reliability,
                offline_classifier_calls=calls, host_before=initial.get('host'),
                world_before=initial.get('world'),
                latency_ms=(time.perf_counter() - initial['started']) * 1000 if initial else None)


# Example: each cycle retains its own selected operation and observed result, never another run's.
def record_cycle(cycle, selection, result, outcome, feedback, signals, trace, cycle_ref, motivation, admission, observation, reliability):
    scenario = _scenario()
    inputs = scenario['initial_state']['inputs']
    message = inputs[cycle - 1] if cycle <= len(inputs) else None
    event = dict(cycle=cycle, input=message, admission=admission if message is not None else None,
        exogenous=[row for row in scenario['initial_state']['observations'] if row['cycle'] == cycle],
        selection=selection, dispatch_result=result, outcome=outcome, feedback=feedback,
        factual_signals=signals, cycle_trace=trace, cycle_ref=cycle_ref, motivation=motivation)
    event.update(episode_position(cycle, scenario))
    event.update(cycle_measurements(observation, reliability))
    path = Path(os.environ['OMEGACLAW_BENCHMARK_OUTPUT']) / 'trajectory.jsonl'
    with path.open('a') as stream:
        stream.write(json.dumps(event) + '\n')
    return 1


# Example: fixed inputs are loaded from this subprocess's private scenario copy only.
def _scenario():
    return json.loads(Path(os.environ['OMEGACLAW_BENCHMARK_SCENARIO']).read_text())


# Example: partial configuration reports survive a later rejected influence request.
def record_configuration(selection, registration, runtime, controls, influence):
    scenario = _scenario()
    fields = dict(registration[1:]) if registration else {}
    capabilities = dict(fields['capabilities'][1:]) if fields else {
        'proposal-kinds': [], 'candidates': [], 'prediction-schemas': [], 'feedback': []}
    effective = {name: value in (True, 'True', 'true') for name, value in controls[1:]} if controls else {
        'collection': False, 'influence': False, 'assessment': False, 'learning': False}
    report = dict(complete=False, isolation=isolation_record(scenario),
        selection=selection, mode=mode(scenario['configuration']),
        requested=scenario['configuration'], effective_controls=effective, capabilities=capabilities,
        contract_version=fields.get('contract-version'), configuration_version=fields.get('configuration-version'),
        engine_version=runtime[1] if runtime else None, intake_limits=fields.get('limits'), influence_setting=influence,
        assessment_feedback_supported='Assessment' in capabilities['feedback'])
    _report_path().write_text(json.dumps(report, indent=2))
    return 1


# Example: clean interpreter exit without this final observation is not a completed matrix run.
def finish(cycles, admissions, influence):
    path = _report_path()
    report = json.loads(path.read_text())
    trajectory = path.with_name('trajectory.jsonl')
    with trajectory.open() as stream:
        first = json.loads(next(stream))
        steps = 1 + sum(1 for _ in stream)
    report.update(complete=True, selected_operation=first['selection'], dispatch_result=first['dispatch_result'],
                  trajectory='output/trajectory.jsonl', executed_cycles=steps,
                  intake_cycles=len(cycles), retained_proposals=sum(len(row[3]) for row in admissions),
                  intake_statuses=[dict(row[3][1:])['status'] for row in cycles],
                  observed_outcomes=sum(bool(row[6]) for row in cycles),
                  influence_setting=influence)
    path.write_text(json.dumps(report, indent=2))
    return 1


# Example: scoring reads retained proposal/receipt identities after execution, without invoking engines.
def write_evidence(cycles, admissions, receipts, selections, routes):
    output = Path(os.environ['OMEGACLAW_BENCHMARK_OUTPUT'])
    evidence = dict(cycles=cycles, admissions=admissions, receipts=receipts, selections=selections, comparator_routes=routes)
    (output / 'reasoner-evidence.json').write_text(json.dumps(evidence, indent=2))
    return 1


# Example: every subprocess writes only within its allocated output directory.
def _report_path():
    return Path(os.environ['OMEGACLAW_BENCHMARK_OUTPUT']) / 'runtime-configuration.json'


# Example: serialize validated scenario values as data consumed by the MeTTa driver.
def run_configuration():
    scenario = _scenario()
    initial, controls, adapter = (scenario[key] for key in ('initial_state', 'configuration', 'adapter'))
    host = initial.get('host', {})
    host_values = [str(host[key]) if key in host else '()'
                   for key in ('root_mode', 'frame_mode', 'status', 'priority', 'posture')]
    flags = ' '.join(f'({key} {"True" if controls[key] else "False"})'
                     for key in ('collection', 'influence', 'assessment', 'learning'))
    values = [initial['reset'], json.dumps(initial['inputs'][0]), json.dumps(initial['policy']),
              str(controls['seed']) if controls['seed'] is not None else '()',
              str(scenario['resource_limits']['max_cycles']), json.dumps(adapter['id']),
              '(HostReasonerControls ' + flags + ')', str(controls['influence_cap']),
              '(BenchmarkHost ' + ' '.join(host_values) + ')']
    return '(BenchmarkScenario ' + ' '.join(values) + ')'


# Example: the native constructor and validators still interpret inference limit data.
def intake_limits():
    return _scenario()['resource_limits']['intake_limits']


# Example: unsupported carried memory is rejected before generating an entry.
def _validate_initial_state(initial):
    has_task = bool(initial['inputs']) and isinstance(initial['inputs'][0], str)
    motivation = initial['motivation']
    supported_motivation = not isinstance(motivation, str) or motivation == 'registry-defaults'
    if not (has_task and initial['memory'] == 'fresh' and supported_motivation):
        raise ValueError('The read fixture needs an initial task, fresh memory and '
                         'registry defaults or explicit motivational overrides')


# Example: classifier scores require a message in the same scheduled cycle.
def _validate_observation(event, inputs, maximum):
    if not isinstance(event, dict) or event['cycle'] > maximum:
        raise ValueError('Observations must be scheduled objects within max_cycles')
    if 'semantics' not in event and 'confirmation' not in event:
        return
    if event['cycle'] > len(inputs) or inputs[event['cycle'] - 1] is None:
        raise ValueError('Classifier observations require a user input at that cycle')


# Example: duplicate external changes must be combined into one event per cycle.
def _validate_schedule(initial, maximum):
    if len(initial['inputs']) > maximum:
        raise ValueError('Input schedule exceeds max_cycles')
    for event in initial['observations']:
        _validate_observation(event, initial['inputs'], maximum)
    cycles = [event['cycle'] for event in initial['observations']]
    if len(set(cycles)) != len(cycles):
        raise ValueError('Combine exogenous changes into one observation per cycle')
    if maximum < 2:
        raise ValueError('The read scenario needs two cycles: selection/dispatch, then feedback application')


# Example: missing fixture or registration files retain their specific failure message.
def _required_file(relative_path, label):
    path = (APP / relative_path).resolve()
    if not path.is_file():
        raise ValueError(label + ' is unavailable: ' + str(path))
    return path


# Example: a fixture reset names a trusted function rather than executable source text.
def _fixture(initial):
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]*', initial['reset']):
        raise ValueError('reset must name a trusted fixture function')
    return _required_file(initial['fixture'], 'Scenario fixture')


# Example: native APIs load before the driver; custom registrations load after it.
def _entry_imports(fixture, adapter):
    lines = ['!(import! &self (library lib_import))', f'!(import! &self {json.dumps(str(fixture))})']
    enabled = adapter['id'] != 'disabled'
    if enabled:
        lines.extend([
            '!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner))',
            '!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_influence))',
            '!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/reasoner_proposals))'])
    driver = APP / 'tools/reasoner_benchmark_driver.metta'
    lines.append(f'!(import! &self {json.dumps(str(driver))})')
    if enabled and 'registration' in adapter:
        registration = _required_file(adapter['registration'], 'Adapter registration')
        lines.append(f'!(import! &self {json.dumps(str(registration))})')
    return lines


# Example: write_entry(scenario, run_dir) writes imports and one driver invocation.
def write_entry(scenario, directory):
    initial = scenario['initial_state']
    _validate_initial_state(initial)
    _validate_schedule(initial, scenario['resource_limits']['max_cycles'])
    lines = _entry_imports(_fixture(initial), scenario['adapter'])
    entry = directory / 'comparison.metta'
    entry.write_text('\n'.join(lines + ['!(benchmarkRun)']) + '\n')
    return entry
