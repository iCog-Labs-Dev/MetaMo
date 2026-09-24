"""Controlled provider responses and file bindings; real host admission/dispatch."""
import host_dispatch_config as host
import host_config_fixture as files
_config = None


def setup():
    global _config
    _config = host.read_config(files.setup())
    return 1


def provision(frame, denied=False):
    import copy
    import janus
    config = copy.deepcopy(_config)
    frame = host.Symbol(frame)
    config['frame_id'] = frame
    if denied:
        config['frame']['permissions'] = []
    row = host.binding(config['commands'][0], frame, config['allowed_files'])
    row[2][-1] = host.Symbol('respond')
    row[3][1] = host.record('candidate', host.Symbol('respond'))
    source = host.encode(host.record(
        'HostDispatchConfig', host.scope(config['global'], host.Symbol('Global')),
        host.scope(config['frame'], host.record('FrameTarget', frame)), [row]))
    return int(janus.query_once(host._INSTALL, {'Source': source}).get('truth', False))
