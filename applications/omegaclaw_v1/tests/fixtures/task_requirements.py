"""Only providers/IRC transport are doubled; classification and ownership stay real."""
import json

_scenario = ''
_calls = 0
_preparations = 0
_request = ''
_changed = False
_completion_scenario = ''
_REQUESTS = {
    'conversation': 'Explain recursion',
    'factual': 'What is photosynthesis?',
    'casual': 'Tell me a joke',
    'writing': 'Write a short poem about rain',
    'rewrite': 'Rewrite this politely: I disagree.',
    'mixed': 'Explain recursion and read /secret',
}
_ANSWERS = {
    'conversation': 'Recursion solves a problem by calling itself on smaller instances.',
    'factual': 'Photosynthesis converts light energy into chemical energy.',
    'casual': 'Why did the bicycle fall over? It was two-tired.',
    'writing': 'Rain taps softly on the pane, a quiet song returns again.',
    'rewrite': 'I see things differently, but I appreciate your perspective.',
}
_COMPLETION_CASES = {'completion': 'conversation', 'acknowledgement': 'conversation',
    'completion_second': 'conversation', 'completion_uncertain': 'uncertain_delivery',
    'completion_denied': 'denied', 'completion_mixed': 'mixed',
    'completion_stale': 'before_dispatch'}
_SCENARIOS = set(_COMPLETION_CASES) | set(_REQUESTS) | {
    'uncertain', 'invalid', 'external', 'failure', 'followup', 'replacement', 'session',
    'policy', 'route', 'prepared_followup', 'prepared_replacement', 'prepared_session',
    'prepared_policy', 'prepared_route', 'prepared_requirements', 'prepared_no_action',
    'prepared_invalid', 'prepared_failure', 'before_dispatch', 'denied', 'uncertain_delivery',
}


# Example: one test file runs all cases without sharing interpreter or fixture globals.
def run_scenario(scenario):
    from pathlib import Path
    import os
    import re
    import signal
    import subprocess
    import shutil
    if scenario not in _SCENARIOS:
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
    global _scenario, _calls, _preparations, _request, _changed, _completion_scenario
    _completion_scenario = scenario if scenario in _COMPLETION_CASES else ""
    scenario = _COMPLETION_CASES.get(scenario, scenario)
    _scenario, _calls, _preparations, _changed = scenario, 0, 0, False
    conversation.install('denied' if scenario == 'denied' else 'unsupported')
    if _completion_scenario:
        import os
        from pathlib import Path
        path = Path(os.environ['OMEGACLAW_HOST_CONFIG'])
        config = json.loads(path.read_text())
        config['completion_criterion'] = ('RecipientAcknowledged'
            if _completion_scenario == 'acknowledgement' else 'TransportSubmission')
        path.write_text(json.dumps(config))
    _request = _REQUESTS.get(scenario, 'Explain recursion')
    conversation._messages = iter(('Nahom: ' + _request, '', ''))
    if _completion_scenario == 'completion_second':
        conversation._messages = iter(('Nahom: ' + _request, '', 'Nahom: Explain recursion again', '', ''))
    if scenario == 'uncertain_delivery':
        import irc_routing_fixture
        irc_routing_fixture._sockets[-1].sendall.side_effect = OSError('uncertain write')
    lib_llm_ext.callProvider = provider
    return 1


# Example: mutations during inference exercise the actual owner/snapshot recheck.
def mutate_during_classification(scenario):
    import host_ingress
    import janus
    if scenario == 'followup':
        assert 'FollowUp' in host_ingress.ingest('follow-up: read /secret')
    if scenario == 'replacement':
        assert 'Replaced' in host_ingress.ingest('replace: read /secret')
    if scenario == 'session':
        assert janus.query_once('eval([initOperationSession], _)')['truth']
    if scenario == 'policy':
        assert janus.query_once('oc_dispatch_mutate(true)')['truth']
    if scenario == 'route':
        import irc_routing_fixture
        irc_routing_fixture.connect('channel')
    if scenario == 'requirements':
        assert janus.query_once('''
            eval(['get-state','&host-task-requirements'], [Tag,Owner,Cont,_,_,Assessed]),
            Value=[Tag,Owner,Cont,['RequiredWork',['Files']],
                   ['RequirementAssessment','RequiresTools','HostReadRequirement'],Assessed],
            oc_dispatch_mutate(eval(['change-state!','&host-task-requirements',[quote,Value]],_))
        ''')['truth']


# Example: proposals and answers use distinct bounded provider contracts.
def provider(name, prompt, max_tokens, *args):
    import janus
    global _calls, _changed, _request
    assert name == 'Offline'
    if max_tokens == 1024:
        return prepare_answer(prompt)
    if max_tokens != 512:
        if _scenario == 'before_dispatch' and not _changed:
            _changed = True
            mutate_during_classification('followup')
        result = janus.query_once('eval([selectedHostCommand], Command), swrite(Command,Source)')
        return result['Source'] if result['Command'] else '()'
    _calls += 1
    assert _calls <= (2 if _completion_scenario == 'completion_second' else 1), 'idle cycles retried classification'
    data = json.loads(prompt.split(':-:-:-:', 1)[1])
    if _completion_scenario == 'completion_second' and _calls == 2:
        _request = 'Explain recursion again'
    assert data == {'request': _request, 'existing_requirements': []}
    mutate_during_classification(_scenario)
    if _scenario == 'uncertain':
        return '{"kind":"Uncertain","needs":[]}'
    if _scenario == 'invalid':
        return '{"kind":"Conversation","needs":[],"command":"send"}'
    if _scenario == 'external':
        return '{"kind":"External","needs":["PrivateData"]}'
    if _scenario == 'failure':
        raise RuntimeError('fixture-provider-secret')
    return '{"kind":"Conversation","needs":[]}'


# Example: only text is returned; exact send construction stays in production code.
def prepare_answer(prompt):
    global _preparations
    _preparations += 1
    assert _preparations <= (2 if _completion_scenario == 'completion_second' else 1), 'idle cycles retried preparation'
    data = json.loads(prompt.split(':-:-:-:', 1)[1])
    assert data == {'request': _request, 'requirements': {'kind': 'Conversation', 'tools': 'None'}}
    if _scenario.startswith('prepared_'):
        mutate_during_classification(_scenario[len('prepared_'):])
    if _scenario == 'prepared_no_action':
        return '{"no_action":true}'
    if _scenario == 'prepared_invalid':
        return '{"text":"answer","command":"send"}'
    if _scenario == 'prepared_failure':
        raise RuntimeError('fixture-provider-secret')
    if _completion_scenario == 'completion_second' and _preparations == 2:
        return json.dumps({'text': 'A recursive function calls itself until it reaches a base case.'})
    return json.dumps({'text': _ANSWERS.get(_scenario, _ANSWERS['conversation'])})


# Example: accepted conversations submit once; explicit completion profiles then become idle.
def verified():
    import janus
    import irc_routing_fixture
    count = 2 if _completion_scenario == 'completion_second' else 1
    assert _calls == (0 if _scenario == 'mixed' else count), _calls
    prepared = _scenario in _ANSWERS or _scenario.startswith('prepared_') or _scenario in (
        'before_dispatch', 'denied', 'uncertain_delivery')
    assert _preparations == int(prepared) * count, (_scenario, _preparations)
    success = _scenario in _ANSWERS
    assert irc_routing_fixture.writes() == int(success or _scenario == 'uncertain_delivery') * count
    assert janus.query_once("\\+ oc_dispatch_result(_,['read-file',_],_)")['truth']
    if _completion_scenario in ('completion', 'completion_second'):
        completed = janus.query_once("findall(_Id,mm_commitment(_Id,_,_,'Completed',_),Ids)")['Ids']
        assert len(completed) == count, completed
        assert janus.query_once("eval(['get-state','&cfv2-current-frame-id'], [])")['truth']
        assert janus.query_once("eval(['get-state','&task-open'], false)")['truth']
        assert janus.query_once("eval(['get-state','&constitutional-mode'], 'Sleep')")['truth']
        events = janus.query_once("commitmentEvents(Events)")['Events']
        assert len(events) == count, events
        answers = [_ANSWERS['conversation']]
        if count == 2:
            answers.append('A recursive function calls itself until it reaches a base case.')
        actual = [call.args[0] for call in irc_routing_fixture._sockets[-1].sendall.call_args_list]
        assert actual == [f'PRIVMSG #room :{answer}\r\n'.encode() for answer in answers], actual
        return 1
    if success:
        expected = f'PRIVMSG #room :{_ANSWERS[_scenario]}\r\n'.encode()
        assert irc_routing_fixture._sockets[-1].sendall.call_args.args == (expected,)
        assert janus.query_once("eval(['get-state','&answered-operation-key'],Key), Key \\== []")['truth']
    else:
        assert janus.query_once("eval(['get-state','&answered-operation-key'],[])")['truth']
    state = janus.query_once('''
        eval(['get-state','&host-task-requirements'], Requirements),
        eval(['get-state','&operation-context'], ['OperationContext',Session,_,Frame]),
        commitmentSnapshot(Commitment),
        eval(['get-state','&host-response-input'], Input),
        eval(['get-state','&host-transport-input'], Transport)
    ''')
    record = state['Requirements']
    if _scenario in ('session', 'policy', 'route', 'prepared_session'):
        assert record == [], record
        return 1
    assert record[0] == 'HostTaskRequirements', record
    assert record[1][:3] == [state['Session'], state['Frame'], state['Commitment']], record
    assert record[1][5:] == [state['Input'], state['Transport']], record
    status, reason = record[4][1:]
    if _scenario in ('mixed', 'followup', 'replacement', 'external', 'prepared_followup',
                     'prepared_replacement', 'prepared_requirements', 'before_dispatch'):
        assert status == 'RequiresTools', record
        assert record[3] == ['RequiredWork', ['PrivateData' if _scenario == 'external' else 'Files']], record
    elif _scenario in ('uncertain', 'invalid', 'failure'):
        assert status == 'NoAction', record
        assert reason == {'uncertain': 'Uncertain', 'invalid': 'InvalidProposal',
                          'failure': 'ProviderUnavailable'}[_scenario], record
    else:
        assert record[3:5] == [['RequiredWork', []],
                             ['RequirementAssessment', 'Conversational', 'ValidatedProposal']], record
        assert record[5] == ['AssessedRequest', _request], record
    return 1


# Example: legacy profiles stay open; explicitly completed conversations become idle.
def verified_lifecycle():
    import janus
    expected = _completion_scenario not in ('completion', 'completion_second')
    state = janus.query_once("eval(['get-state','&task-open'],Open)")
    assert state['Open'] == ('true' if expected else 'false'), state
    return 1
