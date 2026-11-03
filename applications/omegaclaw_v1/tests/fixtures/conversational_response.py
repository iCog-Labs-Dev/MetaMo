"""External provider/socket doubles for F2.9; never queue or dispatch directly."""
import json
import os
from pathlib import Path

_calls = 0
_messages = iter(())
_scenario = 'answer'
_drain_irc = None
_before_calls = 0
REPLY = 'Hi! I\'m ready. You said "hello".\nHow can I help?'


# Example: install() supplies explicit send policy, with no fixed send command.
def install(scenario):
    global _scenario, _messages, _drain_irc
    _scenario = scenario
    message = 'hello, read /secret' if scenario == 'unsupported' else 'hello'
    _messages = iter(('Nahom: ' + message, '', ''))
    import host_config_fixture as files
    import irc_routing_fixture
    import lib_llm_ext
    path = Path(files.write_irc('allowed'))
    config = json.loads(path.read_text())
    config['frame_id'] = 'current-frame'
    config['commands'] = []
    if scenario == 'denied':
        config['frame']['egress'] = []
    path.write_text(json.dumps(config))
    os.environ['OMEGACLAW_HOST_CONFIG'] = str(path)
    irc_routing_fixture.connect()
    import irc
    irc._set_auth_secret('fixture-secret')
    assert irc._is_allowed_message('Nahom', 'auth fixture-secret') == 'auth_bound'
    _drain_irc = irc.getLastMessage
    irc.getLastMessage = receive
    lib_llm_ext.PROMPT_DELIMITER = ':-:-:-:'
    lib_llm_ext.callProvider = provider
    return 1


# Example: only the first polling turn receives a greeting.
def receive():
    import irc
    message = next(_messages, '')
    if message:
        sender, _, body = message.partition(': ')
        assert irc._is_allowed_message(sender, body) == 'allow'
        irc._set_last(message)
    return _drain_irc()


# Example: preparation returns JSON; asking a model to echo commands is a failure.
def provider(name, prompt, max_tokens, *args):
    import janus
    global _calls
    assert name == 'Offline'
    if max_tokens == 512:
        data = json.loads(prompt.split(':-:-:-:', 1)[1])
        assert 'read /secret' in data['request']
        return '{"kind":"External","needs":["Files"]}'
    if max_tokens == 16384:
        _calls += 1
        data = json.loads(prompt.split(':-:-:-:', 1)[1])
        assert data == {'request': 'hello', 'requirements': {'kind': 'Conversation', 'tools': 'None'}}
        provenance = janus.query_once('''
            eval(['get-state','&host-transport-input'], Transport),
            eval(['get-state','&operation-context'], ['OperationContext',Session,_,Frame]),
            commitmentSnapshot(['CommitmentSnapshot',_,Frame,_,'Open',"hello"])
        ''')
        assert provenance['truth']
        assert provenance['Transport'] == ['HostTransportInput', provenance['Session'],
            provenance['Frame'], ['TransportInput', 'irc', 'Nahom', 'Nahom: hello'], 'hello']
        if _scenario == 'followup':
            import host_ingress
            assert 'FollowUp' in host_ingress.ingest('follow-up: read /secret')
        if _scenario == 'replacement':
            import host_ingress
            assert 'Replaced' in host_ingress.ingest('replace: read /secret')
        if _scenario == 'session':
            assert janus.query_once('eval([initOperationSession], _)')['truth']
        if _scenario == 'no_action':
            return '{"no_action":true}'
        if _scenario == 'invalid':
            return '{"command":"send", "permissions":["all"]}'
        return json.dumps({'text': REPLY})
    raise AssertionError('Core must not call a command-generation model for host commands or no action')


# Example: mutate current ownership after selection but before final dispatch checks.
def before_dispatch():
    global _before_calls
    import host_ingress
    _before_calls += 1
    assert _scenario == 'before_dispatch' and _before_calls == 1
    assert 'FollowUp' in host_ingress.ingest('follow-up: read /secret')
    return 1


# Example: three polling turns submit one greeting and perform zero reads.
def verified():
    import janus
    import irc_routing_fixture
    assert _calls == (0 if _scenario == 'unsupported' else 1), _calls
    expected = 2 if _scenario == 'answer' else 0
    assert _before_calls == (1 if _scenario == 'before_dispatch' else 0)
    assert irc_routing_fixture.writes() == expected, irc_routing_fixture.writes()
    assert janus.query_once("\\+ oc_dispatch_result(_, ['read-file',_], _)")['truth']
    if not expected:
        assert janus.query_once("eval(['get-state','&answered-operation-key'], [])")['truth']
        return 1
    submitted = [call.args[0] for call in irc_routing_fixture._sockets[0].sendall.call_args_list]
    assert submitted == [b'PRIVMSG #room :Hi! I\'m ready. You said "hello".\r\n',
                         b'PRIVMSG #room :How can I help?\r\n'], submitted
    receipts = janus.query_once("findall(C, oc_dispatch_result(_, C, ['DispatchResult','Executed',_,_]), Commands), C=ignored")
    assert receipts['Commands'] == [['send', REPLY]], receipts
    assert janus.query_once("eval(['get-state','&answered-operation-key'], Key), Key \\== []")['truth']
    return 1


# Example: exercise standalone Core's opt-out path with a bounded provider double.
def install_legacy_provider():
    import lib_llm_ext

    def legacy_provider(name, prompt, max_tokens, *args):
        assert name == 'Offline' and max_tokens == 256
        return '(send "legacy model reply")'

    lib_llm_ext.callProvider = legacy_provider
    return 1
