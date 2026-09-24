"""Two explicit real Core file reads with normal production host bindings."""
import json
import host_dispatch_config as host
import host_config_fixture as files

_config_path = None
_commands = None


def setup():
    global _config_path, _commands
    files.setup()
    _config_path = files.write('ambiguous')
    data = host.read_config(_config_path)
    _commands = [host.record(row['skill'], *row['arguments'])
                 for row in data['commands'] if row['skill'] == 'read-file']
    return _config_path


def plan():
    return host.encode([host.record('ExecutionStep', str(i + 1), command)
                        for i, command in enumerate(_commands)])


def command(index):
    return host.encode(_commands[index])


def deny_second():
    data = host.read_config(_config_path)
    data['frame']['permissions'].remove('files.read:' + _commands[1][1])
    with open(_config_path, 'w', encoding='utf-8') as stream:
        json.dump(data, stream)
    return _config_path
