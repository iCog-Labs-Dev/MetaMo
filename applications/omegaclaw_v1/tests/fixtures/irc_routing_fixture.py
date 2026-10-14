"""Real Core IRC adapter/locks with only sockets and provider doubled."""
import json
from pathlib import Path
import threading
from unittest.mock import Mock, patch

_sockets = []
_mode = 'answer'
_writer = None
_stopped = None


def connect(variant='same'):
    import irc
    server, port, channel = 'IRC.Example.org', 6667, '#room'
    if variant == 'server':
        server = 'other.example.org'
    elif variant == 'port':
        port = 6697
    elif variant == 'channel':
        channel = '#other'
    elif variant != 'same':
        raise ValueError('unknown route variant')
    # Prevent network startup; exercise the real publication/lifecycle methods.
    with patch.object(irc.threading, 'Thread'):
        irc.start_irc(channel, server, port, auth_secret='')
    sock = Mock()
    _sockets.append(sock)
    assert irc._install_connection(sock, server, port, channel, irc._run_id)
    assert irc._mark_registered(sock, irc._run_id)
    return 1


def disconnect():
    import irc
    irc.stop_irc()
    return 1


def writes():
    return sum(sock.sendall.call_count for sock in _sockets)


def provision():
    import host_config_fixture
    import host_dispatch_config
    path = Path(host_config_fixture.write_irc('allowed'))
    config = json.loads(path.read_text())
    config['commands'] = [row for row in config['commands'] if row['skill'] != 'send']
    path.write_text(json.dumps(config))
    host_dispatch_config.configure_startup(str(path))
    return host_dispatch_config.provision_startup()


def queue(mode='answer'):
    import host_operations
    import prepared_response_fixture
    import lib_llm_ext
    global _mode
    _mode = mode
    lib_llm_ext.PROMPT_DELIMITER = ':-:-:-:'
    lib_llm_ext.callProvider = provider
    observations = prepared_response_fixture._observations
    return host_operations.queue_response_preparation('Offline', 'Summarize the file', observations,
        dict(channel='irc', server='irc.example.org', port=6667, recipient='#room'),
        required_reads=[observations[0][1][3][1]])


def provider(provider_name, prompt, max_tokens):
    assert provider_name == 'Offline' and max_tokens == 1024
    if _mode == 'reconnect':
        connect()
    return json.dumps({'text': 'observed reply'})


def prepare_then_reconnect():
    import host_operations
    host_operations._prepare_pending_response()
    return connect()


def start_writer():
    global _writer, _stopped
    attempting, _stopped = threading.Event(), threading.Event()

    def stop():
        attempting.set()
        disconnect()
        _stopped.set()

    _writer = threading.Thread(target=stop)
    _writer.start()
    assert attempting.wait(1)
    assert not _stopped.wait(0.05), 'route changed between final gate and handler'
    return 1


def finish_writer():
    _writer.join(3)
    return int(not _writer.is_alive() and _stopped.is_set())


def route_lock_available():
    import irc
    done = threading.Event()

    def acquire():
        with irc._sock_lock:
            done.set()

    worker = threading.Thread(target=acquire, daemon=True)
    worker.start()
    worker.join(2)
    return int(done.is_set())
