"""Temporary storage for the real MeTTa identity tests; no logic doubles."""
import tempfile
from pathlib import Path

_directory = None


def ledger_path():
    global _directory
    if _directory is None:
        _directory = tempfile.TemporaryDirectory(prefix="metamo-identities-")
    return str(Path(_directory.name) / "ledger.json")


def cleanup():
    global _directory
    if _directory is not None:
        _directory.cleanup()
        _directory = None
    return "True"
