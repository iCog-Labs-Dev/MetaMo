"""Use the shipped IRC profile with real startup and mocked transport."""
import json
import os
from pathlib import Path


def configure(variant='allowed'):
    import host_config_fixture as files
    import host_dispatch_config as host
    profile = Path(__file__).resolve().parents[2] / 'host_dispatch.irc.example.json'
    config = json.loads(profile.read_text())
    if variant == 'mismatch':
        config['destination']['recipient'] = '#other'
    elif variant == 'read-only':
        config.pop('destination')
        config['commands'] = []
        for name in ('global', 'frame'):
            config[name]['skills'] = []
            config[name]['permissions'] = []
            config[name]['egress'] = []
    elif variant == 'denied':
        config['frame']['permissions'] = []
    elif variant != 'allowed':
        raise ValueError('unknown test variant')
    path = Path(files.write_irc('allowed'))
    path.write_text(json.dumps(config))
    os.environ['OMEGACLAW_HOST_CONFIG'] = str(path)
    return host.configure_startup(str(path))


def reject_mismatch():
    import host_dispatch_config as host
    configure('mismatch')
    try:
        host.provision_startup()
    except host.ConfigError as error:
        return int(str(error).startswith('StartupIrcDestinationMismatch:'))
    return 0
