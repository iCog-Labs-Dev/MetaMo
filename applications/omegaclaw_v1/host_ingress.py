"""Trusted ingress transport helpers; routing rules live in host_ingress.metta."""

import json
import re


# Example: correction: {"session":"s","commitment":"c","plan":"p","step":"2","revision":0,"path":"report.txt"}
def parse_correction(message):
    """Validate bounded correlation data; a proposed path carries no permission."""
    def unique_fields(pairs):
        result = dict(pairs)
        if len(result) != len(pairs):
            raise ValueError('duplicate correction field')
        return result

    try:
        data = json.loads(message.strip().partition(':')[2], object_pairs_hook=unique_fields)
        fields = {'session', 'commitment', 'plan', 'step', 'revision', 'path'}
        if not isinstance(data, dict) or set(data) != fields:
            return None
        for field in fields - {'revision'}:
            value = data[field]
            if (not isinstance(value, str) or not value.strip() or len(value) > 256
                    or any(ord(char) < 32 for char in value)):
                return None
            value.encode('utf-8')
        if type(data['revision']) is not int or not 0 <= data['revision'] <= 9007199254740991:
            return None
        return data
    except (ValueError, TypeError, UnicodeEncodeError, RecursionError):
        return None


# Example: only IRC's transport envelope turns 'Nahom: hello' into 'hello'.
def normalize_transport(message, channel):
    """Return sender/body or a Held reason without interpreting message content.

    Core joins IRC messages with an unescaped ' | '. Its flattened batches are
    ambiguous, including a single body containing that delimiter; hold the whole
    input rather than invent boundaries or apply partial lifecycle changes.
    """
    if classify_message(message) == 'InvalidInput':
        return '', '', 'InvalidInput'
    if channel != 'irc':
        return '', message, ''
    if ' | ' in message:
        return '', '', 'AmbiguousIrcBatch'
    sender, separator, body = message.partition(': ')
    if (not separator or not re.fullmatch(r'[A-Za-z\[\]\\`_^{|}][A-Za-z0-9\[\]\\`_^{|}-]*', sender)
            or '\r' in message or '\n' in message):
        return '', '', 'InvalidIrcEnvelope'
    if classify_message(body) == 'InvalidInput':
        return '', '', 'InvalidInput'
    return sender, body, ''


# Example: the live callback supplies commchannel; trusted internal ingest stays raw.
def ingest_transport(message, channel):
    sender, body, reason = normalize_transport(message, channel)
    if reason:
        return '(HostInput Held ' + reason + ')'
    return ingest(body, (str(channel), sender, message))


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
    kinds = {'follow-up': 'FollowUp', 'cancel': 'Cancel', 'replace': 'Replace',
             'correction': 'Correction'}
    if prefix.casefold() not in kinds or not separator:
        return 'NewTask'
    if prefix.casefold() == 'correction':
        return 'Correction' if parse_correction(message) is not None else 'InvalidInput'
    return kinds[prefix.casefold()] if body.strip() else 'InvalidInput'


# Example: ingest('follow-up: include examples') returns a quoted HostInput result.
def ingest(message, transport=None):
    """Serialize frame checks and updates with Core dispatch; never evaluate text."""
    kind = classify_message(message)
    if kind == 'InvalidInput':
        return '(HostInput Held InvalidInput)'
    import janus
    from host_dispatch_config import encode, record
    # Core may queue a new frame before selecting it after a completed task.
    # Correlate new input with the admitted identity, not the still-empty current slot.
    metadata = record('TransportInput', *(transport or ('host', '', message)))
    result = janus.query_once('''with_mutex(omegaclaw_dispatch, (
        sread(MessageSource, _Message), sread(KindSource, _Kind),
        sread(TransportSource, _Transport),
        eval(['get-state','&operation-context'], ['OperationContext',_Session,_,_]),
        eval(['get-state','&host-transport-input'], _PreviousTransport),
        (memberchk(_Kind, ['NewTask','Replace']), mm_dispatch_busy
         -> _Decision=['HostInput','Held','OutstandingInvocation']
         ; _Transport=['TransportInput',"irc",_Sender,_],
           commitmentSnapshot(['CommitmentSnapshot',_,_OwnerFrame,_,'Open',_]),
           _PreviousTransport=['HostTransportInput',_Session,_OwnerFrame,
                               ['TransportInput',"irc",_PreviousSender,_],_],
           string_lower(_Sender, _NormalizedSender),
           string_lower(_PreviousSender, _NormalizedPreviousSender),
           _NormalizedSender \\== _NormalizedPreviousSender
         -> _Decision=['HostInput','Held','SenderMismatch']
         ; eval([hostIngressDecision, [quote,_Kind]], _Decision)),
        eval([hostIngressApply, [quote,_Decision], [quote,_Message]], _Result),
        (_Result = ['HostInput',_Status|_], \+ memberchk(_Status, ['Held','CorrectionRecorded'])
         -> (_Kind == 'NewTask'
             -> eval(['get-state','&cfv2-last-admitted-frame-id'], _Frame)
             ; eval(['get-state','&cfv2-current-frame-id'], _Frame)),
            _Input=['HostResponseInput',_Frame,_Kind,_Message],
            _TransportInput=['HostTransportInput',_Session,_Frame,_Transport,_Message],
            eval(['get-state','&host-response-input'], _Previous),
            (_Previous == _Input, _PreviousTransport == _TransportInput -> true
             ; oc_dispatch_mutate((
                 eval(['change-state!','&host-response-input',[quote,_Input]], _),
                 eval(['change-state!','&host-transport-input',[quote,_TransportInput]], _))))
         ; true),
        swrite(_Result, Source)))''',
        {'MessageSource': encode(message), 'KindSource': kind,
         'TransportSource': encode(metadata)})
    if not result.get('truth', False):
        raise RuntimeError('host input routing failed')
    return result['Source']


# Example: a delayed correction cannot attach to a successor or changed plan revision.
def correct(decision, message):
    data = parse_correction(message) if classify_message(message) == 'Correction' else None
    if data is None:
        return '(HostInput Held InvalidInput)'
    import janus
    from host_dispatch_config import encode, record
    target = record('CorrectionTarget', *(data[key] for key in
                    ('session', 'commitment', 'plan', 'step', 'revision')))
    result = janus.query_once('''with_mutex(omegaclaw_dispatch, (
        sread(DecisionSource, _Decision), sread(TargetSource, _Target),
        sread(PathSource, _Path),
        (_Decision = ['HostInput','Correction',_Id,_Frame,_Revision],
         commitmentSnapshot(['CommitmentSnapshot',_Id,_Frame,_Revision,'Open',_]),
         eval(['get-state','&cfv2-current-frame-id'], _Frame)
         -> eval([hostCorrelateCorrection,[quote,_Target],[quote,_Path]], _Result)
         ; _Result=['HostInput','Held','StaleCommitment']),
        swrite(_Result, Source)))''',
        {'DecisionSource': decision, 'TargetSource': encode(target),
         'PathSource': encode(data['path'])})
    if not result.get('truth', False):
        raise RuntimeError('host correction correlation failed')
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
