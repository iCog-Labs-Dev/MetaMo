"""Temporary trusted config for real host provisioning/dispatch tests."""
import copy
import json
from pathlib import Path
import tempfile

_temp = None
_config = None
_path = None


def setup():
    global _temp, _config, _path
    _temp = tempfile.TemporaryDirectory(prefix="omegaclaw-host-config-")
    root = Path(_temp.name).resolve()
    data = root / 'input "quoted".txt'
    data.write_text("observed local file content", encoding="utf-8")
    _config = json.loads((Path(__file__).resolve().parents[2] / "host_dispatch.example.json").read_text())
    _config["frame_id"] = "configured-frame"
    _config["allowed_files"] = [str(data)]
    _config["commands"][0]["arguments"] = [str(data)]
    for name in ("global", "frame"):
        _config[name]["permissions"] = ["files.read", "files.read:" + str(data), "frames.read"]
    _path = root / "host.json"
    return write("allowed")


def write(variant):
    config = copy.deepcopy(_config)
    if variant == "permission-denied":
        config["frame"]["permissions"] = ["frames.read"]
    elif variant == "frame-denied":
        config["frame"]["permissions"] = ["files.read"]
    elif variant == "ambiguous":
        other = _path.parent / "other.txt"
        other.write_text("other content", encoding="utf-8")
        config["allowed_files"].append(str(other))
        config["commands"].append({"skill": "read-file", "arguments": [str(other)]})
        for scope in ("global", "frame"):
            config[scope]["permissions"].append("files.read:" + str(other))
    elif variant == "global-denied":
        config["global"]["skills"] = []
    elif variant == "budget-denied":
        config["frame"]["budgets"][0]["available"] = 0
    elif variant == "constraint-denied":
        config["frame"]["constraints"].append(["DenySkill", "read-file"])
    elif variant == "cost-denied":
        config["global"]["constraints"] = [["MaxCost", "commands", "units", 0]]
    elif variant == "empty":
        config["commands"] = []
    elif variant == "invalid":
        config["frame"]["constraints"].append(["UnimplementedConstraint", "x"])
    elif variant != "allowed":
        raise ValueError("unknown fixture variant")
    _path.write_text(json.dumps(config), encoding="utf-8")
    return str(_path)


def command():
    return '(read-file ' + json.dumps(_config["allowed_files"][0]) + ')'


def revoke_frame_command():
    import janus
    return int(janus.query_once("mm_dispatch_revoke(['show-current-frame'])")["truth"])


def set_frame_status(status):
    import janus
    if status not in ("Blocked", "Active"):
        raise ValueError("unsupported fixture status")
    return int(janus.query_once(
        "sread(Source, _Command), oc_dispatch_mutate(eval(_Command, _))",
        {"Source": "(change-state! &cfv2-current-status " + status + ")"},
    )["truth"])


def replace_file_content():
    Path(_config["allowed_files"][0]).write_text("changed after invocation", encoding="utf-8")
    return 1


def install_failure_handler():
    import janus
    return int(janus.query_once("""
oc_dispatch_mutate((
    mm_dispatch_binding(_Command, _Request, _Operation), _Command=['read-file',_],
    mm_dispatch_revoke(_Command),
    mm_dispatch_register(['outcome-test-failure'], _Request, _Operation)
))
""")["truth"])


def remove_file():
    Path(_config["allowed_files"][0]).unlink()
    return 1


def rejects_invalid():
    import host_dispatch_config
    try:
        host_dispatch_config.provision(write("invalid"))
    except host_dispatch_config.ConfigError:
        return 1
    return 0


def cleanup():
    _temp.cleanup()
    return 1
