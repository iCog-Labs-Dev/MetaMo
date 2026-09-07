"""Atomic, versioned storage for committed MetaMo adapter state."""

import hashlib
import json
import os
from pathlib import Path
import tempfile
from time import time


_FORMAT = "omegaclaw-metamo-state"
_DURABLE_TASK_STATE = "(omegaClawTaskStateRecord none inactive no-effect ())"


def _payload_syntax_detail(state):
    """Reject malformed persisted text before it reaches MeTTa's parser."""
    text = str(state).strip()
    if not text or not text.startswith("(") or not text.endswith(")"):
        return "invalid-state-shape"

    depth = 0
    quoted = False
    escaped = False
    for character in text:
        if quoted:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                quoted = False
        elif character == '"':
            quoted = True
        elif character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth < 0:
                return "unbalanced-state"

    if quoted:
        return "unterminated-state-text"
    if depth != 0:
        return "unbalanced-state"
    if "omegaClawTaskStateRecord" in text and _DURABLE_TASK_STATE not in text:
        return "non-durable-task-state"
    return "none"


def _digest(version, state):
    content = f"{_FORMAT}\n{int(version)}\n{state}".encode("utf-8")
    return hashlib.sha256(content).hexdigest()


def _result(status, state="", detail="none"):
    return json.dumps(
        {"status": status, "state": state, "detail": detail},
        ensure_ascii=False,
        separators=(",", ":"),
    )


def save_snapshot(path, version, state):
    """Atomically persist one fully committed adapter state."""
    target = Path(str(path))
    state_text = str(state).strip()
    if not state_text:
        return "save-invalid-state"

    envelope = {
        "format": _FORMAT,
        "version": int(version),
        "state": state_text,
        "checksum": _digest(version, state_text),
    }
    temporary_path = None
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=target.parent,
            prefix=f".{target.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)
            json.dump(envelope, temporary, ensure_ascii=False, indent=2)
            temporary.write("\n")
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_path, target)
        return "saved"
    except (OSError, TypeError, ValueError) as error:
        if temporary_path is not None:
            try:
                temporary_path.unlink(missing_ok=True)
            except OSError:
                pass
        print(
            f"[MetaMoStateStore] save failed: {type(error).__name__}: {error}",
            flush=True,
        )
        return "save-error"


def load_snapshot(path, expected_version):
    """Load and validate the storage envelope without parsing MeTTa state."""
    target = Path(str(path))
    if not target.exists():
        return _result("missing")
    try:
        envelope = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return _result("invalid", detail=f"unreadable-{type(error).__name__}")

    if not isinstance(envelope, dict) or envelope.get("format") != _FORMAT:
        return _result("invalid", detail="unknown-format")
    try:
        version = int(envelope.get("version"))
    except (TypeError, ValueError):
        return _result("invalid", detail="invalid-version")
    if version != int(expected_version):
        return _result("incompatible", detail="version-mismatch")

    state = envelope.get("state")
    checksum = envelope.get("checksum")
    if not isinstance(state, str) or not state.strip():
        return _result("invalid", detail="empty-state")
    if checksum != _digest(version, state):
        return _result("invalid", detail="checksum-mismatch")
    syntax_detail = _payload_syntax_detail(state)
    if syntax_detail != "none":
        return _result("invalid", detail=syntax_detail)
    return _result("loaded", state=state)


def snapshot_field(result, field):
    """Read a stable field from a serialized load result."""
    try:
        decoded = json.loads(str(result))
    except (TypeError, ValueError, json.JSONDecodeError):
        decoded = {"status": "invalid", "state": "", "detail": "bad-result"}
    value = decoded.get(str(field), "")
    return str(value)


def quarantine_snapshot(path, reason="invalid"):
    """Move an unusable snapshot aside so a fresh state can be established."""
    target = Path(str(path))
    if not target.exists():
        return "missing"
    safe_reason = "".join(
        character if character.isalnum() or character in "-_" else "-"
        for character in str(reason)
    ).strip("-") or "invalid"
    quarantine = target.with_name(
        f"{target.name}.{safe_reason}.{int(time())}.invalid"
    )
    try:
        os.replace(target, quarantine)
        return "quarantined"
    except OSError as error:
        print(
            f"[MetaMoStateStore] quarantine failed: "
            f"{type(error).__name__}: {error}",
            flush=True,
        )
        return "quarantine-error"
