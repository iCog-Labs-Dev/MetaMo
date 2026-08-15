import json
import os
import signal
import subprocess
import threading

USECASE_DIR = os.environ.get("QWESTOR_USECASE_DIR", "/app/usecase")
CYCLE_ENTRY_FILE = "service_cycle_entry.metta"
DEFAULTS_ENTRY_FILE = "service_defaults_entry.metta"
RESULT_MARKER = "@@QWESTOR_RESULT@@"
DEFAULTS_MARKER = "@@QWESTOR_DEFAULTS@@"
CYCLE_TIMEOUT_SECONDS = int(os.environ.get("QWESTOR_CYCLE_TIMEOUT", "60"))

"""
MeTTa engine execution interface.

Provides a thread-safe wrapper around the PeTTa runtime for executing
Qwestor reasoning cycles, handling process execution, timeouts, errors,
and parsing structured cycle results.
"""

class EngineError(RuntimeError):
    """Raised when the MeTTa engine execution fails."""
    pass


def _extract_marked_json(output: str, marker: str) -> dict:
    """Decode the JSON object following the final result marker."""

    marker_index = output.rfind(marker)
    if marker_index == -1:
        raise EngineError(f"no parseable result from engine: {output[-2000:]}")

    payload = output[marker_index + len(marker):].lstrip()
    try:
        value, _ = json.JSONDecoder().raw_decode(payload)
    except json.JSONDecodeError as exc:
        raise EngineError(f"invalid JSON result from engine: {output[-2000:]}") from exc

    if not isinstance(value, dict):
        raise EngineError(f"engine result must be a JSON object: {output[-2000:]}")
    return value


class MettaEngine:
    """Manages execution of Qwestor cycles through the PeTTa runtime."""

    def __init__(self):
        """Initialize the engine with single-flight execution locking."""

        self._lock = threading.Lock()
        self._defaults = None

    def _run_entry(self, entry_file: str, env: dict, marker: str) -> dict:
        """Run a MeTTa service entry point and parse its marked JSON output."""

        with self._lock:
            process = subprocess.Popen(
                ["petta", entry_file],
                cwd=USECASE_DIR,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                start_new_session=True,
            )
            try:
                stdout, stderr = process.communicate(timeout=CYCLE_TIMEOUT_SECONDS)
            except subprocess.TimeoutExpired as exc:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    stdout, stderr = process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    stdout, stderr = process.communicate()

                partial_output = "\n".join(
                    part for part in (stdout, stderr) if part
                )
                detail = f": {partial_output[-2000:]}" if partial_output else ""
                raise EngineError(
                    f"engine timed out after {CYCLE_TIMEOUT_SECONDS}s{detail}"
                ) from exc

        output = "\n".join(part for part in (stdout, stderr) if part)

        if process.returncode != 0:
            raise EngineError(f"petta exited {process.returncode}: {output[-2000:]}")
        if "(Error " in output:
            raise EngineError(f"engine reported a MeTTa error: {output[-2000:]}")

        return _extract_marked_json(output, marker)

    def load_defaults(self) -> dict:
        """Load and cache the canonical session defaults from config.metta."""

        if self._defaults is None:
            self._defaults = self._run_entry(
                DEFAULTS_ENTRY_FILE,
                os.environ.copy(),
                DEFAULTS_MARKER,
            )
        return self._defaults

    def run_cycle(self, session_id: str, query: str) -> dict:
        """
        Execute a Qwestor reasoning cycle.

        Runs the configured MeTTa entry file with session context,
        validates execution results, and returns the parsed engine output.
        """
        env = os.environ.copy()
        env["QWESTOR_SESSION_ID"] = session_id
        env["QWESTOR_QUERY"] = query

        return self._run_entry(CYCLE_ENTRY_FILE, env, RESULT_MARKER)


engine = MettaEngine()
