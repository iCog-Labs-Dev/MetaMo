"""Matched configuration expansion and read-only observation of normal runtime APIs."""
import hashlib
import json
import os
from pathlib import Path
import re

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
def record_initial(motivation, self_model, task, frame_mode):
    path = Path(os.environ['OMEGACLAW_BENCHMARK_OUTPUT']) / 'initial-state.json'
    path.write_text(json.dumps(dict(motivation=motivation, self_model=self_model,
                                   task=task, frame_mode=frame_mode), indent=2))
    return 1


# Example: partial configuration reports survive a later rejected influence request.
def record_configuration(selection, registration, runtime, controls, influence):
    scenario = json.loads(Path(os.environ['OMEGACLAW_BENCHMARK_SCENARIO']).read_text())
    fields = dict(registration[1:]) if registration else {}
    capabilities = dict(fields['capabilities'][1:]) if fields else {
        'proposal-kinds': [], 'candidates': [], 'prediction-schemas': [], 'feedback': []}
    effective = {name: value in (True, 'True', 'true') for name, value in controls[1:]} if controls else {
        'collection': False, 'influence': False, 'assessment': False, 'learning': False}
    report = dict(complete=False, selection=selection, mode=mode(scenario['configuration']),
        requested=scenario['configuration'], effective_controls=effective, capabilities=capabilities,
        contract_version=fields.get('contract-version'), configuration_version=fields.get('configuration-version'),
        engine_version=runtime[1] if runtime else None, influence_setting=influence,
        assessment_feedback_supported='Assessment' in capabilities['feedback'])
    _report_path().write_text(json.dumps(report, indent=2))
    return 1


# Example: clean interpreter exit without this final observation is not a completed matrix run.
def finish(selection, result, cycles, admissions, influence):
    path = _report_path()
    report = json.loads(path.read_text())
    report.update(complete=True, selected_operation=selection, dispatch_result=result,
                  intake_cycles=len(cycles), retained_proposals=sum(len(row[3]) for row in admissions),
                  intake_statuses=[dict(row[3][1:])['status'] for row in cycles],
                  observed_outcomes=sum(bool(row[6]) for row in cycles),
                  influence_setting=influence)
    path.write_text(json.dumps(report, indent=2))
    return 1


# Example: every subprocess writes only within its allocated output directory.
def _report_path():
    return Path(os.environ['OMEGACLAW_BENCHMARK_OUTPUT']) / 'runtime-configuration.json'


# Example: normalize native configuration Booleans at the generated entry boundary.
def _require(expression):
    return '(1 (benchmarkRequire ' + expression + '))'


# Example: generate calls to existing fixture/runtime APIs, never a benchmark selector or dispatcher.
def write_entry(scenario, directory):
    initial, controls, adapter = (scenario[key] for key in ('initial_state', 'configuration', 'adapter'))
    if (len(initial['inputs']) != 1 or initial['observations'] or initial['memory'] != 'fresh'
            or initial['motivation'] != 'registry-defaults' or controls['seed'] is not None):
        raise ValueError('This driver supports one input, fresh memory, registry defaults and no exogenous observations/seed')
    if scenario['resource_limits']['max_cycles'] < 2:
        raise ValueError('The read scenario needs two cycles: selection/dispatch, then feedback application')
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]*', initial['reset']):
        raise ValueError('reset must name a trusted fixture function')
    fixture = (APP / initial['fixture']).resolve()
    if not fixture.is_file():
        raise ValueError('Scenario fixture is unavailable: ' + str(fixture))
    q = json.dumps
    enabled = adapter['id'] != 'disabled'
    lines = [f'!(import! &self (library lib_import))', f'!(import! &self {q(str(fixture))})',
             f'!(import! &self {q(str(Path(__file__).resolve()))})',
             f'(= (benchmarkIntakeLimits) (sread {q(scenario["resource_limits"]["intake_limits"])}))']
    if enabled:
        lines.append('!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner))')
        lines.append('!(import! &self (library MetaMo applications/omegaclaw_v1/reasoners/host_reasoner_influence))')
        if 'registration' in adapter:
            registration = (APP / adapter['registration']).resolve()
            if not registration.is_file():
                raise ValueError('Adapter registration is unavailable: ' + str(registration))
            lines.append(f'!(import! &self {q(str(registration))})')
    lines.append(_episode(scenario, enabled))
    entry = directory / 'comparison.metta'
    entry.write_text('\n'.join(lines) + '\n')
    return entry


# Example: failed native setup/configuration stops the episode and leaves a partial audit.
def _episode(scenario, enabled):
    initial, controls, adapter = (scenario[key] for key in ('initial_state', 'configuration', 'adapter'))
    q = json.dumps
    identity = q(adapter['id'])
    setup = ''
    if enabled:
        if adapter['id'] in ('nars', 'pln'):
            setup = _require(f'''(let* (
                ((ReasonerAdapterRegistration $regAdapter $regVersion $regConfig $regSource $regCaps $regOldLimits)
                    (builtinHostReasoner {adapter['id']}))
                ($nativeLimits (benchmarkIntakeLimits)))
                (registerHostReasoner
                    (quote (ReasonerAdapterRegistration $regAdapter $regVersion $regConfig $regSource $regCaps (limits $nativeLimits)))
                    (quote loadHostReasonerInference)))''')
        setup += '\n' + '\n'.join(_require(expression) for expression in (
            f'(selectHostReasoner {identity})', f'(benchmarkConfigureAdapter {identity})',
            f'(== (mrcValue (index-atom (registeredHostReasoner {identity}) 1) 6) (benchmarkIntakeLimits))'))
    control_record = '(HostReasonerControls ' + ' '.join(
        f'({key} {"True" if controls[key] else "False"})' for key in ('collection', 'influence', 'assessment', 'learning')) + ')'
    configure = ''
    if enabled and controls['influence']:
        configure += _require(f'(configureHostReasonerInfluence {identity} {controls["influence_cap"]} ())') + '\n'
    if enabled:
        configure += _require(f'(configureHostReasonerControls {identity} {control_record})')
    registration = f'(index-atom (registeredHostReasoner {identity}) 1)' if enabled else '()'
    runtime = f'(hostReasonerRuntimeBinding {identity})' if enabled else '()'
    effective = f'(hostReasonerControlsFor {identity})' if enabled else '()'
    setting = f'(hostReasonerInfluenceSettingFor {identity})' if enabled else '()'
    report = f'''(let* (($r {registration}) ($rt {runtime}) ($c {effective}) ($i {setting}))
        (py-call (reasoner_benchmark_matrix.record_configuration {identity} (quote $r) (quote $rt) (quote $c) (quote $i))))'''
    return f'''(= (benchmarkRequire $value)
        (if (== $value True) 1 (progn (println! (repr $value)) 0)))
    (= (benchmarkReport) {report})
    !(let* (
        (1 ({initial['reset']} {q(initial['inputs'][0])} {q(initial['policy'])}))
        ($_ (let* (($m (motivosToMetamoState)) ($s (getSelfModel)))
            (py-call (reasoner_benchmark_matrix.record_initial (quote $m) (quote $s)
                (get-state &active-task) (frameBundleCurrentMode (frameStateForMetaMo))))))
        {setup}
        (1 (benchmarkReport))
        {configure}
        (1 (benchmarkReport))
        (1 (boundaryCycle benchmark))
        ($selection (repr (get-state &selected-operation-decision)))
        ($result (repr (fullLoopDispatch benchmark (coreLoopDispatchBegin) (selectedHostCommand))))
        ($_ (change-state! &new-msg-flag False))
        (1 (boundaryCycle benchmark-feedback))
        ($cycles {"(hostReasonerCycles)" if enabled else "()"})
        ($admissions {"(hostReasonerAdmissions)" if enabled else "()"})
        ($influence {setting})
    ) (progn
        (py-call (reasoner_benchmark_matrix.finish $selection $result (quote $cycles) (quote $admissions) (quote $influence)))
        (py-call (host_config_fixture.cleanup))))'''
