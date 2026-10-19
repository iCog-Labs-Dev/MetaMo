"""Offline provider only; capture, policies, read/send handlers remain real."""
import json
from pathlib import Path

_observations = None
_mode = 'answer'
_calls = 0
_inputs = 0


def new_input():
    """A new admitted input identity, without opening a network channel."""
    import janus
    global _inputs
    _inputs += 1
    return int(janus.query_once("oc_dispatch_mutate(eval(['change-state!',"
        "'&cfv2-last-admitted-frame-id', Input], _))",
        {'Input': 'answer-test-input-' + str(_inputs)})['truth'])


def configure(variant):
    import host_config_fixture
    path = host_config_fixture.write_send(variant)
    config = json.loads(Path(path).read_text())
    # Grant send explicitly, but let F1.5 supply its exact generated text.
    config['commands'] = [row for row in config['commands'] if row['skill'] != 'send']
    Path(path).write_text(json.dumps(config))
    return path


def retain_read():
    import janus
    global _observations
    _observations = [janus.query_once("eval(['get-state','&last-operation-outcome'], Outcome)")['Outcome']]
    return 1


def provision(variant):
    import host_dispatch_config
    host_dispatch_config.configure_startup(configure(variant))
    return host_dispatch_config.provision_startup()


def calls():
    return _calls


# Example: actual queued/read evidence cannot be replaced with greeting readiness.
def greeting_shortcut():
    import host_operations
    return host_operations.queue_response_preparation('Offline', 'hello', [],
        {'channel': 'local', 'recipient': 'stdout'}, requirements='ConversationNoTools')


def revoke_reply():
    import janus
    return int(janus.query_once('mm_dispatch_revoke([send,"observed reply"])')['truth'])


def queue(mode):
    import host_operations
    import lib_llm_ext
    global _mode
    _mode = mode[6:] if mode.startswith("ready-") else mode
    lib_llm_ext.PROMPT_DELIMITER = ':-:-:-:'
    lib_llm_ext.callProvider = call_provider
    required = None
    if mode in ('ready', 'missing-read') or mode.startswith('ready-'):
        required = [_observations[0][1][3][1]]
        if mode == 'missing-read':
            required.append('/not-observed')
    return host_operations.queue_response_preparation(
        'Offline', 'Summarize the observed file', _observations,
        {'channel': 'local', 'recipient': 'stdout'}, required_reads=required)


def call_provider(provider, prompt, max_tokens):
    import janus
    global _calls
    _calls += 1
    assert provider == 'Offline' and max_tokens == 1024
    data = json.loads(prompt.split(':-:-:-:', 1)[1])
    assert data['observations'][0]['content'] == _observations[0][4][3]
    if _mode == 'route-change':
        janus.query_once("eval(['change-state!','&send-test-channel',telegram], _)")
    if _mode == 'policy-change':
        import host_config_fixture
        host_config_fixture.revoke_frame_command()
    if _mode == 'invalid':
        return 'not JSON'
    if _mode == 'no-action':
        return '{"no_action":true}'
    return json.dumps({'text': 'observed reply'})
