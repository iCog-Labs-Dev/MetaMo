"""Only providers/IRC transport are doubled; classification and ownership stay real."""
import json

_scenario = ''
_calls = 0


# Example: one test file runs all cases without sharing interpreter or fixture globals.
def run_scenario(scenario):
    from pathlib import Path
    import os
    import re
    import signal
    import subprocess
    import shutil
    if scenario not in ('conversation', 'mixed', 'uncertain', 'invalid', 'external',
                        'failure', 'followup', 'replacement', 'session', 'policy', 'route'):
        raise ValueError('unknown requirements scenario')
    fixture = Path(__file__).resolve()
    launcher = fixture.parents[4] / 'scripts' / 'run-omegaclaw.py'
    # The canonical launcher runs the parent in its selected compiler workspace.
    command = [shutil.which('python3'), str(launcher),
        str(fixture.with_name('task_requirements_loop.metta')),
        '--workspace', str(Path.cwd()), 'requirementsScenario=' + scenario]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               text=True, start_new_session=True)
    try:
        stdout, stderr = process.communicate(timeout=30)
    finally:
        # The launcher starts SWI-Prolog; clean up both on timeout/interruption.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
    output = stdout + stderr
    passed = len(re.findall(r'^is .*?, should .*?\. ✅\s*$', output, re.MULTILINE))
    errors = re.search(r'^\s*(?:ERROR:|Traceback \(most recent call last\):|\(Error(?:\s|\)))',
                       output, re.MULTILINE)
    if process.returncode or '❌' in output or errors or passed != 6:
        raise AssertionError(f'{scenario}: expected six passing checks\n{output}')
    print(f'Task requirements: {scenario}: {passed}/6 checks passed', flush=True)
    return 1


# Example: each scenario enters through transport-faithful real Core polling.
def install(scenario):
    import conversational_response as conversation
    import lib_llm_ext
    global _scenario, _calls
    _scenario, _calls = scenario, 0
    conversation.install('unsupported')
    message = ('Explain recursion and read /secret' if scenario == 'mixed'
               else 'Explain recursion')
    conversation._messages = iter(('Nahom: ' + message, '', ''))
    lib_llm_ext.callProvider = provider
    return 1


# Example: mutations during inference exercise the actual owner/snapshot recheck.
def mutate_during_classification():
    import host_ingress
    import janus
    if _scenario == 'followup':
        assert 'FollowUp' in host_ingress.ingest('follow-up: read /secret')
    if _scenario == 'replacement':
        assert 'Replaced' in host_ingress.ingest('replace: read /secret')
    if _scenario == 'session':
        assert janus.query_once('eval([initOperationSession], _)')['truth']
    if _scenario == 'policy':
        assert janus.query_once('oc_dispatch_mutate(true)')['truth']
    if _scenario == 'route':
        import irc_routing_fixture
        irc_routing_fixture.connect('channel')


# Example: proposals are JSON data; F2.9b never calls the answer-preparation provider.
def provider(name, prompt, max_tokens, *args):
    import janus
    global _calls
    assert name == 'Offline' and max_tokens != 1024
    if max_tokens != 512:
        assert janus.query_once('eval([selectedHostCommand], [])')['truth']
        return '()'
    _calls += 1
    assert _calls == 1, 'idle cycles retried classification'
    data = json.loads(prompt.split(':-:-:-:', 1)[1])
    assert data == {'request': 'Explain recursion', 'existing_requirements': []}
    mutate_during_classification()
    if _scenario == 'uncertain':
        return '{"kind":"Uncertain","needs":[]}'
    if _scenario == 'invalid':
        return '{"kind":"Conversation","needs":[],"command":"send"}'
    if _scenario == 'external':
        return '{"kind":"External","needs":["PrivateData"]}'
    if _scenario == 'failure':
        raise RuntimeError('fixture-provider-secret')
    return '{"kind":"Conversation","needs":[]}'


# Example: eligibility is recorded, but there are no read/send/completion effects.
def verified():
    import janus
    import irc_routing_fixture
    assert _calls == (0 if _scenario == 'mixed' else 1)
    assert irc_routing_fixture.writes() == 0
    assert janus.query_once('\\+ oc_dispatch_result(_,_,_)')['truth']
    state = janus.query_once('''
        eval(['get-state','&host-task-requirements'], Requirements),
        eval(['get-state','&operation-context'], ['OperationContext',Session,_,Frame]),
        commitmentSnapshot(Commitment),
        eval(['get-state','&host-response-input'], Input),
        eval(['get-state','&host-transport-input'], Transport)
    ''')
    record = state['Requirements']
    if _scenario in ('session', 'policy', 'route'):
        assert record == [], record
        return 1
    assert record[0] == 'HostTaskRequirements', record
    assert record[1][:3] == [state['Session'], state['Frame'], state['Commitment']], record
    assert record[1][5:] == [state['Input'], state['Transport']], record
    status, reason = record[4][1:]
    if _scenario in ('mixed', 'followup', 'replacement', 'external'):
        assert status == 'RequiresTools', record
        assert record[3] == ['RequiredWork', ['PrivateData' if _scenario == 'external' else 'Files']], record
    elif _scenario in ('uncertain', 'invalid', 'failure'):
        assert status == 'NoAction', record
        assert reason == {'uncertain': 'Uncertain', 'invalid': 'InvalidProposal',
                          'failure': 'ProviderUnavailable'}[_scenario], record
    else:
        assert record[3:] == [['RequiredWork', []],
                             ['RequirementAssessment', 'Conversational', 'ValidatedProposal']], record
    return 1
