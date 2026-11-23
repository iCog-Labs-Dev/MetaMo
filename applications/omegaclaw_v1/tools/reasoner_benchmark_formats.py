"""Version-one benchmark JSON records. Validation never starts the runtime."""
import json
import re


# Example: reject a misspelled control instead of silently running a different comparison.
def _fields(value, names, optional=()):
    required = set(names.split())
    if not isinstance(value, dict) or not required <= value.keys() or value.keys() - required - set(optional):
        raise ValueError('expected fields: ' + names)


# Example: engine versions and native trace identities must be explicit nonempty text.
def _text(value):
    if not isinstance(value, str) or not value.strip():
        raise ValueError('expected nonempty text')


# Example: True is a control flag, not an integer resource allowance.
def _count(value, minimum=0):
    if type(value) is not int or value < minimum:
        raise ValueError('expected integer >= ' + str(minimum))


# Example: disabled has no engine; registered adapter IDs are not limited to NARS/PLN.
def _adapter(value):
    _fields(value, 'id adapter_version engine_version configuration_version', ('registration',))
    _text(value['id'])
    _text(value['configuration_version'])
    if 'registration' in value:
        _text(value['registration'])
    for name in ('adapter_version', 'engine_version'):
        if value['id'] == 'disabled':
            if value[name] is not None:
                raise ValueError('disabled adapter has no adapter/engine version')
        else:
            _text(value[name])


# Example: zero influence remains valid when collecting shadow proposals.
def _configuration(controls, adapter_id):
    _fields(controls, 'collection influence assessment learning influence_cap seed')
    for name in ('collection', 'influence', 'assessment', 'learning'):
        if type(controls[name]) is not bool:
            raise ValueError(name + ' must be a boolean')
    cap = controls['influence_cap']
    if type(cap) not in (int, float) or not 0 <= cap <= 1:
        raise ValueError('influence_cap must be in 0..1')
    if not controls['influence'] and cap != 0:
        raise ValueError('disabled influence requires zero influence_cap')
    if adapter_id == 'disabled' and any(controls[name] for name in
            ('collection', 'influence', 'assessment', 'learning')):
        raise ValueError('disabled adapter cannot enable reasoner controls')
    if controls['seed'] is not None:
        _count(controls['seed'])
        if controls['seed'] > 4294967295:
            raise ValueError('seed must fit Python hash seed range 0..4294967295')


# Example: fixture-owned reset/policy labels describe state without executing setup.
def _initial_state(initial):
    _fields(initial, 'fixture reset policy motivation memory inputs observations',
            ('host', 'operations', 'budgets', 'file_content'))
    for name in ('fixture', 'reset', 'policy', 'memory'):
        _text(initial[name])
    if isinstance(initial['motivation'], str):
        _text(initial['motivation'])
    else:
        _fields(initial['motivation'], '', ('goals', 'anti_goals', 'modulators', 'self'))
        for rows in initial['motivation'].values():
            if not isinstance(rows, dict):
                raise ValueError('motivational overrides must map names to normalized values')
            for name, value in rows.items():
                _text(name)
                if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_-]*', name):
                    raise ValueError('invalid motivational field name')
                _ratio(value)
    if not isinstance(initial['inputs'], list) or not isinstance(initial['observations'], list):
        raise ValueError('inputs and observations must be lists')
    for message in initial['inputs']:
        if message is not None:
            _text(message)
    for observation in initial['observations']:
        _observation(observation)
    _host_options(initial)


# Example: classifier estimates and normalized initial weights reject booleans and nonfinite values.
def _ratio(value):
    if type(value) not in (float, int) or not 0 <= value <= 1:
        raise ValueError('expected a normalized number in 0..1')


# Example: a scheduled file disappearance is an external input, never an invented handler result.
def _observation(value):
    if isinstance(value, str):
        _text(value)  # Legacy opaque observations remain representable; drivers may reject them.
        return
    _fields(value, 'cycle', ('file_content', 'semantics', 'confirmation'))
    _count(value['cycle'], 1)
    if 'file_content' in value and value['file_content'] is not None and not isinstance(value['file_content'], str):
        raise ValueError('file_content must be text or null for absence')
    if 'confirmation' in value:
        _ratio(value['confirmation'])
    if 'semantics' in value:
        _fields(value['semantics'], '', ('danger', 'user-angry', 'execution-request'))
        for score in value['semantics'].values():
            _ratio(score)


# Example: supported operation names refer to the fixture's existing command catalog.
def _host_options(initial):
    host = initial.get('host', {})
    _fields(host, '', ('root_mode', 'frame_mode', 'priority', 'status', 'posture'))
    for name, allowed in (('root_mode', ('Fast', 'Slow')), ('frame_mode', ('Fast', 'Slow')), ('status', ('Active', 'Focused', 'Blocked')),
                          ('posture', ('Sleep', 'Engaged', 'Rumination', 'Threat'))):
        if name in host and host[name] not in allowed:
            raise ValueError('unsupported initial host ' + name)
    if 'priority' in host:
        _ratio(host['priority'])
    if 'operations' in initial:
        operations = initial['operations']
        if not isinstance(operations, list) or any(name not in ('read-file', 'show-current-frame') for name in operations):
            raise ValueError('operations must name supported fixture catalog entries')
        if len(set(operations)) != len(operations):
            raise ValueError('duplicate operations')
    _fields(initial.get('budgets', {}), '', ('global', 'frame'))
    for amount in initial.get('budgets', {}).values():
        _count(amount)
    if 'file_content' in initial and not isinstance(initial['file_content'], str):
        raise ValueError('initial file_content must be text')


# Example: a shadow run collects proposals while influence and learning remain off.
def validate_scenario(value):
    _fields(value, 'schema_version scenario_id description source_versions adapter configuration initial_state resource_limits')
    if type(value['schema_version']) is not int or value['schema_version'] != 1:
        raise ValueError('unsupported scenario schema version')
    _text(value['scenario_id'])
    _text(value['description'])
    versions = value['source_versions']
    if not isinstance(versions, dict) or not {'v1', 'core'} <= versions.keys():
        raise ValueError('source_versions must identify v1 and core revisions')
    for name, revision in versions.items():
        _text(name)
        _text(revision)
    _adapter(value['adapter'])
    _configuration(value['configuration'], value['adapter']['id'])
    _initial_state(value['initial_state'])
    limits = value['resource_limits']
    _fields(limits, 'max_cycles max_elapsed_ms intake_limits')
    _count(limits['max_cycles'], 1)
    _count(limits['max_elapsed_ms'], 1)
    # Reuse the serialized ReasonerIntakeLimits contract; the runtime validates it.
    _text(limits['intake_limits'])
    json.dumps(value, allow_nan=False)
    return value


# Example: a failed adapter run can retain partial traces without claiming task success.
def validate_result(value):
    _fields(value, 'schema_version run_id scenario status error elapsed_ms trace_references measurements',
            ('runtime_configuration',))
    if type(value['schema_version']) is not int or value['schema_version'] != 1:
        raise ValueError('unsupported result schema version')
    _text(value['run_id'])
    validate_scenario(value['scenario'])
    if value['status'] not in ('completed', 'failed', 'timed_out', 'unavailable'):
        raise ValueError('unsupported run status')
    if value['status'] == 'completed':
        if value['error'] is not None:
            raise ValueError('completed run cannot report an execution error')
    else:
        _text(value['error'])
    _count(value['elapsed_ms'])
    if not isinstance(value['trace_references'], list):
        raise ValueError('trace_references must be a list')
    for reference in value['trace_references']:
        _fields(reference, 'artifact stage identity cycle_ref')
        for item in reference.values():
            _text(item)
    if not isinstance(value['measurements'], dict):
        raise ValueError('measurements must be an object; absent metrics are omitted')
    if 'runtime_configuration' in value and not isinstance(value['runtime_configuration'], dict):
        raise ValueError('runtime_configuration must be an object')
    json.dumps(value, allow_nan=False)
    return value
