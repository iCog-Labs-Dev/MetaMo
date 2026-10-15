"""Acceptance-only provider/socket doubles; real reads, preparation and dispatch."""
import json
from pathlib import Path

_channel = None
_calls = 0


def start(channel):
    global _channel
    _channel = channel
    if channel == 'irc':
        import irc_routing_fixture
        irc_routing_fixture.connect('same')
    provision('allowed')
    if channel == 'local':
        import host_config_fixture
        host_config_fixture.capture_local_output()
    return 1


def provision(variant):
    import host_config_fixture as files
    import host_dispatch_config as host
    path = Path(files.write_irc('allowed') if _channel == 'irc' else files.write_clarification('allowed'))
    value = json.loads(path.read_text())
    # Reply text comes only from preparation. Keep an explicit clarification.
    value['commands'] = [row for row in value['commands']
                         if row['skill'] != 'send' or row.get('candidate') == 'ask-clarification']
    if variant != 'allowed':
        assert variant in ('global', 'frame')
        value[variant]['egress'] = []
    path.write_text(json.dumps(value))
    host.configure_startup(str(path))
    host.provision_startup()
    return 1


def queue():
    import host_operations
    import prepared_response_fixture
    import lib_llm_ext
    observations = prepared_response_fixture._observations
    lib_llm_ext.PROMPT_DELIMITER = ':-:-:-:'
    lib_llm_ext.callProvider = provider
    destination = (dict(channel='local', recipient='stdout') if _channel == 'local' else
                   dict(channel='irc', server='irc.example.org', port=6667, recipient='#room'))
    return host_operations.queue_response_preparation('Offline', 'Report the file contents',
        observations, destination, required_reads=[observations[0][1][3][1]])


def provider(name, prompt, max_tokens):
    global _calls
    assert name == 'Offline'
    data = json.loads(prompt.split(':-:-:-:', 1)[1])
    _calls += 1
    return json.dumps({'text': 'File says: ' + data['observations'][0]['content']})


def calls():
    return _calls


def effects():
    if _channel == 'irc':
        import irc_routing_fixture
        return irc_routing_fixture.writes()
    return len(local_messages())


def local_messages():
    import host_config_fixture
    return [json.loads(line)['message'] for line in host_config_fixture._send_output.getvalue().splitlines()
            if line.startswith('{"channel": "local",')]


def delivered(text):
    if _channel == 'local':
        return local_messages().count(text)
    import irc_routing_fixture
    wire = ('PRIVMSG #room :' + text + '\r\n').encode()
    return sum(call.args == (wire,) for sock in irc_routing_fixture._sockets
               for call in sock.sendall.call_args_list)


def reads():
    import janus
    return janus.query_once("findall(_Ticket, oc_dispatch_result(_Ticket, ['read-file',_], "
        "['DispatchResult','Executed','Feasible',_]), _Rows), length(_Rows, Count)")['Count']


def clear_marker():
    if _channel == 'irc':
        import irc_submission_fixture
        irc_submission_fixture.clear_marker()
    return 1


def change_route():
    if _channel == 'irc':
        import irc_routing_fixture
        return irc_routing_fixture.connect('server')
    import janus
    return int(janus.query_once("eval(['change-state!','&send-test-channel',telegram], _)")['truth'])


def restore_route():
    if _channel == 'irc':
        import irc_routing_fixture
        return irc_routing_fixture.connect('same')
    import janus
    return int(janus.query_once("eval(['change-state!','&send-test-channel',local], _)")['truth'])


def fail_send():
    if _channel == 'irc':
        import irc_submission_fixture
        return irc_submission_fixture.fail_after(0)
    import host_config_fixture
    return host_config_fixture.fail_local_flush()


def restore_send():
    if _channel == 'local':
        import host_config_fixture
        host_config_fixture.restore_local_flush()
    return 1


def finish():
    if _channel == 'local':
        import host_config_fixture
        host_config_fixture.finish_local_capture()
    return 1
