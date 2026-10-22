"""Two explicit real Core file reads with normal production host bindings."""
import json
import host_dispatch_config as host
import host_config_fixture as files
import host_requirements

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


# Example: existing configured reads traverse F3.2's production constructor in order.
def proposed_steps(count=2):
    paths = [_commands[i % len(_commands)][1] + (str(i) if count > 2 else '')
             for i in range(count)]
    proposal = host_requirements.read_request_result('Proposed', paths, 'ValidatedProposal')
    return host_requirements.construct_read_steps(proposal)


# Example: parsing a serialized command-like path must never evaluate its contents.
def inert_steps():
    proposal = host_requirements.read_request_result(
        'Proposed', ['(change-state! &error "ran")', 'a "quote" \\ naïve.txt'], 'ValidatedProposal')
    return host_requirements.construct_read_steps(proposal)


# Example: cwd-relative references resolve to the exact catalog command, retaining order.
def relative_steps():
    import os
    paths = [os.path.relpath(command[1]) for command in reversed(_commands)]
    proposal = host_requirements.read_request_result('Proposed', paths, 'ValidatedProposal')
    return host_requirements.construct_read_steps(proposal)


# Example: different spellings of the same file must not create duplicate reads.
def aliased_steps():
    from pathlib import Path
    path = Path(_commands[0][1])
    paths = [str(path), str(path.parent) + '/./' + path.name]
    return host_requirements.construct_read_steps(
        host_requirements.read_request_result('Proposed', paths, 'ValidatedProposal'))


# Example: an unconfigured symlink cannot borrow its target's catalog binding.
def symlink_steps():
    from pathlib import Path
    link = Path(_commands[0][1]).with_name('alias.txt')
    link.symlink_to(_commands[0][1])
    return host_requirements.construct_read_steps(
        host_requirements.read_request_result('Proposed', [str(link)], 'ValidatedProposal'))


# Example: each denial is installed through the real configuration API, then restored.
def admission_config(scope, variant):
    data = host.read_config(_config_path)
    if variant == 'permission':
        data[scope]['permissions'].remove('files.read:' + _commands[1][1])
    elif variant == 'skill':
        data[scope]['skills'].remove('read-file')
    elif variant == 'budget':
        data[scope]['budgets'][0]['available'] = 0
    elif variant == 'constraint':
        data[scope]['constraints'].append(['DenySkill', 'read-file'])
    elif variant == 'unsupported':
        data['commands'] = [row for row in data['commands'] if row['arguments'] != [_commands[1][1]]]
    else:
        raise ValueError('unknown admission variant')
    path = _config_path + '.admission.json'
    with open(path, 'w', encoding='utf-8') as stream:
        json.dump(data, stream)
    return path


def command(index):
    return host.encode(_commands[index])


def deny_second():
    data = host.read_config(_config_path)
    data['frame']['permissions'].remove('files.read:' + _commands[1][1])
    with open(_config_path, 'w', encoding='utf-8') as stream:
        json.dump(data, stream)
    return _config_path


# Example: an uncertain Core ledger entry still blocks installation after selection clears.
def uncertain_invocation(enabled):
    import janus
    if enabled:
        query = '''assertz(oc_dispatch_result(['DispatchTicket',"f34-uncertain"],
                   ['read-file',"fixture"],
                   ['DispatchResult','Unobserved','ExecutionUncertain',none]))'''
    else:
        query = 'retractall(oc_dispatch_result([\'DispatchTicket\',"f34-uncertain"],_,_))'
    return int(janus.query_once(query)['truth'])


# Example: an allowed but unrequested file must never displace a pending plan read.
def with_unrequested_read():
    from pathlib import Path
    data = host.read_config(_config_path)
    extra = Path(_config_path).with_name('unrequested.txt')
    extra.write_text('unrequested content', encoding='utf-8')
    data['allowed_files'].append(str(extra))
    data['commands'].insert(0, {'skill': 'read-file', 'arguments': [str(extra)]})
    for scope in ('global', 'frame'):
        data[scope]['permissions'].append('files.read:' + str(extra))
    path = _config_path + '.unrequested.json'
    Path(path).write_text(json.dumps(data), encoding='utf-8')
    return path


_response_calls = 0
_response_mode = 'answer'


# Example: configure a local answer destination, retaining the real read catalog.
def enable_answers(mode='answer'):
    import lib_llm_ext
    global _response_mode
    _response_mode = mode
    data = host.read_config(_config_path)
    data['destination'] = {'channel': 'local', 'recipient': 'stdout'}
    data['completion_criterion'] = 'LocalAccepted'
    for scope in ('global', 'frame'):
        data[scope]['skills'].append('send')
        data[scope]['permissions'].extend(['channels.send', 'channels.send:local:stdout'])
        data[scope]['egress'] = ['local:stdout']
    if mode == 'denied':
        data['frame']['egress'] = []
    path = _config_path + '.answers.json'
    from pathlib import Path
    Path(path).write_text(json.dumps(data), encoding='utf-8')
    host.configure_startup(path)
    host.provision_startup()
    lib_llm_ext.PROMPT_DELIMITER = ':-:-:-:'
    lib_llm_ext.callProvider = answer_provider
    return 1


# Example: verify both actual observations reached preparation; never synthesize read evidence.
def answer_provider(provider, prompt, max_tokens):
    global _response_calls
    _response_calls += 1
    assert provider == 'Offline' and max_tokens == 1024
    payload = json.loads(prompt.split(':-:-:-:', 1)[1])
    assert payload['observations'] == [
        {'path': _commands[1][1], 'content': 'other content'},
        {'path': _commands[0][1], 'content': 'changed after invocation'}]
    if _response_mode == 'no-action':
        return '{"no_action":true}'
    if _response_mode == 'stale':
        import janus
        janus.query_once("oc_dispatch_mutate(eval(['change-state!','&host-response-input',"
                         "['HostResponseInput',\"configured-frame\",'FollowUp',\"new question\"]],_))")
    return '{"text":"Both files: other content; changed after invocation."}'


# Example: idle cycles and incomplete evidence never invoke preparation again.
def response_calls():
    return _response_calls


# Example: one allowed prefix cannot authorize a plan containing an unconfigured file.
def unallowed_steps():
    paths = [_commands[0][1], _commands[1][1] + '.unallowed']
    return host_requirements.construct_read_steps(
        host_requirements.read_request_result('Proposed', paths, 'ValidatedProposal'))


# Example: rejected admission/installation must not create any Core invocation result.
def dispatch_result_count():
    import janus
    return janus.query_once('aggregate_all(count, oc_dispatch_result(_,_,_), Count)')['Count']
