"""Trusted ingress transport helpers; routing rules live in host_ingress.metta."""


# Example: classify_message('follow-up: use the second section') -> FollowUp.
def classify_message(message):
    """Recognize an explicit, bounded same-task marker without semantic guessing."""
    if not isinstance(message, str) or not message.strip() or len(message) > 4096:
        return 'InvalidInput'
    if '\x00' in message:
        return 'InvalidInput'
    try:
        message.encode('utf-8')
    except UnicodeEncodeError:
        return 'InvalidInput'
    prefix, separator, body = message.strip().partition(':')
    if prefix.casefold() != 'follow-up' or not separator:
        return 'NewTask'
    return 'FollowUp' if body.strip() else 'InvalidInput'


# Example: ingest('follow-up: include examples') returns a quoted HostInput result.
def ingest(message):
    """Serialize frame checks and updates with Core dispatch; never evaluate text."""
    kind = classify_message(message)
    if kind == 'InvalidInput':
        return '(HostInput Held InvalidInput)'
    import janus
    from host_dispatch_config import encode
    result = janus.query_once('''with_mutex(omegaclaw_dispatch, (
        sread(MessageSource, _Message), sread(KindSource, _Kind),
        eval([hostIngressDecision, [quote,_Kind]], _Decision),
        eval([hostIngressApply, [quote,_Decision], [quote,_Message]], _Result),
        swrite(_Result, Source)))''',
        {'MessageSource': encode(message), 'KindSource': kind})
    if not result.get('truth', False):
        raise RuntimeError('host input routing failed')
    return result['Source']


# Example: mutate('FollowUp', message) records data through Core's existing API.
def mutate(kind, message):
    """Called only from the locked host router; advance dispatch epoch on writes."""
    import janus
    from host_dispatch_config import encode
    handlers = {'FollowUp': 'cfv2-record-message-for-current-frame',
                'NewTask': 'ctx-ingest-user-message'}
    handler = handlers[kind]
    result = janus.query_once('''sread(MessageSource, _Message),
        oc_dispatch_mutate(once(eval([Handler, [quote,_Message]], _)))''',
        {'MessageSource': encode(message), 'Handler': handler})
    if not result.get('truth', False):
        raise RuntimeError('host input mutation failed')
    return 1
