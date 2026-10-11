"""Trusted session configuration for Core inspection and local send handlers.

Not a model skill. Call provision from trusted host code after initMetaMoDispatch.
The host owns this file and the configured filesystem paths throughout the session.
Only command-count costs are modeled here; reservation/settlement is separate.
"""
import json
from pathlib import Path
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
    """
    keys(value, ("channel", "recipient"))
    channel = identifier(value["channel"])
    recipient = identifier(value["recipient"])
    if channel != "local" or recipient != "stdout":
        raise ConfigError("unsupported destination; expected local/stdout")
    return record("HostDestination", record("channel", channel),
                  record("recipient", recipient),
                  record("permissions", ["channels.send", "channels.send:local:stdout"]),
                  record("egress", ["local:stdout"]))


def binding(command, frame_id, allowed_files, destination=None):
    keys(command, ("skill", "arguments"))
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
        if (len(arguments) != 1 or type(arguments[0]) is not str
                or not arguments[0].strip() or len(arguments[0]) > 1200
                or any(ord(c) < 32 and c not in "\n\t" for c in arguments[0])):
            raise ConfigError("send requires one nonblank text argument of at most 1200 characters")
        metadata = dict(destination_metadata(destination)[1:])
        candidate = "respond"
        permissions = metadata["permissions"]
        egress = metadata["egress"]
    else:
        raise ConfigError("unsupported skill")
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
           mm_dispatch_register(_Command, _Request, _Operation))
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


def configure_startup(path=None):
    """Read trusted startup configuration once, before starting external services.

    frame_id="current-frame" explicitly binds once to the first active native
    frame. A concrete ID must match that frame. No grants follow frame switches.
    """
    import os
    global _startup_config, _startup_installed
    selected = path if path is not None else os.environ.get('OMEGACLAW_HOST_CONFIG')
    config = read_config(selected) if selected else None
    if config is not None:
        build_config(config)
    _startup_config = config
    _startup_installed = False
    return 1


def provision_startup():
    """Called by Core after ingestion/maintenance and before first selection."""
    import copy
    import re
    import janus
    global _startup_installed
    if _startup_config is None or _startup_installed:
        return 1
    current = janus.query_once('''
        with_mutex(omegaclaw_dispatch,
          (eval(['cfv2-root-current-frame-id'], Frame),
           (atom(Frame) -> Symbolic=1 ; Symbolic=0)))
    ''')
    frame = current.get('Frame')
    if frame == []:
        return 1  # No active frame yet; missing bindings keep admission closed.
    if not current.get('truth') or not isinstance(frame, str) or not frame:
        raise ConfigError('startup requires a valid active Core frame')
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
    query = '''with_mutex(omegaclaw_dispatch, (
        sread(Source, _StartupParsed),
        _StartupParsed = ['HostDispatchConfig', _,
                      ['PolicyScope', [target, ['FrameTarget', Expected]]|_], _],
        eval(['cfv2-root-current-frame-id'], Actual), Actual == Expected,
    ''' + _INSTALL + '))'
    if not janus.query_once(query, {'Source': source}).get('truth', False):
        raise ConfigError('startup policy installation failed or active frame changed')
    _startup_installed = True
    return 1
