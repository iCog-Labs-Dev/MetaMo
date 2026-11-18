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


# Example: exercise the same startup idle provisioning branch as the live loop.
def provision_idle(variant="allowed"):
    host.configure_startup(files.write_idle(variant))
    host.provision_admitted_task()
    return 1


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
    elif variant not in ('allowed', 'empty', 'interactive', 'maintenance', 'maintenance-denied', 'maintenance-budget',
                         'maintenance-interactive', 'maintenance-restructure'):
        raise ValueError('unknown policy variant')
    row = host.binding(config['commands'][0], frame, config['allowed_files'])
    row[2][-1] = host.Symbol('respond')
    row[3][1] = host.record('candidate', host.Symbol('respond'))
    rows = [row]
    if variant.startswith('maintenance'):
        operation = 'memory-compression' if variant == 'maintenance-restructure' else 'memory-rent'
        for scope in ('global', 'frame'):
            config[scope]['skills'].append('host-maintenance')
            config[scope]['permissions'].append('maintenance.' + operation)
        if variant == 'maintenance-denied':
            config['frame']['permissions'].remove('maintenance.memory-rent')
        if variant == 'maintenance-budget':
            config['frame']['budgets'][0]['available'] = 0
        rows = [host.binding(dict(skill='host-maintenance', arguments=[operation]), frame, [])]
        if variant == 'maintenance-interactive':
            rows.insert(0, row)
    if variant == 'interactive':
        other = host.binding(config['commands'][1], frame, config['allowed_files'])
        other[2][-1] = host.Symbol('ask-clarification')
        other[3][1] = host.record('candidate', host.Symbol('ask-clarification'))
        rows.append(other)
    source = host.encode(host.record(
        'HostDispatchConfig', host.scope(config['global'], host.Symbol('Global')),
        host.scope(config['frame'], host.record('FrameTarget', frame)),
        [] if variant == 'empty' else rows))
    return int(janus.query_once(host._INSTALL, {'Source': source, 'CompletionSource': host.completion_policy(config)}).get('truth', False))


def revoke_failure_handler():
    import janus
    return int(janus.query_once("mm_dispatch_revoke(['outcome-test-failure'])")['truth'])
