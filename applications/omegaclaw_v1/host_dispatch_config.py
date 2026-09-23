"""Trusted, explicit session configuration for existing Core inspection handlers.

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


def keys(value, required):
    if not isinstance(value, dict) or set(value) != set(required):
        raise ConfigError("expected exactly these fields: " + ", ".join(required))


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


def binding(command, frame_id, allowed_files):
    keys(command, ("skill", "arguments"))
    skill = command["skill"]
    arguments = items(command["arguments"])
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
    else:
        raise ConfigError("unsupported skill")
    # These two Core handlers perform local reads only. There is no command
    # argument that can add a destination, omit a permission, or change the cost.
    operation = record("PolicyOperation", record("candidate", Symbol(candidate)),
                       record("target", frame_id), record("skill", skill),
                       record("permissions", permissions), record("egress", []),
                       record("costs", [record("ResourceCost", "commands", "units", 1)]))
    request = record("AdmissionRequest", Symbol("propose-candidate"),
                     Symbol("current-frame"), Symbol(candidate))
    return record("HostCommandBinding", record(skill, *arguments), request, operation)


def build_config(value):
    """Build typed data only. No policy is inferred from model text or defaults."""
    keys(value, ("version", "frame_id", "allowed_files", "global", "frame", "commands"))
    if type(value["version"]) is not int or value["version"] != 1:
        raise ConfigError("unsupported host configuration version")
    frame_id = identifier(value["frame_id"])
    files = [allowed_file(path) for path in identifiers(value["allowed_files"])]
    global_scope = scope(value["global"], Symbol("Global"))
    frame_scope = scope(value["frame"], record("FrameTarget", frame_id))
    bindings = [binding(command, frame_id, files) for command in items(value["commands"])]
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
