"""Only channel/provider boundaries are doubled for the real Core polling loop."""
_messages = iter(('Inspect the configured local file',
                  'follow-up: include examples', 'An unrelated request',
                  'cancel: no longer needed'))
_observations = []


# Example: receive() supplies the next channel message without routing it.
def receive():
    return next(_messages, '')


# Example: provider() captures the host result after the real loop's preparation.
def provider(*args):
    import janus
    observation = janus.query_once('''
        eval([commitmentSnapshot], _Owner), swrite(_Owner, Owner),
        eval(['get-state','&last-host-input'], _Route), swrite(_Route, Route),
        eval(['get-state','&cfv2-current-frame-id'], _Frame), swrite(_Frame, Frame),
        eval(['get-state','&new-msg-flag'], Fresh)
    ''')
    _observations.append(observation)
    return '()'


# Example: install() replaces provider transport, not ingestion or scheduling.
def install():
    import lib_llm_ext
    lib_llm_ext.callProvider = provider
    return 1


# Example: verified() checks retained ownership followed by explicit abandonment.
def verified():
    assert len(_observations) == 4, _observations
    first, followup, held, cancelled = _observations
    assert first['Owner'] == followup['Owner'] == held['Owner']
    assert ' Open ' in first['Owner']
    assert first['Frame'] == followup['Frame'] == held['Frame']
    assert first['Route'] == '(HostInput NewTask)'
    assert followup['Route'].startswith('(HostInput FollowUp ')
    assert held['Route'] == '(HostInput Held ExplicitFollowupRequired)'
    assert cancelled['Owner'] == first['Owner'].replace(' 0 Open ', ' 1 Abandoned ')
    assert cancelled['Frame'] == first['Frame']
    assert cancelled['Route'].startswith('(HostInput Cancelled ')
    assert [row['Fresh'] for row in _observations] == ['true', 'true', 'false', 'false']
    return 1
