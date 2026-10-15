"""Only channel/provider boundaries are doubled for the real Core polling loop."""
_messages = iter(('Inspect the configured local file',
                  'follow-up: include examples', 'An unrelated request'))
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


# Example: verified() checks that all three loop turns retain the same open owner.
def verified():
    assert len(_observations) == 3, _observations
    first, followup, held = _observations
    assert first['Owner'] == followup['Owner'] == held['Owner']
    assert ' Open ' in first['Owner']
    assert first['Frame'] == followup['Frame'] == held['Frame']
    assert first['Route'] == '(HostInput NewTask)'
    assert followup['Route'].startswith('(HostInput FollowUp ')
    assert held['Route'] == '(HostInput Held ExplicitFollowupRequired)'
    assert [row['Fresh'] for row in _observations] == ['true', 'true', 'false']
    return 1
