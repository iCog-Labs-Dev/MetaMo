"""Host-owned temporary startup configuration; no providers or channels."""
import json
import os
from pathlib import Path
import host_config_fixture as files
import host_dispatch_config as host


def configure(variant='allowed', target='current-frame'):
    path = Path(files.write(variant))
    value = json.loads(path.read_text())
    value['frame_id'] = target
    path.write_text(json.dumps(value))
    os.environ["OMEGACLAW_HOST_CONFIG"] = str(path)
    return host.configure_startup(str(path))


def mismatched():
    configure(target='different-frame')
    try:
        host.provision_startup()
    except host.ConfigError:
        return 1
    return 0


# Example: a captured predecessor owner fails the install-time ownership recheck.
def stale_owner(source):
    try:
        host.provision_startup(expected_owner=source)
    except host.ConfigError:
        return 1
    return 0


# Example: removing operator configuration revokes previously automatic grants.
def disable():
    os.environ.pop('OMEGACLAW_HOST_CONFIG', None)
    return host.configure_startup()
