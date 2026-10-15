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
    kinds = {'follow-up': 'FollowUp', 'cancel': 'Cancel', 'replace': 'Replace'}
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
        (memberchk(_Kind, ['NewTask','Replace']), mm_dispatch_busy
         -> _Decision=['HostInput','Held','OutstandingInvocation']
         ; eval([hostIngressDecision, [quote,_Kind]], _Decision)),
        eval([hostIngressApply, [quote,_Decision], [quote,_Message]], _Result),
        swrite(_Result, Source)))''',
        {'MessageSource': encode(message), 'KindSource': kind})
    if not result.get('truth', False):
        raise RuntimeError('host input routing failed')
    return result['Source']


# Example: cancel(decision, 'cancel: no longer needed') records abandonment.
def cancel(decision, message):
    if classify_message(message) != 'Cancel':
        return '(HostInput Held InvalidInput)'
    from host_dispatch_config import record
    reason = message.strip().partition(':')[2].strip()
    return apply_transition(decision, 'Cancel', record('Abandoned', reason))


# Example: replace(decision, 'replace: summarize B') creates a distinct successor.
def replace(decision, message):
    if classify_message(message) != 'Replace':
        return '(HostInput Held InvalidInput)'
    from uuid import uuid4
    from host_dispatch_config import record
    summary = message.strip().partition(':')[2].strip()
    change = record('Superseded', str(uuid4()), summary, 'Explicit user replacement')
    return apply_transition(decision, 'Replace', change)


# Example: a stale decision cannot abandon or supersede the new current owner.
def apply_transition(decision, kind, change):
    """Apply the event and revoke predecessor work while holding the dispatch lock."""
    import janus
    from uuid import uuid4
    from host_dispatch_config import encode
    result = janus.query_once('''with_mutex(omegaclaw_dispatch, (
        sread(DecisionSource, _Decision), sread(KindSource, _Kind),
        sread(EventSource, _EventId), sread(ChangeSource, _Change),
        (_Kind == 'Replace', mm_dispatch_busy
         -> _Result = ['HostInput','Held','OutstandingInvocation']
         ; _Decision = ['HostInput',_Kind,_Id,_Frame,_Revision],
         commitmentSnapshot(['CommitmentSnapshot',_Id,_Frame,_Revision,'Open',_]),
         eval(['get-state','&cfv2-current-frame-id'], _Current), _Current == _Frame
         -> mm_commitment_apply(
              ['CommitmentEvent',_EventId,_Id,_Revision,_Change],
              ['CommitmentApplied',_EventId,_Id,_Status,_Next]),
            findall(_Command,
              (mm_dispatch_binding(_Command,_,_Operation),
               memberchk([target,_Frame],_Operation)), _Commands),
            maplist(mm_dispatch_revoke, _Commands),
            eval(['change-state!','&prepared-host-operation',[]], _),
            (_Status == 'Abandoned'
             -> _Result = ['HostInput','Cancelled',_Id,_Frame,_Next]
             ; _Change = ['Superseded',_Successor,_,_],
               _Result = ['HostInput','Replaced',_Id,_Successor,_Frame,0])
         ; _Result = ['HostInput','Held','StaleCommitment']),
        swrite(_Result, Source)))''',
        {'DecisionSource': decision, 'KindSource': kind,
         'EventSource': encode(str(uuid4())), 'ChangeSource': encode(change)})
    if not result.get('truth', False):
        raise RuntimeError('host lifecycle transition failed')
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
