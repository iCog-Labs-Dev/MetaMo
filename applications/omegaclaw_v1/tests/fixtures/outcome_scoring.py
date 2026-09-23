"""Test-only bindings: local readers stand in for Interactive execution effects.

Reuse the existing validated, atomic host installer. This does not extend the
production handler catalog or claim live response/clarification support.
"""
import host_dispatch_config as host
import host_config_fixture


def provision():
    import janus
    config = host.read_config(host_config_fixture.setup())
    bindings = []
    for command, candidate in zip(config['commands'], ('respond', 'ask-clarification')):
        row = host.binding(command, config['frame_id'], config['allowed_files'])
        row[2][-1] = host.Symbol(candidate)
        row[3][1] = host.record('candidate', host.Symbol(candidate))
        bindings.append(row)
    source = host.encode(host.record(
        'HostDispatchConfig', host.scope(config['global'], host.Symbol('Global')),
        host.scope(config['frame'], host.record('FrameTarget', config['frame_id'])),
        bindings))
    result = janus.query_once(host._INSTALL, {'Source': source})
    if not result.get('truth', False):
        raise RuntimeError('test host bindings rejected')
    return 1
