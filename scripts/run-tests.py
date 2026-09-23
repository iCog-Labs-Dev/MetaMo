#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import pathlib
import re
import signal
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed


TEST_SUFFIXES = ("-test", "-tests", "_test", "_tests")
IGNORED_DIRS = {
    ".git",
    ".mypy_cache",
    ".pytest_cache",
    ".venv",
    "__pycache__",
    "node_modules",
    "venv",
    ".ci",
}
PASS_MARKER = "\u2705"
FAIL_MARKER = "\u274c"
REPO = pathlib.Path(__file__).resolve().parent.parent
V1 = REPO / "applications/omegaclaw_v1"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run MetaMo MeTTa tests through a PeTTa checkout."
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root to search for MeTTa test files.",
    )
    parser.add_argument(
        "--petta-runner",
        help="Path to PeTTa's run.sh. Defaults to PETTA_RUNNER, PETTA_PATH/run.sh, then the enclosing workspace.",
    )
    parser.add_argument("--import-report-dir", type=pathlib.Path,
                        help="Write one v1 import-resolution JSON report per test")
    parser.add_argument("--exclude", action="append", type=pathlib.Path, default=[],
                        help="Exclude a subtree relative to --root (repeatable)")
    parser.add_argument(
        "--jobs",
        type=int,
        default=int(os.environ.get("METTA_TEST_JOBS", "1")),
        help="Number of test files to run concurrently.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=int(os.environ.get("METTA_TEST_TIMEOUT", "300")),
        help="Timeout per test file in seconds.",
    )
    parser.add_argument(
        "--allow-empty",
        action="store_true",
        help="Exit successfully when no matching MeTTa test files are found.",
    )
    return parser.parse_args()


def is_ignored(path: pathlib.Path) -> bool:
    return any(part in IGNORED_DIRS for part in path.parts)


def is_metta_test(path: pathlib.Path) -> bool:
    return path.suffix == ".metta" and path.stem.endswith(TEST_SUFFIXES)


def discover_tests(root: pathlib.Path) -> list[pathlib.Path]:
    tests = [
        path
        for path in root.rglob("*.metta")
        if not is_ignored(path) and is_metta_test(path)
    ]
    return sorted(tests)


def resolve_petta_runner(root: pathlib.Path, explicit_runner: str | None) -> pathlib.Path:
    candidates: list[pathlib.Path] = []

    env_runner = os.environ.get("PETTA_RUNNER")
    env_path = os.environ.get("PETTA_PATH")
    selected = explicit_runner or env_runner or (str(pathlib.Path(env_path) / "run.sh") if env_path else None)
    if selected:
        path = pathlib.Path(selected).expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f"Selected PeTTa runner does not exist: {path}")
        return path

    candidates.append(REPO.parent / "run.sh")

    path_runner = shutil.which("run.sh")
    if path_runner:
        candidates.append(pathlib.Path(path_runner))

    candidates.append(root.parent / "PeTTa" / "run.sh")

    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()

    searched = "\n".join(f"  - {candidate}" for candidate in candidates)
    raise FileNotFoundError(
        "Could not find PeTTa run.sh. Set PETTA_PATH, PETTA_RUNNER, or pass "
        f"--petta-runner.\nSearched:\n{searched}"
    )


def count_test_forms(path: pathlib.Path, seen: set[pathlib.Path] | None = None) -> int:
    # Tokenize strings/comments before counting: assertions can span lines or
    # share one line, and literal examples must not count as assertions.
    seen = set() if seen is None else seen
    path = path.resolve()
    if path in seen:
        return 0
    seen.add(path)
    source = path.read_text(encoding="utf-8")
    # Preserve quoted import paths while stripping comments.
    source = re.sub(r'"(?:\\.|[^"\\])*"|;[^\n]*',
                    lambda m: " " if m[0].startswith(";") else m[0], source)
    code = re.sub(r'"(?:\\.|[^"\\])*"', " ", source)
    count = len(re.findall(r"!\s*\(\s*test(?=\s|\))", code))
    # Include statically imported local/MetaMo assertions, notably the shared
    # regression wrappers. Count each physical file once, like the v1 loader.
    imports = re.finditer(
        r'!\s*\(\s*import!\s+&self\s+(?:\(\s*library\s+MetaMo\s+([^\s()]+)\s*\)|"([^"\n]+)"|([^\s()]+))\s*\)',
        source)
    for match in imports:
        named, quoted, relative = match.groups()
        imported = REPO / named if named else path.parent / (quoted or relative)
        if not imported.suffix:
            imported = imported.with_suffix(".metta")
        if imported.suffix == ".metta" and imported.is_file():
            count += count_test_forms(imported, seen)
    return count


def run_test_file(
    root: pathlib.Path,
    petta_runner: pathlib.Path,
    test_file: pathlib.Path,
    timeout: int,
    report_dir: pathlib.Path | None = None,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["SHELL"] = "/bin/bash"

    if test_file.is_relative_to(V1):
        command = [sys.executable, str(REPO / "scripts/run-omegaclaw.py"),
                   str(test_file), "--workspace", str(petta_runner.parent)]
        if report_dir:
            report = report_dir / test_file.relative_to(V1).with_suffix(".json")
            report.parent.mkdir(parents=True, exist_ok=True)
            command.extend(["--report", str(report)])
    else:
        command = ["sh", str(petta_runner), str(test_file), "-s"]
    return run_captured(
        command,
        cwd=petta_runner.parent,
        env=env,
        timeout=timeout,
    )


def run_captured(command, *, cwd, env, timeout):
    # The shell/launcher spawns an interpreter. Kill the whole isolated process
    # group on timeout so descendants cannot keep pipes open or continue work.
    with subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True, errors="replace",
                          start_new_session=True) as process:
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            stdout, stderr = process.communicate()
            raise subprocess.TimeoutExpired(command, timeout, output=stdout,
                                            stderr=stderr) from None
        return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)


def output_tail(output: str, max_lines: int = 80) -> str:
    lines = output.strip().splitlines()
    return "\n".join(lines[-max_lines:])


def captured_text(value: str | bytes | None) -> str:
    return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")


def summarize_result(
    path: pathlib.Path,
    result: subprocess.CompletedProcess[str],
) -> tuple[bool, str]:
    output = "\n".join(part for part in (result.stdout, result.stderr) if part)
    expected_tests = count_test_forms(path)
    # Count interpreter assertion records, not emoji printed by arbitrary code.
    passed = len(re.findall(r"^is .*?, should .*?\. ✅\s*$", output, re.MULTILINE))
    failed = output.count(FAIL_MARKER)

    if result.returncode != 0:
        return (
            False,
            f"exit code {result.returncode}; {passed} passed marker(s), {failed} failed marker(s)",
        )

    if failed:
        return False, f"{failed} failed marker(s), {passed} passed marker(s)"

    if re.search(r"^\s*(?:ERROR:|Traceback \(most recent call last\):)|\(Error(?:\s|\))",
                 output, re.MULTILINE):
        return False, "interpreter/import error in output (even though exit code was zero)"

    if expected_tests and passed < expected_tests:
        return (
            False,
            f"expected {expected_tests} test marker(s), saw {passed}",
        )

    if expected_tests == 0 and passed == 0:
        return False, "file matched test naming convention but produced no test markers"

    return True, f"{passed}/{expected_tests or passed} test marker(s) passed"


def main() -> int:
    args = parse_args()
    root = pathlib.Path(args.root).resolve()
    jobs = max(1, args.jobs)
    tests = discover_tests(root)
    excluded = [(root / path).resolve() for path in args.exclude]
    tests = [test for test in tests if not any(test.is_relative_to(path) for path in excluded)]

    if not tests:
        suffixes = ", ".join(f"*{suffix}.metta" for suffix in TEST_SUFFIXES)
        print(f"No MeTTa test files found. Expected one of: {suffixes}")
        return 0 if args.allow_empty else 1

    try:
        petta_runner = resolve_petta_runner(root, args.petta_runner)
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        return 1

    print(f"PeTTa runner: {petta_runner}")
    print(f"Discovered {len(tests)} MeTTa test file(s):")
    for test in tests:
        print(f"  - {test.relative_to(root)}")

    failures: list[tuple[pathlib.Path, str, str]] = []

    with ThreadPoolExecutor(max_workers=jobs) as executor:
        future_to_test = {
            executor.submit(run_test_file, root, petta_runner, test, args.timeout,
                            args.import_report_dir.resolve() if args.import_report_dir else None): test
            for test in tests
        }

        for future in as_completed(future_to_test):
            test = future_to_test[future]
            rel_test = test.relative_to(root)

            try:
                result = future.result()
            except subprocess.TimeoutExpired as exc:
                message = f"timed out after {args.timeout}s"
                output = "\n".join(captured_text(part) for part in (exc.stdout, exc.stderr) if part)
                failures.append((test, message, output))
                print(f"FAIL {rel_test}: {message}")
                continue
            except Exception as exc:  # pragma: no cover - defensive CI reporting
                message = f"runner exception: {exc}"
                failures.append((test, message, ""))
                print(f"FAIL {rel_test}: {message}")
                continue

            passed, message = summarize_result(test, result)
            print(f"{'PASS' if passed else 'FAIL'} {rel_test}: {message}")

            if not passed:
                output = "\n".join(
                    part for part in (result.stdout, result.stderr) if part
                )
                failures.append((test, message, output))

    if failures:
        print("\nFailed MeTTa test file(s):")
        for test, message, output in failures:
            print(f"\n--- {test.relative_to(root)} ---")
            print(message)
            if output.strip():
                print(output_tail(output))
        return 1

    print(f"\nAll {len(tests)} MeTTa test file(s) passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
