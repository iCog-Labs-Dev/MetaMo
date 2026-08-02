import os, re, json, subprocess, threading

USECASE_DIR = os.environ.get("QWESTOR_USECASE_DIR", "/app/usecase")
CYCLE_ENTRY_FILE = "service_cycle_entry.metta"
RESULT_MARKER = "@@QWESTOR_RESULT@@"
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

    def run_cycle(self, session_id: str, query: str) -> dict:
        """
        Execute a Qwestor reasoning cycle.

        Runs the configured MeTTa entry file with session context,
        validates execution results, and returns the parsed engine output.
        """
        env = os.environ.copy()
        env["QWESTOR_SESSION_ID"] = session_id
        env["QWESTOR_QUERY"] = query  # passed via env var, never embedded in .metta source

        with self._lock:
            try:
                result = subprocess.run(
                    ["petta", CYCLE_ENTRY_FILE],
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

        match = re.search(re.escape(RESULT_MARKER) + r"(\{.*\})", output)
        if not match:
            raise EngineError(f"no parseable result from engine: {output[-2000:]}")

        return json.loads(match.group(1))


engine = MettaEngine()