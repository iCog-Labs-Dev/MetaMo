"""Read-only workspace command policy for autonomous OmegaClaw turns.

The MetaMo adapter treats a shell command as an effect unless this module can
prove that it is a single, bounded inspection command. Unknown syntax and
commands are denied.
"""

import json
import shlex
import shutil
import subprocess
import time


READ_ONLY_COMMANDS = {
    "pwd",
    "ls",
    "rg",
    "grep",
    "head",
    "tail",
    "wc",
    "stat",
    "file",
}

READ_ONLY_GIT_COMMANDS = {
    "status",
    "diff",
    "log",
    "show",
    "ls-files",
    "grep",
    "rev-parse",
}

SHELL_CONTROL_TOKENS = (";", "&&", "||", "|", ">", "<", "`", "\n", "\r")
SHELL_EXPANSIONS = ("$(", "${")
MUTATING_FIND_OPTIONS = {
    "-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fprintf"
}
EXECUTING_RG_OPTIONS = {"--pre", "--pre-glob"}
MUTATING_GIT_OPTIONS = {
    "--output",
    "--ext-diff",
    "--textconv",
    "--config-env",
}
UNBOUNDED_TEXT_SUFFIXES = {".log"}
SHELL_OUTPUT_LIMIT = 12000

EMPTY_RESULT_EXIT_CODES = {
    "grep": {1},
    "rg": {1},
}


def monotonic_seconds():
    """Return a process-local monotonic timestamp for lifecycle diagnostics."""

    return time.perf_counter()


def safe_workspace_path(path):
    """Return a MeTTa boolean atom for a syntactically local relative path."""

    text = str(path).strip()
    allowed = bool(text) and _within_workspace(text)
    return "true" if allowed else "false"


def workspace_path_reason(path):
    """Explain why a workspace path is accepted or rejected.

    The returned atoms are consumed by the MeTTa realization contract so the
    next proposal can correct the actual policy violation instead of seeing a
    generic blocked-command result.
    """

    text = str(path).strip()
    if not text:
        return "empty-path"
    normalized = text.replace("\\", "/")
    if normalized.startswith(("/", "~/")) or (
        len(normalized) >= 3
        and normalized[1] == ":"
        and normalized[2] == "/"
    ):
        return "absolute-path-not-allowed"
    if ".." in normalized.split("/"):
        return "parent-path-not-allowed"
    if any(normalized.lower().endswith(suffix) for suffix in UNBOUNDED_TEXT_SUFFIXES):
        return "unbounded-log-read-not-allowed"
    return "ok"


def bounded_content(value, maximum):
    """Return a MeTTa boolean atom when generated content stays bounded."""

    text = str(value)
    allowed = "\x00" not in text and len(text) <= int(maximum)
    return "true" if allowed else "false"


def _within_workspace(token):
    normalized = token.replace("\\", "/")
    if normalized.startswith(("/", "~/")):
        return False
    return ".." not in normalized.split("/")


def _arguments_stay_local(tokens):
    for token in tokens:
        if token.startswith("-"):
            continue
        if not _within_workspace(token):
            return False
    return True


def _safe_find(tokens):
    lowered = {token.lower() for token in tokens[1:]}
    if lowered.intersection(MUTATING_FIND_OPTIONS):
        return False
    try:
        depth_index = [token.lower() for token in tokens].index("-maxdepth")
        maximum_depth = int(tokens[depth_index + 1])
    except (ValueError, IndexError):
        return False
    return (
        0 <= maximum_depth <= 5
        and _arguments_stay_local(tokens[1:])
    )


def _safe_rg(tokens):
    lowered = [token.lower() for token in tokens[1:]]
    if any(
        token == option or token.startswith(option + "=")
        for token in lowered
        for option in EXECUTING_RG_OPTIONS
    ):
        return False
    positional = [token for token in tokens[1:] if not token.startswith("-")]
    return (
        _arguments_stay_local(tokens[1:])
        and len(positional) >= 2
        and positional[-1] not in {".", "./"}
    )


def _safe_grep(tokens):
    recursive = any(
        token in {"-r", "-R", "--recursive"}
        or (token.startswith("-") and not token.startswith("--")
            and "r" in token.lower()[1:])
        for token in tokens[1:]
    )
    positional = [token for token in tokens[1:] if not token.startswith("-")]
    return (
        not recursive
        and len(positional) >= 2
        and _arguments_stay_local(tokens[1:])
    )


def _safe_git(tokens):
    if len(tokens) < 2 or tokens[1] not in READ_ONLY_GIT_COMMANDS:
        return False
    lowered = [token.lower() for token in tokens[2:]]
    if any(
        token == option or token.startswith(option + "=")
        for token in lowered
        for option in MUTATING_GIT_OPTIONS
    ):
        return False
    return _arguments_stay_local(tokens[2:])


def safe_workspace_shell(command):
    """Return a MeTTa boolean atom for a recognized workspace inspection."""

    text = str(command).strip()
    if not text:
        return "false"
    if any(token in text for token in SHELL_CONTROL_TOKENS + SHELL_EXPANSIONS):
        return "false"

    try:
        tokens = shlex.split(text, posix=True)
    except ValueError:
        return "false"

    if not tokens:
        return "false"

    command_name = tokens[0].lower()
    if command_name == "find":
        allowed = _safe_find(tokens)
        return "true" if allowed else "false"
    if command_name == "rg":
        allowed = _safe_rg(tokens)
        return "true" if allowed else "false"
    if command_name == "grep":
        allowed = _safe_grep(tokens)
        return "true" if allowed else "false"
    if command_name == "git":
        allowed = _safe_git(tokens)
        return "true" if allowed else "false"
    if command_name not in READ_ONLY_COMMANDS:
        return "false"
    allowed = _arguments_stay_local(tokens[1:])
    return "true" if allowed else "false"


def workspace_shell_reason(command):
    """Return a stable rejection reason for autonomous shell inspection."""

    text = str(command).strip()
    if not text:
        return "empty-shell-command"
    if any(token in text for token in SHELL_CONTROL_TOKENS + SHELL_EXPANSIONS):
        return "shell-control-operator-not-allowed"
    try:
        tokens = shlex.split(text, posix=True)
    except ValueError:
        return "malformed-shell-command"
    if not tokens:
        return "empty-shell-command"
    if safe_workspace_shell(text) == "true":
        return "ok"
    if not _arguments_stay_local(tokens[1:]):
        return "workspace-path-not-allowed"
    if tokens[0].lower() == "find" and "-maxdepth" not in {
        token.lower() for token in tokens[1:]
    }:
        return "bounded-depth-required"
    if tokens[0].lower() == "grep":
        return "recursive-grep-not-allowed"
    if tokens[0].lower() == "rg":
        return "bounded-search-root-required"
    return "shell-command-not-read-only"


def available_workspace_commands():
    """Return the read-only command names actually available to the host."""

    candidates = set(READ_ONLY_COMMANDS) | {"find", "git"}
    return " ".join(sorted(name for name in candidates if shutil.which(name)))


def execute_shell_command(command, timeout_seconds=5.0):
    """Execute a contract-approved shell command with structured status.

    OmegaClaw-Core's shell primitive returns combined output but discards the
    process exit status.  The local integration needs both facts so MetaMo can
    distinguish useful evidence, an empty successful result, and execution
    failure. Authorization remains in the MeTTa realization contract.
    """

    text = str(command).strip()
    if not text:
        return _shell_result("invalid", -1, "empty shell command")
    if safe_workspace_shell(text) != "true":
        return _shell_result("invalid", -1, workspace_shell_reason(text))

    try:
        tokens = shlex.split(text, posix=True)
    except ValueError:
        return _shell_result("invalid", -1, "malformed-shell-command")

    try:
        completed = subprocess.run(
            tokens,
            shell=False,
            capture_output=True,
            text=True,
            timeout=max(0.01, float(timeout_seconds)),
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        output = _combined_output(error.stdout, error.stderr)
        return _shell_result("timeout", -1, output)
    except OSError as error:
        return _shell_result("unavailable", -1, str(error))

    output = _combined_output(completed.stdout, completed.stderr)
    command_name = tokens[0].lower()
    if completed.returncode in EMPTY_RESULT_EXIT_CODES.get(command_name, set()):
        status = "empty"
    elif completed.returncode != 0:
        status = "failure"
    elif output:
        status = "success"
    else:
        status = "empty"
    return _shell_result(status, completed.returncode, output)


def shell_result_field(serialized_result, field):
    """Read one stable field from ``execute_shell_command`` output."""

    try:
        result = json.loads(str(serialized_result))
    except (TypeError, ValueError, json.JSONDecodeError):
        result = {
            "status": "invalid",
            "exit_code": -1,
            "output": "malformed structured shell result",
        }

    if field == "status":
        return str(result.get("status", "invalid"))
    if field == "exit-code":
        try:
            return int(result.get("exit_code", -1))
        except (TypeError, ValueError):
            return -1
    if field == "output":
        return str(result.get("output", ""))
    return "unknown-field"


def _combined_output(stdout, stderr):
    parts = []
    for value in (stdout, stderr):
        if value:
            parts.append(str(value).strip())
    return "\n".join(part for part in parts if part)[:SHELL_OUTPUT_LIMIT]


def _shell_result(status, exit_code, output):
    return json.dumps(
        {
            "status": status,
            "exit_code": int(exit_code),
            "output": str(output)[:SHELL_OUTPUT_LIMIT],
        },
        ensure_ascii=False,
    )
