"""Two explicit real Core file reads with normal production host bindings."""
import json
import host_dispatch_config as host
import host_config_fixture as files
import host_requirements

_config_path = None
_commands = None


def setup():
    global _config_path, _commands
    files.setup()
    _config_path = files.write('ambiguous')
    data = host.read_config(_config_path)
    _commands = [host.record(row['skill'], *row['arguments'])
                 for row in data['commands'] if row['skill'] == 'read-file']
    return _config_path


def plan():
    return host.encode([host.record('ExecutionStep', str(i + 1), command)
                        for i, command in enumerate(_commands)])


# Example: existing configured reads traverse F3.2's production constructor in order.
def proposed_steps(count=2):
    paths = [_commands[i % len(_commands)][1] + (str(i) if count > 2 else '')
             for i in range(count)]
    proposal = host_requirements.read_request_result('Proposed', paths, 'ValidatedProposal')
    return host_requirements.construct_read_steps(proposal)


# Example: parsing a serialized command-like path must never evaluate its contents.
def inert_steps():
    proposal = host_requirements.read_request_result(
        'Proposed', ['(change-state! &error "ran")', 'a "quote" \\ naïve.txt'], 'ValidatedProposal')
    return host_requirements.construct_read_steps(proposal)


# Example: cwd-relative references resolve to the exact catalog command, retaining order.
def relative_steps():
    import os
    paths = [os.path.relpath(command[1]) for command in reversed(_commands)]
    proposal = host_requirements.read_request_result('Proposed', paths, 'ValidatedProposal')
    return host_requirements.construct_read_steps(proposal)


# Example: different spellings of the same file must not create duplicate reads.
def aliased_steps():
    from pathlib import Path
    path = Path(_commands[0][1])
    paths = [str(path), str(path.parent) + '/./' + path.name]
    return host_requirements.construct_read_steps(
        host_requirements.read_request_result('Proposed', paths, 'ValidatedProposal'))


# Example: an unconfigured symlink cannot borrow its target's catalog binding.
def symlink_steps():
    from pathlib import Path
    link = Path(_commands[0][1]).with_name('alias.txt')
    link.symlink_to(_commands[0][1])
    return host_requirements.construct_read_steps(
        host_requirements.read_request_result('Proposed', [str(link)], 'ValidatedProposal'))


# Example: each denial is installed through the real configuration API, then restored.
def admission_config(scope, variant):
    data = host.read_config(_config_path)
    if variant == 'permission':
        data[scope]['permissions'].remove('files.read:' + _commands[1][1])
    elif variant == 'skill':
        data[scope]['skills'].remove('read-file')
    elif variant == 'budget':
        data[scope]['budgets'][0]['available'] = 0
    elif variant == 'constraint':
        data[scope]['constraints'].append(['DenySkill', 'read-file'])
    elif variant == 'unsupported':
        data['commands'] = [row for row in data['commands'] if row['arguments'] != [_commands[1][1]]]
    else:
        raise ValueError('unknown admission variant')
    path = _config_path + '.admission.json'
    with open(path, 'w', encoding='utf-8') as stream:
        json.dump(data, stream)
    return path


def command(index):
    return host.encode(_commands[index])


def deny_second():
    data = host.read_config(_config_path)
    data['frame']['permissions'].remove('files.read:' + _commands[1][1])
    with open(_config_path, 'w', encoding='utf-8') as stream:
        json.dump(data, stream)
    return _config_path


# Example: an uncertain Core ledger entry still blocks installation after selection clears.
def uncertain_invocation(enabled):
    import janus
    if enabled:
        query = '''assertz(oc_dispatch_result(['DispatchTicket',"f34-uncertain"],
                   ['read-file',"fixture"],
                   ['DispatchResult','Unobserved','ExecutionUncertain',none]))'''
    else:
        query = 'retractall(oc_dispatch_result([\'DispatchTicket\',"f34-uncertain"],_,_))'
    return int(janus.query_once(query)['truth'])


# Example: an allowed but unrequested file must never displace a pending plan read.
def with_unrequested_read():
    from pathlib import Path
    data = host.read_config(_config_path)
    extra = Path(_config_path).with_name('unrequested.txt')
    extra.write_text('unrequested content', encoding='utf-8')
    data['allowed_files'].append(str(extra))
    data['commands'].insert(0, {'skill': 'read-file', 'arguments': [str(extra)]})
    for scope in ('global', 'frame'):
        data[scope]['permissions'].append('files.read:' + str(extra))
    path = _config_path + '.unrequested.json'
    Path(path).write_text(json.dumps(data), encoding='utf-8')
    return path


_response_calls = 0
_response_mode = 'answer'


# Example: configure a local answer destination, retaining the real read catalog.
def enable_answers(mode='answer'):
    import lib_llm_ext
    global _response_mode
    _response_mode = mode
    data = host.read_config(_config_path)
    data['destination'] = {'channel': 'local', 'recipient': 'stdout'}
    data['completion_criterion'] = 'LocalAccepted'
    for scope in ('global', 'frame'):
        data[scope]['skills'].append('send')
        data[scope]['permissions'].extend(['channels.send', 'channels.send:local:stdout'])
        data[scope]['egress'] = ['local:stdout']
    if mode == 'denied':
        data['frame']['egress'] = []
    path = _config_path + '.answers.json'
    from pathlib import Path
    Path(path).write_text(json.dumps(data), encoding='utf-8')
    host.configure_startup(path)
    host.provision_startup()
    lib_llm_ext.PROMPT_DELIMITER = ':-:-:-:'
    lib_llm_ext.callProvider = answer_provider
    return 1


# Example: verify both actual observations reached preparation; never synthesize read evidence.
def answer_provider(provider, prompt, max_tokens):
    global _response_calls
    _response_calls += 1
    assert provider == 'Offline' and max_tokens == 1024
    payload = json.loads(prompt.split(':-:-:-:', 1)[1])
    assert payload['observations'] == [
        {'path': _commands[1][1], 'content': 'other content'},
        {'path': _commands[0][1], 'content': 'changed after invocation'}]
    if _response_mode == 'no-action':
        return '{"no_action":true}'
    if _response_mode == 'stale':
        import janus
        janus.query_once("oc_dispatch_mutate(eval(['change-state!','&host-response-input',"
                         "['HostResponseInput',\"configured-frame\",'FollowUp',\"new question\"]],_))")
    return '{"text":"Both files: other content; changed after invocation."}'


# Example: idle cycles and incomplete evidence never invoke preparation again.
def response_calls():
    return _response_calls


# Example: one allowed prefix cannot authorize a plan containing an unconfigured file.
def unallowed_steps():
    paths = [_commands[0][1], _commands[1][1] + '.unallowed']
    return host_requirements.construct_read_steps(
        host_requirements.read_request_result('Proposed', paths, 'ValidatedProposal'))


# Example: rejected admission/installation must not create any Core invocation result.
def dispatch_result_count():
    import janus
    return janus.query_once('aggregate_all(count, oc_dispatch_result(_,_,_), Count)')['Count']


_auto_calls = None
_auto_messages = None
_auto_scenario = None
_auto_before = None
_auto_question_turns = 0


# Example: only input/provider services are doubled; normal startup owns task and plan installation.
def install_auto_loop(scenario):
    import os
    import janus
    import local_channel
    import lib_llm_ext
    from pathlib import Path
    global _auto_calls, _auto_messages, _auto_scenario, _auto_before, _auto_question_turns
    setup()
    data = host.read_config(with_unrequested_read())
    # Core's text ingress escapes quotes; use ordinary literal paths for this loop scenario.
    old_path = _commands[0][1]
    new_path = str(Path(old_path).with_name('first.txt'))
    Path(new_path).write_text('observed local file content', encoding='utf-8')
    data['allowed_files'] = [new_path if path == old_path else path for path in data['allowed_files']]
    for command in data['commands']:
        if command['arguments'] == [old_path]:
            command['arguments'] = [new_path]
    for scope in ('global', 'frame'):
        data[scope]['permissions'] = [item.replace(old_path, new_path) for item in data[scope]['permissions']]
    _commands[0] = host.record('read-file', new_path)
    data['frame_id'] = 'current-frame'
    data['destination'] = {'channel': 'local', 'recipient': 'stdout'}
    data['completion_criterion'] = 'LocalAccepted'
    for scope in ('global', 'frame'):
        data[scope]['skills'].append('send')
        data[scope]['permissions'].extend(['channels.send', 'channels.send:local:stdout'])
        data[scope]['egress'] = ['local:stdout']
    if scenario.startswith('missing'):
        data['commands'].append({'skill': 'send', 'candidate': 'ask-clarification',
            'arguments': ['Which allowed file should replace the unavailable file?']})
        if scenario == 'missing-denied':
            data['frame']['egress'] = []
        if scenario == 'missing-unbound':
            data['commands'] = [row for row in data['commands']
                                if row.get('candidate') != 'ask-clarification']
        if scenario == 'missing-ambiguous':
            data['commands'].append({'skill': 'send', 'candidate': 'ask-clarification',
                                    'arguments': ['A different question?']})
    if scenario == 'missing-irc':
        import irc
        import irc_routing_fixture
        irc_routing_fixture.connect()
        data['destination'] = dict(channel='irc', server='irc.example.org', port=6667, recipient='#room')
        data['completion_criterion'] = 'TransportSubmission'
        for scope in ('global', 'frame'):
            data[scope]['permissions'] = [item.replace('local:stdout', 'irc:irc.example.org:6667:#room')
                                           for item in data[scope]['permissions']]
            data[scope]['egress'] = ['irc:irc.example.org:6667:#room']
        irc.getLastMessage = auto_receive
    path = _config_path + '.loop.json'
    Path(path).write_text(json.dumps(data), encoding='utf-8')
    os.environ['OMEGACLAW_HOST_CONFIG'] = path
    _auto_scenario = scenario
    _auto_question_turns = 0
    _auto_calls = dict(classification=0, extraction=0, answer=0, messages=0)
    paths = auto_paths()
    _auto_messages = iter(('Compare ' + ' and '.join(paths),))
    if scenario == 'missing-irc':
        _auto_messages = iter(('Nahom: Compare ' + ' and '.join(paths),))
    _auto_before = janus.query_once('findall(_T,oc_dispatch_result(_T,_,_),Tickets)')['Tickets']
    local_channel.getLastMessage = auto_receive
    lib_llm_ext.PROMPT_DELIMITER = ':-:-:-:'
    lib_llm_ext.callProvider = auto_provider
    return 1


# Example: a denied reference is literal in the request, but absent from the trusted catalog.
def auto_paths():
    paths = [row[1] for row in reversed(_commands)]
    if _auto_scenario == 'unallowed':
        paths[1] += '.unallowed'
    return paths


# Example: only one polling turn supplies input; idle turns cannot supply the next read.
def auto_receive():
    message = next(_auto_messages, '')
    _auto_calls['messages'] += int(bool(message))
    return message


# Example: the model proposes references, answers from observations, and echoes selected commands.
def auto_provider(provider, prompt, max_tokens, *args):
    import janus
    global _auto_question_turns
    assert provider == 'Offline'
    if max_tokens == 512:
        _auto_calls['classification'] += 1
        return '{"kind":"External","needs":["Files"]}'
    if max_tokens == 4096:
        _auto_calls['extraction'] += 1
        if _auto_scenario == 'no-action':
            return '{"no_action":true}'
        if _auto_scenario == 'stale':
            janus.query_once("oc_dispatch_mutate(true)")
        if _auto_scenario == 'session':
            janus.query_once('eval([initOperationSession],_)')
        if _auto_scenario == 'cancel':
            import host_ingress
            assert 'Cancelled' in host_ingress.ingest('cancel: stop during extraction')
        return json.dumps({'files': auto_paths()})
    if max_tokens == 1024:
        _auto_calls['answer'] += 1
        payload = json.loads(prompt.split(':-:-:-:', 1)[1])
        assert payload['observations'] == [
            {'path': _commands[1][1], 'content': 'other content'},
            {'path': _commands[0][1], 'content': 'observed local file content'}]
        return '{"text":"Both files were inspected: other content; observed local file content."}'
    result = janus.query_once('eval([selectedHostCommand],Command), swrite(Command,Source)')
    if _auto_scenario.startswith('missing'):
        if result['Command'] == _commands[0]:
            from pathlib import Path
            Path(_commands[0][1]).unlink()
        if result['Command'] and result['Command'][0] == 'send':
            _auto_question_turns += 1
            if _auto_scenario == 'missing-no-action' and _auto_question_turns == 1:
                return '()'
            if _auto_scenario == 'missing-stale':
                janus.query_once('oc_dispatch_mutate(true)')
            if _auto_scenario == 'missing-uncertain':
                # Trusted callback fixture only: no handler success is claimed for this attempt.
                outcome = janus.query_once("""eval(['get-state','&selected-operation-decision'],Decision),
                    sread(CommandSource,Command),
                    Outcome=['OperationOutcome',Decision,['attempted-command',Command],
                             'Unobserved',['DispatchResult','Unobserved','ExecutionUncertain',none]],
                    eval([ingestOperationOutcome,[quote,Outcome]],Result)""",
                    {'CommandSource': result['Source']})
                assert outcome['Result'] == 'OutcomeAccepted', outcome
                return '()'
    return result['Source'] if result['Command'] else '()'


# Example: verify real Core invocations after a single input, not helper-installed plan state.
def verify_auto_loop():
    import janus
    records = janus.query_once('findall([_T,_C,_R],oc_dispatch_result(_T,_C,_R),Rows)')['Rows']
    fresh = [row for row in records if row[0] not in _auto_before]
    assert _auto_calls == dict(classification=1, extraction=1,
                              answer=int(_auto_scenario in ('answer', 'sleep')), messages=1), _auto_calls
    state = janus.query_once("commitmentSnapshot(Owner), eval(['get-state','&host-continuation'],Plan)")
    if _auto_scenario.startswith('missing'):
        return verify_missing_loop(fresh, state)
    if _auto_scenario not in ('answer', 'sleep'):
        assert not [row for row in fresh if row[1][0] in ('read-file', 'send')], fresh
        assert state['Plan'] == [], state
        assert state['Owner'][4] == ('Abandoned' if _auto_scenario == 'cancel' else 'Open'), state
        return 1
    reads = [row for row in fresh if row[1][0] == 'read-file']
    assert [row[1][1] for row in reads] == auto_paths(), reads
    assert all(row[2][1:3] == ['Executed', 'Feasible'] for row in reads), reads
    sends = [row for row in fresh if row[1][0] == 'send']
    assert len(sends) == 1 and sends[0][2] == [
        'DispatchResult', 'Executed', 'Feasible', ['SendObservation', 'local:stdout', 'Accepted']], sends
    assert state['Owner'][4] == 'Completed', state
    return 1


# Example: actual Core polling asks once and leaves the missing second read held and open.
def verify_missing_loop(records, state):
    import janus
    reads = [row for row in records if row[1][0] == 'read-file']
    assert [row[1][1] for row in reads] == auto_paths(), reads
    assert reads[0][2] == ['DispatchResult', 'Executed', 'Feasible', 'other content'], reads
    assert reads[1][2] == ['DispatchResult', 'Executed', 'Feasible',
                           ['Error', 'read-file', 'FileUnavailable']], reads
    assert state['Owner'][4] == 'Open' and state['Plan'][6] == 'Held', state
    assert state['Plan'][7] == [['ExecutionStep', '2', _commands[0]]], state
    retained = janus.query_once("""eval([hostContinuationRecovery],Recovery),
        eval(['get-state','&continuation-evidence'],Evidence),
        eval(['get-state','&continuation-clarification'],Question),
        eval(['get-state','&recovery-view'],RecoveryView)""")
    assert retained['Recovery'][7] == ['ReadRecoveryNeed', 'MissingInput', 'FileUnavailable'], retained
    assert len(retained['Evidence'][5]) == 1, retained
    assert retained['RecoveryView'] == 'RecoveryPending', retained
    sends = [row for row in records if row[1][0] == 'send']
    if _auto_scenario in ('missing-denied', 'missing-unbound', 'missing-ambiguous'):
        assert not sends and retained['Question'] == 'NoClarificationObservation', retained
        return 1
    assert len(sends) == (0 if _auto_scenario == 'missing-uncertain' else 1), sends
    question = retained['Question']
    assert question[:2] == ['ClarificationObservation', retained['Recovery']], question
    expected_status = 'Held' if _auto_scenario in ('missing-stale', 'missing-uncertain') else 'Delivered'
    assert question[2] == expected_status, question
    assert question[3][1][2] == 'ask-clarification', question
    expected_outcome = ('Unobserved' if _auto_scenario == 'missing-uncertain'
                        else 'Blocked' if _auto_scenario == 'missing-stale' else 'Success')
    assert question[3][3] == expected_outcome, question
    assert _auto_question_turns == (2 if _auto_scenario == 'missing-no-action' else 1)
    if _auto_scenario == 'missing-irc':
        import irc_routing_fixture
        assert irc_routing_fixture.writes() == 1
        assert sends[0][2][3] == ['SendObservation', 'irc:irc.example.org:6667:#room',
                                  ['TransportSubmission', 'Submitted', 'Complete', 1, 1]], sends
    elif expected_status == 'Delivered':
        assert sends[0][2] == ['DispatchResult', 'Executed', 'Feasible',
                              ['SendObservation', 'local:stdout', 'Accepted']], sends
    return 1
