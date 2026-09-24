"""Controlled provider responses and file bindings; real host admission/dispatch."""
import host_dispatch_config as host
import host_config_fixture as files
_config = None


def setup():
    global _config
    _config = host.read_config(files.setup())
    return 1


def provision(frame, denied=False):
    return provision_variant(frame, 'permission-denied' if denied else 'allowed')


def provision_variant(frame, variant):
    import copy
    import janus
    config = copy.deepcopy(_config)
    frame = host.Symbol(frame)
    config['frame_id'] = frame
    if variant == 'permission-denied':
        config['frame']['permissions'] = []
    elif variant == 'budget-denied':
        config['frame']['budgets'][0]['available'] = 0
    elif variant not in ('allowed', 'empty'):
        raise ValueError('unknown policy variant')
    row = host.binding(config['commands'][0], frame, config['allowed_files'])
    row[2][-1] = host.Symbol('respond')
    row[3][1] = host.record('candidate', host.Symbol('respond'))
    source = host.encode(host.record(
        'HostDispatchConfig', host.scope(config['global'], host.Symbol('Global')),
        host.scope(config['frame'], host.record('FrameTarget', frame)),
        [] if variant == 'empty' else [row]))
    return int(janus.query_once(host._INSTALL, {'Source': source}).get('truth', False))


def revoke_failure_handler():
    import janus
    return int(janus.query_once("mm_dispatch_revoke(['outcome-test-failure'])")['truth'])
