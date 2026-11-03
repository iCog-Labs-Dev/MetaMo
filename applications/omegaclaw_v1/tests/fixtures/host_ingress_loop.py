"""Only channel/provider boundaries are doubled for the real Core polling loop."""
_messages = iter(('Inspect the configured local file',
                  'follow-up: include examples', 'An unrelated request',
                  'replace: Summarize B',
                  'cancel: no longer needed'))
_observations = []


# Example: receive() supplies the next channel message without routing it.
def receive():
    return next(_messages, '')


# Example: observe() captures host state after selection, without a command model call.
def observe():
    import janus
    observation = janus.query_once('''
        eval([commitmentSnapshot], _Owner), swrite(_Owner, Owner),
        eval(['get-state','&last-host-input'], _Route), swrite(_Route, Route),
        eval(['get-state','&cfv2-current-frame-id'], _Frame), swrite(_Frame, Frame),
        eval(['get-state','&new-msg-flag'], Fresh)
    ''')
    _observations.append(observation)
    return 1


def provider(*args):
    raise AssertionError('Host-owned commands must not require model reproduction')


# Example: install() replaces provider transport, not ingestion or scheduling.
def install():
    import lib_llm_ext
    lib_llm_ext.callProvider = provider
    return 1


# Example: verified() checks retained ownership followed by explicit abandonment.
def verified():
    assert len(_observations) == 5, _observations
    first, followup, held, replaced, cancelled = _observations
    assert first['Owner'] == followup['Owner'] == held['Owner']
    assert ' Open ' in first['Owner']
    assert first['Frame'] == followup['Frame'] == held['Frame']
    assert first['Route'] == '(HostInput NewTask)'
    assert followup['Route'].startswith('(HostInput FollowUp ')
    assert held['Route'] == '(HostInput Held ExplicitFollowupRequired)'
    assert replaced['Owner'] != first['Owner']
    assert ' 0 Open "Summarize B"' in replaced['Owner']
    assert replaced['Frame'] == first['Frame']
    assert replaced['Route'].startswith('(HostInput Replaced ')
    assert cancelled['Owner'] == replaced['Owner'].replace(' 0 Open ', ' 1 Abandoned ')
    assert cancelled['Frame'] == first['Frame']
    assert cancelled['Route'].startswith('(HostInput Cancelled ')
    assert [row['Fresh'] for row in _observations] == ['true', 'true', 'false', 'true', 'false']
    return 1
