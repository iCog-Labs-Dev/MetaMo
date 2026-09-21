"""Trusted host UUID and storage primitives; causal rules live in MeTTa.

No model skills are registered. The host must hold its dispatch/mutation lock
while using these APIs to capture authoritative state or start execution.
This file stores opaque MeTTa data, never evaluates it, and never authorizes work.
"""
from __future__ import annotations

import copy
import fcntl
import json
import os
from pathlib import Path
import tempfile
import threading
import uuid

_lock = threading.RLock()
_path = None
_file_lock = None
_state = None
_roles = ("host", "metamo", "scheduler", "nars", "pln", "llm",
          "rule-engine", "human-adapter", "verification", "executor")


def _reject(reason):
    return f"(ContractRejection {reason} None None None)"


def _text(value):
    return isinstance(value, str) and 0 < len(value) <= 256


def _write(state):
    """Commit one image before publishing its contents in memory."""
    global _state
    fd, name = tempfile.mkstemp(prefix=_path.name + ".", dir=_path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(state, stream, ensure_ascii=False)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, _path)
        # Commit the directory entry too. Unsupported fsync is a storage error,
        # never a reason to report successful identity publication.
        directory = os.open(_path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
        _state = state
    except OSError:
        # Rename may already have committed. Do not continue from stale memory;
        # close/resume must reconcile the on-disk image before any further write.
        _state = None
        raise
    finally:
        if os.path.exists(name):
            os.unlink(name)


def open_ledger(path, expected_host=""):
    """Empty expected_host creates; nonempty resumes that exact lineage.

    Missing/corrupt ledgers are never silently recreated. Restoring a backup or
    forking host state requires an explicitly new path/lineage, not resume.
    """
    global _path, _file_lock, _state
    with _lock:
        if _state is not None or _file_lock is not None:
            return _reject("AlreadyOpen")
        _path = Path(path).resolve()
        lock = open(str(_path) + ".lock", "a", encoding="utf-8")
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if expected_host:
                if not _path.exists():
                    return _reject("MissingReference")
                state = json.loads(_path.read_text(encoding="utf-8"))
                if not _valid_image(state):
                    return _reject("MalformedRecord")
                if state["host"] != expected_host:
                    return _reject("IdentityConflict")
                _state = state
            else:
                if _path.exists():
                    return _reject("IdentityConflict")
                producers = {role: str(uuid.uuid4()) for role in _roles}
                _write({"version": 1, "host": producers["host"],
                        "producers": producers, "entries": []})
            _file_lock = lock
            return f'(IdentityHost {json.dumps(_state["host"])})'
        except (ValueError, KeyError, TypeError):
            return _reject("MalformedRecord")
        finally:
            if _file_lock is not lock:
                lock.close()
                _state = None
                _path = None


def _valid_image(state):
    if not isinstance(state, dict) or state.get("version") != 1:
        return False
    producers, entries = state.get("producers"), state.get("entries")
    if not isinstance(producers, dict) or set(producers) != set(_roles):
        return False
    if not all(_text(p) for p in producers.values()) or len(set(producers.values())) != len(_roles):
        return False
    if state.get("host") != producers["host"] or not isinstance(entries, list):
        return False
    keys, causes, types = set(), set(), {}
    for e in entries:
        if not isinstance(e, dict) or set(e) != {"kind", "namespace", "id", "revision", "cause", "data"}:
            return False
        if not all(_text(e[k]) for k in ("kind", "namespace", "id")) or e["namespace"] not in producers.values():
            return False
        if not isinstance(e["revision"], str) or not isinstance(e["cause"], str):
            return False
        if e["data"] is not None and not isinstance(e["data"], str):
            return False
        key = (e["namespace"], e["id"], e["revision"])
        type_key = key[:2]
        if key in keys or types.get(type_key, e["kind"]) != e["kind"]:
            return False
        keys.add(key)
        types[type_key] = e["kind"]
        if e["cause"]:
            cause = (e["kind"], e["cause"])
            if cause in causes:
                return False
            causes.add(cause)
    return True


def close_ledger():
    global _path, _file_lock, _state
    with _lock:
        if _file_lock is not None:
            _file_lock.close()
        _path = _file_lock = _state = None
    return True


def producer(role):
    with _lock:
        if _state is None:
            return _reject("NotInitialized")
        value = _state["producers"].get(role)
        return json.dumps(value) if value else _reject("InvalidProducer")


def reserve(role, kind, cause=""):
    """Allocate once for a durable cause (directive/dispatch), or fresh if empty.

    An unfinished reservation survives restart. It is not an execution claim.
    """
    with _lock:
        if _state is None:
            return _reject("NotInitialized")
        namespace = _state["producers"].get(role)
        if not namespace or not _text(kind) or not isinstance(cause, str):
            return _reject("InvalidValue")
        if cause:
            old = next((e for e in _state["entries"] if e["kind"] == kind and e["cause"] == cause), None)
            if old:
                if old["namespace"] != namespace:
                    return _reject("IdentityConflict")
                return f'(IdentityAllocation {json.dumps(namespace)} {json.dumps(old["id"])})'
        state = copy.deepcopy(_state)
        occupied = {e["id"] for e in state["entries"]}
        identifier = str(uuid.uuid4())
        while identifier in occupied:
            identifier = str(uuid.uuid4())
        state["entries"].append(dict(kind=kind, namespace=namespace, id=identifier,
                                     revision="", cause=cause, data=None))
        _write(state)
        return f'(IdentityAllocation {json.dumps(namespace)} {json.dumps(identifier)})'


def resolve(kind, namespace, identifier, revision=""):
    with _lock:
        if _state is None:
            return _reject("NotInitialized")
        same_id = [e for e in _state["entries"] if e["namespace"] == namespace and e["id"] == identifier]
        if any(e["kind"] != kind for e in same_id):
            return _reject("MalformedRecord")
        entry = next((e for e in same_id if e["revision"] == revision), None)
        return entry["data"] if entry and entry["data"] is not None else _reject("MissingReference")


def lookup_cause(kind, cause):
    """Read a prior allocation without reserving one (including unfinished IDs)."""
    with _lock:
        if _state is None:
            return _reject("NotInitialized")
        entry = next((e for e in _state["entries"] if e["kind"] == kind and e["cause"] == cause), None)
        if entry is None:
            return "IdentityUnallocated"
        return f'(IdentityAllocation {json.dumps(entry["namespace"])} {json.dumps(entry["id"])})'


def commit(kind, namespace, identifier, revision, data, mode="record"):
    """Persist opaque data under a reservation, or adopt a native entity ID.

    Same ID/version + same content is idempotent. Existing versions remain
    reserved forever; there is no delete/reset API. Causal checks are in MeTTa.
    """
    with _lock:
        if _state is None:
            return _reject("NotInitialized")
        if not all(_text(x) for x in (kind, namespace, identifier)) or not isinstance(data, str):
            return _reject("InvalidValue")
        same_id = [e for e in _state["entries"] if e["namespace"] == namespace and e["id"] == identifier]
        if any(e["kind"] != kind for e in same_id):
            return _reject("IdentityConflict")
        old = next((e for e in same_id if e["revision"] == revision), None)
        if old and old["data"] is not None:
            return data if old["data"] == data else _reject("IdentityConflict")
        if mode not in ("entity", "record"):
            return _reject("InvalidValue")
        if mode == "entity":
            if namespace != _state["host"] or not revision.isdecimal():
                return _reject("InvalidValue")
            if same_id and int(revision) != max(int(e["revision"]) for e in same_id) + 1:
                return _reject("InvalidValue")
        elif not old:
            return _reject("MissingReference")
        state = copy.deepcopy(_state)
        if old:
            state["entries"][_state["entries"].index(old)]["data"] = data
        else:
            state["entries"].append(dict(kind=kind, namespace=namespace, id=identifier,
                                         revision=revision, cause="", data=data))
        _write(state)
        return data
