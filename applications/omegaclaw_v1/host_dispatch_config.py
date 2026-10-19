"""Trusted session configuration for Core inspection and send bindings.

Not a model skill. Call provision from trusted host code after initMetaMoDispatch.
The host owns this file and the configured filesystem paths throughout the session.
Only command-count costs are modeled here; reservation/settlement is separate.
"""
import json
import ipaddress
from pathlib import Path
import re
import stat


class ConfigError(ValueError):
    pass


class Symbol(str):
    """Internal closed-vocabulary MeTTa symbol; configuration cannot create one."""


def record(tag, *fields):
    return [Symbol(tag), *fields]


def encode(value):
    if isinstance(value, Symbol):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if type(value) is int:
        return str(value)
    if isinstance(value, list):
        return "(" + " ".join(encode(item) for item in value) + ")"
    raise ConfigError("unsupported configuration value")


def keys(value, required, optional=()):
    if (not isinstance(value, dict) or not set(required).issubset(value)
            or not set(value).issubset(set(required) | set(optional))):
        raise ConfigError("expected required fields: " + ", ".join(required)
                          + "; optional fields: " + ", ".join(optional))


def identifier(value):
    if (not isinstance(value, str) or not value.strip() or len(value) > 256
            or any(ord(char) < 32 for char in value)):
        raise ConfigError("expected a nonempty identifier of at most 256 characters")
    return value


def quantity(value):
    if type(value) is not int or not 0 <= value <= 9007199254740991:
        raise ConfigError("resource amounts must be nonnegative safe integers")
    return value


def items(value):
    if not isinstance(value, list) or len(value) > 128:
        raise ConfigError("expected a list of at most 128 entries")
    return value


def identifiers(value):
    result = [identifier(item) for item in items(value)]
    if len(result) != len(set(result)):
        raise ConfigError("duplicate identifier")
    return result


def constraint(value):
    if not isinstance(value, list) or not value:
        raise ConfigError("invalid constraint")
    name = value[0]
    if name in ("DenySkill", "RequirePermission", "DenyEgress") and len(value) == 2:
        return record(name, identifier(value[1]))
    if name == "MaxCost" and len(value) == 4:
        return record(name, identifier(value[1]), identifier(value[2]), quantity(value[3]))
    raise ConfigError("unsupported or malformed constraint")


def scope(value, target):
    keys(value, ("skills", "permissions", "egress", "constraints", "budgets"))
    budgets = []
    seen = set()
    for budget in items(value["budgets"]):
        keys(budget, ("resource", "unit", "available", "status"))
        resource = identifier(budget["resource"])
        if resource in seen:
            raise ConfigError("duplicate resource budget")
        seen.add(resource)
        if budget["status"] not in ("Open", "Closed", "Exhausted"):
            raise ConfigError("unsupported budget status")
        budgets.append(record("ResourceBudget", resource, identifier(budget["unit"]),
                              quantity(budget["available"]), Symbol(budget["status"])))
    return record("PolicyScope", record("target", target),
                  record("skills", identifiers(value["skills"])),
                  record("permissions", identifiers(value["permissions"])),
                  record("egress", identifiers(value["egress"])),
                  record("constraints", [constraint(c) for c in items(value["constraints"])]),
                  record("budgets", budgets))


def allowed_file(value):
    name = identifier(value)
    path = Path(name)
    if not path.is_absolute() or str(path.resolve(strict=True)) != name:
        raise ConfigError("allowed files must use canonical absolute paths without symlinks")
    if not stat.S_ISREG(path.stat().st_mode):
        raise ConfigError("allowed file is not a regular file")
    return name


def destination_metadata(value):
    """Resolve explicit destination data to requirements, never permission grants.

    IRC routing must use this same normalization at the dispatch boundary (F1.11).
    IRC metadata alone does not enable network dispatch.
    """
    keys(value, ("channel", "recipient"), optional=("server", "port"))
    channel = identifier(value["channel"])
    recipient = identifier(value["recipient"])
    if channel == "irc":
        keys(value, ("channel", "recipient", "server", "port"))
        server = identifier(value["server"]).lower()
        # A bounded ASCII DNS name or canonical IPv4 literal. No URL, wildcard,
        # credentials, implicit port, DNS lookup or server-specific case mapping.
        labels = server.split(".")
        if (len(server) > 253 or any(not re.fullmatch(
                r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label) for label in labels)):
            raise ConfigError("IRC server must be an ASCII DNS name or IPv4 address")
        if re.fullmatch(r"[0-9.]+", server):
            try:
                server = str(ipaddress.IPv4Address(server))
            except ipaddress.AddressValueError as exc:
                raise ConfigError("invalid IRC IPv4 address") from exc
        port = value["port"]
        if type(port) is not int or not 1 <= port <= 65535:
            raise ConfigError("IRC port must be an integer from 1 to 65535")
        # Mirror Core start_irc's optional # prefix. Preserve channel spelling:
        # do not assume the connected server's IRC casemapping rules.
        if not recipient.startswith("#"):
            recipient = "#" + recipient
        if len(recipient) > 50 or not re.fullmatch(r"#[A-Za-z0-9_#.-]+", recipient):
            raise ConfigError("IRC recipient must be a bounded #channel name")
        egress = identifier("irc:" + server + ":" + str(port) + ":" + recipient)
        permission = identifier("channels.send:" + egress)
        return record("HostDestination", record("channel", channel),
                      record("recipient", recipient), record("server", server),
                      record("port", port),
                      record("permissions", ["channels.send", permission]),
                      record("egress", [egress]))
    keys(value, ("channel", "recipient"))
    if channel != "local" or recipient != "stdout":
        raise ConfigError("unsupported destination; expected local/stdout or IRC channel")
    return record("HostDestination", record("channel", channel),
                  record("recipient", recipient),
                  record("permissions", ["channels.send", "channels.send:local:stdout"]),
                  record("egress", ["local:stdout"]))


def validate_send_text(text):
    """Shared bounds for configured and prepared send text; no execution."""
    if (type(text) is not str or not text.strip() or len(text) > 1200
            or any(ord(c) < 32 and c not in "\n\t" for c in text)):
        raise ConfigError("send requires nonblank text of at most 1200 characters")
    return text


def binding(command, frame_id, allowed_files, destination=None):
    keys(command, ("skill", "arguments"), optional=("candidate",))
    skill = command["skill"]
    arguments = items(command["arguments"])
    egress = []
    if skill == "read-file":
        if len(arguments) != 1 or arguments[0] not in allowed_files:
            raise ConfigError("read-file requires one explicitly allowed canonical path")
        candidate = "execute-skill"
        permissions = ["files.read", "files.read:" + arguments[0]]
        # Permission identifiers obey the same bounds as the typed policy gate.
        for permission in permissions:
            identifier(permission)
    elif skill == "show-current-frame":
        if arguments:
            raise ConfigError("show-current-frame accepts no arguments")
        candidate = "search-knowledge"
        permissions = ["frames.read"]
    elif skill == "send":
        if len(arguments) != 1:
            raise ConfigError("send requires one text argument")
        validate_send_text(arguments[0])
        metadata = dict(destination_metadata(destination)[1:])
        candidate = "respond"
        permissions = metadata["permissions"]
        egress = metadata["egress"]
    else:
        raise ConfigError("unsupported skill")
    # An explicit candidate selects only a catalog-approved mapping. Omission
    # preserves existing defaults; it cannot change handler requirements.
    supported_candidates = ("respond", "ask-clarification") if skill == "send" else (candidate,)
    candidate = command.get("candidate", candidate)
    if type(candidate) is not str or candidate not in supported_candidates:
        raise ConfigError("unsupported candidate/handler mapping")
    # Requirements come from the trusted catalog, never command-supplied grants.
    # One invocation costs one command unit, not tokens/bytes or settled usage.
    operation = record("PolicyOperation", record("candidate", Symbol(candidate)),
                       record("target", frame_id), record("skill", skill),
                       record("permissions", permissions), record("egress", egress),
                       record("costs", [record("ResourceCost", "commands", "units", 1)]))
    request = record("AdmissionRequest", Symbol("propose-candidate"),
                     Symbol("current-frame"), Symbol(candidate))
    return record("HostCommandBinding", record(skill, *arguments), request, operation)


def build_config(value):
    """Build typed data only. No policy is inferred from model text or defaults."""
    keys(value, ("version", "frame_id", "allowed_files", "global", "frame", "commands"),
         optional=("destination",))
    if type(value["version"]) is not int or value["version"] != 1:
        raise ConfigError("unsupported host configuration version")
    # Optional for existing read-only configurations, but never default a
    # supplied incomplete/null destination. Validate before any installation.
    # Declaring a destination alone must not add grants or executable work.
    if "destination" in value:
        destination_metadata(value["destination"])
    frame_id = identifier(value["frame_id"])
    files = [allowed_file(path) for path in identifiers(value["allowed_files"])]
    global_scope = scope(value["global"], Symbol("Global"))
    frame_scope = scope(value["frame"], record("FrameTarget", frame_id))
    bindings = [binding(command, frame_id, files, value.get("destination"))
                for command in items(value["commands"])]
    encoded_commands = [encode(row[1]) for row in bindings]
    if len(set(encoded_commands)) != len(encoded_commands):
        raise ConfigError("duplicate command binding")
    return encode(record("HostDispatchConfig", global_scope, frame_scope, bindings))


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ConfigError("duplicate JSON key: " + key)
        result[key] = value
    return result


def read_config(path):
    path = Path(path)
    if not path.is_absolute():
        raise ConfigError("host configuration path must be absolute")
    with path.open(encoding="utf-8") as stream:
        data = stream.read(65537)
    if len(data.encode("utf-8")) > 65536:
        raise ConfigError("host configuration exceeds 64 KiB")
    return json.loads(data, object_pairs_hook=unique_object)


# Constant bridge to existing host APIs, not generated executable model code.
# Native parsing ensures command strings match Core's parsed command arguments.
# Validate every record before one atomic replacement under the dispatch lock.
_INSTALL = """
sread(Source, _Parsed), _Parsed = ['HostDispatchConfig', _Global, _Frame, _Bindings],
oc_dispatch_hooks(mm_dispatch_snapshot, mm_dispatch_resolve, mm_dispatch_gate, mm_dispatch_execute),
_Frame = ['PolicyScope', [target, _Target]|_],
eval([tpScopeValid, [quote, _Global], 'Global'], true),
eval([tpScopeValid, [quote, _Frame], [quote, _Target]], true),
forall(member(['HostCommandBinding', _Command, _Request, _Operation], _Bindings),
       (ground(_Command-_Request-_Operation), eval([tpOperationValid, [quote, _Operation]], true))),
oc_dispatch_mutate(transaction((
    mm_dispatch_set_policies(_Global, _Frame),
    retractall(mm_dispatch_binding(_, _, _)),
    forall(member(['HostCommandBinding', _Command, _Request, _Operation], _Bindings),
           mm_dispatch_register(_Command, _Request, _Operation)),
    retractall(mm_dispatch_owner(_)),
    (var(_InstallOwner) -> true ; assertz(mm_dispatch_owner(_InstallOwner)))
)))
"""


def provision(path):
    """Replace this session's policies/bindings; raise on any setup failure.

    Call only from trusted host startup/admission code. No module import, model
    output, or environment variable automatically installs permission grants.
    """
    config = read_config(path)
    source = build_config(config)
    import janus
    result = janus.query_once(_INSTALL, {"Source": source})
    if not result.get("truth", False):
        raise ConfigError("host configuration rejected; load composition and initialize dispatch first")
    return encode(record("HostDispatchConfigured", config["frame_id"], len(config["commands"])))


_startup_config = None
_startup_installed = False
_startup_checked = False


# Example: automatic preparation uses only the explicitly configured destination.
def response_destination():
    import copy
    return copy.deepcopy((_startup_config or {}).get('destination'))


def startup_channel_diagnostics(config, channel, route=None):
    """Check recorded configuration against Core; never grant or send anything.

    Called before first-frame installation, after Core has configured channels.
    Diagnostics contain fixed instructions, never configuration values/secrets.
    Read-only profiles remain valid; missing reply setup is informational.
    Final feasibility, connection availability and route freshness belong to Core.
    """
    destination = config.get('destination') if config else None
    expected = dict(destination_metadata(destination)[1:]) if destination else None
    if expected and expected['channel'] != channel:
        raise ConfigError('StartupChannelMismatch: match host destination.channel to Core commchannel; no policy installed')
    if channel != 'irc':
        return []
    if expected:
        try:
            actual = dict(destination_metadata(dict(channel='irc', server=route['server'],
                          port=route['port'], recipient=route['recipient']))[1:])
        except (ConfigError, KeyError, TypeError):
            raise ConfigError('StartupIrcRouteUnavailable: initialize the matching Core IRC adapter before policy installation') from None
        if actual['egress'] != expected['egress']:
            raise ConfigError('StartupIrcDestinationMismatch: match host server, port and recipient to the Core IRC route; no policy installed')
    if config is None:
        return ['MissingReplyPolicy: supply --host-config /absolute/path/host.json to enable explicitly authorized replies; dispatch remains closed']
    if expected is None:
        return ['MissingReplyDestination: read-only profile retained; add an explicit IRC destination, both-scope send policy and reply binding to enable replies']
    diagnostics = []
    for name in ('global', 'frame'):
        policy = config[name]
        if ('send' not in policy['skills']
                or not set(expected['permissions']) <= set(policy['permissions'])
                or not set(expected['egress']) <= set(policy['egress'])):
            diagnostics.append('MissingReplyPolicy: explicitly configure send skill, generic and destination-specific permissions, and exact egress in the ' + name + ' scope; no grants added')
    if not any(row['skill'] == 'send' and row.get('candidate', 'respond') == 'respond'
               for row in config['commands']):
        diagnostics.append('MissingReplyBinding: configure an exact respond/send command or queue a trusted prepared reply; automatic preparation requires a validated conversational task')
    return diagnostics


def configure_startup(path=None):
    """Read trusted startup configuration once, before starting external services.

    frame_id="current-frame" is a template for admitted task owners. A concrete
    ID stays pinned to that frame. Arbitrary frame switches never retarget grants.
    """
    import os
    global _startup_config, _startup_installed, _startup_checked
    selected = path if path is not None else os.environ.get('OMEGACLAW_HOST_CONFIG')
    config = read_config(selected) if selected else None
    if config is not None:
        build_config(config)
    _startup_config = config
    _startup_installed = False
    _startup_checked = False
    return 1


# Example: after confirmed completion, archive its matching Core frame once.
def complete_host_frame():
    """Reconcile terminal commitment bookkeeping before admitting the next task."""
    import janus
    result = janus.query_once('mm_commitment_complete_frame(_Result), swrite(_Result, Source)')
    if not result.get('truth', False):
        raise ConfigError('host frame completion failed')
    return result['Source']


def admit_startup_commitment():
    """Open a commitment for Core's admitted current user frame.

    Called by prepareHostStartup after ingestion, before selection. For example,
    an Active UserDirective returns CommitmentOpened; idle polling retains it.
    Read native IDs inside Prolog so symbol/string identity survives Janus.
    Rejections and repeated polling do not mutate state or invalidate tickets.
    """
    import janus
    import uuid
    result = janus.query_once('''with_mutex(omegaclaw_dispatch, (
        (mm_dispatch_busy
         -> _Result=['CommitmentRejected','OutstandingInvocation']
         ; eval(['get-state','&cfv2-current-frame-id'], _Frame),
         mm_commitment_frame_id(_Frame),
         eval(['get-state','&cfv2-last-admitted-frame-id'], _Admitted), _Frame == _Admitted,
         eval(['get-state','&cfv2-current-source'], 'UserDirective'),
         eval(['get-state','&cfv2-current-status'], _Status),
         memberchk(_Status, ['Active','Focused']),
         eval(['get-state','&cfv2-current-deliverables'], [_Summary|_]),
         mm_commitment_text(_Summary)
         -> (mm_commitment_current(_Id), mm_commitment(_Id,_Frame,_,_,_)
             -> _Result=['CommitmentRetained',_Id]
             ; mm_commitment_current(_Id), mm_commitment(_Id,_,_,'Open',_)
             -> _Result=['CommitmentRejected','ActiveCommitmentExists']
             ; mm_commitment(_Id,_Frame,_,_,_)
             -> _Result=['CommitmentRetained',_Id]
             ; sread(NewIdSource, _NewId),
               mm_commitment_open(_NewId,_Frame,_Summary,_Result))
         ; _Result=['CommitmentAdmissionSkipped','NoAdmittedUserFrame']),
        swrite(_Result, Source)))''', {'NewIdSource': encode(str(uuid.uuid4()))})
    if not result.get('truth', False):
        raise ConfigError('host commitment admission failed')
    return result['Source']


# Example: an unchanged owner retains tickets; a replacement receives fresh bindings.
def provision_admitted_task():
    """Install only for an admitted open owner, rechecked atomically at installation."""
    import janus
    current = janus.query_once('''with_mutex(omegaclaw_dispatch, (
        (mm_dispatch_busy -> State='OutstandingInvocation', Source=''
         ; mm_dispatch_task_owner(_Owner)
         -> swrite(_Owner, Source),
            (mm_dispatch_owner(_Prior), _Prior == _Owner
             -> State='Retained'
             ; State='Ready')
         ; State='NoAdmittedCommitment', Source='')))''')
    if not current.get('truth', False):
        raise ConfigError('task provisioning ownership check failed')
    if current['State'] == 'Retained' and not _startup_installed:
        current['State'] = 'Ready'
    if current['State'] != 'Ready':
        return encode(record('TaskProvisioning', Symbol(current['State'])))
    try:
        provision_startup(expected_owner=current['Source'])
    except ConfigError as error:
        if str(error) == 'configured frame does not match the active Core frame':
            return '(TaskProvisioning TargetMismatch)'
        raise
    if _startup_config is None:
        clear_task_policy()
    status = 'Installed' if _startup_config is not None else 'MissingConfiguration'
    return encode(record('TaskProvisioning', Symbol(status)))


# Example: removing automatic task configuration revokes its old bindings.
def clear_task_policy():
    import janus
    result = janus.query_once('''with_mutex(omegaclaw_dispatch, (
        \\+ mm_dispatch_busy,
        (mm_dispatch_owner(_)
         -> oc_dispatch_mutate((retractall(mm_dispatch_binding(_,_,_)),
              retractall(mm_dispatch_owner(_)), mm_dispatch_set_policies([],[])))
         ; true)))''')
    if not result.get('truth', False):
        raise ConfigError('task policy revocation failed')


def provision_startup(expected_owner=None):
    """Install a checked task owner, or once for explicit standalone host setup."""
    import copy
    import re
    import janus
    global _startup_installed, _startup_checked
    if (expected_owner is None and _startup_installed) or (_startup_config is None and _startup_checked):
        return 1
    current = janus.query_once('''
        with_mutex(omegaclaw_dispatch,
          (eval(['cfv2-root-current-frame-id'], Frame),
           eval([commchannel], Channel),
           (atom(Frame) -> Symbolic=1 ; Symbolic=0)))
    ''')
    frame = current.get('Frame')
    if frame == []:
        return 1  # No active frame yet; missing bindings keep admission closed.
    if not current.get('truth') or not isinstance(frame, str) or not frame:
        raise ConfigError('startup requires a valid active Core frame')
    if not _startup_checked:
        route = None
        if current.get('Channel') == 'irc' and _startup_config and _startup_config.get('destination'):
            from host_operations import _irc_transport
            try:
                route = _irc_transport().route_snapshot()
            except RuntimeError:
                pass  # Report a fixed, credential-free diagnostic below.
        diagnostics = startup_channel_diagnostics(_startup_config, current.get('Channel'), route)
        for diagnostic in diagnostics:
            print('[HostStartup] ' + diagnostic)
        _startup_checked = True
    if _startup_config is None:
        return 1
    configured = _startup_config['frame_id']
    if configured != 'current-frame' and configured != frame:
        raise ConfigError('configured frame does not match the active Core frame')
    if current['Symbolic'] == 1:
        # Serialize only safe native identifiers; never interpret config as code.
        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_-]*', frame):
            raise ConfigError('unsupported native frame identifier')
        frame = Symbol(frame)
    config = copy.deepcopy(_startup_config)
    config['frame_id'] = frame
    source = build_config(config)
    # Guard the native target and installation with the same host mutex. Reuse
    # the existing atomic installer; do not rename or rewrite the Core frame.
    owner_guard = '''sread(OwnerSource, _InstallOwner),
        mm_dispatch_task_owner(_ActualOwner), _ActualOwner == _InstallOwner,
        \\+ mm_dispatch_busy,
    ''' if expected_owner is not None else ''
    query = '''with_mutex(omegaclaw_dispatch, (
        sread(Source, _StartupParsed),
        _StartupParsed = ['HostDispatchConfig', _,
                      ['PolicyScope', [target, ['FrameTarget', Expected]]|_], _],
        eval(['cfv2-root-current-frame-id'], Actual), Actual == Expected,
    ''' + owner_guard + _INSTALL + '))'
    inputs = {'Source': source}
    if expected_owner is not None:
        inputs['OwnerSource'] = expected_owner
    if not janus.query_once(query, inputs).get('truth', False):
        raise ConfigError('startup policy installation failed or active frame changed')
    _startup_installed = True
    return 1
