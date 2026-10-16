"""Real IRC authentication/queue and host provenance; no sockets or providers."""


# Example: a rejected sender never reaches the transport queue.
def deliver(sender, body):
    import irc
    state = irc._is_allowed_message(sender, body)
    if state == 'allow':
        irc._set_last(f'{sender}: {body}')
    return state


# Example: set the same authentication secret consumed by the real receiver.
def authenticate():
    import irc
    irc._set_auth_secret('fixture-secret')
    return 1


# Example: check native session/frame identity and its admitted commitment together.
def provenance(sender, original, body):
    import janus
    result = janus.query_once('''
        eval(['get-state','&host-transport-input'], Transport),
        eval(['get-state','&operation-context'], ['OperationContext',Session,_,_]),
        commitmentSnapshot(['CommitmentSnapshot',_,Frame,_,'Open',_]),
        eval(['get-state','&host-response-input'], ['HostResponseInput',Frame,_,Body])
    ''')
    assert result['truth'], result
    assert result['Body'] == body, result
    assert result['Transport'] == ['HostTransportInput', result['Session'], result['Frame'],
        ['TransportInput', 'irc', sender, original], body], result
    return 1


# Example: changing sender without authentication cannot mutate another owner.
def allow_all():
    import irc
    irc._set_auth_secret('')
    return 1
