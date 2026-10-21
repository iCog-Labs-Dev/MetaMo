"""External provider/socket doubles for F2.9; never queue or dispatch directly."""
import json
import os
from pathlib import Path

_calls = 0
_messages = iter(())
_scenario = 'answer'
_drain_irc = None


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


# Example: preparation returns JSON; Core command generation echoes its selection.
def provider(name, prompt, max_tokens, *args):
    import janus
    global _calls
    assert name == 'Offline'
    if max_tokens == 512:
        data = json.loads(prompt.split(':-:-:-:', 1)[1])
        assert 'read /secret' in data['request']
        return '{"kind":"External","needs":["Files"]}'
    if max_tokens == 1024:
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
        return '{"text":"Hello!"}'
    if _scenario == 'before_dispatch':
        import host_ingress
        assert 'FollowUp' in host_ingress.ingest('follow-up: read /secret')
    result = janus.query_once('''eval([selectedHostCommand], Command), swrite(Command, Source),
        eval(['get-state','&prepared-host-operation'], Prepared)''')
    if result['Command']:
        assert result['Prepared'][6] == ['NoToolEvidenceReady', 'Conversation', 'hello']
    return result['Source'] if result['Command'] else '()'


# Example: three polling turns submit one greeting and perform zero reads.
def verified():
    import janus
    import irc_routing_fixture
    assert _calls == (0 if _scenario == 'unsupported' else 1), _calls
    expected = 1 if _scenario == 'answer' else 0
    assert irc_routing_fixture.writes() == expected, irc_routing_fixture.writes()
    assert janus.query_once("\\+ oc_dispatch_result(_, ['read-file',_], _)")['truth']
    if not expected:
        assert janus.query_once("eval(['get-state','&answered-operation-key'], [])")['truth']
        return 1
    assert irc_routing_fixture._sockets[0].sendall.call_args.args == (b'PRIVMSG #room :Hello!\r\n',)
    assert janus.query_once("eval(['get-state','&answered-operation-key'], Key), Key \\== []")['truth']
    return 1
