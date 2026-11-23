"""Controlled external inputs for the offline read fixture, not dispatch-outcome doubles."""
import json
import os
from pathlib import Path
import random


# Example: each comparison reads its own immutable scenario copy.
def scenario():
    return json.loads(Path(os.environ['OMEGACLAW_BENCHMARK_SCENARIO']).read_text())


# Example: a declared seed controls Python RNG; native Prolog RNG is seeded by the fixture.
def initialize(frame):
    import host_config_fixture
    value = scenario()
    seed = value['configuration']['seed']
    if seed is not None:
        random.seed(seed)
    initial = value['initial_state']
    if 'file_content' in initial:
        Path(host_config_fixture._config['allowed_files'][0]).write_text(initial['file_content'])
    return provision(frame)


# Example: a replacement receives its own policy; a follow-up does not reset spent budgets.
def provision(frame):
    import host_mode_fixture
    initial = scenario()['initial_state']
    if 'operations' in initial or 'budgets' in initial:
        return host_mode_fixture.provision_variant(frame, initial['policy'],
            initial.get('operations'), initial.get('budgets'))
    return host_mode_fixture.provision_variant(frame, initial['policy'])


# Example: only native restore record data crosses to MeTTa, never executable setter text.
def motivation():
    value = scenario()['initial_state']['motivation']
    if value == 'registry-defaults':
        return '()'
    tags = {'goals': 'goal', 'anti_goals': 'anti-goal', 'modulators': 'modulator', 'self': 'self-metric'}
    # The policy encoder accepts persisted integers only; these validated volatile weights are floats.
    return '(' + ' '.join(f'({tags[group]} {name} {amount!r})'
                         for group, rows in value.items() for name, amount in rows.items()) + ')'


# Example: null slots represent idle cycles without manufacturing a user message.
def input_at(cycle):
    values = scenario()['initial_state']['inputs']
    value = values[cycle - 1] if cycle <= len(values) else None
    return '()' if value is None else json.dumps(value)


# Example: file changes affect only this run's real file; reads still use Core dispatch.
def before_cycle(cycle, message_summary):
    import host_config_fixture
    import lib_llm_ext
    value = scenario()['initial_state']
    lib_llm_ext.semantic_response(message_summary, '()')
    lib_llm_ext.confirmation_response(message_summary, 0.0)
    for event in value['observations']:
        if event['cycle'] != cycle:
            continue
        if 'file_content' in event:
            path = Path(host_config_fixture._config['allowed_files'][0])
            if event['file_content'] is None:
                path.unlink(missing_ok=True)
            else:
                path.write_text(event['file_content'])
        if 'semantics' in event:
            rows = ' '.join(f'(signal {kind} {score!r})' for kind, score in event['semantics'].items())
            lib_llm_ext.semantic_response(message_summary, '(' + rows + ')')
        if 'confirmation' in event:
            lib_llm_ext.confirmation_response(message_summary, event['confirmation'])
    return 1


# Example: read the run-owned file independently before the handler is invoked.
def inspect_file():
    import host_config_fixture
    path = Path(host_config_fixture._config['allowed_files'][0])
    return dict(path=str(path), exists=path.is_file(), content=path.read_text() if path.is_file() else None)
