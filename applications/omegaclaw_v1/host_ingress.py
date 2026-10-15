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
    kinds = {'follow-up': 'FollowUp', 'cancel': 'Cancel'}
    if prefix.casefold() not in kinds or not separator:
        return 'NewTask'
    return kinds[prefix.casefold()] if body.strip() else 'InvalidInput'


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


# Example: cancel('(HostInput Cancel "c1" frame-1 0)', 'cancel: no longer needed').
def cancel(decision, message):
    """Recheck ownership, abandon, and revoke pending work under the dispatch lock."""
    if classify_message(message) != 'Cancel':
        return '(HostInput Held InvalidInput)'
    import janus
    from uuid import uuid4
    from host_dispatch_config import encode
    result = janus.query_once('''with_mutex(omegaclaw_dispatch, (
        sread(DecisionSource, _Decision),
        sread(EventSource, _EventId), sread(ReasonSource, _Reason),
        (_Decision = ['HostInput','Cancel',_Id,_Frame,_Revision],
         commitmentSnapshot(['CommitmentSnapshot',_Id,_Frame,_Revision,'Open',_]),
         eval(['get-state','&cfv2-current-frame-id'], _Current), _Current == _Frame
         -> mm_commitment_apply(
              ['CommitmentEvent',_EventId,_Id,_Revision,['Abandoned',_Reason]],
              ['CommitmentApplied',_EventId,_Id,'Abandoned',_Next]),
            findall(_Command,
              (mm_dispatch_binding(_Command,_,_Operation),
               memberchk([target,_Frame],_Operation)), _Commands),
            maplist(mm_dispatch_revoke, _Commands),
            eval(['change-state!','&prepared-host-operation',[]], _),
            _Result = ['HostInput','Cancelled',_Id,_Frame,_Next]
         ; _Result = ['HostInput','Held','StaleCommitment']),
        swrite(_Result, Source)))''',
        {'DecisionSource': decision, 'EventSource': encode(str(uuid4())),
         'ReasonSource': encode(message.strip().partition(':')[2].strip())})
    if not result.get('truth', False):
        raise RuntimeError('host cancellation failed')
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
