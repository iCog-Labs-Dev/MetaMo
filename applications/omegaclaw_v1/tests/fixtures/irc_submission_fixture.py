"""Exact send bindings and controlled socket outcomes for the real handler."""
import json
from pathlib import Path


def configure(variant):
    import host_config_fixture
    path = Path(host_config_fixture.write_irc('allowed'))
    config = json.loads(path.read_text())
    text = '界' * 400 if variant == 'long' else 'observed reply'
    for row in config['commands']:
        if row['skill'] == 'send' and row.get('candidate', 'respond') == 'respond':
            row['arguments'] = [text]
    path.write_text(json.dumps(config))
    return str(path)


def long_command():
    return '(send ' + json.dumps('界' * 400, ensure_ascii=False) + ')'


def fail_after(completed):
    import irc
    irc._sock.sendall.side_effect = [None] * completed + [OSError('test socket write failed')]
    return 1


def clear_marker():
    import irc
    with irc._sock_lock:
        irc._last_submission = None
    return 1


def marker_empty():
    import irc
    return int(irc._last_submission is None)
