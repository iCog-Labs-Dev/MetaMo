import os, re, json, subprocess, threading

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


class MettaEngine:
    """Manages execution of Qwestor cycles through the PeTTa runtime."""

    def __init__(self):
        """Initialize the engine with single-flight execution locking."""

        self._lock = threading.Lock()
        self._defaults = None

    def _run_entry(self, entry_file: str, env: dict, marker: str) -> dict:
        """Run a MeTTa service entry point and parse its marked JSON output."""

        with self._lock:
            try:
                result = subprocess.run(
                    ["petta", entry_file],
                    cwd=USECASE_DIR,
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=CYCLE_TIMEOUT_SECONDS,
                )
            except subprocess.TimeoutExpired as exc:
                raise EngineError(f"engine timed out after {CYCLE_TIMEOUT_SECONDS}s") from exc

        output = "\n".join(part for part in (result.stdout, result.stderr) if part)

        if result.returncode != 0:
            raise EngineError(f"petta exited {result.returncode}: {output[-2000:]}")
        if "(Error " in output:
            raise EngineError(f"engine reported a MeTTa error: {output[-2000:]}")

        match = re.search(re.escape(marker) + r"(\{.*\})", output)
        if not match:
            raise EngineError(f"no parseable result from engine: {output[-2000:]}")

        return json.loads(match.group(1))

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
